"""Thu nhận, lưu dữ liệu cảm biến chống trùng (RB29) và phát sự kiện dữ liệu mới."""

from datetime import UTC, datetime
from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import SessionLocal
from app.event_bus import event_bus


def parse_utc_timestamp(created_at: str) -> datetime:
    """Chuyển chuỗi ISO timestamp (ví dụ từ Adafruit IO created_at) về UTC datetime (độ phân giải ms)."""
    dt = datetime.fromisoformat(created_at)
    if dt.tzinfo is not None:
        dt = dt.astimezone(UTC).replace(tzinfo=None)
    return dt.replace(microsecond=0)


async def get_sensor_feeds(session: AsyncSession) -> list[dict[str, Any]]:
    """Lấy danh sách thiết bị cảm biến có feed_key từ bảng ThietBiIot."""
    result = await session.execute(
        text(
            """
            SELECT tb.ma_thiet_bi, tb.feed_key
            FROM ThietBiIot tb JOIN PhanLoaiThietBi pl on pl.ma_phan_loai_thiet_bi =tb.ma_phan_loai
            WHERE tb.feed_key IS NOT NULL AND tb.feed_key <> '' AND pl.don_vi_do is not NULL  AND tb.trang_thai_hoat_dong <> 'NGUNG_SU_DUNG'
            """
        )
    )
    return [{"ma_thiet_bi": row.ma_thiet_bi, "feed_key": row.feed_key} for row in result]


async def get_latest_recorded_at(session: AsyncSession, ma_thiet_bi: int) -> datetime | None:
    """Lấy thời điểm ghi mới nhất của thiết bị trong BangGhiDuLieu để phục vụ đọc bù REST."""
    result = await session.execute(
        text(
            """
            SELECT MAX(thoi_gian_ghi) AS latest_time
            FROM BangGhiDuLieu
            WHERE ma_thiet_bi = :ma_thiet_bi
            """
        ),
        {"ma_thiet_bi": ma_thiet_bi},
    )
    row = result.first()
    return row.latest_time if row else None


async def save_telemetry_point(
    ma_thiet_bi: int,
    feed_key: str,
    raw_value: Any,
    created_at_iso: str,
) -> bool:
    """Lưu 1 điểm dữ liệu bằng INSERT IGNORE; nếu được chèn mới thì phát sự kiện dữ liệu mới."""
    gia_tri_thong_so = float(raw_value)
    thoi_gian_ghi = parse_utc_timestamp(created_at_iso)

    async with SessionLocal() as session, session.begin():
        res = await session.execute(
            text(
                """
                    INSERT IGNORE INTO BangGhiDuLieu (ma_thiet_bi, thoi_gian_ghi, gia_tri_thong_so)
                    VALUES (:ma_thiet_bi, :thoi_gian_ghi, :gia_tri_thong_so);
                    """
            ),
            {
                "ma_thiet_bi": ma_thiet_bi,
                "thoi_gian_ghi": thoi_gian_ghi,
                "gia_tri_thong_so": gia_tri_thong_so,
            },
        )
        await session.execute(
            text("""
                    UPDATE ThietBiIot
                    SET thoi_gian_hoat_dong_lan_cuoi = GREATEST(COALESCE(thoi_gian_hoat_dong_lan_cuoi, :t), :t),
                        trang_thai_hoat_dong = 'HOAT_DONG'
                    WHERE ma_thiet_bi = :id AND trang_thai_hoat_dong <> 'NGUNG_SU_DUNG'
                """),
            {"t": thoi_gian_ghi, "id": ma_thiet_bi},
        )
        inserted = (res.rowcount or 0) > 0

    if inserted:
        await event_bus.publish(
            "telemetry.created",
            {
                "ma_thiet_bi": ma_thiet_bi,
                "feed_key": feed_key,
                "gia_tri_thong_so": gia_tri_thong_so,
                "thoi_gian_ghi": thoi_gian_ghi.replace(tzinfo=UTC).isoformat(),
            },
        )
    return inserted
