"""Test de verification du flux 2FA (mot de passe + OTP envoye par Supabase Auth).

Lance via venv depuis backend/ avec DATABASE_URL vide (SQLite local) :
    DATABASE_URL="" venv/Scripts/python.exe verify_supabase_auth.py
"""
import os
import sys

os.environ["DATABASE_URL"] = ""  # -> sqlite local, jamais la base de prod
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fastapi.testclient import TestClient  # noqa: E402

from app.config import settings  # noqa: E402
from app.database import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models import User  # noqa: E402
from app.services import supabase_auth_service as sbs  # noqa: E402

client = TestClient(app)

# -- 1. flux legacy (ticket + dev_code) quand Supabase non configure --
r = client.post("/api/auth/signup", json={
    "profile": "owner", "first_name": "Legacy", "last_name": "Test",
    "email": "legacy.test@example.com", "password": "secret123",
})
assert r.status_code == 201, r.text
d = r.json()
assert d["ticket"] and d["delivery"] == "simulated"
r = client.post("/api/auth/otp/verify", json={"ticket": d["ticket"], "code": d["dev_code"]})
assert r.status_code == 200, r.text
assert r.json()["token"]
print("[OK] 1. flux legacy signup+ticket intact")

# -- 2. endpoints supabase refusent quand non configure --
assert client.post("/api/auth/otp/send", json={"email": "a@b.c"}).status_code == 501
assert client.post("/api/auth/otp/verify", json={"code": "123456", "email": "a@b.c"}).status_code == 501
print("[OK] 2. otp/send et otp/verify(email) -> 501 sans config")

# -- 3. activation supabase : login = mot de passe puis code OTP Supabase --
settings.supabase_url = "https://test.supabase.co"
settings.supabase_anon_key = "anon-test"
sbs.send_email_otp = lambda email, data=None: None
sbs.verify_email_otp = lambda email, token: {
    "id": "11111111-2222-3333-4444-555555555555",
    "email": email,
    "user_metadata": {},
}

r = client.post("/api/auth/login", json={
    "profile": "owner", "email": "legacy.test@example.com", "password": "mauvais",
})
assert r.status_code == 401, "le mot de passe reste le 1er facteur"

r = client.post("/api/auth/login", json={
    "profile": "finder", "email": "legacy.test@example.com", "password": "secret123",
})
assert r.status_code == 200, r.text
d = r.json()
assert d["ticket"] == "" and d["delivery"] == "supabase" and d["dev_code"] == ""
print("[OK] 3. login mot de passe -> challenge OTP supabase (sans ticket ni dev_code)")

r = client.post("/api/auth/otp/verify", json={
    "code": "123456", "email": "legacy.test@example.com", "profile": "finder",
})
assert r.status_code == 200, r.text
payload = r.json()
assert payload["user"]["active_profile"] == "finder"
assert client.get("/api/auth/me", headers={"Authorization": f"Bearer {payload['token']}"}).status_code == 200
db = SessionLocal()
linked = db.query(User).filter(User.email == "legacy.test@example.com").first()
assert linked.supabase_user_id == "11111111-2222-3333-4444-555555555555"
print("[OK] 4. verify(email, code) -> compte lie + JWT emis par le backend")

# -- 5. renvoi du code via /otp/send (compte existant seulement) --
r = client.post("/api/auth/otp/send", json={"email": "legacy.test@example.com"})
assert r.status_code == 200 and r.json()["delivery"] == "supabase", r.text
assert client.post("/api/auth/otp/send", json={"email": "inconnu@example.com"}).status_code == 404
print("[OK] 5. otp/send: 200 pour compte existant, 404 sinon")

# -- 6. pas de provisioning : code valide mais compte DOCTRY inconnu -> 401 --
sbs.verify_email_otp = lambda email, token: {
    "id": "22222222-2222-2222-2222-222222222222", "email": email, "user_metadata": {},
}
r = client.post("/api/auth/otp/verify", json={"code": "654321", "email": "jamais.inscrit@example.com"})
assert r.status_code == 401, r.text
print("[OK] 6. aucun compte cree sans passage par /signup (mot de passe requis)")

# -- 7. statut d'installation annonce 'supabase' --
r = client.get("/api/auth/status")
assert r.json()["email_delivery"] == "supabase", r.text
print("[OK] 7. /status email_delivery=supabase")

# -- menage : suppression des comptes de test --
for email in ("legacy.test@example.com",):
    row = db.query(User).filter(User.email == email).first()
    if row:
        db.delete(row)
db.commit()
db.close()
print("\nTOUS LES TESTS PASSENT")
