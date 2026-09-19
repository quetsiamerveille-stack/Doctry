"""Relais vers Supabase Auth (GoTrue) pour l'envoi et la verification des codes OTP email.

Le backend ne gere plus l'envoi de l'email lui-meme : Supabase Auth envoie le code
a 6 chiffres (template "Sign in via OTP") et le backend verifie ce code aupres de
l'endpoint /verify avant d'emettre son propre JWT applicatif.
"""
from __future__ import annotations

from typing import Any

import httpx

from ..config import settings


class SupabaseAuthError(Exception):
    def __init__(self, message: str, status_code: int = 502) -> None:
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def _headers() -> dict[str, str]:
    key = settings.supabase_anon_key
    return {"apikey": key, "Authorization": f"Bearer {key}", "Content-Type": "application/json"}


def _error_message(resp: httpx.Response) -> str:
    try:
        body = resp.json()
        detail = body.get("error_msg") or body.get("msg") or body.get("error_description") or str(body)
    except ValueError:
        detail = resp.text
    return str(detail)[:300]


def send_email_otp(email: str, data: dict[str, Any] | None = None) -> None:
    """Demande a GoTrue d'envoyer un code OTP par email (cree le compte si inconnu)."""
    body: dict[str, Any] = {"email": email, "create_user": True}
    if data:
        body["data"] = data
    try:
        resp = httpx.post(
            f"{settings.supabase_url.rstrip('/')}/auth/v1/otp",
            json=body,
            headers=_headers(),
            timeout=20,
        )
    except httpx.HTTPError as exc:
        raise SupabaseAuthError("Service d'authentification indisponible.") from exc
    if resp.status_code >= 400:
        raise SupabaseAuthError(_error_message(resp), resp.status_code)


def verify_email_otp(email: str, token: str) -> dict[str, Any]:
    """Verifie le code OTP aupres de GoTrue et retourne l'objet user (id, email, metadonnees)."""
    try:
        resp = httpx.post(
            f"{settings.supabase_url.rstrip('/')}/auth/v1/verify",
            json={"type": "email", "email": email, "token": token},
            headers=_headers(),
            timeout=20,
        )
    except httpx.HTTPError as exc:
        raise SupabaseAuthError("Service d'authentification indisponible.") from exc
    if resp.status_code >= 400:
        raise SupabaseAuthError(_error_message(resp), resp.status_code)
    user = resp.json().get("user") or {}
    if not user.get("id"):
        raise SupabaseAuthError("Code OTP invalide ou expire.", 400)
    return user
