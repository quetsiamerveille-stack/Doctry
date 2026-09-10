from __future__ import annotations

import json
import uuid
from pathlib import Path

import qrcode
from qrcode.constants import ERROR_CORRECT_H

from ..config import settings

DARK_COLOR = "#1A2B4C"
ACCENT_COLOR = "#00A8B5"
BACK_COLOR = "#FFFFFF"


def build_payload(qr_id: str, data: dict[str, str]) -> str:
    payload = {"app": "DOCTRY", "v": 1, "id": qr_id}
    payload.update({key: value for key, value in data.items() if value})
    return json.dumps(payload, separators=(",", ":"), ensure_ascii=False)


def parse_payload(raw: str) -> dict[str, object]:
    text = (raw or "").strip()
    if not text:
        return {}
    if text.startswith("{"):
        try:
            parsed = json.loads(text)
            return parsed if isinstance(parsed, dict) else {}
        except json.JSONDecodeError:
            return {}
    parts = [chunk for chunk in text.split("|") if chunk != ""]
    if len(parts) >= 2 and parts[0].upper() == "DOCTRY":
        keys = ["id", "t", "ln", "fn", "ph", "em"]
        return dict(zip(keys, parts[1:]))
    return {"raw": text}


def new_qr_id() -> str:
    return f"DCT-{uuid.uuid4().hex[:16].upper()}"


def generate_qr(payload: str, qr_id: str) -> tuple[Path, str]:
    factory = qrcode.image.styledpil.StyledPilImage if _styled_available() else None
    qr = qrcode.QRCode(
        version=None,
        error_correction=ERROR_CORRECT_H,
        box_size=12,
        border=3,
    )
    qr.add_data(payload)
    qr.make(fit=True)

    kwargs: dict[str, object] = {"fill_color": DARK_COLOR, "back_color": BACK_COLOR}
    image = qr.make_image(image_factory=factory, **kwargs) if factory else qr.make_image(**kwargs)

    file_path = settings.qr_dir / f"{qr_id}.png"
    image.save(str(file_path))
    return file_path, f"/api/qr/{qr_id}.png"


def _styled_available() -> bool:
    try:
        import qrcode.image.styledpil  # noqa: F401

        return True
    except Exception:  # noqa: BLE001
        return False


def qr_public_url(qr_id: str) -> str:
    return f"/api/qr/{qr_id}.png"
