"""Device endpoints (task 19): list by room, device detail, raw readings."""

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user, get_room_ids
from app.database import get_session
from app.storage_rooms import to_json_row

router = APIRouter(prefix="/api", tags=["Devices"])


def to_db_time(value: datetime) -> datetime:
    """Đổi thời điểm người dùng gửi lên về dạng CSDL lưu: giờ UTC, không kèm múi giờ."""
    if value.tzinfo is not None:
        value = value.astimezone(UTC)
    return value.replace(tzinfo=None)


async def get_device(session: AsyncSession, user: dict, device_id: int) -> dict:
    """Thiết bị trong phạm vi người dùng. Không tồn tại hoặc ngoài phạm vi đều trả 404."""
    sql = text("""
        SELECT tb.ma_thiet_bi, tb.ten_thiet_bi, tb.dia_chi_mac, tb.feed_key, tb.vi_tri_trong_phong,
               tb.trang_thai_hoat_dong, tb.dung_luong_pin, tb.thoi_gian_hoat_dong_lan_cuoi,
               pk.ma_phong_kho, pk.ten_phong_kho,
               pl.ten_phan_loai, pl.don_vi_do, pl.don_vi_do
        FROM ThietBiIot tb
        JOIN PhongKho pk ON pk.ma_phong_kho = tb.ma_phong_kho
        JOIN PhanLoaiThietBi pl ON pl.ma_phan_loai_thiet_bi = tb.ma_phan_loai
        WHERE tb.ma_thiet_bi = :device_id
    """)
    row = (await session.execute(sql, {"device_id": device_id})).mappings().first()
    if row is None or row["ma_phong_kho"] not in await get_room_ids(session, user):
        raise HTTPException(404, "Device not found")
    device = to_json_row(row)
    return device


@router.get("/storage-rooms/{room_id}/devices")
async def list_room_devices(
    room_id: int,
    include_inactive: bool = False,
    user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    """Thiết bị của một phòng, thông tin ngắn gọn: cảm biến trước, thiết bị điều khiển sau."""
    if room_id not in await get_room_ids(session, user):
        raise HTTPException(404, "Storage room not found")

    sql = """
        SELECT tb.ma_thiet_bi, tb.ten_thiet_bi,
               pl.ten_phan_loai, pl.don_vi_do,
               tb.trang_thai_hoat_dong
        FROM ThietBiIot tb
        JOIN PhanLoaiThietBi pl ON pl.ma_phan_loai_thiet_bi = tb.ma_phan_loai
        WHERE tb.ma_phong_kho = :room_id
    """
    if not include_inactive:
        sql += " AND tb.trang_thai_hoat_dong <> 'NGUNG_SU_DUNG'"
    sql += " ORDER BY tb.ma_thiet_bi"

    rows = (await session.execute(text(sql), {"room_id": room_id})).mappings().all()
    devices = [to_json_row(row) for row in rows]
    return devices


@router.get("/devices/{device_id}")
async def get_device_detail(
    device_id: int,
    user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    """Chi tiết thiết bị: thông tin đầy đủ, các rule đang gán, bản ghi mới nhất (nếu là cảm biến)."""
    device = await get_device(session, user, device_id)

    rule_sql = text("""
        SELECT r.ma_rule, r.ten_rule, r.ma_xu_ly, r.gioi_han_tren, r.gioi_han_duoi
        FROM ThietLapRule tl
        JOIN RuleEngine r ON r.ma_rule = tl.ma_rule
        WHERE tl.ma_thiet_bi = :device_id
        ORDER BY r.ma_rule
    """)
    rules = (await session.execute(rule_sql, {"device_id": device_id})).mappings().all()
    device["thiet_lap_rule"] = [dict(rule) for rule in rules]

    device["ban_ghi_moi_nhat"] = None
    if device["don_vi_do"] is not None:
        latest_sql = text("""
            SELECT thoi_gian_ghi, gia_tri_thong_so FROM BangGhiDuLieu
            WHERE ma_thiet_bi = :device_id
            ORDER BY thoi_gian_ghi DESC LIMIT 1
        """)
        latest = (await session.execute(latest_sql, {"device_id": device_id})).mappings().first()
        if latest is not None:
            device["ban_ghi_moi_nhat"] = to_json_row(latest)
    return device


@router.get("/devices/{device_id}/readings")
async def list_device_readings(
    device_id: int,
    start: datetime | None = None,
    end: datetime | None = None,
    limit: int = Query(200, ge=1, le=1000),
    user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    """Bản ghi thô của một cảm biến, mới nhất trước.
    Tải thêm: gửi end = thoi_gian_ghi của bản ghi cũ nhất vừa nhận."""
    device = await get_device(session, user, device_id)
    if device["don_vi_do"] is None:
        raise HTTPException(400, "This device has no readings")

    start_db = to_db_time(start) if start else None
    end_db = to_db_time(end) if end else None
    if start_db and end_db and start_db >= end_db:
        raise HTTPException(400, "'start' must be earlier than 'end'")

    sql = "SELECT thoi_gian_ghi, gia_tri_thong_so FROM BangGhiDuLieu WHERE ma_thiet_bi = :device_id"
    params: dict = {"device_id": device_id, "limit": limit}
    if start_db:
        sql += " AND thoi_gian_ghi >= :start"
        params["start"] = start_db
    if end_db:
        sql += " AND thoi_gian_ghi <= :end"
        params["end"] = end_db
    sql += " ORDER BY thoi_gian_ghi DESC LIMIT :limit"

    rows = (await session.execute(text(sql), params)).mappings().all()
    return {
        "ma_thiet_bi": device_id,
        "don_vi_do": device["don_vi_do"],
        "ban_ghi": [to_json_row(row) for row in rows],
    }
