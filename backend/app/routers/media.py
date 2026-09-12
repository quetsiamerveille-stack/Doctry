from __future__ import annotations

from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from ..config import settings
from ..database import get_db
from ..models import Document, FindDeclaration, User
from ..security import decode_access_token

router = APIRouter(tags=["media"])


def resolve_user(request: Request, db: Session) -> User | None:
    token = ""
    header = request.headers.get("Authorization", "")
    if header.lower().startswith("bearer "):
        token = header[7:].strip()
    if not token:
        token = request.query_params.get("token", "")
    if not token:
        return None
    payload = decode_access_token(token)
    if not payload or not payload.get("sub"):
        return None
    return db.get(User, str(payload["sub"]))


def require_user(request: Request, db: Session = Depends(get_db)) -> User:
    user = resolve_user(request, db)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentification requise."
        )
    return user


def _image_response(path_str: str) -> FileResponse:
    path = Path(path_str)
    if not path_str or not path.exists():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Fichier introuvable.")
    return FileResponse(str(path), media_type="image/png")


@router.get("/api/qr/{filename}")
def get_qr(filename: str) -> FileResponse:
    qr_id = filename[:-4] if filename.lower().endswith(".png") else filename
    if not qr_id or "/" in qr_id or "\\" in qr_id or ".." in qr_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Identifiant invalide.")

    path = settings.qr_dir / f"{qr_id}.png"
    if not path.exists():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="QR Code introuvable.")
    return FileResponse(str(path), media_type="image/png")


@router.get("/api/media/documents/{document_id}")
def document_image(
    document_id: str,
    request: Request,
    db: Session = Depends(get_db),
) -> FileResponse:
    user = require_user(request, db)
    document = db.get(Document, document_id)
    if document is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document introuvable.")
    if document.owner_id != user.id and not user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accès refusé.")
    return _image_response(document.image_file)


@router.get("/api/media/documents/{document_id}/blurred")
def document_blurred(
    document_id: str,
    request: Request,
    db: Session = Depends(get_db),
) -> FileResponse:
    user = require_user(request, db)
    document = db.get(Document, document_id)
    if document is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document introuvable.")
    allowed = document.owner_id == user.id or user.is_admin
    if not allowed:
        linked = (
            db.query(FindDeclaration)
            .filter(FindDeclaration.document_id == document.id, FindDeclaration.finder_id == user.id)
            .first()
        )
        allowed = linked is not None
    if not allowed:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accès refusé.")
    if not document.blurred_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Version floutée indisponible."
        )
    return _image_response(document.blurred_file)


@router.get("/api/media/finds/{find_id}")
def find_image(
    find_id: str,
    request: Request,
    db: Session = Depends(get_db),
) -> FileResponse:
    user = require_user(request, db)
    find = db.get(FindDeclaration, find_id)
    if find is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Déclaration introuvable.")
    allowed = find.finder_id == user.id or user.is_admin or find.matched_owner_id == user.id
    if not allowed:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accès refusé.")
    return _image_response(find.image_file)


@router.get("/api/media/profiles/{user_id}")
def profile_photo(
    user_id: str,
    request: Request,
    db: Session = Depends(get_db),
) -> FileResponse:
    """Photo de profil d'un utilisateur (authentifie requis, anti-enum)."""
    user = require_user(request, db)
    target = db.get(User, user_id)
    if target is None or not target.profile_photo:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Photo de profil introuvable.")
    path = Path(target.profile_photo)
    if not path.exists():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Photo de profil introuvable.")
    # Seul le proprietaire de la photo (ou un admin) peut la voir en pleine taille
    if target.id != user.id and not user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accès refusé.")
    return FileResponse(str(path))


@router.get("/api/media/finds/{find_id}/blurred")
def find_blurred(
    find_id: str,
    request: Request,
    db: Session = Depends(get_db),
) -> FileResponse:
    user = require_user(request, db)
    find = db.get(FindDeclaration, find_id)
    if find is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Déclaration introuvable.")
    allowed = find.finder_id == user.id or user.is_admin or find.matched_owner_id == user.id
    if not allowed:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accès refusé.")
    if not find.blurred_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Version floutée indisponible."
        )
    return _image_response(find.blurred_file)
