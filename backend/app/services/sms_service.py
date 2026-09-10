from __future__ import annotations

import httpx
from sqlalchemy.orm import Session

from ..config import settings
from ..models import SmsLog


def send_sms(db: Session, phone: str, body: str) -> str:
    if not phone:
        return "skipped"

    log = SmsLog(phone=phone, body=body, provider="TEXTSOFT", status="simulated")

    if not settings.sms_enabled:
        db.add(log)
        db.commit()
        return "simulated"

    payload = {
        "sender": settings.textsoft_sender,
        "recipient": phone,
        "message": body,
    }
    headers = {
        "Authorization": f"Bearer {settings.textsoft_api_key}",
        "Content-Type": "application/json",
    }

    try:
        response = httpx.post(
            settings.textsoft_api_url,
            json=payload,
            headers=headers,
            timeout=20,
        )
        log.status = "sent" if response.status_code < 400 else f"error_{response.status_code}"
    except httpx.HTTPError as exc:
        log.status = f"failed:{type(exc).__name__}"

    db.add(log)
    db.commit()
    return log.status


def match_alert_sms(doc_type: str, role: str, counterpart: str) -> str:
    if role == "owner":
        return (
            f"DOCTRY: Bonne nouvelle! Un document similaire ({doc_type}) a ete retrouve "
            f"par {counterpart}. Connectez-vous a l'application pour le recuperer."
        )
    return (
        f"DOCTRY: Le document ({doc_type}) que vous avez declare correspond a une perte "
        f"signalee par {counterpart}. Ouvrez le chat dans l'application."
    )


def reward_released_sms(amount: float, finder_name: str) -> str:
    return (
        f"DOCTRY: La recompense de {amount:,.0f} XAF a ete liberee en faveur de {finder_name}. "
        "Merci pour votre honnetete."
    )
