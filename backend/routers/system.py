import socket

from fastapi import APIRouter

from .. import __system_name__, __version__
from HEPiC.database.material_database import get_material_database

router = APIRouter()


def _local_ip() -> str | None:
    """Best-effort IP the device would use to reach the LAN (its WiFi address on the Pi)."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except OSError:
        return None
    finally:
        s.close()


@router.get("/info")
def get_info():
    return {
        "system_name": __system_name__,
        "version": __version__,
        "hostname": socket.gethostname(),
        "ip_address": _local_ip(),
        "material_db_version": get_material_database().get_version(),
    }
