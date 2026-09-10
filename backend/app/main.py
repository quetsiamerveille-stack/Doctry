from __future__ import annotations

from contextlib import asynccontextmanager
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from .config import settings
from .database import init_db
from .routers import admin, auth, chat, declarations, documents, media, notifications, payments, ratings, stats
from .services import deepseek_service


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings.storage_path.mkdir(parents=True, exist_ok=True)
    init_db()
    yield


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description=(
        "Plateforme intelligente de gestion, perte et retrouvaille de documents d'identité. "
        "Backend FastAPI : QR Code natif, matching IA DeepSeek, séquestre OM/MTN, SMS Textsoft."
    ),
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Disposition"],
)

app.include_router(auth.router)
app.include_router(documents.router)
app.include_router(declarations.router)
app.include_router(payments.router)
app.include_router(chat.router)
app.include_router(notifications.router)
app.include_router(ratings.router)
app.include_router(stats.router)
app.include_router(admin.router)
app.include_router(media.router)


@app.exception_handler(RequestValidationError)
async def validation_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    first = (exc.errors() or [{}])[0]
    field = ".".join(str(part) for part in first.get("loc", [])[1:]) or "requete"
    return JSONResponse(
        status_code=422,
        content={"detail": f"Champ invalide : {field}. {first.get('msg', '')}"},
    )


@app.get("/", tags=["system"])
def root() -> dict[str, Any]:
    return {
        "name": settings.app_name,
        "version": settings.app_version,
        "documentation": "/docs",
        "health": "/api/health",
    }


@app.get("/api/health", tags=["system"])
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "version": settings.app_version,
        "ai_engine": "deepseek" if deepseek_service.is_available() else "moteur-local",
        "email_delivery": "smtp" if settings.smtp_enabled else "simulation",
        "sms_delivery": "textsoft" if settings.sms_enabled else "simulation",
        "min_reward_amount": settings.min_reward_amount,
    }


@app.get("/api/config/public", tags=["system"])
def public_config() -> dict[str, Any]:
    return {
        "min_reward_amount": settings.min_reward_amount,
        "commission_rate": settings.platform_commission_rate,
        "rating_interval_days": settings.rating_interval_days,
        "otp_length": settings.otp_length,
        "document_types": [
            "CNI",
            "PASSEPORT",
            "PERMIS",
            "CARTE_VITALE",
            "CARTE_ETUDIANT",
            "CARTE_SEJOUR",
            "ACTE_NAISSANCE",
            "AUTRE",
        ],
    }


def create_session() -> Session:
    from .database import SessionLocal

    return SessionLocal()
