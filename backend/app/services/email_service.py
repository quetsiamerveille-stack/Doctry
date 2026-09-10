from __future__ import annotations

import smtplib
from email.message import EmailMessage

from sqlalchemy.orm import Session

from ..config import settings
from ..models import MailLog


def send_email(db: Session, to_email: str, subject: str, body: str) -> tuple[str, bool]:
    mail = MailLog(email=to_email, subject=subject, body=body, status="simulated")

    if not settings.smtp_enabled:
        db.add(mail)
        db.commit()
        return "simulated", False

    message = EmailMessage()
    message["From"] = settings.mail_from
    message["To"] = to_email
    message["Subject"] = subject
    message.set_content(body)

    try:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=25) as server:
            if settings.smtp_tls:
                server.starttls()
            server.login(settings.smtp_user, settings.smtp_password)
            server.send_message(message)
        mail.status = "sent"
        db.add(mail)
        db.commit()
        return "sent", True
    except Exception as exc:  # noqa: BLE001
        mail.status = f"failed:{type(exc).__name__}"
        db.add(mail)
        db.commit()
        return "failed", False


def otp_email_content(code: str, purpose: str) -> tuple[str, str]:
    labels = {
        "login": "votre connexion",
        "signup": "la validation de votre compte",
        "release": "la libération de votre récompense",
        "admin": "votre connexion administrateur",
    }
    label = labels.get(purpose, "votre opération")
    subject = f"DOCTRY - Code de vérification {code}"
    body = (
        "Bonjour,\n\n"
        f"Voici le code de vérification pour {label} : {code}\n"
        f"Ce code expire dans {settings.otp_ttl_seconds // 60} minutes.\n\n"
        "Ne partagez jamais ce code.\n"
        "L'équipe DOCTRY"
    )
    return subject, body
