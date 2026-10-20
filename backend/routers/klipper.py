import math

from fastapi import APIRouter, Request
from pydantic import BaseModel

router = APIRouter()


def _state(request: Request):
    return request.app.state.app_state


def _clean(v: object) -> object:
    return None if (isinstance(v, float) and not math.isfinite(v)) else v


class TemperatureRequest(BaseModel):
    temperature: float


class GcodeRequest(BaseModel):
    script: str


class ManualJogRequest(BaseModel):
    direction: int


@router.get("/status")
async def get_status(request: Request):
    k = _state(request).klipper
    return {
        "hotend_temperature": _clean(k.hotend_temperature),
        "target_temperature": _clean(k.target_hotend_temperature),
        "feedrate_mms": k.active_feedrate_mms,
        "progress": k.progress,
        "klippy_state": k.klippy_state,
    }


@router.post("/temperature")
async def set_temperature(body: TemperatureRequest, request: Request):
    await _state(request).klipper.set_temperature(body.temperature)
    return {"ok": True}


@router.post("/gcode")
async def send_gcode(body: GcodeRequest, request: Request):
    await _state(request).klipper.send_gcode(body.script)
    return {"ok": True}


@router.post("/manual_jog/start")
async def start_manual_jog(body: ManualJogRequest, request: Request):
    accepted = await _state(request).klipper.start_manual_jog(body.direction)
    return {"ok": True, "accepted": accepted}


@router.post("/manual_jog/stop")
async def stop_manual_jog(request: Request):
    await _state(request).klipper.stop_manual_jog()
    return {"ok": True}


@router.post("/zero_sensors")
async def zero_sensors(request: Request):
    tcp_client = _state(request).tcp_client
    for name in tcp_client.get_zeroable_sensor_names():
        tcp_client.zero_sensor(name)
    return {"ok": True}


@router.post("/emergency_stop")
async def emergency_stop(request: Request):
    await _state(request).klipper.emergency_stop()
    return {"ok": True}


@router.post("/restart")
async def restart_firmware(request: Request):
    await _state(request).klipper.restart_firmware()
    return {"ok": True}


@router.post("/abort_and_recover")
async def abort_and_recover(request: Request):
    await _state(request).klipper.abort_and_recover()
    return {"ok": True}
