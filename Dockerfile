# Dockerfile backend DOCTRY pour Render.com
FROM python:3.12-slim

# Deux variables de build : petite image + pas de cache pip
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Dependances systeme minimales (bcrypt/psycopg2 sont en wheels pures)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Installation des dependances Python
COPY backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Code de l'application
COPY backend/app ./app
COPY backend/run.py ./run.py

# Frontend web compile ( servi par FastAPI sur / ) - build avec :
#   flutter build web --release --dart-define=API_BASE_URL=https://doctry-api.onrender.com
COPY build/web ./static

# Dossier de stockage (QR, photos) - monte en volume Render
RUN mkdir -p /app/storage

ENV PORT=${PORT:-8000}
EXPOSE 8000

# Uvicorn : Render injecte PORT dynamiquement
CMD ["sh", "-c", "python run.py --port=${PORT}"]
