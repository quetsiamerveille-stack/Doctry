from __future__ import annotations

from sqlalchemy.orm import Session

from ..models import Notification, User


def notify(
    db: Session,
    user_id: str | None,
    title: str,
    body: str,
    kind: str = "info",
) -> Notification | None:
    if not user_id:
        return None
    user = db.get(User, user_id)
    if user is None:
        return None
    item = Notification(user_id=user_id, title=title, body=body, kind=kind)
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


def mark_all_read(db: Session, user_id: str) -> int:
    pending = (
        db.query(Notification)
        .filter(Notification.user_id == user_id, Notification.read.is_(False))
        .all()
    )
    for item in pending:
        item.read = True
    db.commit()
    return len(pending)
