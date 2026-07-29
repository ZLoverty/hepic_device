import asyncio

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

router = APIRouter()


@router.websocket("/sensors")
async def sensor_stream(websocket: WebSocket):
    """Stream real-time sensor + Klipper state as JSON at ~10 Hz."""
    await websocket.accept()
    broadcaster = websocket.app.state.app_state.broadcaster
    q = broadcaster.subscribe()
    try:
        while True:
            payload = await asyncio.wait_for(q.get(), timeout=5.0)
            await websocket.send_text(payload)
    except (WebSocketDisconnect, asyncio.TimeoutError, asyncio.CancelledError):
        pass
    except Exception:
        # Client dropped the connection at the transport level (e.g. network
        # loss) before Starlette raised WebSocketDisconnect; the underlying
        # write then fails with a non-WebSocketDisconnect error.
        pass
    finally:
        broadcaster.unsubscribe(q)
