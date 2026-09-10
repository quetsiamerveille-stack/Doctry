from __future__ import annotations

import uuid
from pathlib import Path
from typing import Any

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from ..config import settings
from ..database import get_db
from ..deps import get_current_user
from ..models import Document, User
from ..services import matching_service
from ..services.qrcode_service import build_payload, generate_qr, new_qr_id
from ..urls import document_blurred_url, document_image_url, qr_url

router = APIRouter(prefix="/api/documents", tags=["documents"])

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}
MAX_UPLOAD_BYTES = 12 * 1024 * 1024


def serialize(document: Document) -> dict[str, Any]:
    return {
        "id": document.id,
        "doc_type": document.doc_type,
        "holder_first_name": document.holder_first_name,
        "holder_last_name": document.holder_last_name,
        "holder_phone": document.holder_phone,
        "holder_email": document.holder_email,
        "qr_id": document.qr_id,
        "qr_url": qr_url(document.qr_id),
        "qr_payload": document.qr_payload,
        "image_url": document_image_url(document.id, bool(document.image_file)),
        "blurred_url": document_blurred_url(document.id, bool(document.blurred_file)),
        "status": document.status,
        "created_at": document.created_at.isoformat() if document.created_at else None,
    }


def _save_upload(upload: UploadFile) -> Path:
    suffix = Path(upload.filename or "document.jpg").suffix.lower()
    if suffix not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Format non supporté : {suffix or 'inconnu'}. Utilisez JPG, PNG ou WEBP.",
        )
    data = upload.file.read()
    if not data:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Fichier vide.")
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Fichier trop volumineux (12 Mo maximum).",
        )
    destination = settings.docs_dir / f"{uuid.uuid4().hex}{suffix}"
    destination.write_bytes(data)
    return destination


@router.post("/qr", status_code=status.HTTP_201_CREATED)
def register_by_qr(
    doc_type: str = Form(...),
    last_name: str = Form(...),
    first_name: str = Form(...),
    phone: str = Form(""),
    email: str = Form(""),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    qr_id = new_qr_id()
    payload = build_payload(
        qr_id,
        {
            "t": doc_type.strip().upper(),
            "ln": last_name.strip(),
            "fn": first_name.strip(),
            "ph": phone.strip(),
            "em": email.strip().lower(),
        },
    )
    file_path, relative_url = generate_qr(payload, qr_id)

    document = Document(
        owner_id=current_user.id,
        doc_type=doc_type.strip().upper(),
        holder_first_name=first_name.strip(),
        holder_last_name=last_name.strip(),
        holder_phone=phone.strip(),
        holder_email=email.strip().lower(),
        qr_id=qr_id,
        qr_payload=payload,
        qr_file=str(file_path),
        status="preregistered",
        fingerprint=matching_service.build_fingerprint(
            doc_type,
            {
                "first_name": first_name,
                "last_name": last_name,
                "phone": phone,
                "email": email,
                "identifier": qr_id,
            },
        ),
    )
    db.add(document)
    db.commit()
    db.refresh(document)
    return {"document": serialize(document), "qr_url": relative_url}


@router.post("/photo", status_code=status.HTTP_201_CREATED)
async def register_by_photo(
    file: UploadFile = File(...),
    doc_type: str = Form(...),
    last_name: str = Form(""),
    first_name: str = Form(""),
    phone: str = Form(""),
    email: str = Form(""),
    source: str = Form("gallery"),
    document_id: str = Form(""),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    stored = _save_upload(file)
    doc_type_value = doc_type.strip().upper()

    if document_id:
        document = db.get(Document, document_id)
        if document is None or document.owner_id != current_user.id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document introuvable.")
    else:
        qr_id = new_qr_id()
        payload = build_payload(
            qr_id,
            {
                "t": doc_type_value,
                "ln": (last_name or current_user.last_name).strip(),
                "fn": (first_name or current_user.first_name).strip(),
                "ph": (phone or current_user.phone).strip(),
                "em": (email or current_user.email).strip().lower(),
            },
        )
        qr_file, _ = generate_qr(payload, qr_id)
        document = Document(
            owner_id=current_user.id,
            doc_type=doc_type_value,
            holder_first_name=(first_name or current_user.first_name).strip(),
            holder_last_name=(last_name or current_user.last_name).strip(),
            holder_phone=(phone or current_user.phone).strip(),
            holder_email=(email or current_user.email).strip().lower(),
            qr_id=qr_id,
            qr_payload=payload,
            qr_file=str(qr_file),
            status="preregistered",
        )
        db.add(document)
        db.commit()
        db.refresh(document)

    document.image_file = str(stored)
    blurred_path = settings.blurred_dir / f"{document.id}.png"
    document.blurred_file = matching_service.blur_image(stored, blurred_path, document.doc_type)
    document.fingerprint = matching_service.build_fingerprint(
        document.doc_type,
        {
            "first_name": document.holder_first_name,
            "last_name": document.holder_last_name,
            "phone": document.holder_phone,
            "email": document.holder_email,
            "identifier": document.qr_id,
        },
        source,
    )
    db.commit()
    db.refresh(document)
    return {"document": serialize(document), "blurred": bool(document.blurred_file)}


@router.get("")
def list_documents(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    documents = (
        db.query(Document)
        .filter(Document.owner_id == current_user.id)
        .order_by(Document.created_at.desc())
        .all()
    )
    return {"items": [serialize(item) for item in documents], "count": len(documents)}


@router.get("/{document_id}")
def get_document(
    document_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    document = db.get(Document, document_id)
    if document is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document introuvable.")
    if document.owner_id != current_user.id and not current_user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accès refusé.")
    return serialize(document)


@router.delete("/{document_id}")
def delete_document(
    document_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    document = db.get(Document, document_id)
    if document is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document introuvable.")
    if document.owner_id != current_user.id and not current_user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Accès refusé.")
    db.delete(document)
    db.commit()
    return {"success": True, "message": "Document supprimé."}
