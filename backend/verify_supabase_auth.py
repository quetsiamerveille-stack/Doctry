"""Test de verification du flux Supabase Auth (branches feat). Lance via venv depuis backend/.

Force SQLite local + stub du service GoTrue : aucune ecriture sur la base de prod.
"""
import os
import sys

os.environ["DATABASE_URL"] = ""  # -> sqlite local (backend/storage/doctry.db)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402
from app.database import SessionLocal  # noqa: E402
from app.config import settings  # noqa: E402
from app.models import User  # noqa: E402
from app.services import supabase_auth_service as sbs  # noqa: E402

client = TestClient(app)

# -- 1. flux legacy (ticket + dev_code) toujours fonctionnel, supabase desactive --
r = client.post("/api/auth/signup", json={
    "profile": "owner", "first_name": "Legacy", "last_name": "Test",
    "email": "legacy.test@example.com", "password": "secret123",
})
assert r.status_code == 201, r.text
d = r.json()
r = client.post("/api/auth/otp/verify", json={"ticket": d["ticket"], "code": d["dev_code"]})
assert r.status_code == 200, r.text
assert r.json()["token"]
print("[OK] 1. flux legacy signup+ticket intact")

# -- 2. endpoints supabase refusent quand non configure --
assert client.post("/api/auth/otp/send", json={"email": "a@b.c"}).status_code == 501
assert client.post("/api/auth/otp/verify", json={"code": "123456", "email": "a@b.c"}).status_code == 501
print("[OK] 2. otp/send et otp/verify(email) -> 501 sans config")

# -- 3. activation supabase + stub GoTrue --
settings.supabase_url = "https://test.supabase.co"
settings.supabase_anon_key = "anon-test"
sbs.send_email_otp = lambda email, data=None: None
sbs.verify_email_otp = lambda email, token: {
    "id": "11111111-2222-3333-4444-555555555555",
    "email": email,
    "user_metadata": {
        "first_name": "Nouveau", "last_name": "Test",
        "profile": "finder", "phone": "+22900000000",
    },
}
r = client.post("/api/auth/otp/send", json={
    "email": "nouveau.test@example.com", "first_name": "Nouveau",
    "last_name": "Test", "profile": "finder",
})
assert r.status_code == 200, r.text
assert r.json()["delivery"] == "supabase"
r = client.post("/api/auth/otp/verify", json={"code": "123456", "email": "nouveau.test@example.com"})
assert r.status_code == 200, r.text
u = r.json()["user"]
assert u["email"] == "nouveau.test@example.com" and u["role"] == "finder", u
assert client.get("/api/auth/me", headers={"Authorization": f"Bearer {r.json()['token']}"}).status_code == 200
print("[OK] 3. nouveau compte provisionne via otp Supabase + JWT emis par le backend")

# -- 4. compte legacy lie automatiquement par email --
sbs.verify_email_otp = lambda email, token: {
    "id": "99999999-8888-7777-6666-555555555555", "email": email, "user_metadata": {},
}
r = client.post("/api/auth/otp/verify", json={"code": "654321", "email": "legacy.test@example.com"})
assert r.status_code == 200, r.text
db = SessionLocal()
linked = db.query(User).filter(User.email == "legacy.test@example.com").first()
assert linked.supabase_user_id == "99999999-8888-7777-6666-555555555555"
print("[OK] 4. lien automatique supabase_user_id sur compte existant")

# -- 5. statut d'installation annonce 'supabase' --
r = client.get("/api/auth/status")
assert r.json()["email_delivery"] == "supabase", r.text
print("[OK] 5. /status email_delivery=supabase")

# -- menage : suppression des comptes de test --
for email in ("legacy.test@example.com", "nouveau.test@example.com"):
    row = db.query(User).filter(User.email == email).first()
    if row:
        db.delete(row)
db.commit()
db.close()
print("\nTOUS LES TESTS PASSENT")
