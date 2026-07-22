import asyncio

from fastapi import APIRouter, HTTPException

from HEPiC.database import sync_materials
from HEPiC.database.material_database import get_material_database

router = APIRouter()


def _db():
    return get_material_database()


@router.get("/")
def list_families():
    return {"families": _db().get_family_names()}


@router.get("/version")
def get_version():
    return {"version": _db().get_version()}


@router.post("/sync")
async def sync():
    """Pull the latest material database (GitHub release, falling back to the
    Tencent COS mirror) and reload it into the running process. No restart
    needed — sync_materials() never raises, it just logs and keeps the
    existing cache on any failure."""
    before = _db().get_version()
    await asyncio.to_thread(sync_materials)
    db = _db()
    db.load()
    return {
        "version": db.get_version(),
        "changed": db.get_version() != before,
        "families": len(db.get_family_names()),
        "materials": len(db.materials),
    }


@router.get("/{family}")
def list_materials(family: str):
    db = _db()
    if family not in db.material_families:
        raise HTTPException(status_code=404, detail="Family not found")
    return {"pi_codes": db.get_pi_codes(family)}


@router.get("/{family}/{pi_code}")
def get_material(family: str, pi_code: str):
    material = _db().get_material(pi_code, family=family)
    if not material:
        raise HTTPException(status_code=404, detail="Material not found")
    return material
