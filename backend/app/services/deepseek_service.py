from __future__ import annotations

import json
import re
from typing import Any

import httpx

from ..config import settings

SENSITIVE_ZONE_TEMPLATES: dict[str, list[tuple[float, float, float, float, str]]] = {
    "CNI": [
        (0.05, 0.12, 0.55, 0.10, "numero_document"),
        (0.05, 0.62, 0.35, 0.14, "signature"),
        (0.66, 0.18, 0.30, 0.38, "photo"),
    ],
    "PASSEPORT": [
        (0.06, 0.10, 0.50, 0.09, "numero_passeport"),
        (0.62, 0.16, 0.34, 0.40, "photo"),
        (0.06, 0.78, 0.88, 0.16, "zone_mrz"),
    ],
    "PERMIS": [
        (0.05, 0.13, 0.52, 0.09, "numero_permis"),
        (0.66, 0.20, 0.30, 0.36, "photo"),
    ],
    "CARTE_VITALE": [
        (0.05, 0.15, 0.45, 0.10, "numero_secu"),
        (0.66, 0.22, 0.30, 0.34, "photo"),
    ],
    "CARTE_ETUDIANT": [
        (0.05, 0.16, 0.45, 0.09, "numero_etudiant"),
        (0.66, 0.20, 0.30, 0.36, "photo"),
    ],
    "CARTE_SEJOUR": [
        (0.05, 0.12, 0.55, 0.10, "numero_titre"),
        (0.66, 0.18, 0.30, 0.38, "photo"),
    ],
    "ACTE_NAISSANCE": [
        (0.08, 0.20, 0.60, 0.10, "numero_acte"),
        (0.10, 0.72, 0.35, 0.12, "signature"),
    ],
    "AUTRE": [
        (0.05, 0.10, 0.55, 0.10, "zone_identifiante"),
    ],
}


def is_available() -> bool:
    return settings.deepseek_enabled


def _extract_json(text: str) -> dict[str, Any]:
    if not text:
        return {}
    fenced = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", text, re.DOTALL)
    candidate = fenced.group(1) if fenced else None
    if candidate is None:
        brace = re.search(r"\{.*\}", text, re.DOTALL)
        candidate = brace.group(0) if brace else None
    if candidate is None:
        return {}
    try:
        parsed = json.loads(candidate)
        return parsed if isinstance(parsed, dict) else {}
    except json.JSONDecodeError:
        return {}


def chat(system_prompt: str, user_prompt: str) -> str:
    if not settings.deepseek_enabled:
        return ""
    try:
        response = httpx.post(
            f"{settings.deepseek_base_url.rstrip('/')}/chat/completions",
            headers={
                "Authorization": f"Bearer {settings.deepseek_api_key}",
                "Content-Type": "application/json",
                # En-tetes OpenRouter : identification de l'app appelante
                "HTTP-Referer": "https://doctry.app",
                "X-Title": "DOCTRY Document Matching",
            },
            json={
                "model": settings.deepseek_model,
                "temperature": 0.1,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
            },
            timeout=settings.deepseek_timeout,
        )
        response.raise_for_status()
        data = response.json()
        # Format OpenAI-compatible (DeepSeek comme OpenRouter)
        return data["choices"][0]["message"]["content"]
    except (httpx.HTTPError, KeyError, IndexError, ValueError):
        return ""


def analyze_document(doc_type: str, fields: dict[str, str], ocr_text: str = "") -> dict[str, Any]:
    prompt = (
        "Tu es un moteur d'analyse documentaire. "
        "Analyse les informations ci-dessous et renvoie UNIQUEMENT un objet JSON avec les cles: "
        "\"normalized\" (objet: type, first_name, last_name, phone, email, identifier), "
        "\"keywords\" (tableau de 8 mots-cles discriminants maximum), "
        "\"confidence\" (nombre entre 0 et 1), "
        "\"sensitivity\" (\"high\"|\"medium\"|\"low\").\n\n"
        f"Type de document: {doc_type}\n"
        f"Champs declares: {json.dumps(fields, ensure_ascii=False)}\n"
        f"Texte brut extrait: {ocr_text[:1200] or 'aucun'}"
    )
    raw = chat("Tu es l'IA documentaire de la plateforme DOCTRY.", prompt)
    parsed = _extract_json(raw)
    if parsed:
        parsed["engine"] = "ai"
        return parsed

    normalized = {
        "type": (doc_type or "").strip().upper(),
        "first_name": (fields.get("first_name") or "").strip(),
        "last_name": (fields.get("last_name") or "").strip(),
        "phone": re.sub(r"\D", "", fields.get("phone") or ""),
        "email": (fields.get("email") or "").strip().lower(),
        "identifier": (fields.get("identifier") or "").strip(),
    }
    keywords = [
        token
        for token in re.split(r"[^A-Za-z0-9]+", f"{ocr_text} {' '.join(fields.values())}")
        if len(token) >= 4
    ][:8]
    return {
        "normalized": normalized,
        "keywords": keywords,
        "confidence": 0.45,
        "sensitivity": "medium",
        "engine": "local",
    }


def detect_sensitive_zones(doc_type: str, width: int, height: int) -> list[dict[str, Any]]:
    key = (doc_type or "AUTRE").strip().upper()
    template = SENSITIVE_ZONE_TEMPLATES.get(key, SENSITIVE_ZONE_TEMPLATES["AUTRE"])
    zones = [
        {
            "x": int(rx * width),
            "y": int(ry * height),
            "w": max(8, int(rw * width)),
            "h": max(8, int(rh * height)),
            "label": label,
        }
        for rx, ry, rw, rh, label in template
    ]

    prompt = (
        "Tu es un moteur de detection de zones sensibles sur un document d'identite. "
        f"Le document est de type {key} et l'image mesure {width}x{height} pixels. "
        "Renvoie UNIQUEMENT un objet JSON {\"zones\":[{\"x\":int,\"y\":int,\"w\":int,\"h\":int,"
        "\"label\":string}]} couvrant les donnees extremement sensibles "
        "(numero de document, photo, signature, adresse, zone MRZ)."
    )
    raw = chat("Tu es l'IA de floutage automatique de DOCTRY.", prompt)
    parsed = _extract_json(raw)
    ai_zones = parsed.get("zones") if isinstance(parsed, dict) else None
    if isinstance(ai_zones, list) and ai_zones:
        cleaned: list[dict[str, Any]] = []
        for zone in ai_zones[:8]:
            if not isinstance(zone, dict):
                continue
            try:
                x = max(0, min(width - 1, int(zone.get("x", 0))))
                y = max(0, min(height - 1, int(zone.get("y", 0))))
                w = max(4, min(width - x, int(zone.get("w", 0))))
                h = max(4, min(height - y, int(zone.get("h", 0))))
            except (TypeError, ValueError):
                continue
            cleaned.append({"x": x, "y": y, "w": w, "h": h, "label": str(zone.get("label", "zone"))})
        if cleaned:
            return cleaned

    return zones


def compare_documents(left: dict[str, Any], right: dict[str, Any]) -> dict[str, Any]:
    prompt = (
        "Tu es le moteur de matching de documents perdus/retrouves. "
        "Compare les deux fiches ci-dessous et renvoie UNIQUEMENT un objet JSON "
        "{\"score\": nombre entre 0 et 1, \"reason\": explication courte en francais}.\n\n"
        f"Fiche A (perte): {json.dumps(left, ensure_ascii=False)[:900]}\n"
        f"Fiche B (retrouvaille): {json.dumps(right, ensure_ascii=False)[:900]}"
    )
    raw = chat("Tu es l'IA de comparaison documentaire de DOCTRY.", prompt)
    parsed = _extract_json(raw)
    score = parsed.get("score")
    if isinstance(score, (int, float)):
        return {
            "score": max(0.0, min(1.0, float(score))),
            "reason": str(parsed.get("reason", "Comparaison IA"))[:400],
            "engine": "ai",
        }
    return {"score": -1.0, "reason": "", "engine": "ai_unavailable"}
