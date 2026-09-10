from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..models import Notification, User
from ..services import notification_service

router = APIRouter(prefix="/api/notifications", tags=["notifications"])


def serialize(item: Notification) -> dict[str, Any]:
    return {
        "id": item.id,
        "title": item.title,
        "body": item.body,
        "kind": item.kind,
        "read": item.read,
        "created_at": item.created_at.isoformat() if item.created_at else None,
    }


@router.get("")
def list_notifications(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    rows = (
        db.query(Notification)
        .filter(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
        .limit(100)
        .all()
    )
    unread = sum(1 for row in rows if not row.read)
    return {"items": [serialize(row) for row in rows], "count": len(rows), "unread": unread}


@router.get("/unread-count")
def unread_count(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    rows = (
        db.query(Notification)
        .filter(Notification.user_id == current_user.id, Notification.read.is_(False))
        .count()
    )
    return {"unread": int(rows)}


@router.post("/read-all")
def read_all(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    updated = notification_service.mark_all_read(db, current_user.id)
    return {"success": True, "updated": updated}


@router.post("/{notification_id}/read")
def read_one(
    notification_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    item = db.get(Notification, notification_id)
    if item is None or item.user_id != current_user.id:
        return {"success": False, "message": "Notification introuvable."}
    item.read = True
    db.commit()
    return {"success": True, "message": "Notification marquée comme lue."}
