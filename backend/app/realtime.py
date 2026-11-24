"""Quản lý kết nối WebSocket và đẩy dữ liệu cảm biến mới theo thời gian thực."""
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.event_bus import event_bus

router = APIRouter(tags=["Realtime"])


class RealtimeManager:
    def __init__(self) -> None:
        self._connections: set[WebSocket] = set()

    async def connect(self, ws: WebSocket) -> None:
        await ws.accept()
        self._connections.add(ws)

    def disconnect(self, ws: WebSocket) -> None:
        self._connections.discard(ws)

    async def broadcast(self, event: dict[str, Any]) -> None:
        dead: list[WebSocket] = []
        for ws in list(self._connections):
            try:
                await ws.send_json({"event": "telemetry.created", "data": event})
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(ws)


realtime_manager = RealtimeManager()
event_bus.subscribe("telemetry.created", realtime_manager.broadcast)


@router.websocket("/ws/telemetry")
async def ws_telemetry(ws: WebSocket) -> None:
    await realtime_manager.connect(ws)
    try:
        while True:
            await ws.receive_text()
    except WebSocketDisconnect:
        realtime_manager.disconnect(ws)