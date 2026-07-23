import asyncio
import json
from typing import Optional

from fastapi import APIRouter, HTTPException, Request, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

from HEPiC.database import get_qc_history_store
from HEPiC.database.material_database import get_material_database
from HEPiC.quality_check.gcode import build_quality_check_gcode

router = APIRouter()


def _db():
    return get_material_database()


class QCStartRequest(BaseModel):
    family: str
    pi_code: str


class QCHistoryRequest(BaseModel):
    family: Optional[str] = None
    pi_code: Optional[str] = None
    mean_force: Optional[float] = None
    std_force: Optional[float] = None


@router.post("/start")
async def start_quality_check(body: QCStartRequest, request: Request):
    """Generate QC gcode for the given material and send it to Klipper."""
    material = _db().get_material(body.pi_code, family=body.family)
    if not material:
        raise HTTPException(status_code=404, detail="Material not found")

    gcode = build_quality_check_gcode(material)
    await request.app.state.app_state.klipper.send_gcode(gcode)
    return {"ok": True, "gcode": gcode}


@router.get("/history")
def list_quality_check_history(limit: int = 200):
    """Persisted QC run history (newest first), local to this device."""
    records = get_qc_history_store().list_recent(limit=limit)
    return {"records": [vars(r) for r in records]}


@router.post("/history")
def add_quality_check_history(body: QCHistoryRequest):
    """Record one finished QC run, called by the frontend once a run ends."""
    record = get_qc_history_store().add(
        family=body.family,
        pi_code=body.pi_code,
        mean_force=body.mean_force,
        std_force=body.std_force,
    )
    return vars(record)


@router.websocket("/stream")
async def qc_status_stream(websocket: WebSocket):
    """Stream M118 gcode responses (STATUS, START/STOP_QUALITY_CHECK, etc.)."""
    await websocket.accept()
    klipper = websocket.app.state.app_state.klipper
    q = klipper.subscribe_responses()
    try:
        while True:
            text = await asyncio.wait_for(q.get(), timeout=30.0)
            await websocket.send_text(json.dumps({"response": text}))
    except (WebSocketDisconnect, asyncio.TimeoutError, asyncio.CancelledError):
        pass
    finally:
        klipper.unsubscribe_responses(q)
