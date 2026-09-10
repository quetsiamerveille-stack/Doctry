from __future__ import annotations

import sys
from datetime import date

import httpx

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8000"

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


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


with httpx.Client(base_url=BASE, timeout=60.0) as http:
    step("1. Serveur HTTP réel")
    health = http.get("/api/health")
    check("GET /api/health", health.status_code == 200, health.text)
    check("CORS autorisé", http.options("/api/health").status_code in (200, 405))

    status = http.get("/api/auth/status")
    check("statut d'installation exposé", status.status_code == 200, status.text)
    payload = status.json()
    check("montant minimum de récompense = 1500", payload["min_reward_amount"] == 1500, status.text)
    install_required = payload["admin_install_required"]

    step("2. Administrateur créé à la volée (aucun compte codé en dur)")
    if install_required:
        install = http.post(
            "/api/auth/install",
            json={
                "email": "admin@doctry.live",
                "password": "Admin!2026",
                "first_name": "Grace",
                "last_name": "Ndongo",
                "phone": "+237600000000",
            },
        )
        check("POST /api/auth/install", install.status_code == 201, install.text)
        ticket = install.json()["ticket"]
        code = install.json()["dev_code"]
    else:
        login = http.post(
            "/api/auth/admin/login",
            json={"email": "admin@doctry.live", "password": "Admin!2026"},
        )
        check("connexion admin existante", login.status_code == 200, login.text)
        ticket = login.json()["ticket"]
        code = login.json()["dev_code"]

    verify = http.post("/api/auth/otp/verify", json={"ticket": ticket, "code": code})
    check("OTP admin vérifié", verify.status_code == 200, verify.text)
    admin_token = verify.json()["token"]
    check("profil admin actif", verify.json()["user"]["active_profile"] == "admin", verify.text)

    step("3. Inscription du propriétaire et du trouveur")
    owner_signup = http.post(
        "/api/auth/signup",
        json={
            "profile": "owner",
            "first_name": "Alain",
            "last_name": "Mbarga",
            "email": "alain@doctry.live",
            "password": "Owner!2026",
            "phone": "+237611111111",
        },
    )
    check("inscription propriétaire", owner_signup.status_code == 201, owner_signup.text)
    owner_otp = owner_signup.json()
    owner_verify = http.post(
        "/api/auth/otp/verify",
        json={"ticket": owner_otp["ticket"], "code": owner_otp["dev_code"]},
    )
    check("OTP propriétaire vérifié", owner_verify.status_code == 200, owner_verify.text)
    owner = auth(owner_verify.json()["token"])

    finder_signup = http.post(
        "/api/auth/signup",
        json={
            "profile": "finder",
            "first_name": "Sylvie",
            "last_name": "Fotso",
            "email": "sylvie@doctry.live",
            "password": "Finder!2026",
            "phone": "+237622222222",
        },
    )
    check("inscription trouveur", finder_signup.status_code == 201, finder_signup.text)
    finder_otp = finder_signup.json()
    finder_verify = http.post(
        "/api/auth/otp/verify",
        json={"ticket": finder_otp["ticket"], "code": finder_otp["dev_code"]},
    )
    check("OTP trouveur vérifié", finder_verify.status_code == 200, finder_verify.text)
    finder = auth(finder_verify.json()["token"])

    step("4. QR Code généré par FastAPI et servi en PNG")
    qr = http.post(
        "/api/documents/qr",
        data={
            "doc_type": "CNI",
            "last_name": "Mbarga",
            "first_name": "Alain",
            "phone": "+237611111111",
            "email": "alain@doctry.live",
        },
        headers=owner,
    )
    check("génération du QR Code", qr.status_code == 201, qr.text)
    document = qr.json()["document"]
    qr_payload = document["qr_payload"]

    image = http.get(document["qr_url"])
    check("image PNG servie", image.status_code == 200, str(image.status_code))
    check("signature PNG valide", image.content[:8] == b"\x89PNG\r\n\x1a\n", image.content[:8].hex())

    listed = http.get("/api/documents", headers=owner)
    check("document listé", listed.json()["count"] >= 1, listed.text)

    step("5. Trouveur : scan du QR Code puis déclaration de retrouvaille")
    scan = http.post(
        "/api/declarations/scan",
        data={"payload": qr_payload, "location": "Douala, Akwa"},
        headers=finder,
    )
    check("scan QR -> déclaration", scan.status_code == 201, scan.text)
    find_row = scan.json()["find"]
    check("document rattaché au scan", find_row["document_id"] == document["id"], scan.text)

    step("6. Propriétaire : perte, récompense en séquestre, restitution")
    loss_res = http.post(
        "/api/declarations/losses",
        json={
            "number": 1,
            "doc_type": "CNI",
            "description": "Perdue au marché de Douala",
            "location": "Douala",
            "document_id": document["id"],
        },
        headers=owner,
    )
    check("déclaration de perte", loss_res.status_code == 201, loss_res.text)
    loss = loss_res.json()["loss"]
    check("matching IA déclenché", len(loss_res.json()["matches"]) >= 1, loss_res.text)

    topup = http.post(
        "/api/payments/topup",
        json={"amount": 20000, "provider": "ORANGE_MONEY", "phone": "+237611111111", "pin": "1234"},
        headers=owner,
    )
    check("recharge Mobile Money simulée", topup.status_code == 200, topup.text)

    initiate = http.post(
        "/api/payments/escrow/initiate",
        json={"loss_id": loss["id"], "amount": 5000, "provider": "ORANGE_MONEY", "phone": "+237611111111"},
        headers=owner,
    )
    check("initiation du séquestre", initiate.status_code == 200, initiate.text)
    reference = initiate.json()["reference"]
    check("code USSD Orange Money fourni", initiate.json()["ussd"] != "", initiate.text)

    confirm = http.post(
        "/api/payments/escrow/confirm",
        json={"reference": reference, "pin": "1234"},
        headers=owner,
    )
    check("fonds bloqués sur le compte plateforme", confirm.status_code == 200, confirm.text)
    check("reward_status = escrow", confirm.json().get("reward_status") == "escrow", confirm.text)

    returned = http.post(
        f"/api/declarations/confirm-return?loss_id={loss['id']}&find_id={find_row['id']}",
        headers=owner,
    )
    check("restitution physique confirmée", returned.status_code == 200, returned.text)

    release_req = http.post("/api/payments/release/request", json={"loss_id": loss["id"]}, headers=owner)
    check("OTP de libération envoyé", release_req.status_code == 200, release_req.text)

    release = http.post(
        "/api/payments/release/confirm",
        json={
            "loss_id": loss["id"],
            "ticket": release_req.json()["ticket"],
            "code": release_req.json()["dev_code"],
        },
        headers=owner,
    )
    check("récompense libérée vers le trouveur", release.status_code == 200, release.text)
    check("commission plateforme prélevée", release.json()["transaction"]["commission"] == 250.0, release.text)

    finder_account = http.get("/api/payments/accounts", headers=finder)
    check("trouveur crédité de 4750 XAF net", finder_account.json()["wallet_balance"] == 4750.0, finder_account.text)

    step("7. Chat interne, notifications et statistiques")
    conversations = http.get("/api/chat/conversations", headers=owner)
    check("conversation mise en relation", conversations.json()["count"] >= 1, conversations.text)
    conversation_id = conversations.json()["items"][0]["id"]

    sent = http.post(
        f"/api/chat/conversations/{conversation_id}/messages",
        json={"body": "Bonjour, où puis-je récupérer mon document ?"},
        headers=owner,
    )
    check("message envoyé", sent.status_code == 201, sent.text)

    messages = http.get(f"/api/chat/conversations/{conversation_id}/messages", headers=finder)
    check("message reçu par le trouveur", messages.json()["count"] >= 1, messages.text)

    notifs = http.get("/api/notifications", headers=owner)
    check("notification de correspondance", any(i["kind"] == "match" for i in notifs.json()["items"]), notifs.text)

    owner_stats = http.get("/api/stats/owner", headers=owner)
    check("stats propriétaire", owner_stats.json()["returned_documents"] >= 1, owner_stats.text)
    finder_stats = http.get("/api/stats/finder", headers=finder)
    check("stats trouveur", finder_stats.json()["finds_done"] >= 1, finder_stats.text)

    step("8. Notation automatique tous les 3 jours")
    due = http.get("/api/ratings/due", headers=finder)
    check("fenêtre de notation exposée", due.status_code == 200, due.text)
    rating = http.post("/api/ratings", json={"stars": 5, "comment": "Excellent service."}, headers=finder)
    check("évaluation 5 étoiles enregistrée", rating.status_code == 201, rating.text)

    step("9. Console d'administration")
    users = http.get("/api/admin/users", headers=auth(admin_token))
    check("liste des utilisateurs", users.json()["count"] >= 2, users.text)
    target = next(u for u in users.json()["items"] if u["email"] == "sylvie@doctry.live")

    blocked = http.post(f"/api/admin/users/{target['id']}/block", headers=auth(admin_token))
    check("blocage utilisateur", blocked.status_code == 200, blocked.text)
    unblocked = http.post(f"/api/admin/users/{target['id']}/unblock", headers=auth(admin_token))
    check("déblocage utilisateur", unblocked.status_code == 200, unblocked.text)

    finance = http.get("/api/admin/finance", headers=auth(admin_token))
    check("revenus annuels", finance.json()["year_revenue"] == 250.0, finance.text)
    check("revenus mensuels", finance.json()["month_revenue"] == 250.0, finance.text)

    by_date = http.get(f"/api/admin/finance?date={date.today().isoformat()}", headers=auth(admin_token))
    check("recherche par date précise", by_date.status_code == 200, by_date.text)

    admin_stats = http.get("/api/admin/stats", headers=auth(admin_token))
    check("stats pertes", len(admin_stats.json()["losses"]) >= 1, admin_stats.text)
    check("stats retrouvailles", len(admin_stats.json()["finds"]) >= 1, admin_stats.text)
    check("stats restitutions", len(admin_stats.json()["returns"]) >= 1, admin_stats.text)
    check("stats en attente de matching", "pending_matching" in admin_stats.json(), admin_stats.text)

    overview = http.get("/api/admin/overview", headers=auth(admin_token))
    check("vue globale admin", overview.json()["returned"] >= 1, overview.text)

    sms = http.get("/api/admin/sms-logs", headers=auth(admin_token))
    check("journal SMS Textsoft", sms.json()["count"] >= 1, sms.text)

    step("10. Sécurité")
    check("accès anonyme refusé", http.get("/api/admin/users").status_code in (401, 403))
    check("admin interdit au propriétaire", http.get("/api/admin/users", headers=owner).status_code == 403)
    check("jeton invalide refusé", http.get("/api/auth/me", headers=auth("faux")).status_code == 401)

print("\n" + "=" * 60)
print(f"RESULTAT LIVE : {PASS} succès, {FAIL} échecs  ({BASE})")
print("=" * 60)
sys.exit(1 if FAIL else 0)
