"""Migration manuelle des colonnes DOCTRY sur PostgreSQL/Supabase.

Usage :
    python migrate_db.py            # applique les ALTER TABLE idempotents

Gere les ecarts entre le schéma SQLite historique et les contraintes
strictes de PostgreSQL (longueurs de VARCHAR).
"""
from __future__ import annotations

import sys
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(BACKEND_ROOT))

from sqlalchemy import inspect, text  # noqa: E402

from app.database import engine  # noqa: E402

# (table, colonne, nouveau type) - ordre maintenu pour lisibilite
MIGRATIONS: list[tuple[str, str, str]] = [
    ("otp_codes", "context_ref", "VARCHAR(255)"),
]

# (table, colonne, type) - ajout idempotent de nouvelles colonnes
ADD_COLUMNS: list[tuple[str, str, str]] = [
    ("users", "supabase_user_id", "VARCHAR(36)"),
]


def add_missing_columns() -> int:
    applied = 0
    inspector = inspect(engine)
    with engine.begin() as conn:
        for table, column, column_type in ADD_COLUMNS:
            existing = {c["name"] for c in inspector.get_columns(table)}
            if column in existing:
                print(f"[=] {table}.{column} : deja presente")
                continue
            conn.execute(text(f'ALTER TABLE "{table}" ADD COLUMN "{column}" {column_type}'))
            print(f"[OK] {table}.{column} : ajoutee ({column_type})")
            applied += 1
        conn.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS ix_users_supabase_user_id "
                "ON users (supabase_user_id)"
            )
        )
    return applied


def main() -> int:
    print(f"Cible: {engine.url.host}")
    applied = add_missing_columns()
    if engine.dialect.name != "postgresql":
        print("[=] ajustements VARCHAR ignores (PostgreSQL uniquement)")
        print(f"\n{applied} migration(s) appliquee(s).")
        return 0
    with engine.begin() as conn:
        for table, column, new_type in MIGRATIONS:
            current = conn.execute(
                text(
                    "SELECT character_maximum_length FROM information_schema.columns "
                    "WHERE table_schema = 'public' AND table_name = :t AND column_name = :c"
                ),
                {"t": table, "c": column},
            ).scalar()
            if current is None:
                print(f"[!] {table}.{column} : colonne introuvable, ignoree")
                continue
            limit = int(current)
            wanted = int(new_type.strip("VARCHAR()"))
            if limit >= wanted:
                print(f"[=] {table}.{column} : deja VARCHAR({limit}), rien a faire")
                continue
            conn.execute(
                text(f'ALTER TABLE "{table}" ALTER COLUMN "{column}" TYPE {new_type}')
            )
            print(f"[OK] {table}.{column} : VARCHAR({limit}) -> {new_type}")
            applied += 1
    print(f"\n{applied} migration(s) appliquee(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
