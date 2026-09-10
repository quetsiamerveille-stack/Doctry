from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import func
from sqlalchemy.orm import Session

from ..config import settings
from ..models import LossDeclaration, Transaction, User
from ..security import generate_reference

PROVIDERS = {
    "ORANGE_MONEY": {
        "label": "Orange Money",
        "prefix": "OM",
        "ussd": "#150#",
    },
    "MTN_MONEY": {
        "label": "MTN Mobile Money",
        "prefix": "MTN",
        "ussd": "*126#",
    },
}

REJECTED_PIN = "0000"


class PaymentError(Exception):
    def __init__(self, message: str, code: str = "payment_failed") -> None:
        super().__init__(message)
        self.message = message
        self.code = code


def provider_info(provider: str) -> dict[str, str]:
    return PROVIDERS.get(provider, PROVIDERS["ORANGE_MONEY"])


def escrow_balance(db: Session) -> float:
    deposited = (
        db.query(func.coalesce(func.sum(Transaction.amount), 0.0))
        .filter(Transaction.kind == "escrow_deposit", Transaction.status == "settled")
        .scalar()
    )
    released = (
        db.query(func.coalesce(func.sum(Transaction.amount), 0.0))
        .filter(Transaction.kind == "escrow_release", Transaction.status == "settled")
        .scalar()
    )
    refunded = (
        db.query(func.coalesce(func.sum(Transaction.amount), 0.0))
        .filter(Transaction.kind == "escrow_refund", Transaction.status == "settled")
        .scalar()
    )
    return float(deposited or 0.0) - float(released or 0.0) - float(refunded or 0.0)


def platform_revenue(db: Session, start: datetime | None = None, end: datetime | None = None) -> float:
    query = db.query(func.coalesce(func.sum(Transaction.commission), 0.0)).filter(
        Transaction.kind == "escrow_release",
        Transaction.status == "settled",
    )
    if start:
        query = query.filter(Transaction.created_at >= start)
    if end:
        query = query.filter(Transaction.created_at <= end)
    return float(query.scalar() or 0.0)


def _validate_pin(pin: str) -> None:
    if not pin.isdigit():
        raise PaymentError("Le code PIN doit être numérique.", "invalid_pin")
    if pin == REJECTED_PIN:
        raise PaymentError("Code PIN rejeté par l'opérateur (simulation).", "wrong_pin")


def top_up(db: Session, user: User, amount: float, provider: str, phone: str, pin: str) -> Transaction:
    if amount <= 0:
        raise PaymentError("Montant de recharge invalide.", "invalid_amount")
    _validate_pin(pin)

    info = provider_info(provider)
    transaction = Transaction(
        reference=generate_reference(f"{info['prefix']}-TOP"),
        kind="topup",
        provider=provider,
        amount=round(amount, 2),
        payer_id=user.id,
        phone=phone or user.phone,
        status="settled",
        message=f"Recharge {info['label']} simulée",
        settled_at=datetime.now(timezone.utc),
    )
    user.wallet_balance = round((user.wallet_balance or 0.0) + amount, 2)
    db.add(transaction)
    db.commit()
    db.refresh(transaction)
    return transaction


def deposit_escrow(
    db: Session,
    user: User,
    loss: LossDeclaration,
    amount: float,
    provider: str,
    phone: str,
    pin: str,
) -> Transaction:
    if amount < settings.min_reward_amount:
        raise PaymentError(
            f"Le montant minimum de la récompense est de {settings.min_reward_amount} XAF.",
            "amount_too_low",
        )
    _validate_pin(pin)

    balance = float(user.wallet_balance or 0.0)
    if balance < amount:
        raise PaymentError(
            f"Solde {provider_info(provider)['label']} insuffisant "
            f"({balance:,.0f} XAF). Rechargez votre compte pour continuer.",
            "insufficient_funds",
        )

    info = provider_info(provider)
    transaction = Transaction(
        reference=generate_reference(f"{info['prefix']}-ESC"),
        kind="escrow_deposit",
        provider=provider,
        amount=round(amount, 2),
        payer_id=user.id,
        loss_id=loss.id,
        phone=phone or user.phone,
        status="settled",
        message="Fonds bloqués sur le compte séquestre de la plateforme DOCTRY",
        settled_at=datetime.now(timezone.utc),
    )
    user.wallet_balance = round(balance - amount, 2)
    loss.reward_amount = round(amount, 2)
    loss.reward_status = "escrow"
    loss.escrow_reference = transaction.reference
    db.add(transaction)
    db.commit()
    db.refresh(transaction)
    return transaction


def release_escrow(db: Session, loss: LossDeclaration, finder: User) -> Transaction:
    if loss.reward_status != "escrow":
        raise PaymentError("Aucune récompense séquestrée à libérer.", "no_escrow")

    amount = float(loss.reward_amount or 0.0)
    commission = round(amount * settings.platform_commission_rate, 2)
    net = round(amount - commission, 2)

    deposit = (
        db.query(Transaction)
        .filter(Transaction.loss_id == loss.id, Transaction.kind == "escrow_deposit")
        .order_by(Transaction.created_at.desc())
        .first()
    )
    provider = deposit.provider if deposit else "ORANGE_MONEY"
    info = provider_info(provider)

    transaction = Transaction(
        reference=generate_reference(f"{info['prefix']}-REL"),
        kind="escrow_release",
        provider=provider,
        amount=round(amount, 2),
        commission=commission,
        payee_id=finder.id,
        payer_id=loss.owner_id,
        loss_id=loss.id,
        phone=finder.phone,
        status="settled",
        message=f"Récompense libérée au trouveur (net {net:,.0f} XAF, commission {commission:,.0f} XAF)",
        settled_at=datetime.now(timezone.utc),
    )
    finder.wallet_balance = round(float(finder.wallet_balance or 0.0) + net, 2)
    loss.reward_status = "released"
    db.add(transaction)
    db.commit()
    db.refresh(transaction)
    return transaction


def refund_escrow(db: Session, loss: LossDeclaration, owner: User) -> Transaction:
    if loss.reward_status != "escrow":
        raise PaymentError("Aucune récompense séquestrée à rembourser.", "no_escrow")

    amount = float(loss.reward_amount or 0.0)
    deposit = (
        db.query(Transaction)
        .filter(Transaction.loss_id == loss.id, Transaction.kind == "escrow_deposit")
        .order_by(Transaction.created_at.desc())
        .first()
    )
    provider = deposit.provider if deposit else "ORANGE_MONEY"
    info = provider_info(provider)

    transaction = Transaction(
        reference=generate_reference(f"{info['prefix']}-REF"),
        kind="escrow_refund",
        provider=provider,
        amount=round(amount, 2),
        payee_id=owner.id,
        loss_id=loss.id,
        phone=owner.phone,
        status="settled",
        message="Remboursement du séquestre au propriétaire",
        settled_at=datetime.now(timezone.utc),
    )
    owner.wallet_balance = round(float(owner.wallet_balance or 0.0) + amount, 2)
    loss.reward_status = "refunded"
    loss.reward_amount = 0.0
    db.add(transaction)
    db.commit()
    db.refresh(transaction)
    return transaction
