from collections import defaultdict
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import bindparam, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user, get_room_ids
from app.database import get_session

router = APIRouter(prefix="/api", tags=["Storage rooms"])
DASHBOARD_HOURS = 24
VALUE_RULE_CODES = ["CANH_BAO_NGOAI_KHOANG", "BAT_KHI_VUOT_NGUONG_TREN"]


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
               COUNT(CASE WHEN tb.trang_thai_hoat_dong = 'HOAT_DONG' THEN 1 END) AS so_luong_thiet_bi_dang_hoat_dong
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


@router.get("/storage-rooms/{room_id}/readings")
async def get_room_readings(
    room_id: int,
    user: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    """Dashboard phòng: thông tin phòng; mỗi cảm biến kèm ngưỡng và toàn bộ bản ghi thô
    trong 24 giờ gần nhất (cũ trước, mới sau). Trạng thái thiết bị lấy ở /storage-rooms/{room_id}/devices."""
    if room_id not in await get_room_ids(session, user):
        raise HTTPException(404, "Storage room not found")

    end = datetime.now(UTC).replace(tzinfo=None, microsecond=0)
    start = end - timedelta(hours=DASHBOARD_HOURS)

    room_sql = text("""
        SELECT pk.ma_phong_kho, pk.ten_phong_kho, pk.vi_tri_phong_kho, pk.thong_tin_phong_kho,
               nk.ma_nha_kho, nk.ten_nha_kho
        FROM PhongKho pk
        JOIN NhaKho nk ON nk.ma_nha_kho = pk.ma_nha_kho
        WHERE pk.ma_phong_kho = :room_id
    """)
    room = (await session.execute(room_sql, {"room_id": room_id})).mappings().one()

    sensor_sql = text("""
        SELECT tb.ma_thiet_bi, tb.ten_thiet_bi, pl.ten_phan_loai, pl.don_vi_do
        FROM ThietBiIot tb
        JOIN PhanLoaiThietBi pl ON pl.ma_phan_loai_thiet_bi = tb.ma_phan_loai
        WHERE tb.ma_phong_kho = :room_id
          AND tb.trang_thai_hoat_dong <> 'NGUNG_SU_DUNG'
          AND pl.don_vi_do IS NOT NULL
        ORDER BY tb.ma_phan_loai, tb.ma_thiet_bi
    """)
    sensor_rows = (await session.execute(sensor_sql, {"room_id": room_id})).mappings()
    sensors = [to_json_row(row) for row in sensor_rows]
    sensor_ids = [sensor["ma_thiet_bi"] for sensor in sensors]

    thresholds: dict[int, list] = defaultdict(list)
    readings: dict[int, list] = defaultdict(list)

    if sensor_ids:
        rule_sql = text("""
            SELECT tl.ma_thiet_bi, r.ma_rule, r.ten_rule, r.gioi_han_tren, r.gioi_han_duoi
            FROM ThietLapRule tl
            JOIN RuleEngine r ON r.ma_rule = tl.ma_rule
            WHERE tl.ma_thiet_bi IN :sensor_ids AND r.ma_xu_ly IN :rule_codes
            ORDER BY tl.ma_thiet_bi, r.ma_rule
        """).bindparams(bindparam("sensor_ids", expanding=True), bindparam("rule_codes", expanding=True))
        rule_rows = await session.execute(
            rule_sql, {"sensor_ids": sensor_ids, "rule_codes": VALUE_RULE_CODES}
        )
        for row in rule_rows.mappings():
            item = dict(row)
            thresholds[item.pop("ma_thiet_bi")].append(item)
        
        reading_sql = text("""
            SELECT ma_thiet_bi, thoi_gian_ghi, gia_tri_thong_so
            FROM BangGhiDuLieu
            WHERE ma_thiet_bi IN :sensor_ids AND thoi_gian_ghi >= :start AND thoi_gian_ghi <= :end
            ORDER BY ma_thiet_bi, thoi_gian_ghi
        """).bindparams(bindparam("sensor_ids", expanding=True))
        params = {"sensor_ids": sensor_ids, "start": start, "end": end}
        for row in (await session.execute(reading_sql, params)).mappings():
            item = to_json_row(row)
            readings[item.pop("ma_thiet_bi")].append(item)

    for sensor in sensors:
        sensor["nguong"] = thresholds[sensor["ma_thiet_bi"]]
        sensor["ban_ghi"] = readings[sensor["ma_thiet_bi"]]

    return {
        **to_json_row(room),
        "start": start.replace(tzinfo=UTC),
        "end": end.replace(tzinfo=UTC),
        "thiet_bi": sensors,
    }
