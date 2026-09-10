from __future__ import annotations

import os
from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_ROOT = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(BACKEND_ROOT / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "DOCTRY API"
    app_version: str = "1.0.0"
    environment: str = "development"

    storage_dir: str = str(BACKEND_ROOT / "storage")
    database_url: str = ""
    port: int = 8000

    jwt_secret: str = "doctry-change-this-secret-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 720

    otp_length: int = 6
    otp_ttl_seconds: int = 600

    min_reward_amount: int = 1500
    platform_commission_rate: float = 0.05
    rating_interval_days: int = 3

    deepseek_api_key: str = ""
    deepseek_base_url: str = "https://openrouter.ai/api/v1"
    deepseek_model: str = "nvidia/nemotron-3-ultra-550b-a55b:free"
    deepseek_timeout: int = 60
    matching_threshold: float = 0.55

    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_tls: bool = True
    mail_from: str = "no-reply@doctry.app"

    textsoft_api_url: str = ""
    textsoft_api_key: str = ""
    textsoft_sender: str = "DOCTRY"

    cors_origins: str = "*"

    @property
    def storage_path(self) -> Path:
        path = Path(self.storage_dir)
        path.mkdir(parents=True, exist_ok=True)
        return path

    @property
    def resolved_database_url(self) -> str:
        if self.database_url:
            return self.database_url
        db_file = self.storage_path / "doctry.db"
        return f"sqlite:///{db_file.as_posix()}"

    @property
    def qr_dir(self) -> Path:
        path = self.storage_path / "qr"
        path.mkdir(parents=True, exist_ok=True)
        return path

    @property
    def docs_dir(self) -> Path:
        path = self.storage_path / "documents"
        path.mkdir(parents=True, exist_ok=True)
        return path

    @property
    def blurred_dir(self) -> Path:
        path = self.storage_path / "blurred"
        path.mkdir(parents=True, exist_ok=True)
        return path

    @property
    def deepseek_enabled(self) -> bool:
        return bool(self.deepseek_api_key.strip())

    @property
    def smtp_enabled(self) -> bool:
        return bool(self.smtp_host.strip() and self.smtp_user.strip())

    @property
    def sms_enabled(self) -> bool:
        return bool(self.textsoft_api_url.strip() and self.textsoft_api_key.strip())

    @property
    def cors_origin_list(self) -> list[str]:
        raw = self.cors_origins.strip()
        if raw in ("", "*"):
            return ["*"]
        return [item.strip() for item in raw.split(",") if item.strip()]


@lru_cache
def get_settings() -> Settings:
    settings = Settings()
    os.environ.setdefault("DOCTRY_STORAGE_DIR", settings.storage_dir)
    return settings


settings = get_settings()
