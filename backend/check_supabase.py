"""Verification de la connexion Supabase pour DOCTRY.

Usage :
    python check_supabase.py            # lit DATABASE_URL depuis backend/.env
    python check_supabase.py <URL>      # teste une URL passee en argument

Etapes :
  1. Connexion PostgreSQL (SSL force)
  2. Version du serveur + latence
  3. Creation des 13 tables DOCTRY (Base.metadata.create_all)
  4. Listing des tables + comptage des lignes
"""
from __future__ import annotations

import sys
import time
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(BACKEND_ROOT))


def normalize_url(url: str) -> str:
    url = url.strip().strip('"').strip("'")
    if url.startswith("postgres://"):
        url = "postgresql://" + url[len("postgres://"):]
    if "sslmode" not in url:
        separator = "&" if "?" in url else "?"
        url = f"{url}{separator}sslmode=require"
    return url


def main() -> int:
    raw_url = sys.argv[1] if len(sys.argv) > 1 else None
    if raw_url is None:
        from app.config import settings

        raw_url = settings.database_url
        source = "backend/.env"
    else:
        source = "argument"

    if not raw_url or not raw_url.startswith(("postgresql://", "postgres://")):
        print("[!] DATABASE_URL non configuree -> SQLite local en service.")
        print("    Renseignez DATABASE_URL dans backend/.env (voir .env.example)")
        print("    puis relancez : python check_supabase.py")
        return 1

    url = normalize_url(raw_url)
    host = url.split("@")[-1].split(":")[0] if "@" in url else "?"
    print(f"[1] Connexion a {host} (source: {source}) ...")

    try:
        from sqlalchemy import create_engine, text
    except ImportError:
        print("[X] SQLAlchemy introuvable.")
        return 2

    try:
        started = time.perf_counter()
        engine = create_engine(url, pool_pre_ping=True)
        with engine.connect() as conn:
            version = conn.execute(text("SELECT version()")).scalar()
            latency_ms = (time.perf_counter() - started) * 1000
        print(f"[OK] Connexion etablie ({latency_ms:.0f} ms)")
        print(f"    {str(version)[:80]}")
    except Exception as exc:  # noqa: BLE001
        message = str(exc).replace("\n", " ")[:160]
        print(f"[X] Echec de connexion : {message}")
        if "password" in message.lower() or "authentication" in message.lower():
            print("    -> Verifiez le mot de passe de la base (percent-encode les caracteres speciaux).")
        elif "tenant" in message.lower():
            print("    -> Mauvaise region : le pooler attendu est aws-1-eu-west-1.pooler.supabase.com")
        return 3

    print("[2] Creation des tables DOCTRY ...")
    from app.database import Base  # noqa: E402
    from app import models  # noqa: F401,E402  (enregistre les modeles)

    try:
        Base.metadata.create_all(bind=engine)
        print("[OK] Tables creees (ou deja existantes)")
    except Exception as exc:  # noqa: BLE001
        print(f"[X] Echec de creation des tables : {str(exc)[:160]}")
        return 4

    print("[3] Inventaire des tables ...")
    try:
        with engine.connect() as conn:
            rows = conn.execute(
                text(
                    "SELECT tablename FROM pg_tables "
                    "WHERE schemaname = 'public' ORDER BY tablename"
                )
            ).fetchall()
            total = 0
            for row in rows:
                name = row[0]
                count = conn.execute(text(f'SELECT COUNT(*) FROM "{name}"')).scalar()
                total += int(count or 0)
                print(f"    {name:<22} {count} ligne(s)")
            print(f"[OK] {len(rows)} table(s), {total} ligne(s) au total")
    except Exception as exc:  # noqa: BLE001
        print(f"[X] Echec d'inventaire : {str(exc)[:160]}")
        return 5

    print("\n=== CONNEXION SUPABASE OPERATIONNELLE ===")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
