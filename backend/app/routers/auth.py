from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
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
    OtpVerifyIn,
    ProfileSwitchIn,
    ProfileUpdateIn,
    SignupIn,
    TokenPayload,
    UserOut,
)
from ..security import create_access_token, hash_password, verify_password
from ..services import deepseek_service, otp_service
from ..services.otp_service import OtpError

router = APIRouter(prefix="/api/auth", tags=["auth"])


def _delivery_modes() -> tuple[str, str, str]:
    email_mode = "smtp" if settings.smtp_enabled else "simulation"
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


@router.post("/otp/verify", response_model=TokenPayload)
def verify_otp(payload: OtpVerifyIn, db: Session = Depends(get_db)) -> TokenPayload:
    try:
        record = otp_service.verify_otp(db, payload.ticket, payload.code)
    except OtpError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=exc.message) from exc

    try:
        context = json.loads(record.context_ref or "{}")
    except json.JSONDecodeError:
        context = {}

    user = db.get(User, str(context.get("uid", "")))
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

    profile = str(context.get("profile") or user.active_profile)
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
    db.commit()
    db.refresh(current_user)
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
