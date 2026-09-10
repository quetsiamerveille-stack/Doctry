from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from ..config import settings
from ..models import OtpCode
from ..security import generate_otp
from ..timeutil import is_past
from . import email_service


class OtpError(Exception):
    def __init__(self, message: str, code: str = "otp_invalid") -> None:
        super().__init__(message)
        self.message = message
        self.code = code


def issue_otp(db: Session, email: str, purpose: str, context_ref: str = "") -> dict[str, object]:
    db.query(OtpCode).filter(
        OtpCode.email == email,
        OtpCode.purpose == purpose,
        OtpCode.consumed.is_(False),
    ).update({"consumed": True}, synchronize_session=False)

    code = generate_otp()
    record = OtpCode(
        email=email.lower(),
        code=code,
        purpose=purpose,
        context_ref=context_ref,
        expires_at=datetime.now(timezone.utc) + timedelta(seconds=settings.otp_ttl_seconds),
    )
    db.add(record)
    db.commit()
    db.refresh(record)

    subject, body = email_service.otp_email_content(code, purpose)
    status, delivered = email_service.send_email(db, email, subject, body)

    return {
        "ticket": record.id,
        "delivery": status,
        "delivered": delivered,
        "dev_code": "" if delivered else code,
        "expires_in": settings.otp_ttl_seconds,
    }


def verify_otp(db: Session, ticket: str, code: str, purpose: str | None = None) -> OtpCode:
    record = db.get(OtpCode, ticket)
    if record is None:
        raise OtpError("Session OTP introuvable. Veuillez recommencer.", "otp_not_found")
    if purpose and record.purpose != purpose:
        raise OtpError("Ce code n'est pas valide pour cette opération.", "otp_purpose")
    if record.consumed:
        raise OtpError("Ce code a déjà été utilisé.", "otp_consumed")
    if is_past(record.expires_at):
        raise OtpError("Code expiré. Veuillez en demander un nouveau.", "otp_expired")

    record.attempts += 1
    if record.code != (code or "").strip():
        db.commit()
        if record.attempts >= 5:
            record.consumed = True
            db.commit()
            raise OtpError("Trop de tentatives. Veuillez demander un nouveau code.", "otp_locked")
        raise OtpError("Code OTP incorrect.", "otp_wrong")

    record.consumed = True
    db.commit()
    db.refresh(record)
    return record
