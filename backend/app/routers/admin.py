from __future__ import annotations

from datetime import date as date_type
from datetime import datetime, time, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import func
from sqlalchemy.orm import Session

from ..config import settings
from ..database import get_db
from ..deps import get_current_admin
from ..models import (
    Document,
    FindDeclaration,
    LossDeclaration,
    MatchRecord,
    SmsLog,
    Transaction,
    User,
)
from ..security import hash_password
from ..services import notification_service
from ..services.payment_service import escrow_balance, provider_info

router = APIRouter(prefix="/api/admin", tags=["admin"])


class AdminUserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6)
    first_name: str = Field(min_length=1)
    last_name: str = Field(min_length=1)
    phone: str = ""
    role: str = Field(default="owner", pattern="^(finder|owner)$")


def _serialize_user(user: User) -> dict[str, Any]:
    return {
        "id": user.id,
        "email": user.email,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "full_name": user.full_name,
        "phone": user.phone,
        "role": user.role,
        "active_profile": user.active_profile,
        "profile_photo": user.profile_photo,
        "is_admin": user.is_admin,
        "is_blocked": user.is_blocked,
        "wallet_balance": user.wallet_balance,
        "average_rating": user.average_rating,
        "rating_count": user.rating_count,
        "created_at": user.created_at.isoformat() if user.created_at else None,
    }


def _parse_date(value: str | None) -> date_type | None:
    if not value:
        return None
    try:
        return datetime.strptime(value, "%Y-%m-%d").date()
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Format de date invalide. Utilisez AAAA-MM-JJ.",
        ) from exc


def _revenue_between(db: Session, start: datetime, end: datetime) -> tuple[float, int]:
    amount = (
        db.query(func.coalesce(func.sum(Transaction.commission), 0.0))
        .filter(
            Transaction.kind == "escrow_release",
            Transaction.status == "settled",
            Transaction.created_at >= start,
            Transaction.created_at <= end,
        )
        .scalar()
    )
    count = (
        db.query(func.count(Transaction.id))
        .filter(
            Transaction.kind == "escrow_release",
            Transaction.status == "settled",
            Transaction.created_at >= start,
            Transaction.created_at <= end,
        )
        .scalar()
    )
    return float(amount or 0.0), int(count or 0)


@router.get("/overview")
def overview(
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    now = datetime.now(timezone.utc)
    year_start = datetime(now.year, 1, 1, tzinfo=timezone.utc)
    month_start = datetime(now.year, now.month, 1, tzinfo=timezone.utc)

    year_revenue, _ = _revenue_between(db, year_start, now)
    month_revenue, _ = _revenue_between(db, month_start, now)

    return {
        "users": db.query(func.count(User.id)).filter(User.is_admin.is_(False)).scalar() or 0,
        "blocked_users": db.query(func.count(User.id)).filter(User.is_blocked.is_(True)).scalar() or 0,
        "documents": db.query(func.count(Document.id)).scalar() or 0,
        "losses": db.query(func.count(LossDeclaration.id)).scalar() or 0,
        "finds": db.query(func.count(FindDeclaration.id)).scalar() or 0,
        "matches": db.query(func.count(MatchRecord.id)).scalar() or 0,
        "returned": db.query(func.count(LossDeclaration.id))
        .filter(LossDeclaration.returned_at.is_not(None))
        .scalar()
        or 0,
        "escrow_balance": escrow_balance(db),
        "year_revenue": year_revenue,
        "month_revenue": month_revenue,
        "ai_engine": "deepseek" if settings.deepseek_enabled else "moteur-local",
        "email_delivery": "smtp" if settings.smtp_enabled else "simulation",
        "sms_delivery": "textsoft" if settings.sms_enabled else "simulation",
    }


@router.get("/users")
def list_users(
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
    search: str = "",
) -> dict[str, Any]:
    query = db.query(User).filter(User.is_admin.is_(False))
    if search.strip():
        pattern = f"%{search.strip().lower()}%"
        query = query.filter(
            func.lower(User.email).like(pattern)
            | func.lower(User.first_name).like(pattern)
            | func.lower(User.last_name).like(pattern)
        )
    users = query.order_by(User.created_at.desc()).all()
    return {"items": [_serialize_user(user) for user in users], "count": len(users)}


@router.post("/users", status_code=status.HTTP_201_CREATED)
def create_user(
    payload: AdminUserCreate,
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    email = payload.email.lower()
    if db.query(User).filter(User.email == email).first():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Un compte existe déjà avec cette adresse email.",
        )
    user = User(
        email=email,
        password_hash=hash_password(payload.password),
        first_name=payload.first_name.strip(),
        last_name=payload.last_name.strip(),
        phone=payload.phone.strip(),
        role=payload.role,
        active_profile=payload.role,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    notification_service.notify(
        db,
        user.id,
        "Bienvenue sur DOCTRY",
        "Votre compte a été créé par l'administrateur de la plateforme.",
        "info",
    )
    return _serialize_user(user)


@router.post("/users/{user_id}/block")
def block_user(
    user_id: str,
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Utilisateur introuvable.")
    if user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Impossible de bloquer un compte administrateur.",
        )
    user.is_blocked = True
    db.commit()
    return {"success": True, "message": f"{user.full_name} a été bloqué.", "user": _serialize_user(user)}


@router.post("/users/{user_id}/unblock")
def unblock_user(
    user_id: str,
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Utilisateur introuvable.")
    user.is_blocked = False
    db.commit()
    return {
        "success": True,
        "message": f"{user.full_name} a été débloqué.",
        "user": _serialize_user(user),
    }


@router.get("/finance")
def finance(
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
    date: str | None = None,
) -> dict[str, Any]:
    target = _parse_date(date)
    now = datetime.now(timezone.utc)

    if target:
        day_start = datetime.combine(target, time.min, tzinfo=timezone.utc)
        day_end = datetime.combine(target, time.max, tzinfo=timezone.utc)
        day_revenue, day_count = _revenue_between(db, day_start, day_end)
        label = target.strftime("%Y-%m-%d")
    else:
        day_start = datetime.combine(now.date(), time.min, tzinfo=timezone.utc)
        day_end = datetime.combine(now.date(), time.max, tzinfo=timezone.utc)
        day_revenue, day_count = _revenue_between(db, day_start, day_end)
        label = now.date().strftime("%Y-%m-%d")

    month_start = datetime(target.year if target else now.year, target.month if target else now.month, 1, tzinfo=timezone.utc)
    month_revenue, month_count = _revenue_between(db, month_start, now if not target else day_end)

    year_start = datetime(target.year if target else now.year, 1, 1, tzinfo=timezone.utc)
    year_revenue, year_count = _revenue_between(db, year_start, now if not target else day_end)

    total_revenue, total_count = _revenue_between(
        db, datetime(2000, 1, 1, tzinfo=timezone.utc), datetime(2999, 1, 1, tzinfo=timezone.utc)
    )

    query = db.query(Transaction).filter(
        Transaction.kind == "escrow_release",
        Transaction.status == "settled",
    )
    if target:
        query = query.filter(
            Transaction.created_at >= day_start, Transaction.created_at <= day_end
        )
    rows = query.order_by(Transaction.created_at.desc()).limit(100).all()

    return {
        "date": label,
        "currency": "XAF",
        "day_revenue": round(day_revenue, 2),
        "month_revenue": round(month_revenue, 2),
        "year_revenue": round(year_revenue, 2),
        "total_revenue": round(total_revenue, 2),
        "escrow_balance": round(escrow_balance(db), 2),
        "counts": {
            "day": day_count,
            "month": month_count,
            "year": year_count,
            "total": total_count,
        },
        "rows": [
            {
                "reference": row.reference,
                "provider": provider_info(row.provider)["label"],
                "amount": row.amount,
                "commission": row.commission,
                "payee_id": row.payee_id,
                "loss_id": row.loss_id,
                "created_at": row.created_at.isoformat() if row.created_at else None,
            }
            for row in rows
        ],
    }


@router.get("/stats")
def admin_stats(
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    losses = (
        db.query(LossDeclaration).order_by(LossDeclaration.created_at.desc()).limit(100).all()
    )
    finds = (
        db.query(FindDeclaration).order_by(FindDeclaration.created_at.desc()).limit(100).all()
    )
    returns = [item for item in losses if item.returned_at is not None]

    pending_matches = (
        db.query(LossDeclaration)
        .filter(LossDeclaration.status.in_(["pending", "declared"]), LossDeclaration.returned_at.is_(None))
        .order_by(LossDeclaration.created_at.desc())
        .limit(100)
        .all()
    )

    def _user_name(user_id: str | None) -> str:
        if not user_id:
            return ""
        user = db.get(User, user_id)
        return user.full_name if user else ""

    return {
        "losses": [
            {
                "id": item.id,
                "number": item.number,
                "name": item.owner_name or _user_name(item.owner_id),
                "doc_type": item.doc_type,
                "date": item.loss_date.isoformat() if item.loss_date else None,
                "status": item.status,
                "reward_amount": item.reward_amount,
                "reward_status": item.reward_status,
            }
            for item in losses
        ],
        "finds": [
            {
                "id": item.id,
                "number": item.number,
                "name": _user_name(item.finder_id),
                "holder_name": item.holder_name,
                "doc_type": item.doc_type,
                "date": item.found_date.isoformat() if item.found_date else None,
                "status": item.status,
                "source": item.source,
            }
            for item in finds
        ],
        "returns": [
            {
                "id": item.id,
                "number": item.number,
                "date": item.returned_at.isoformat() if item.returned_at else None,
                "location": item.location,
                "owner": item.owner_name or _user_name(item.owner_id),
                "finder": _user_name(
                    (db.get(FindDeclaration, item.matched_find_id).finder_id
                     if item.matched_find_id and db.get(FindDeclaration, item.matched_find_id)
                     else None)
                ),
                "reward_amount": item.reward_amount,
                "reward_status": item.reward_status,
            }
            for item in returns
        ],
        "pending_matching": [
            {
                "id": item.id,
                "number": item.number,
                "name": item.owner_name or _user_name(item.owner_id),
                "doc_type": item.doc_type,
                "date": item.loss_date.isoformat() if item.loss_date else None,
                "status": item.status,
            }
            for item in pending_matches
        ],
        "counts": {
            "losses": len(losses),
            "finds": len(finds),
            "returns": len(returns),
            "pending_matching": len(pending_matches),
        },
    }


@router.get("/sms-logs")
def sms_logs(
    admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    rows = db.query(SmsLog).order_by(SmsLog.created_at.desc()).limit(100).all()
    return {
        "items": [
            {
                "id": row.id,
                "phone": row.phone,
                "body": row.body,
                "provider": row.provider,
                "status": row.status,
                "created_at": row.created_at.isoformat() if row.created_at else None,
            }
            for row in rows
        ],
        "count": len(rows),
    }
