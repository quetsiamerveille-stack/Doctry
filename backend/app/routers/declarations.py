from __future__ import annotations

import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from ..config import settings
from ..database import get_db
from ..deps import get_current_user
from ..models import Document, FindDeclaration, LossDeclaration, MatchRecord, User
from ..schemas import LossDeclarationIn
from ..services import matching_service
from ..services.qrcode_service import parse_payload
from ..urls import find_blurred_url, find_image_url

router = APIRouter(prefix="/api/declarations", tags=["declarations"])

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


def _next_number(db: Session, model: Any, field: str, user_id: str) -> int:
    current = (
        db.query(func.max(getattr(model, "number")))
        .filter(getattr(model, field) == user_id)
        .scalar()
    )
    return int(current or 0) + 1


def serialize_loss(db: Session, loss: LossDeclaration) -> dict[str, Any]:
    document = db.get(Document, loss.document_id) if loss.document_id else None
    return {
        "id": loss.id,
        "number": loss.number,
        "doc_type": loss.doc_type,
        "preregistration_date": (
            document.created_at.isoformat() if document and document.created_at else None
        ),
        "loss_date": loss.loss_date.isoformat() if loss.loss_date else None,
        "owner_name": loss.owner_name,
        "owner_id": loss.owner_id,
        "description": loss.description,
        "location": loss.location,
        "status": loss.status,
        "reward_amount": loss.reward_amount,
        "reward_status": loss.reward_status,
        "document_id": loss.document_id,
        "qr_url": f"/api/qr/{document.qr_id}.png" if document and document.qr_id else "",
        "matched_find_id": loss.matched_find_id,
        "returned_at": loss.returned_at.isoformat() if loss.returned_at else None,
        "created_at": loss.created_at.isoformat() if loss.created_at else None,
    }


def serialize_find(db: Session, find: FindDeclaration) -> dict[str, Any]:
    return {
        "id": find.id,
        "number": find.number,
        "doc_type": find.doc_type,
        "found_date": find.found_date.isoformat() if find.found_date else None,
        "holder_name": find.holder_name,
        "finder_id": find.finder_id,
        "description": find.description,
        "location": find.location,
        "source": find.source,
        "status": find.status,
        "document_id": find.document_id,
        "matched_owner_id": find.matched_owner_id,
        "image_url": find_image_url(find.id, bool(find.image_file)),
        "blurred_url": find_blurred_url(find.id, bool(find.blurred_file)),
        "returned_at": find.returned_at.isoformat() if find.returned_at else None,
        "created_at": find.created_at.isoformat() if find.created_at else None,
    }


def serialize_match(db: Session, record: MatchRecord, viewer_id: str) -> dict[str, Any]:
    loss = db.get(LossDeclaration, record.loss_id)
    find = db.get(FindDeclaration, record.find_id)
    if loss is None or find is None:
        return {}
    is_owner = loss.owner_id == viewer_id
    counterpart_id = find.finder_id if is_owner else loss.owner_id
    counterpart = db.get(User, counterpart_id)
    return {
        "id": record.id,
        "loss_id": record.loss_id,
        "find_id": record.find_id,
        "score": record.score,
        "engine": record.engine,
        "reason": record.reason,
        "status": record.status,
        "doc_type": loss.doc_type,
        "counterpart_id": counterpart_id,
        "counterpart_name": counterpart.full_name if counterpart else "",
        "reward_amount": loss.reward_amount,
        "reward_status": loss.reward_status,
        "loss_status": loss.status,
        "find_status": find.status,
        "created_at": record.created_at.isoformat() if record.created_at else None,
    }


@router.get("/losses")
def list_losses(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    query = db.query(LossDeclaration)
    if not current_user.is_admin:
        query = query.filter(LossDeclaration.owner_id == current_user.id)
    losses = query.order_by(LossDeclaration.number.desc()).all()
    return {"items": [serialize_loss(db, item) for item in losses], "count": len(losses)}


@router.post("/losses", status_code=status.HTTP_201_CREATED)
def create_loss(
    payload: LossDeclarationIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    document = None
    if payload.document_id:
        document = db.get(Document, payload.document_id)
        if document is None or document.owner_id != current_user.id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document introuvable.")

    owner_name = current_user.full_name
    if document:
        owner_name = f"{document.holder_first_name} {document.holder_last_name}".strip() or owner_name

    loss = LossDeclaration(
        number=payload.number or _next_number(db, LossDeclaration, "owner_id", current_user.id),
        owner_id=current_user.id,
        document_id=document.id if document else None,
        doc_type=(document.doc_type if document else payload.doc_type).strip().upper(),
        loss_date=payload.loss_date or datetime.now(timezone.utc),
        description=payload.description,
        location=payload.location,
        owner_name=owner_name,
        status="declared",
    )
    db.add(loss)
    if document:
        document.status = "lost"
    db.commit()
    db.refresh(loss)

    matches = matching_service.run_matching_for_loss(db, loss)
    db.refresh(loss)
    return {
        "loss": serialize_loss(db, loss),
        "matches": [serialize_match(db, item, current_user.id) for item in matches],
    }


@router.patch("/losses/{loss_id}/activate")
def activate_loss(
    loss_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    loss = db.get(LossDeclaration, loss_id)
    if loss is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Déclaration introuvable.")
    if loss.owner_id != current_user.id and not current_user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accès refusé.")
    if loss.status in ("returned",):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ce document a déjà été restitué.",
        )
    loss.status = "declared"
    db.commit()
    db.refresh(loss)
    matches = matching_service.run_matching_for_loss(db, loss)
    db.refresh(loss)
    return {
        "loss": serialize_loss(db, loss),
        "matches": [serialize_match(db, item, current_user.id) for item in matches],
    }


@router.get("/finds")
def list_finds(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    query = db.query(FindDeclaration)
    if not current_user.is_admin:
        query = query.filter(FindDeclaration.finder_id == current_user.id)
    finds = query.order_by(FindDeclaration.number.desc()).all()
    return {"items": [serialize_find(db, item) for item in finds], "count": len(finds)}


def _persist_find_image(find: FindDeclaration, upload: UploadFile) -> None:
    suffix = Path(upload.filename or "find.jpg").suffix.lower()
    if suffix not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Format non supporté : {suffix or 'inconnu'}.",
        )
    data = upload.file.read()
    if not data:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Fichier vide.")
    stored = settings.docs_dir / f"{uuid.uuid4().hex}{suffix}"
    stored.write_bytes(data)
    find.image_file = str(stored)
    find.blurred_file = matching_service.blur_image(
        stored, settings.blurred_dir / f"find-{find.id}.png", find.doc_type
    )


@router.post("/finds", status_code=status.HTTP_201_CREATED)
async def create_find(
    doc_type: str = Form(...),
    description: str = Form(""),
    location: str = Form(""),
    holder_name: str = Form(""),
    source: str = Form("gallery"),
    number: int = Form(0),
    file: UploadFile | None = File(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    find = FindDeclaration(
        number=number or _next_number(db, FindDeclaration, "finder_id", current_user.id),
        finder_id=current_user.id,
        doc_type=doc_type.strip().upper(),
        found_date=datetime.now(timezone.utc),
        description=description,
        location=location,
        holder_name=holder_name.strip(),
        source=source,
        status="found",
    )
    db.add(find)
    db.commit()
    db.refresh(find)

    if file is not None and file.filename:
        _persist_find_image(find, file)
        find.fingerprint = matching_service.build_fingerprint(
            find.doc_type,
            {
                "first_name": "",
                "last_name": find.holder_name,
                "phone": "",
                "email": "",
                "identifier": "",
            },
            f"{find.description} {find.location}",
        )
        db.commit()
        db.refresh(find)
    else:
        find.fingerprint = matching_service.build_fingerprint(
            find.doc_type,
            {"first_name": "", "last_name": find.holder_name, "phone": "", "email": "", "identifier": ""},
            f"{find.description} {find.location}",
        )
        db.commit()
        db.refresh(find)

    matches = matching_service.run_matching_for_find(db, find)
    db.refresh(find)
    return {
        "find": serialize_find(db, find),
        "matches": [serialize_match(db, item, current_user.id) for item in matches],
    }


@router.post("/scan", status_code=status.HTTP_201_CREATED)
async def scan_qr(
    payload: str = Form(...),
    location: str = Form(""),
    file: UploadFile | None = File(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    parsed = parse_payload(payload)
    qr_id = str(parsed.get("id", ""))

    document = None
    if qr_id:
        document = db.query(Document).filter(Document.qr_id == qr_id).first()

    if document is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Ce QR Code ne correspond à aucun document pré-enregistré sur DOCTRY.",
        )

    existing = (
        db.query(FindDeclaration)
        .filter(FindDeclaration.document_id == document.id, FindDeclaration.returned_at.is_(None))
        .first()
    )
    if existing:
        return {
            "find": serialize_find(db, existing),
            "matches": [],
            "document": {"id": document.id, "doc_type": document.doc_type},
            "already_declared": True,
        }

    find = FindDeclaration(
        number=_next_number(db, FindDeclaration, "finder_id", current_user.id),
        finder_id=current_user.id,
        document_id=document.id,
        doc_type=document.doc_type,
        found_date=datetime.now(timezone.utc),
        description="Document identifié par scan du QR Code DOCTRY.",
        location=location,
        holder_name=f"{document.holder_first_name} {document.holder_last_name}".strip(),
        source="qr",
        qr_payload=payload,
        fingerprint=document.fingerprint,
        status="found",
        matched_owner_id=document.owner_id,
    )
    db.add(find)
    db.commit()
    db.refresh(find)

    if file is not None and file.filename:
        _persist_find_image(find, file)
        db.commit()
        db.refresh(find)

    matches = matching_service.run_matching_for_find(db, find)
    db.refresh(find)
    return {
        "find": serialize_find(db, find),
        "matches": [serialize_match(db, item, current_user.id) for item in matches],
        "document": {
            "id": document.id,
            "doc_type": document.doc_type,
            "holder": find.holder_name,
        },
        "already_declared": False,
    }


@router.get("/matches")
def list_matches(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    if current_user.is_admin:
        records = db.query(MatchRecord).order_by(MatchRecord.created_at.desc()).limit(300).all()
    else:
        owner_losses = (
            db.query(LossDeclaration.id).filter(LossDeclaration.owner_id == current_user.id)
        )
        finder_finds = (
            db.query(FindDeclaration.id).filter(FindDeclaration.finder_id == current_user.id)
        )
        records = (
            db.query(MatchRecord)
            .filter(
                (MatchRecord.loss_id.in_(owner_losses)) | (MatchRecord.find_id.in_(finder_finds))
            )
            .order_by(MatchRecord.created_at.desc())
            .limit(300)
            .all()
        )
    items = [serialize_match(db, record, current_user.id) for record in records]
    return {"items": [item for item in items if item], "count": len(items)}


@router.post("/confirm-return")
def confirm_return(
    loss_id: str,
    find_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    loss = db.get(LossDeclaration, loss_id)
    find = db.get(FindDeclaration, find_id)
    if loss is None or find is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Déclaration introuvable.")
    if current_user.id not in (loss.owner_id, find.finder_id) and not current_user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accès refusé.")
    if loss.returned_at:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cette restitution a déjà été confirmée.",
        )

    now = datetime.now(timezone.utc)
    loss.returned_at = now
    loss.status = "returned"
    find.returned_at = now
    find.status = "returned"
    if loss.document_id:
        document = db.get(Document, loss.document_id)
        if document:
            document.status = "returned"
    db.commit()
    db.refresh(loss)
    db.refresh(find)
    return {
        "success": True,
        "message": "Restitution confirmée. Vous pouvez maintenant libérer la récompense.",
        "loss": serialize_loss(db, loss),
        "find": serialize_find(db, find),
    }
