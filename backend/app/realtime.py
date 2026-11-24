"""Quản lý kết nối WebSocket và đẩy dữ liệu cảm biến mới theo thời gian thực."""

from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect
from sqlalchemy import text

from app.auth import get_current_user, get_room_ids
from app.database import SessionLocal
from app.event_bus import event_bus

router = APIRouter(prefix="/api", tags=["Realtime"])


class RealtimeManager:
    def __init__(self) -> None:
        self._connections: dict[WebSocket, set[int]] = {}

    async def connect(self, ws: WebSocket, device_ids: set[int]) -> None:
        await ws.accept()
        self._connections[ws] = device_ids

    def disconnect(self, ws: WebSocket) -> None:
        self._connections.pop(ws, None)

    async def broadcast(self, event: dict) -> None:
        for ws, device_ids in list(self._connections.items()):
            if event["ma_thiet_bi"] not in device_ids:
                continue
            try:
                await ws.send_json({"event": "telemetry.created", "data": event})
            except Exception:  # noqa: BLE001 - gửi thất bại vì bất kỳ lý do gì thì coi như đã ngắt kết nối
                self.disconnect(ws)


realtime_manager = RealtimeManager()
event_bus.subscribe("telemetry.created", realtime_manager.broadcast)


@router.websocket("/ws/storage-rooms/{room_id}")
async def ws_storage_room(ws: WebSocket, room_id: int, user_id: int):
    """TEMPORARY: user_id in the query string (browsers cannot set headers on a WebSocket).
    Task 6 replaces it with ?token=<JWT>."""
    async with SessionLocal() as session:
        try:
            user = await get_current_user(user_id, session)
        except HTTPException:
            await ws.close(code=1008)  # 1008 = vi phạm chính sách: từ chối kết nối
            return
        if room_id not in await get_room_ids(session, user):
            await ws.close(code=1008)
            return
        result = await session.execute(
            text("SELECT ma_thiet_bi FROM ThietBiIot WHERE ma_phong_kho = :room_id"),
            {"room_id": room_id},
        )
        device_ids = set(result.scalars().all())

    await realtime_manager.connect(ws, device_ids)
    try:
        while True:
            await ws.receive_text()  # giữ kết nối; phát hiện khi trình duyệt đóng
    except WebSocketDisconnect:
        pass
    finally:
        realtime_manager.disconnect(ws)
