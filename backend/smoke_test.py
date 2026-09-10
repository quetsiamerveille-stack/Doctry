from __future__ import annotations

import shutil
import sys
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(BACKEND_ROOT))

TEST_STORAGE = BACKEND_ROOT / "storage_test"
if TEST_STORAGE.exists():
    shutil.rmtree(TEST_STORAGE, ignore_errors=True)

import os  # noqa: E402

os.environ["STORAGE_DIR"] = str(TEST_STORAGE)
os.environ["DATABASE_URL"] = f"sqlite:///{(TEST_STORAGE / 'test.db').as_posix()}"

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402

PASS = 0
FAIL = 0


def check(label: str, condition: bool, detail: str = "") -> None:
    global PASS, FAIL
    if condition:
        PASS += 1
        print(f"  [OK]   {label}")
    else:
        FAIL += 1
        print(f"  [FAIL] {label} :: {detail}")


def step(title: str) -> None:
    print(f"\n=== {title} ===")


with TestClient(app) as client:
    step("1. Sante et statut d'installation")
    health = client.get("/api/health")
    check("GET /api/health", health.status_code == 200, health.text)
    check("moteur IA reporte", "ai_engine" in health.json(), health.text)

    status_res = client.get("/api/auth/status")
    check("GET /api/auth/status", status_res.status_code == 200, status_res.text)
    check(
        "aucun utilisateur par défaut -> installation requise",
        status_res.json().get("admin_install_required") is True,
        status_res.text,
    )

    step("2. Installation de l'administrateur (créée par l'admin, pas codée en dur)")
    install = client.post(
        "/api/auth/install",
        json={
            "email": "admin@doctry.app",
            "password": "Admin!2026",
            "first_name": "Grace",
            "last_name": "Ndongo",
            "phone": "+237600000000",
        },
    )
    check("POST /api/auth/install", install.status_code == 201, install.text)
    admin_ticket = install.json().get("ticket", "")
    admin_code = install.json().get("dev_code", "")
    check("OTP admin émis", bool(admin_ticket and admin_code), install.text)

    second_install = client.post(
        "/api/auth/install",
        json={
            "email": "other@doctry.app",
            "password": "Admin!2026",
            "first_name": "X",
            "last_name": "Y",
        },
    )
    check("double installation refusée", second_install.status_code == 409, second_install.text)

    verify = client.post("/api/auth/otp/verify", json={"ticket": admin_ticket, "code": admin_code})
    check("vérification OTP admin", verify.status_code == 200, verify.text)
    admin_token = verify.json().get("token", "")
    admin_headers = {"Authorization": f"Bearer {admin_token}"}
    check("profil admin actif", verify.json()["user"]["active_profile"] == "admin", verify.text)

    step("3. OTP invalide rejeté")
    bad = client.post("/api/auth/otp/verify", json={"ticket": admin_ticket, "code": "000000"})
    check("OTP déjà consommé rejeté", bad.status_code == 400, bad.text)

    step("4. Inscription Propriétaire et Trouveur")
    owner_signup = client.post(
        "/api/auth/signup",
        json={
            "profile": "owner",
            "first_name": "Alain",
            "last_name": "Mbarga",
            "email": "alain@doctry.app",
            "password": "Owner!2026",
            "phone": "+237611111111",
        },
    )
    check("inscription propriétaire", owner_signup.status_code == 201, owner_signup.text)
    owner_otp = owner_signup.json()
    owner_verify = client.post(
        "/api/auth/otp/verify",
        json={"ticket": owner_otp["ticket"], "code": owner_otp["dev_code"]},
    )
    check("connexion propriétaire via OTP", owner_verify.status_code == 200, owner_verify.text)
    owner_token = owner_verify.json()["token"]
    owner_headers = {"Authorization": f"Bearer {owner_token}"}

    finder_signup = client.post(
        "/api/auth/signup",
        json={
            "profile": "finder",
            "first_name": "Sylvie",
            "last_name": "Fotso",
            "email": "sylvie@doctry.app",
            "password": "Finder!2026",
            "phone": "+237622222222",
        },
    )
    check("inscription trouveur", finder_signup.status_code == 201, finder_signup.text)
    finder_otp = finder_signup.json()
    finder_verify = client.post(
        "/api/auth/otp/verify",
        json={"ticket": finder_otp["ticket"], "code": finder_otp["dev_code"]},
    )
    finder_token = finder_verify.json()["token"]
    finder_headers = {"Authorization": f"Bearer {finder_token}"}
    check("connexion trouveur via OTP", finder_verify.status_code == 200, finder_verify.text)

    dup = client.post(
        "/api/auth/signup",
        json={
            "profile": "owner",
            "first_name": "A",
            "last_name": "B",
            "email": "alain@doctry.app",
            "password": "Owner!2026",
        },
    )
    check("email dupliqué refusé", dup.status_code == 409, dup.text)

    wrong = client.post(
        "/api/auth/login",
        json={"profile": "owner", "email": "alain@doctry.app", "password": "mauvais"},
    )
    check("mot de passe incorrect refusé", wrong.status_code == 401, wrong.text)

    step("5. Pré-enregistrement de document par QR Code (généré par FastAPI)")
    qr_res = client.post(
        "/api/documents/qr",
        data={
            "doc_type": "CNI",
            "last_name": "Mbarga",
            "first_name": "Alain",
            "phone": "+237611111111",
            "email": "alain@doctry.app",
        },
        headers=owner_headers,
    )
    check("génération QR Code", qr_res.status_code == 201, qr_res.text)
    document = qr_res.json()["document"]
    qr_id = document["qr_id"]
    qr_payload = document["qr_payload"]
    check("qr_id présent", bool(qr_id), qr_res.text)

    qr_image = client.get(f"/api/qr/{qr_id}.png")
    check("image QR servie", qr_image.status_code == 200, str(qr_image.status_code))
    check(
        "signature PNG valide",
        qr_image.content[:8] == b"\x89PNG\r\n\x1a\n",
        qr_image.content[:8].hex(),
    )

    docs_list = client.get("/api/documents", headers=owner_headers)
    check("liste des documents", docs_list.json().get("count") >= 1, docs_list.text)

    step("5b. Pré-enregistrement par photo + floutage automatique des zones sensibles")
    from PIL import Image, ImageDraw

    fake_card = TEST_STORAGE / "fake_cni.png"
    fake_card.parent.mkdir(parents=True, exist_ok=True)
    image = Image.new("RGB", (800, 500), "#FFFFFF")
    draw = ImageDraw.Draw(image)
    draw.rectangle([40, 60, 480, 110], fill="#1A2B4C")
    draw.rectangle([520, 90, 760, 280], fill="#00A8B5")
    draw.rectangle([40, 310, 320, 380], fill="#FFD700")
    image.save(str(fake_card))

    with open(fake_card, "rb") as handle:
        photo_res = client.post(
            "/api/documents/photo",
            data={
                "doc_type": "PERMIS",
                "last_name": "Mbarga",
                "first_name": "Alain",
                "phone": "+237611111111",
                "email": "alain@doctry.app",
                "source": "camera",
            },
            files={"file": ("permis.png", handle, "image/png")},
            headers=owner_headers,
        )
    check("enregistrement par photo", photo_res.status_code == 201, photo_res.text)
    check("floutage automatique produit", photo_res.json().get("blurred") is True, photo_res.text)
    photo_doc = photo_res.json()["document"]

    original = client.get(
        photo_doc["image_url"], headers=owner_headers
    )
    check("image originale servie", original.status_code == 200, str(original.status_code))
    blurred = client.get(photo_doc["blurred_url"], headers=owner_headers)
    check("image floutée servie", blurred.status_code == 200, str(blurred.status_code))
    check(
        "le floutage a modifié les pixels sensibles",
        original.content != blurred.content and len(blurred.content) > 0,
        "contenus identiques",
    )
    denied = client.get(photo_doc["blurred_url"], headers=finder_headers)
    check(
        "image d'autrui refusée au trouveur",
        denied.status_code in (403, 404),
        str(denied.status_code),
    )
    bad_format = client.post(
        "/api/documents/photo",
        data={"doc_type": "CNI"},
        files={"file": ("doc.exe", b"MZ", "application/octet-stream")},
        headers=owner_headers,
    )
    check("format de fichier refusé", bad_format.status_code == 400, bad_format.text)

    step("6. Trouveur : scan du QR Code -> déclaration de retrouvaille + matching")
    peers = client.get("/api/chat/peers", headers=finder_headers)
    check("liste des propriétaires pour le trouveur", peers.status_code == 200, peers.text)
    check(
        "le propriétaire apparaît dans la liste",
        any(item["email"] == "alain@doctry.app" for item in peers.json()["items"]),
        peers.text,
    )

    scan = client.post(
        "/api/declarations/scan",
        data={"payload": qr_payload, "location": "Douala, Akwa"},
        headers=finder_headers,
    )
    check("scan QR -> déclaration", scan.status_code == 201, scan.text)
    scan_body = scan.json()
    find_row = scan_body["find"]
    check("document rattaché au scan", find_row["document_id"] == document["id"], scan.text)
    check(
        "aucune perte encore déclarée -> en attente de matching",
        scan_body["matches"] == [] and find_row["status"] == "pending",
        str(scan_body),
    )
    check(
        "propriétaire identifié grâce au QR",
        find_row["matched_owner_id"] != "",
        str(find_row),
    )

    unknown_scan = client.post(
        "/api/declarations/scan",
        data={"payload": '{"app":"DOCTRY","id":"DCT-INCONNU"}', "location": ""},
        headers=finder_headers,
    )
    check("QR inconnu rejeté", unknown_scan.status_code == 404, unknown_scan.text)

    step("7. Propriétaire : déclaration de perte + récompense en séquestre")
    loss_res = client.post(
        "/api/declarations/losses",
        json={
            "doc_type": "CNI",
            "description": "Perdue au marché de Douala",
            "location": "Douala",
            "document_id": document["id"],
        },
        headers=owner_headers,
    )
    check("déclaration de perte", loss_res.status_code == 201, loss_res.text)
    loss = loss_res.json()["loss"]
    check(
        "statut actif (déclaré ou déjà apparié)",
        loss["status"] in ("declared", "matched"),
        loss_res.text,
    )
    check(
        "matching QR déclenché a posteriori (score 1.0)",
        any(match["score"] >= 0.99 and match["engine"] == "qr" for match in loss_res.json()["matches"]),
        str(loss_res.json()["matches"]),
    )
    check(
        "statut du trouveur repassé à matched",
        all(match["find_status"] == "matched" for match in loss_res.json()["matches"]),
        str(loss_res.json()["matches"]),
    )
    check("date de pré-enregistrement présente", bool(loss["preregistration_date"]), loss_res.text)

    low_reward = client.post(
        "/api/payments/escrow/initiate",
        json={"loss_id": loss["id"], "amount": 1000, "provider": "ORANGE_MONEY"},
        headers=owner_headers,
    )
    check("récompense < 1500 XAF refusée", low_reward.status_code == 400, low_reward.text)

    initiate = client.post(
        "/api/payments/escrow/initiate",
        json={"loss_id": loss["id"], "amount": 5000, "provider": "ORANGE_MONEY"},
        headers=owner_headers,
    )
    check("initiation paiement OM", initiate.status_code == 200, initiate.text)
    reference = initiate.json()["reference"]

    insufficient = client.post(
        "/api/payments/escrow/confirm",
        json={"reference": reference, "pin": "1234"},
        headers=owner_headers,
    )
    check("solde insuffisant détecté", insufficient.status_code == 400, insufficient.text)

    topup = client.post(
        "/api/payments/topup",
        json={"amount": 20000, "provider": "ORANGE_MONEY", "phone": "+237611111111", "pin": "1234"},
        headers=owner_headers,
    )
    check("recharge Mobile Money simulée", topup.status_code == 200, topup.text)
    check("solde crédité", topup.json()["wallet_balance"] == 20000, topup.text)

    bad_pin = client.post(
        "/api/payments/escrow/initiate",
        json={"loss_id": loss["id"], "amount": 5000, "provider": "MTN_MONEY"},
        headers=owner_headers,
    )
    confirm_bad = client.post(
        "/api/payments/escrow/confirm",
        json={"reference": bad_pin.json()["reference"], "pin": "0000"},
        headers=owner_headers,
    )
    check("PIN opérateur rejeté", confirm_bad.status_code == 400, confirm_bad.text)

    confirm = client.post(
        "/api/payments/escrow/confirm",
        json={"reference": reference, "pin": "1234"},
        headers=owner_headers,
    )
    check("fonds bloqués en séquestre", confirm.status_code == 200, confirm.text)
    check("reward_status = escrow", confirm.json().get("reward_status") == "escrow", confirm.text)
    check(
        "solde débiteur de 5000",
        confirm.json().get("wallet_balance") == 15000,
        confirm.text,
    )

    step("8. Libération de la récompense par OTP")
    early_release = client.post(
        "/api/payments/release/request",
        json={"loss_id": loss["id"]},
        headers=owner_headers,
    )
    check("libération avant restitution refusée", early_release.status_code == 400, early_release.text)

    confirm_return = client.post(
        f"/api/declarations/confirm-return?loss_id={loss['id']}&find_id={find_row['id']}",
        headers=owner_headers,
    )
    check("restitution physique confirmée", confirm_return.status_code == 200, confirm_return.text)

    release_req = client.post(
        "/api/payments/release/request",
        json={"loss_id": loss["id"]},
        headers=owner_headers,
    )
    check("OTP de libération envoyé", release_req.status_code == 200, release_req.text)
    release_ticket = release_req.json()["ticket"]

    wrong_release = client.post(
        "/api/payments/release/confirm",
        json={"loss_id": loss["id"], "ticket": release_ticket, "code": "111111"},
        headers=owner_headers,
    )
    check("mauvais OTP de libération refusé", wrong_release.status_code == 400, wrong_release.text)

    release_again = client.post(
        "/api/payments/release/request",
        json={"loss_id": loss["id"]},
        headers=owner_headers,
    )
    release_ticket = release_again.json()["ticket"]
    release_code = release_again.json()["dev_code"]

    release = client.post(
        "/api/payments/release/confirm",
        json={"loss_id": loss["id"], "ticket": release_ticket, "code": release_code},
        headers=owner_headers,
    )
    check("récompense libérée vers le trouveur", release.status_code == 200, release.text)
    if release.status_code == 200:
        transaction = release.json()["transaction"]
        check("commission plateforme prélevée", transaction["commission"] == 250.0, release.text)
        check("reward_status = released", release.json()["reward_status"] == "released", release.text)

    finder_account = client.get("/api/payments/accounts", headers=finder_headers)
    check(
        "trouveur crédité de 4750 XAF net",
        finder_account.json()["wallet_balance"] == 4750.0,
        finder_account.text,
    )

    step("9. Notifications, chat et statistiques")
    owner_notifs = client.get("/api/notifications", headers=owner_headers)
    check("notifications propriétaire", owner_notifs.json()["count"] > 0, owner_notifs.text)
    check(
        "alerte de correspondance présente",
        any(item["kind"] == "match" for item in owner_notifs.json()["items"]),
        owner_notifs.text,
    )

    finder_notifs = client.get("/api/notifications", headers=finder_headers)
    check("notifications trouveur", finder_notifs.json()["count"] > 0, finder_notifs.text)

    read_all = client.post("/api/notifications/read-all", headers=owner_headers)
    check("marquer tout comme lu", read_all.json()["success"] is True, read_all.text)

    conversations = client.get("/api/chat/conversations", headers=owner_headers)
    check("conversation créée automatiquement", conversations.json()["count"] >= 1, conversations.text)
    conversation_id = conversations.json()["items"][0]["id"]

    sent = client.post(
        f"/api/chat/conversations/{conversation_id}/messages",
        json={"body": "Bonjour, où puis-je récupérer mon document ?"},
        headers=owner_headers,
    )
    check("message envoyé", sent.status_code == 201, sent.text)

    replied = client.post(
        f"/api/chat/conversations/{conversation_id}/messages",
        json={"body": "Disponible demain à Akwa."},
        headers=finder_headers,
    )
    check("réponse du trouveur", replied.status_code == 201, replied.text)

    messages = client.get(
        f"/api/chat/conversations/{conversation_id}/messages", headers=owner_headers
    )
    check("historique de 2 messages", messages.json()["count"] == 2, messages.text)

    owner_stats = client.get("/api/stats/owner", headers=owner_headers)
    check("stats propriétaire", owner_stats.status_code == 200, owner_stats.text)
    check("1 déclaration de perte", owner_stats.json()["loss_declarations"] == 1, owner_stats.text)
    check("1 document restitué", owner_stats.json()["returned_documents"] == 1, owner_stats.text)

    finder_stats = client.get("/api/stats/finder", headers=finder_headers)
    check("stats trouveur", finder_stats.status_code == 200, finder_stats.text)
    check("1 retrouvaille", finder_stats.json()["finds_done"] == 1, finder_stats.text)
    check("gains du trouveur", finder_stats.json()["earnings_total"] == 4750.0, finder_stats.text)

    step("10. Matching sémantique sans QR Code (moteur local/IA)")
    manual_loss = client.post(
        "/api/declarations/losses",
        json={
            "doc_type": "PASSEPORT",
            "description": "Passeport camerounais perdu, nom Ngoum Jean, téléphone 699887766",
            "location": "Yaoundé",
        },
        headers=owner_headers,
    )
    check("perte manuelle créée", manual_loss.status_code == 201, manual_loss.text)

    manual_find = client.post(
        "/api/declarations/finds",
        data={
            "doc_type": "PASSEPORT",
            "description": "Passeport camerounais trouvé, nom Ngoum Jean, téléphone 699887766",
            "location": "Yaoundé centre",
            "holder_name": "Ngoum Jean",
            "source": "gallery",
        },
        headers=finder_headers,
    )
    check("retrouvaille manuelle créée", manual_find.status_code == 201, manual_find.text)
    check(
        "correspondance détectée par le moteur",
        len(manual_find.json()["matches"]) >= 1,
        str(manual_find.json().get("matches")),
    )

    step("11. Notation automatique (fenêtre de 3 jours)")
    due = client.get("/api/ratings/due", headers=owner_headers)
    check("évaluation requise à froid", due.json()["due"] is True, due.text)
    check("intervalle de 3 jours", due.json()["interval_days"] == 3, due.text)

    submit = client.post(
        "/api/ratings", json={"stars": 5, "comment": "Excellent"}, headers=owner_headers
    )
    check("soumission 5 étoiles", submit.status_code == 201, submit.text)
    check("moyenne calculée", submit.json()["average_rating"] == 5.0, submit.text)

    due_after = client.get("/api/ratings/due", headers=owner_headers)
    check("plus requise juste après", due_after.json()["due"] is False, due_after.text)

    step("12. Administration : utilisateurs, finance, statistiques")
    users = client.get("/api/admin/users", headers=admin_headers)
    check("liste des utilisateurs", users.json()["count"] == 2, users.text)

    blocked = client.post(
        f"/api/admin/users/{users.json()['items'][0]['id']}/block", headers=admin_headers
    )
    check("blocage utilisateur", blocked.json()["success"] is True, blocked.text)

    unblocked = client.post(
        f"/api/admin/users/{users.json()['items'][0]['id']}/unblock", headers=admin_headers
    )
    check("déblocage utilisateur", unblocked.json()["success"] is True, unblocked.text)

    created = client.post(
        "/api/admin/users",
        json={
            "email": "paul@doctry.app",
            "password": "Paul!2026",
            "first_name": "Paul",
            "last_name": "Biya",
            "role": "finder",
        },
        headers=admin_headers,
    )
    check("admin crée un utilisateur", created.status_code == 201, created.text)

    finance = client.get("/api/admin/finance", headers=admin_headers)
    check("finance globale", finance.status_code == 200, finance.text)
    check("revenu annuel = 250", finance.json()["year_revenue"] == 250.0, finance.text)
    check("séquestre vidé", finance.json()["escrow_balance"] == 0.0, finance.text)

    finance_date = client.get("/api/admin/finance?date=1999-01-01", headers=admin_headers)
    check("recherche par date sans revenu", finance_date.json()["day_revenue"] == 0.0, finance_date.text)

    bad_date = client.get("/api/admin/finance?date=31-12-2026", headers=admin_headers)
    check("format de date invalide rejeté", bad_date.status_code == 400, bad_date.text)

    admin_stats = client.get("/api/admin/stats", headers=admin_headers)
    check("stats admin", admin_stats.status_code == 200, admin_stats.text)
    check("2 pertes enregistrées", admin_stats.json()["counts"]["losses"] == 2, admin_stats.text)
    check("2 retrouvailles", admin_stats.json()["counts"]["finds"] == 2, admin_stats.text)
    check("1 restitution", admin_stats.json()["counts"]["returns"] == 1, admin_stats.text)
    check("en attente de matching listé", "pending_matching" in admin_stats.json(), admin_stats.text)

    overview = client.get("/api/admin/overview", headers=admin_headers)
    check("vue globale admin", overview.status_code == 200, overview.text)

    sms_logs = client.get("/api/admin/sms-logs", headers=admin_headers)
    check("SMS Textsoft journalisés", sms_logs.json()["count"] > 0, sms_logs.text)

    step("13. Cloisonnement des rôles")
    forbidden = client.get("/api/admin/users", headers=owner_headers)
    check("admin interdit au propriétaire", forbidden.status_code == 403, forbidden.text)

    anonymous = client.get("/api/documents")
    check("accès anonyme refusé", anonymous.status_code == 401, anonymous.text)

    invalid = client.get("/api/documents", headers={"Authorization": "Bearer faux.jeton"})
    check("jeton invalide refusé", invalid.status_code == 401, invalid.text)

    step("14. Bascule de profil et mise à jour")
    switch = client.patch(
        "/api/auth/me/profile", json={"profile": "finder"}, headers=owner_headers
    )
    check("bascule vers Trouveur", switch.json()["active_profile"] == "finder", switch.text)
    switch_back = client.patch(
        "/api/auth/me/profile", json={"profile": "owner"}, headers=owner_headers
    )
    check("retour vers Propriétaire", switch_back.json()["active_profile"] == "owner", switch_back.text)

    profile = client.patch(
        "/api/auth/me",
        json={"first_name": "Alain-Roger", "password": "NewOwner!2026"},
        headers=owner_headers,
    )
    check("modification du profil", profile.json()["first_name"] == "Alain-Roger", profile.text)

    relogin = client.post(
        "/api/auth/login",
        json={"profile": "owner", "email": "alain@doctry.app", "password": "NewOwner!2026"},
    )
    check("connexion avec le nouveau mot de passe", relogin.status_code == 200, relogin.text)

print("\n" + "=" * 60)
print(f"RESULTAT : {PASS} succès, {FAIL} échecs")
print("=" * 60)

shutil.rmtree(TEST_STORAGE, ignore_errors=True)
sys.exit(1 if FAIL else 0)
