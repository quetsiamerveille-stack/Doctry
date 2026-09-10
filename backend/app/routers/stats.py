from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends
from sqlalchemy import func
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..models import FindDeclaration, LossDeclaration, MatchRecord, Transaction, User

router = APIRouter(prefix="/api/stats", tags=["stats"])


def _sum(query) -> float:
    return float(query.scalar() or 0.0)


@router.get("/owner")
def owner_stats(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    losses = (
        db.query(LossDeclaration).filter(LossDeclaration.owner_id == current_user.id).all()
    )
    loss_ids = [item.id for item in losses]

    declared = len(losses)
    returned = sum(1 for item in losses if item.returned_at is not None)
    pending = sum(1 for item in losses if item.returned_at is None)

    find_declarations = 0
    if loss_ids:
        matched_find_ids = [
            row[0]
            for row in db.query(MatchRecord.find_id)
            .filter(MatchRecord.loss_id.in_(loss_ids))
            .distinct()
            .all()
        ]
        if matched_find_ids:
            find_declarations = (
                db.query(func.count(FindDeclaration.id))
                .filter(FindDeclaration.id.in_(matched_find_ids))
                .scalar()
            )

    escrow_total = _sum(
        db.query(func.coalesce(func.sum(LossDeclaration.reward_amount), 0.0)).filter(
            LossDeclaration.owner_id == current_user.id,
            LossDeclaration.reward_status == "escrow",
        )
    )
    released_total = _sum(
        db.query(func.coalesce(func.sum(Transaction.amount), 0.0)).filter(
            Transaction.payer_id == current_user.id,
            Transaction.kind == "escrow_release",
            Transaction.status == "settled",
        )
    )

    return {
        "loss_declarations": int(declared),
        "find_declarations": int(find_declarations or 0),
        "returned_documents": int(returned),
        "pending_documents": int(pending),
        "escrow_total": escrow_total,
        "released_total": released_total,
        "wallet_balance": current_user.wallet_balance,
    }


@router.get("/finder")
def finder_stats(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    finds = (
        db.query(FindDeclaration).filter(FindDeclaration.finder_id == current_user.id).all()
    )
    finds_done = len(finds)
    returned = sum(1 for item in finds if item.returned_at is not None)
    ongoing = sum(1 for item in finds if item.returned_at is None)

    rewarded_losses = 0
    if finds:
        matched_loss_ids = [
            row[0]
            for row in db.query(MatchRecord.loss_id)
            .filter(MatchRecord.find_id.in_([item.id for item in finds]))
            .distinct()
            .all()
        ]
        if matched_loss_ids:
            rewarded_losses = (
                db.query(func.count(LossDeclaration.id))
                .filter(
                    LossDeclaration.id.in_(matched_loss_ids),
                    LossDeclaration.reward_amount > 0,
                )
                .scalar()
            )

    earnings = _sum(
        db.query(
            func.coalesce(
                func.sum(Transaction.amount - Transaction.commission), 0.0
            )
        ).filter(
            Transaction.payee_id == current_user.id,
            Transaction.kind == "escrow_release",
            Transaction.status == "settled",
        )
    )

    return {
        "finds_done": int(finds_done),
        "rewarded_losses": int(rewarded_losses or 0),
        "ongoing": int(ongoing),
        "returned_documents": int(returned),
        "earnings_total": earnings,
        "wallet_balance": current_user.wallet_balance,
    }
