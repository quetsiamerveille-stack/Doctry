from __future__ import annotations

from datetime import datetime, timezone


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def as_aware(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def is_past(value: datetime | None) -> bool:
    aware = as_aware(value)
    if aware is None:
        return True
    return aware <= utcnow()


def age_days(value: datetime | None) -> float:
    aware = as_aware(value)
    if aware is None:
        return float("inf")
    return (utcnow() - aware).total_seconds() / 86400.0


def isoformat(value: datetime | None) -> str | None:
    aware = as_aware(value)
    return aware.isoformat() if aware else None
