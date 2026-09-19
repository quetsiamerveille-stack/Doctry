from __future__ import annotations

import json
import secrets
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, UploadFile, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from ..config import settings
from ..database import get_db
from ..deps import get_current_user
from ..models import User
from ..schemas import (
    AdminInstallIn,
    AdminLoginIn,
    AdminProfileUpdateIn,
    InstallStatus,
    LoginIn,
    OtpSendIn,
    OtpVerifyIn,
    ProfileSwitchIn,
    ProfileUpdateIn,
    SignupIn,
    TokenPayload,
    UserOut,
)
from ..security import create_access_token, hash_password, verify_password
from ..services import deepseek_service, otp_service, supabase_auth_service
from ..services.otp_service import OtpError
from ..services.supabase_auth_service import SupabaseAuthError

router = APIRouter(prefix="/api/auth", tags=["auth"])


def _delivery_modes() -> tuple[str, str, str]:
    if settings.supabase_auth_enabled:
        email_mode = "supabase"
    elif settings.smtp_enabled:
        email_mode = "smtp"
    else:
        email_mode = "simulation"
    sms_mode = "textsoft" if settings.sms_enabled else "simulation"
    ai_mode = "ia-nemotron" if deepseek_service.is_available() else "moteur-local"
    return email_mode, sms_mode, ai_mode


def _otp_challenge(db: Session, user: User, purpose: str, profile: str) -> dict[str, Any]:
    context = json.dumps({"uid": user.id, "profile": profile, "purpose": purpose})
    result = otp_service.issue_otp(db, user.email, purpose, context)
    return {
        "requires_otp": True,
        "email": user.email,
        "ticket": result["ticket"],
        "delivery": result["delivery"],
        "dev_code": result["dev_code"],
        "expires_in": result["expires_in"],
        "profile": profile,
        "is_admin": user.is_admin,
    }


def _token_payload(user: User) -> TokenPayload:
    token = create_access_token(user.id, {"role": user.active_profile, "admin": user.is_admin})
    return TokenPayload(
        token=token,
        user=UserOut.model_validate(user),
        requires_otp=False,
        otp_ticket="",
        dev_code="",
    )


@router.get("/status", response_model=InstallStatus)
def installation_status(db: Session = Depends(get_db)) -> InstallStatus:
    admin_count = db.query(func.count(User.id)).filter(User.is_admin.is_(True)).scalar() or 0
    email_mode, sms_mode, ai_mode = _delivery_modes()
    return InstallStatus(
        admin_install_required=admin_count == 0,
        email_delivery=email_mode,
        sms_delivery=sms_mode,
        ai_engine=ai_mode,
        min_reward_amount=settings.min_reward_amount,
        commission_rate=settings.platform_commission_rate,
    )


@router.post("/install", status_code=status.HTTP_201_CREATED)
def install_admin(payload: AdminInstallIn, db: Session = Depends(get_db)) -> dict[str, Any]:
    exists = db.query(func.count(User.id)).filter(User.is_admin.is_(True)).scalar() or 0
    if exists > 0:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="L'administrateur est déjà installé.",
        )

    email = payload.email.lower()
    if db.query(User).filter(User.email == email).first():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Un compte existe déjà avec cette adresse email.",
        )

    admin = User(
        email=email,
        password_hash=hash_password(payload.password),
        first_name=payload.first_name.strip(),
        last_name=payload.last_name.strip(),
        phone=payload.phone.strip(),
        role="admin",
        active_profile="admin",
        is_admin=True,
    )
    db.add(admin)
    db.commit()
    db.refresh(admin)
    return _otp_challenge(db, admin, "admin", "admin")


@router.post("/signup", status_code=status.HTTP_201_CREATED)
def signup(payload: SignupIn, db: Session = Depends(get_db)) -> dict[str, Any]:
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
        role=payload.profile,
        active_profile=payload.profile,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return _otp_challenge(db, user, "signup", payload.profile)


@router.post("/login")
def login(payload: LoginIn, db: Session = Depends(get_db)) -> dict[str, Any]:
    user = db.query(User).filter(User.email == payload.email.lower()).first()
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou mot de passe incorrect.",
        )
    if user.is_blocked:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Votre compte est bloqué. Contactez l'administrateur.",
        )
    if user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Utilisez la section administrateur pour ce compte.",
        )
    return _otp_challenge(db, user, "login", payload.profile)


@router.post("/admin/login")
def admin_login(payload: AdminLoginIn, db: Session = Depends(get_db)) -> dict[str, Any]:
    user = db.query(User).filter(User.email == payload.email.lower()).first()
    if user is None or not user.is_admin or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Identifiants administrateur incorrects.",
        )
    if user.is_blocked:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Ce compte administrateur est bloqué.",
        )
    return _otp_challenge(db, user, "admin", "admin")


@router.post("/otp/send")
def send_otp_via_supabase(payload: OtpSendIn, db: Session = Depends(get_db)) -> dict[str, Any]:
    """Envoi du code OTP par Supabase Auth (le backend ne fait que relayer la demande).

    Si le compte est inconnu, GoTrue le cree avec les metadonnees fournies
    (premiere connexion = inscription sans mot de passe).
    """
    if not settings.supabase_auth_enabled:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="Authentification Supabase non configuree (SUPABASE_URL / SUPABASE_ANON_KEY).",
        )
    email = payload.email.lower()
    data: dict[str, Any] = {}
    if payload.first_name or payload.last_name or payload.profile:
        data = {
            "first_name": payload.first_name.strip(),
            "last_name": payload.last_name.strip(),
            "phone": payload.phone.strip(),
            "profile": payload.profile or "owner",
        }
    try:
        supabase_auth_service.send_email_otp(email, data or None)
    except SupabaseAuthError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc
    return {
        "requires_otp": True,
        "email": email,
        "delivery": "supabase",
        "expires_in": settings.otp_ttl_seconds,
        "dev_code": "",
    }


def _link_or_provision(db: Session, remote_user: dict[str, Any]) -> User:
    uid = str(remote_user.get("id") or "")
    email = str(remote_user.get("email") or "").lower()
    if not uid or not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Reponse Supabase Auth incomplete (id/email absents).",
        )
    user = db.query(User).filter(User.supabase_user_id == uid).first()
    if user is None:
        # Compte DOCTRY historique : lien automatique par email.
        user = db.query(User).filter(User.email == email).first()
    if user is None:
        meta = remote_user.get("user_metadata") or {}
        profile = str(meta.get("profile") or "owner")
        if profile not in ("finder", "owner"):
            profile = "owner"
        user = User(
            email=email,
            password_hash=hash_password(secrets.token_urlsafe(24)),
            first_name=str(meta.get("first_name") or "").strip(),
            last_name=str(meta.get("last_name") or "").strip(),
            phone=str(meta.get("phone") or "").strip(),
            role=profile,
            active_profile=profile,
            supabase_user_id=uid,
        )
        db.add(user)
    else:
        user.supabase_user_id = uid
    db.commit()
    db.refresh(user)
    return user


@router.post("/otp/verify", response_model=TokenPayload)
def verify_otp(payload: OtpVerifyIn, db: Session = Depends(get_db)) -> TokenPayload:
    profile = ""
    if payload.ticket:
        try:
            record = otp_service.verify_otp(db, payload.ticket, payload.code)
        except OtpError as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=exc.message) from exc
        try:
            context = json.loads(record.context_ref or "{}")
        except json.JSONDecodeError:
            context = {}
        uid = str(context.get("uid", ""))
        user = db.get(User, uid)
        profile = str(context.get("profile") or "")
    else:
        if not payload.email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Ticket OTP ou email requis.",
            )
        if not settings.supabase_auth_enabled:
            raise HTTPException(
                status_code=status.HTTP_501_NOT_IMPLEMENTED,
                detail="Authentification Supabase non configuree (SUPABASE_URL / SUPABASE_ANON_KEY).",
            )
        try:
            remote_user = supabase_auth_service.verify_email_otp(payload.email.lower(), payload.code)
        except SupabaseAuthError as exc:
            raise HTTPException(
                status_code=exc.status_code if exc.status_code >= 400 else 400,
                detail=exc.message,
            ) from exc
        user = _link_or_provision(db, remote_user)

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Compte introuvable après vérification OTP.",
        )
    if user.is_blocked:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Votre compte est bloqué. Contactez l'administrateur.",
        )
    if user.is_admin and not profile:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Utilisez la section administrateur pour ce compte.",
        )

    if user.is_admin:
        profile = "admin"
    elif profile not in ("finder", "owner"):
        profile = user.role if user.role in ("finder", "owner") else "owner"

    user.active_profile = profile
    db.commit()
    db.refresh(user)
    return _token_payload(user)


@router.post("/otp/resend")
def resend_otp(email: str, db: Session = Depends(get_db)) -> dict[str, Any]:
    user = db.query(User).filter(User.email == email.lower()).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Compte introuvable.")
    purpose = "admin" if user.is_admin else "login"
    profile = "admin" if user.is_admin else user.active_profile
    return _otp_challenge(db, user, purpose, profile)


@router.get("/me", response_model=UserOut)
def me(current_user: User = Depends(get_current_user)) -> UserOut:
    return UserOut.model_validate(current_user)


@router.patch("/me", response_model=UserOut)
def update_profile(
    payload: ProfileUpdateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserOut:
    if payload.first_name is not None and payload.first_name.strip():
        current_user.first_name = payload.first_name.strip()
    if payload.last_name is not None and payload.last_name.strip():
        current_user.last_name = payload.last_name.strip()
    if payload.phone is not None:
        current_user.phone = payload.phone.strip()
    if payload.password:
        # Securite : le mot de passe actuel est OBLIGATOIRE pour en changer
        if not payload.current_password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Saisissez votre mot de passe actuel pour le modifier.",
            )
        if not verify_password(payload.current_password, current_user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Mot de passe actuel incorrect.",
            )
        current_user.password_hash = hash_password(payload.password)
    db.commit()
    db.refresh(current_user)
    return UserOut.model_validate(current_user)


@router.patch("/me/admin-profile", response_model=UserOut)
def update_admin_profile(
    payload: AdminProfileUpdateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserOut:
    if not current_user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Réservé à l'administrateur.")
    if payload.first_name is not None and payload.first_name.strip():
        current_user.first_name = payload.first_name.strip()
    if payload.last_name is not None and payload.last_name.strip():
        current_user.last_name = payload.last_name.strip()
    if payload.email is not None:
        email = payload.email.lower()
        clash = db.query(User).filter(User.email == email, User.id != current_user.id).first()
        if clash:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Cette adresse email est déjà utilisée.",
            )
        current_user.email = email
    if payload.password:
        # Securite : le mot de passe actuel est OBLIGATOIRE pour en changer
        if not payload.current_password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Saisissez votre mot de passe actuel pour le modifier.",
            )
        if not verify_password(payload.current_password, current_user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Mot de passe actuel incorrect.",
            )
        current_user.password_hash = hash_password(payload.password)
    db.commit()
    db.refresh(current_user)
    return UserOut.model_validate(current_user)


@router.post("/me/photo", response_model=UserOut)
async def upload_profile_photo(
    file: UploadFile,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserOut:
    """Photo de profil : JPG/PNG/WebP, max 5 Mo, servie via /api/media/profiles/{user_id}."""
    allowed = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}
    content_type = (file.content_type or "").lower()
    if content_type not in allowed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Format non supporté. Utilisez JPG, PNG ou WebP.",
        )

    data = await file.read()
    if not data:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Fichier vide.")
    if len(data) > 5 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Image trop lourde (5 Mo maximum).",
        )

    profiles_dir = settings.storage_path / "profiles"
    profiles_dir.mkdir(parents=True, exist_ok=True)

    # Suppression de l'ancienne photo (toutes extensions possibles)
    for old in profiles_dir.glob(f"{current_user.id}.*"):
        old.unlink(missing_ok=True)

    extension = allowed[content_type]
    file_path = profiles_dir / f"{current_user.id}.{extension}"
    file_path.write_bytes(data)

    current_user.profile_photo = str(file_path)
    db.commit()
    return UserOut.model_validate(current_user)


@router.patch("/me/profile", response_model=UserOut)
def switch_profile(
    payload: ProfileSwitchIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserOut:
    if payload.profile == "admin" and not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Accès réservé à l'administrateur.",
        )
    current_user.active_profile = payload.profile
    current_user.role = payload.profile
    db.commit()
    db.refresh(current_user)
    return UserOut.model_validate(current_user)


@router.post("/logout")
def logout(current_user: User = Depends(get_current_user)) -> dict[str, Any]:
    return {"success": True, "message": "Déconnexion effectuée."}


@router.get("/server-time")
def server_time() -> dict[str, Any]:
    return {"now": datetime.now(timezone.utc).isoformat()}
