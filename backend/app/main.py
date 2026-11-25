"""Điểm khởi động backend.

Chạy ở thư mục backend/:  uvicorn app.main:app --reload
Tài liệu API:             http://127.0.0.1:8000/docs
"""

from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app import auth, devices, realtime, storage_rooms
from app.configuration import config
from app.database import get_session
from app.iot_gateway import iot_gateway


@asynccontextmanager
async def lifespan(_: FastAPI):
    await iot_gateway.start()  # bắt đầu nghe Adafruit IO khi backend khởi động
    yield
    await iot_gateway.stop()  # dừng gọn khi tắt backend


app = FastAPI(title="DADN261 – Backend kho lạnh IoT", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=config.cors_origins.split(","),
    allow_methods=["*"],
    allow_headers=["*"],
)

# Gắn các nhóm API
app.include_router(auth.router)
app.include_router(storage_rooms.router)
app.include_router(realtime.router)
app.include_router(devices.router)


@app.get("/api/health", tags=["System"])
async def suc_khoe(session: AsyncSession = Depends(get_session)):
    """Kiểm tra backend còn chạy và kết nối được CSDL."""
    try:
        await session.execute(text("SELECT 1"))
    except Exception as error:
        print("Lỗi kết nối CSDL:", error)
        raise HTTPException(503, "Không kết nối được CSDL") from error
    return {"trang_thai": "ok"}
