from __future__ import annotations

from .models import Document, FindDeclaration


def qr_url(qr_id: str) -> str:
    return f"/api/qr/{qr_id}.png" if qr_id else ""


def document_image_url(document_id: str, has_image: bool) -> str:
    return f"/api/media/documents/{document_id}" if has_image else ""


def document_blurred_url(document_id: str, has_blurred: bool) -> str:
    return f"/api/media/documents/{document_id}/blurred" if has_blurred else ""


def find_image_url(find_id: str, has_image: bool) -> str:
    return f"/api/media/finds/{find_id}" if has_image else ""


def find_blurred_url(find_id: str, has_blurred: bool) -> str:
    return f"/api/media/finds/{find_id}/blurred" if has_blurred else ""


def document_urls(document: Document) -> tuple[str, str, str]:
    return (
        qr_url(document.qr_id),
        document_image_url(document.id, bool(document.image_file)),
        document_blurred_url(document.id, bool(document.blurred_file)),
    )


def find_urls(find: FindDeclaration) -> tuple[str, str]:
    return (
        find_image_url(find.id, bool(find.image_file)),
        find_blurred_url(find.id, bool(find.blurred_file)),
    )
