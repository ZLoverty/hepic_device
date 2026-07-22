import socket
import subprocess
from pathlib import Path

from fastapi import APIRouter, HTTPException

from .. import __system_name__, __version__
from HEPiC.database.material_database import get_material_database

router = APIRouter()

# backend/routers/system.py -> backend/ -> repo root
REPO_ROOT = Path(__file__).resolve().parents[2]
UPDATE_SCRIPT = REPO_ROOT / "scripts" / "update.sh"
UPDATE_LOG = REPO_ROOT / "update.log"
UPDATE_RUNNING = REPO_ROOT / "update.running"


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


@router.post("/update")
def trigger_update():
    """Kick off git pull + install.sh + service restart in the background.

    Returns immediately; poll GET /update/status for progress. The update
    runs detached (start_new_session) so it survives the `systemctl restart`
    it issues against this very process.
    """
    if UPDATE_RUNNING.exists():
        raise HTTPException(status_code=409, detail="Update already in progress")
    subprocess.Popen(
        [str(UPDATE_SCRIPT)],
        cwd=REPO_ROOT,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return {"status": "started"}


@router.get("/update/status")
def update_status(tail: int = 200):
    log = UPDATE_LOG.read_text(errors="replace").splitlines()[-tail:] if UPDATE_LOG.exists() else []
    return {"running": UPDATE_RUNNING.exists(), "log": log}
