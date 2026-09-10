import os
import socket
import sys

# Empêche l'héritage d'un PYTHONHOME externe qui corrompt la résolution
# de la stdlib dans les processus enfants (multiprocessing / reloader).
if os.environ.get("PYTHONHOME"):
    del os.environ["PYTHONHOME"]

import uvicorn

from app.config import settings


def is_port_available(host: str, port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        try:
            s.bind((host, port))
            return True
        except OSError:
            return False


def select_port(default_port: int) -> int:
    env_port = os.environ.get("PORT")
    if env_port and env_port.isdigit():
        return int(env_port)
    for arg in sys.argv[1:]:
        if arg.startswith("--port="):
            return int(arg.split("=", 1)[1])
        if arg.isdigit():
            return int(arg)

    if is_port_available("127.0.0.1", default_port):
        return default_port

    fallback = default_port + 1 if default_port == 8000 else 8001
    if is_port_available("127.0.0.1", fallback):
        print(
            f"[DOCTRY] Port {default_port} indisponible (occupe par un autre service). "
            f"Bascule automatique sur le port {fallback}."
        )
        return fallback

    return default_port


if __name__ == "__main__":
    target_port = select_port(settings.port)
    print(f"[DOCTRY] Demarrage du serveur FastAPI sur http://127.0.0.1:{target_port} ...")
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=target_port,
        reload=settings.environment == "development",
    )
