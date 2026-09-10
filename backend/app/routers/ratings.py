from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from ..config import settings
from ..database import get_db
from ..deps import get_current_user
from ..models import Rating, User
from ..schemas import RatingIn
from ..timeutil import age_days, utcnow

router = APIRouter(prefix="/api/ratings", tags=["ratings"])


def rating_is_due(user: User) -> bool:
    if user.last_rating_at is None:
        return True
    return age_days(user.last_rating_at) >= settings.rating_interval_days


@router.get("/due")
def due(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    return {
        "due": rating_is_due(current_user),
        "interval_days": settings.rating_interval_days,
        "last_rating_at": (
            current_user.last_rating_at.isoformat() if current_user.last_rating_at else None
        ),
        "average_rating": current_user.average_rating,
        "rating_count": current_user.rating_count,
    }


@router.post("", status_code=status.HTTP_201_CREATED)
def submit(
    payload: RatingIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    rating = Rating(user_id=current_user.id, stars=payload.stars, comment=payload.comment)
    db.add(rating)

    total = float(current_user.average_rating or 0.0) * int(current_user.rating_count or 0)
    count = int(current_user.rating_count or 0) + 1
    current_user.average_rating = round((total + payload.stars) / count, 2)
    current_user.rating_count = count
    current_user.last_rating_at = utcnow()

    db.commit()
    db.refresh(current_user)
    return {
        "success": True,
        "message": "Merci pour votre évaluation !",
        "average_rating": current_user.average_rating,
        "rating_count": current_user.rating_count,
    }


@router.get("/mine")
def mine(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    rows = (
        db.query(Rating)
        .filter(Rating.user_id == current_user.id)
        .order_by(Rating.created_at.desc())
        .limit(50)
        .all()
    )
    return {
        "items": [
            {
                "id": row.id,
                "stars": row.stars,
                "comment": row.comment,
                "created_at": row.created_at.isoformat() if row.created_at else None,
            }
            for row in rows
        ],
        "average_rating": current_user.average_rating,
        "rating_count": current_user.rating_count,
    }
