from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..config import settings
from ..database import get_db
from ..deps import get_current_user
from ..models import FindDeclaration, LossDeclaration, MailLog, MatchRecord, Transaction, User
from ..schemas import PaymentConfirmIn, PaymentInitiateIn, ReleaseConfirmIn, ReleaseRequestIn, TopUpIn
from ..security import generate_reference
from ..services import notification_service, otp_service, payment_service, sms_service
from ..services.otp_service import OtpError
from ..services.payment_service import PaymentError

router = APIRouter(prefix="/api/payments", tags=["payments"])


def serialize(transaction: Transaction) -> dict[str, Any]:
    return {
        "id": transaction.id,
        "reference": transaction.reference,
        "kind": transaction.kind,
        "provider": transaction.provider,
        "provider_label": payment_service.provider_info(transaction.provider)["label"],
        "amount": transaction.amount,
        "commission": transaction.commission,
        "status": transaction.status,
        "message": transaction.message,
        "loss_id": transaction.loss_id,
        "phone": transaction.phone,
        "created_at": transaction.created_at.isoformat() if transaction.created_at else None,
        "settled_at": transaction.settled_at.isoformat() if transaction.settled_at else None,
    }


@router.get("/accounts")
def accounts(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    return {
        "wallet_balance": current_user.wallet_balance,
        "currency": "XAF",
        "escrow_balance": payment_service.escrow_balance(db) if current_user.is_admin else None,
        "min_reward_amount": settings.min_reward_amount,
        "commission_rate": settings.platform_commission_rate,
        "providers": [
            {"code": code, "label": info["label"], "ussd": info["ussd"]}
            for code, info in payment_service.PROVIDERS.items()
        ],
    }


@router.post("/topup")
def top_up(
    payload: TopUpIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    try:
        transaction = payment_service.top_up(
            db, current_user, payload.amount, payload.provider, payload.phone, payload.pin
        )
    except PaymentError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=exc.message) from exc
    db.refresh(current_user)
    return {
        "success": True,
        "message": f"{transaction.amount:,.0f} XAF ajoutés à votre compte "
        f"{payment_service.provider_info(payload.provider)['label']} (simulation).",
        "transaction": serialize(transaction),
        "wallet_balance": current_user.wallet_balance,
    }


@router.post("/escrow/initiate")
def initiate_escrow(
    payload: PaymentInitiateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    loss = db.get(LossDeclaration, payload.loss_id)
    if loss is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Déclaration introuvable.")
    if loss.owner_id != current_user.id and not current_user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accès refusé.")
    if payload.amount < settings.min_reward_amount:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Le montant minimum de la récompense est de {settings.min_reward_amount} XAF.",
        )

    info = payment_service.provider_info(payload.provider)
    pending = Transaction(
        reference=generate_reference(f"{info['prefix']}-ESC"),
        kind="escrow_deposit",
        provider=payload.provider,
        amount=round(payload.amount, 2),
        payer_id=current_user.id,
        loss_id=loss.id,
        phone=payload.phone or current_user.phone,
        status="pending",
        message="En attente de la saisie du code PIN",
    )
    db.add(pending)
    db.commit()
    db.refresh(pending)

    return {
        "reference": pending.reference,
        "provider": info["label"],
        "ussd": info["ussd"],
        "amount": pending.amount,
        "phone": pending.phone,
        "wallet_balance": current_user.wallet_balance,
        "message": f"Saisissez le code PIN {info['label']} pour bloquer {pending.amount:,.0f} XAF "
        "sur le compte séquestre de la plateforme DOCTRY.",
    }


@router.post("/escrow/confirm")
def confirm_escrow(
    payload: PaymentConfirmIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    transaction = (
        db.query(Transaction)
        .filter(Transaction.reference == payload.reference, Transaction.kind == "escrow_deposit")
        .first()
    )
    if transaction is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Opération introuvable.")
    if transaction.payer_id != current_user.id and not current_user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accès refusé.")
    if transaction.status == "settled":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cette récompense est déjà séquestrée.",
        )

    loss = db.get(LossDeclaration, transaction.loss_id) if transaction.loss_id else None
    if loss is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Déclaration introuvable.")

    try:
        settled = payment_service.deposit_escrow(
            db,
            current_user,
            loss,
            transaction.amount,
            transaction.provider,
            transaction.phone,
            payload.pin,
        )
    except PaymentError as exc:
        transaction.status = "failed"
        transaction.message = exc.message
        db.commit()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=exc.message) from exc

    transaction.status = "superseded"
    db.commit()
    db.refresh(loss)
    db.refresh(current_user)

    notification_service.notify(
        db,
        current_user.id,
        "Récompense séquestrée",
        f"{settled.amount:,.0f} XAF sont bloqués sur le compte séquestre DOCTRY pour votre "
        f"déclaration n°{loss.number}.",
        "payment",
    )
    return {
        "success": True,
        "message": f"{settled.amount:,.0f} XAF bloqués sur le compte séquestre de la plateforme.",
        "transaction": serialize(settled),
        "wallet_balance": current_user.wallet_balance,
        "loss_status": loss.status,
        "reward_status": loss.reward_status,
    }


@router.post("/release/request")
def request_release(
    payload: ReleaseRequestIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    loss = db.get(LossDeclaration, payload.loss_id)
    if loss is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Déclaration introuvable.")
    if loss.owner_id != current_user.id and not current_user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accès refusé.")
    if loss.reward_status != "escrow":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Aucune récompense séquestrée à libérer pour cette déclaration.",
        )
    if loss.status != "returned":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Confirmez d'abord la restitution physique du document.",
        )

    result = otp_service.issue_otp(db, current_user.email, "release", loss.id)
    return {
        "ticket": result["ticket"],
        "email": current_user.email,
        "delivery": result["delivery"],
        "dev_code": result["dev_code"],
        "expires_in": result["expires_in"],
        "message": "Un code OTP a été envoyé à votre adresse email pour libérer la récompense.",
    }


@router.post("/release/confirm")
def confirm_release(
    payload: ReleaseConfirmIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    loss = db.get(LossDeclaration, payload.loss_id)
    if loss is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Déclaration introuvable.")
    if loss.owner_id != current_user.id and not current_user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accès refusé.")

    try:
        otp_service.verify_otp(db, payload.ticket, payload.code, purpose="release")
    except OtpError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=exc.message) from exc

    match_record = (
        db.query(MatchRecord)
        .filter(MatchRecord.loss_id == loss.id)
        .order_by(MatchRecord.score.desc())
        .first()
    )
    find = None
    if match_record:
        find = db.get(FindDeclaration, match_record.find_id)
    if find is None and loss.matched_find_id:
        find = db.get(FindDeclaration, loss.matched_find_id)
    if find is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Aucun trouveur associé à cette déclaration.",
        )

    finder = db.get(User, find.finder_id)
    if finder is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trouveur introuvable.")

    try:
        transaction = payment_service.release_escrow(db, loss, finder)
    except PaymentError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=exc.message) from exc

    notification_service.notify(
        db,
        current_user.id,
        "Récompense libérée",
        f"{transaction.amount:,.0f} XAF ont été transférés à {finder.full_name}.",
        "payment",
    )
    notification_service.notify(
        db,
        finder.id,
        "Récompense reçue",
        f"Vous avez reçu {transaction.amount - transaction.commission:,.0f} XAF pour la restitution "
        f"du document {loss.doc_type}.",
        "payment",
    )
    sms_service.send_sms(
        db,
        current_user.phone,
        sms_service.reward_released_sms(transaction.amount, finder.full_name),
    )
    db.refresh(loss)
    return {
        "success": True,
        "message": f"Récompense de {transaction.amount:,.0f} XAF libérée vers {finder.full_name}.",
        "transaction": serialize(transaction),
        "wallet_balance": current_user.wallet_balance,
        "reward_status": loss.reward_status,
    }


@router.post("/escrow/refund")
def refund_escrow(
    loss_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    loss = db.get(LossDeclaration, loss_id)
    if loss is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Déclaration introuvable.")
    if loss.owner_id != current_user.id and not current_user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accès refusé.")
    try:
        transaction = payment_service.refund_escrow(db, loss, current_user)
    except PaymentError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=exc.message) from exc
    db.refresh(current_user)
    return {
        "success": True,
        "message": f"{transaction.amount:,.0f} XAF remboursés sur votre compte.",
        "transaction": serialize(transaction),
        "wallet_balance": current_user.wallet_balance,
    }


@router.get("/history")
def history(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    if current_user.is_admin:
        rows = db.query(Transaction).order_by(Transaction.created_at.desc()).limit(500).all()
    else:
        rows = (
            db.query(Transaction)
            .filter(
                (Transaction.payer_id == current_user.id) | (Transaction.payee_id == current_user.id)
            )
            .order_by(Transaction.created_at.desc())
            .limit(200)
            .all()
        )
    items = [serialize(row) for row in rows if row.status != "superseded"]
    return {"items": items, "count": len(items)}


@router.get("/dev/mailbox")
def mailbox(
    email: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    if email.lower() != current_user.email and not current_user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accès refusé.")

    rows = (
        db.query(MailLog)
        .filter(MailLog.email == email.lower())
        .order_by(MailLog.created_at.desc())
        .limit(5)
        .all()
    )
    return {
        "items": [
            {"subject": row.subject, "body": row.body, "status": row.status}
            for row in rows
        ]
    }
