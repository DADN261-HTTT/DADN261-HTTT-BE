"""Task 19: storage room list and room dashboard."""

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import bindparam, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user, get_room_ids
from app.database import get_session

router = APIRouter(prefix="/api", tags=["Storage rooms"])


def to_json_row(row) -> dict:
    """Convert a result row to a dict; DATETIME values (stored as UTC) get an explicit UTC timezone."""
    return {
        key: value.replace(tzinfo=UTC) if isinstance(value, datetime) else value for key, value in row.items()
    }


@router.get("/storage-rooms")
async def list_storage_rooms(
    user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    """Storage rooms the user can access, with a short summary for the list screen."""
    room_ids = await get_room_ids(session, user)
    if not room_ids:
        return []

    sql = text("""
        SELECT pk.ma_phong_kho, pk.ten_phong_kho, nk.ma_nha_kho, nk.ten_nha_kho,
               COUNT(tb.ma_thiet_bi) AS so_luong_thiet_bi,
               COUNT(CASE WHEN tb.trang_thai_hoat_dong = 'DANG_HOAT_DONG' THEN 1 END) AS so_luong_thiet_bi_dang_hoat_dong
        FROM PhongKho pk
        JOIN NhaKho nk ON nk.ma_nha_kho = pk.ma_nha_kho
        LEFT JOIN ThietBiIot tb
               ON tb.ma_phong_kho = pk.ma_phong_kho
              AND tb.trang_thai_hoat_dong <> 'NGUNG_SU_DUNG'
        WHERE pk.ma_phong_kho IN :room_ids
        GROUP BY pk.ma_phong_kho, pk.ten_phong_kho, nk.ma_nha_kho, nk.ten_nha_kho
        ORDER BY pk.ma_phong_kho
    """).bindparams(bindparam("room_ids", expanding=True))
    rows = (await session.execute(sql, {"room_ids": room_ids})).mappings().all()
    return [to_json_row(row) for row in rows]


@router.get("/storage-rooms/{room_id}")
async def get_storage_room(
    room_id: int,
    user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    """Room dashboard: room information and every sensor with its latest reading."""
    if room_id not in await get_room_ids(session, user):
        raise HTTPException(404, "Storage room not found")

    room_sql = text("""
        SELECT pk.ma_phong_kho, pk.ten_phong_kho, pk.vi_tri_phong_kho, pk.thong_tin_phong_kho,
               nk.ma_nha_kho, nk.ten_nha_kho
        FROM PhongKho pk
        JOIN NhaKho nk ON nk.ma_nha_kho = pk.ma_nha_kho
        WHERE pk.ma_phong_kho = :room_id
    """)
    room = (await session.execute(room_sql, {"room_id": room_id})).mappings().one()

    sensor_sql = text("""
        SELECT tb.ma_thiet_bi, tb.ten_thiet_bi, tb.vi_tri_trong_phong,
               tb.trang_thai_hoat_dong, tb.dung_luong_pin, tb.thoi_gian_hoat_dong_lan_cuoi,
               pl.ten_phan_loai, pl.don_vi_do,
               bg.gia_tri_thong_so, bg.thoi_gian_ghi
        FROM ThietBiIot tb
        JOIN PhanLoaiThietBi pl ON pl.ma_phan_loai_thiet_bi = tb.ma_phan_loai
        LEFT JOIN BangGhiDuLieu bg
               ON bg.ma_thiet_bi = tb.ma_thiet_bi
              AND bg.thoi_gian_ghi = (SELECT MAX(thoi_gian_ghi) FROM BangGhiDuLieu
                                      WHERE ma_thiet_bi = tb.ma_thiet_bi)
        WHERE tb.ma_phong_kho = :room_id
          AND tb.trang_thai_hoat_dong <> 'NGUNG_SU_DUNG'
          AND pl.don_vi_do IS NOT NULL
        ORDER BY tb.ma_phan_loai, tb.ma_thiet_bi
    """)
    sensors = (await session.execute(sensor_sql, {"room_id": room_id})).mappings().all()

    return {**to_json_row(room), "thiet_bi": [to_json_row(sensor) for sensor in sensors]}
