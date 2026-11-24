"""Người dùng hiện tại và phạm vi phòng kho.

TẠM THỜI: người dùng tự khai mã qua header X-Ma-Nguoi-Dung.
Nhiệm vụ 6 sẽ thay hàm get_current_user bằng đăng nhập JWT.
"""

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session

router = APIRouter(prefix="/api", tags=["User"])

OWNER, MANAGER, OPERATOR = 1, 2, 3


async def get_current_user(
    user_id: int = Header(alias="X-User-Id"),
    session: AsyncSession = Depends(get_session),
) -> dict:
    result = await session.execute(
        text("SELECT ma_vai_tro, trang_thai_tai_khoan FROM NguoiDung WHERE ma_nguoi_dung = :id"),
        {"id": user_id},
    )
    row = result.first()
    if row is None:
        raise HTTPException(401, "Người dùng không tồn tại")
    if row.trang_thai_tai_khoan == "BI_KHOA":
        raise HTTPException(403, "Tài khoản đã bị khóa")
    return {"user_id": user_id, "role": row.ma_vai_tro}


async def get_room_ids(session: AsyncSession, user: dict) -> list[int]:
    """Các phòng kho người dùng được xem, tùy theo vai trò."""
    if user["role"] == OWNER:
        sql = """SELECT pk.ma_phong_kho FROM PhongKho pk
                 JOIN NhaKho nk ON nk.ma_nha_kho = pk.ma_nha_kho
                 WHERE nk.ma_chu_doanh_nghiep = :id"""
    elif user["role"] == MANAGER:
        sql = "SELECT ma_phong_kho FROM PhongKho WHERE ma_nguoi_quan_ly = :id"
    else:
        sql = "SELECT ma_phong_kho FROM NhanVienLamViec WHERE ma_nhan_vien = :id"
    result = await session.execute(text(sql), {"id": user["user_id"]})
    return sorted(result.scalars().all())


@router.get("/users/me", tags=["User"])
async def get_me(
    user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    return {
        "ma_nguoi_dung": user["user_id"],
        "ma_vai_tro": user["role"],
        "ds_ma_phong_kho": await get_room_ids(session, user),
    }
