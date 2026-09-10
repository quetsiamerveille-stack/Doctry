from __future__ import annotations

import json
import re
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any

from PIL import Image, ImageFilter
from sqlalchemy import or_
from sqlalchemy.orm import Session

from ..config import settings
from ..models import (
    Conversation,
    Document,
    FindDeclaration,
    LossDeclaration,
    MatchRecord,
    User,
)
from . import deepseek_service, notification_service, sms_service

EMAIL_PATTERN = re.compile(r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}")
PHONE_PATTERN = re.compile(r"\+?\d[\d\s.\-()]{6,18}\d")
NAME_PATTERN = re.compile(
    r"\b(?:nom|nomme|nommé|titulaire|proprietaire|propriétaire|porteur|name)"
    r"\s*[:\-]?\s*([A-ZÀ-Ý][\w'\-]*(?:\s+[A-ZÀ-Ý][\w'\-]*){0,2})",
    re.IGNORECASE,
)
CAPITALIZED_PAIR_PATTERN = re.compile(
    r"\b[A-ZÀ-Ý][\w'\-]*(?:\s+[A-ZÀ-Ý][\w'\-]*)+\b"
)
IDENTIFIER_PATTERN = re.compile(
    r"\b(?:n[°o]|numero|numéro|num|identifiant|id)\s*[:\-]?\s*([A-Z0-9][A-Z0-9\-]{3,19})",
    re.IGNORECASE,
)
NAME_STOPWORDS = {
    "passeport",
    "carte",
    "permis",
    "document",
    "doctry",
    "cni",
    "acte",
    "sejour",
    "séjour",
    "identite",
    "identité",
    "nationale",
    "perdu",
    "perdue",
    "recompense",
    "récompense",
}


def blur_image(source: str | Path, destination: str | Path, doc_type: str) -> str:
    src = Path(source)
    if not src.exists():
        return ""
    try:
        with Image.open(src) as raw:
            image = raw.convert("RGB")
            width, height = image.size
            zones = deepseek_service.detect_sensitive_zones(doc_type, width, height)
            radius = max(10, min(width, height) // 26)
            for zone in zones:
                left = max(0, zone["x"])
                top = max(0, zone["y"])
                right = min(width, left + zone["w"])
                bottom = min(height, top + zone["h"])
                if right <= left or bottom <= top:
                    continue
                region = image.crop((left, top, right, bottom))
                region = region.filter(ImageFilter.GaussianBlur(radius=radius))
                image.paste(region, (left, top))
            Path(destination).parent.mkdir(parents=True, exist_ok=True)
            image.save(destination, format="PNG")
        return str(destination)
    except (OSError, ValueError):
        return ""


def _clean(value: Any) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip().lower()


def _digits(value: Any) -> str:
    return re.sub(r"\D", "", str(value or ""))


def extract_identity_from_text(text: str) -> dict[str, str]:
    extracted = {"phone": "", "email": "", "full_name": "", "identifier": ""}
    if not text:
        return extracted

    emails = EMAIL_PATTERN.findall(text)
    if emails:
        extracted["email"] = emails[0].lower()

    candidates = [re.sub(r"\D", "", item) for item in PHONE_PATTERN.findall(text)]
    candidates = [item for item in candidates if 8 <= len(item) <= 15]
    if candidates:
        extracted["phone"] = max(candidates, key=len)

    name_match = NAME_PATTERN.search(text)
    if name_match:
        extracted["full_name"] = re.sub(r"\s+", " ", name_match.group(1)).strip()
    else:
        pairs = [
            item
            for item in CAPITALIZED_PAIR_PATTERN.findall(text)
            if _clean(item) not in NAME_STOPWORDS
        ]
        if pairs:
            extracted["full_name"] = max(pairs, key=lambda item: len(item.split()))

    identifier_match = IDENTIFIER_PATTERN.search(text)
    if identifier_match:
        extracted["identifier"] = identifier_match.group(1).strip()

    return extracted


def _merge_fields(fields: dict[str, str], raw_text: str) -> dict[str, str]:
    merged = {key: str(value or "").strip() for key, value in fields.items()}
    extracted = extract_identity_from_text(raw_text)

    if not merged.get("phone") and extracted["phone"]:
        merged["phone"] = extracted["phone"]
    if not merged.get("email") and extracted["email"]:
        merged["email"] = extracted["email"]
    if not merged.get("identifier") and extracted["identifier"]:
        merged["identifier"] = extracted["identifier"]

    first = merged.get("first_name", "")
    last = merged.get("last_name", "")
    if not first and not last and extracted["full_name"]:
        parts = extracted["full_name"].split()
        first = parts[0]
        last = " ".join(parts[1:]) if len(parts) > 1 else ""
    if not first and last and " " in last:
        parts = last.split()
        first = parts[0]
        last = " ".join(parts[1:])

    merged["first_name"] = first
    merged["last_name"] = last
    return merged


def build_fingerprint(doc_type: str, fields: dict[str, str], raw_text: str = "") -> str:
    merged = _merge_fields(fields, raw_text)
    analysis = deepseek_service.analyze_document(doc_type, merged, raw_text)
    normalized = analysis.get("normalized") or {}

    keywords = {
        _clean(word)
        for word in (analysis.get("keywords") or [])
        if len(_clean(word)) >= 3
    }
    keywords.update(
        token
        for token in re.split(r"[^A-Za-z0-9]+", f"{raw_text} {' '.join(merged.values())}")
        if len(token) >= 4 and _clean(token) not in NAME_STOPWORDS
    )

    fingerprint = {
        "type": _clean(normalized.get("type") or doc_type),
        "first_name": _clean(normalized.get("first_name") or merged.get("first_name")),
        "last_name": _clean(normalized.get("last_name") or merged.get("last_name")),
        "phone": _digits(normalized.get("phone") or merged.get("phone")),
        "email": _clean(normalized.get("email") or merged.get("email")),
        "identifier": _clean(normalized.get("identifier") or merged.get("identifier")),
        "keywords": sorted(keywords)[:14],
        "engine": analysis.get("engine", "local"),
        "confidence": float(analysis.get("confidence") or 0.4),
    }
    return json.dumps(fingerprint, ensure_ascii=False)


def parse_fingerprint(raw: str) -> dict[str, Any]:
    if not raw:
        return {}
    try:
        parsed = json.loads(raw)
        return parsed if isinstance(parsed, dict) else {}
    except json.JSONDecodeError:
        return {}


def _similarity(left: str, right: str) -> float:
    left = (left or "").strip()
    right = (right or "").strip()
    if not left or not right:
        return 0.0
    if left == right:
        return 1.0
    return SequenceMatcher(None, left, right).ratio()


def _keyword_overlap(left: list[str], right: list[str]) -> float:
    set_a = {item for item in left if item}
    set_b = {item for item in right if item}
    if not set_a or not set_b:
        return 0.0
    return len(set_a & set_b) / len(set_a | set_b)


def local_score(left: dict[str, Any], right: dict[str, Any]) -> tuple[float, str]:
    components: list[tuple[float, float, str]] = []
    identity_scores: list[float] = []

    def add(weight: float, score: float, label: str, identity: bool = False) -> None:
        components.append((weight, score, label))
        if identity:
            identity_scores.append(score)

    doc_type_score = 1.0 if left.get("type") and left["type"] == right.get("type") else (
        _similarity(str(left.get("type", "")), str(right.get("type", "")))
    )
    add(0.22, doc_type_score, "type de document")

    if left.get("last_name") or right.get("last_name"):
        add(0.22, _similarity(str(left.get("last_name", "")), str(right.get("last_name", ""))), "nom", True)

    if left.get("first_name") or right.get("first_name"):
        add(0.12, _similarity(str(left.get("first_name", "")), str(right.get("first_name", ""))), "prénom", True)

    if left.get("phone") or right.get("phone"):
        score = 1.0 if left.get("phone") and left["phone"] == right.get("phone") else 0.0
        add(0.20, score, "téléphone", True)

    if left.get("email") or right.get("email"):
        score = 1.0 if left.get("email") and left["email"] == right.get("email") else 0.0
        add(0.16, score, "email", True)

    if left.get("identifier") or right.get("identifier"):
        a_id = str(left.get("identifier", ""))
        b_id = str(right.get("identifier", ""))
        score = 1.0 if a_id and a_id == b_id else _similarity(a_id, b_id)
        add(0.22, score, "identifiant", True)

    if left.get("keywords") or right.get("keywords"):
        score = _keyword_overlap(list(left.get("keywords") or []), list(right.get("keywords") or []))
        add(0.10, score, "mots-clés")

    total_weight = sum(weight for weight, _, _ in components) or 1.0
    final = sum(weight * value for weight, value, _ in components) / total_weight

    if not identity_scores or max(identity_scores) < 0.6:
        final = min(final, 0.50)

    strong = [label for weight, value, label in components if value >= 0.85 and weight >= 0.12]
    reason = "Correspondance sur : " + ", ".join(strong) if strong else "Correspondance partielle"
    return round(min(1.0, max(0.0, final)), 4), reason


def score_pair(left: dict[str, Any], right: dict[str, Any]) -> tuple[float, str, str]:
    local, reason = local_score(left, right)
    if not deepseek_service.is_available():
        return local, reason, "local"

    ai = deepseek_service.compare_documents(left, right)
    ai_score = float(ai.get("score", -1.0))
    if ai_score < 0:
        return local, reason, "local"

    combined = round(0.5 * local + 0.5 * ai_score, 4)
    ai_reason = str(ai.get("reason", "")).strip()
    merged = f"{reason} | IA DeepSeek : {ai_reason}" if ai_reason else reason
    return combined, merged[:500], "deepseek"


def loss_fingerprint(db: Session, loss: LossDeclaration) -> dict[str, Any]:
    if loss.fingerprint:
        return parse_fingerprint(loss.fingerprint)

    document = db.get(Document, loss.document_id) if loss.document_id else None
    if document and document.fingerprint:
        loss.fingerprint = document.fingerprint
        db.commit()
        return parse_fingerprint(document.fingerprint)

    fingerprint = build_fingerprint(
        loss.doc_type,
        {"first_name": "", "last_name": "", "phone": "", "email": "", "identifier": ""},
        f"{loss.description} {loss.location}",
    )
    loss.fingerprint = fingerprint
    db.commit()
    return parse_fingerprint(fingerprint)


def find_fingerprint(db: Session, find: FindDeclaration) -> dict[str, Any]:
    if find.fingerprint:
        return parse_fingerprint(find.fingerprint)

    fingerprint = build_fingerprint(
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
    find.fingerprint = fingerprint
    db.commit()
    return parse_fingerprint(fingerprint)


def ensure_conversation(
    db: Session,
    owner_id: str,
    finder_id: str,
    subject: str,
    loss_id: str | None = None,
    find_id: str | None = None,
) -> Conversation:
    existing = (
        db.query(Conversation)
        .filter(
            Conversation.owner_id == owner_id,
            Conversation.finder_id == finder_id,
            or_(
                Conversation.loss_id == loss_id if loss_id else Conversation.loss_id.is_(None),
                Conversation.find_id == find_id if find_id else Conversation.find_id.is_(None),
            ),
        )
        .first()
    )
    if existing:
        return existing

    conversation = Conversation(
        owner_id=owner_id,
        finder_id=finder_id,
        subject=subject,
        loss_id=loss_id,
        find_id=find_id,
    )
    db.add(conversation)
    db.commit()
    db.refresh(conversation)
    return conversation


def _notify_match(
    db: Session,
    loss: LossDeclaration,
    find: FindDeclaration,
    record: MatchRecord,
) -> None:
    owner = db.get(User, loss.owner_id)
    finder = db.get(User, find.finder_id)
    owner_name = owner.full_name if owner else "un propriétaire"
    finder_name = finder.full_name if finder else "un trouveur"
    percent = int(round(record.score * 100))

    notification_service.notify(
        db,
        loss.owner_id,
        "Document similaire trouvé",
        f"Une correspondance de {percent}% a été détectée sur votre {loss.doc_type} "
        f"déclaré perdu, trouvée par {finder_name}.",
        "match",
    )
    notification_service.notify(
        db,
        find.finder_id,
        "Document similaire trouvé",
        f"Le {find.doc_type} que vous avez déclaré correspond à {percent}% à la perte "
        f"signalée par {owner_name}.",
        "match",
    )

    sms_service.send_sms(
        db,
        owner.phone if owner else "",
        sms_service.match_alert_sms(loss.doc_type, "owner", finder_name),
    )
    sms_service.send_sms(
        db,
        finder.phone if finder else "",
        sms_service.match_alert_sms(find.doc_type, "finder", owner_name),
    )

    ensure_conversation(
        db,
        loss.owner_id,
        find.finder_id,
        f"Restitution - {loss.doc_type}",
        loss_id=loss.id,
        find_id=find.id,
    )


def run_matching_for_loss(db: Session, loss: LossDeclaration) -> list[MatchRecord]:
    fingerprint = loss_fingerprint(db, loss)

    candidates = (
        db.query(FindDeclaration)
        .filter(FindDeclaration.returned_at.is_(None))
        .order_by(FindDeclaration.created_at.desc())
        .limit(200)
        .all()
    )

    created: list[MatchRecord] = []
    best_score = 0.0

    for find in candidates:
        already = (
            db.query(MatchRecord)
            .filter(MatchRecord.loss_id == loss.id, MatchRecord.find_id == find.id)
            .first()
        )
        if already:
            best_score = max(best_score, already.score)
            continue

        find_fp = find_fingerprint(db, find)
        qr_hit = bool(
            loss.document_id
            and find.document_id
            and loss.document_id == find.document_id
        )
        if qr_hit:
            score, reason, engine = 1.0, "QR Code identique : document pré-enregistré reconnu", "qr"
        else:
            score, reason, engine = score_pair(fingerprint, find_fp)

        best_score = max(best_score, score)
        if score < settings.matching_threshold:
            continue

        record = MatchRecord(
            loss_id=loss.id,
            find_id=find.id,
            score=score,
            engine=engine,
            reason=reason,
            status="proposed",
        )
        db.add(record)
        db.commit()
        db.refresh(record)

        loss.status = "matched"
        loss.matched_find_id = find.id
        if find.status in ("found", "pending"):
            find.status = "matched"
        find.matched_owner_id = loss.owner_id
        db.commit()

        _notify_match(db, loss, find, record)
        created.append(record)

    if not created and loss.status not in ("matched", "returned"):
        loss.status = loss.status if loss.status == "declared" else "pending"
        db.commit()
        notification_service.notify(
            db,
            loss.owner_id,
            "Aucune correspondance trouvée",
            f"Votre déclaration de perte n°{loss.number} ({loss.doc_type}) est placée "
            "en attente. Le moteur IA relancera la comparaison automatiquement.",
            "waiting",
        )

    return created


def run_matching_for_find(db: Session, find: FindDeclaration) -> list[MatchRecord]:
    fingerprint = find_fingerprint(db, find)

    if find.document_id:
        document = db.get(Document, find.document_id)
        if document and document.owner_id:
            find.matched_owner_id = document.owner_id
            db.commit()

    candidates = (
        db.query(LossDeclaration)
        .filter(LossDeclaration.returned_at.is_(None))
        .order_by(LossDeclaration.created_at.desc())
        .limit(200)
        .all()
    )

    created: list[MatchRecord] = []

    for loss in candidates:
        already = (
            db.query(MatchRecord)
            .filter(MatchRecord.loss_id == loss.id, MatchRecord.find_id == find.id)
            .first()
        )
        if already:
            continue

        loss_fp = loss_fingerprint(db, loss)
        qr_hit = bool(
            find.document_id and loss.document_id and find.document_id == loss.document_id
        )
        if qr_hit:
            score, reason, engine = 1.0, "QR Code identique : document pré-enregistré reconnu", "qr"
        else:
            score, reason, engine = score_pair(loss_fp, fingerprint)

        if score < settings.matching_threshold:
            continue

        record = MatchRecord(
            loss_id=loss.id,
            find_id=find.id,
            score=score,
            engine=engine,
            reason=reason,
            status="proposed",
        )
        db.add(record)
        db.commit()
        db.refresh(record)

        if loss.status not in ("returned", "matched"):
            loss.status = "matched"
        loss.matched_find_id = find.id
        if find.status in ("found", "pending"):
            find.status = "matched"
        find.matched_owner_id = loss.owner_id
        db.commit()

        _notify_match(db, loss, find, record)
        created.append(record)

    if not created and find.status == "found":
        find.status = "pending"
        db.commit()
        notification_service.notify(
            db,
            find.finder_id,
            "Aucune correspondance trouvée",
            f"Votre déclaration de retrouvaille n°{find.number} ({find.doc_type}) est placée "
            "en attente de matching.",
            "waiting",
        )

    return created
