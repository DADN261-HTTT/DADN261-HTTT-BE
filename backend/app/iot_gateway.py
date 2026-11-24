"""Adapter kết nối Adafruit IO (MQTT tức thời + REST đọc bù theo header Link)."""

import asyncio
import json
import re
import ssl
from typing import Any

import aiomqtt
import httpx

from app.configuration import config
from app.database import SessionLocal
from app.telemetry import get_latest_recorded_at, get_sensor_feeds, save_telemetry_point

LINK_NEXT_RE = re.compile(r'<([^>]+)>;\s*rel="next"')
PAGE_LIMIT = 1000


class AdafruitIoTGateway:
    def __init__(self) -> None:
        self._task: asyncio.Task[None] | None = None
        self._stop_event = asyncio.Event()

    async def start(self) -> None:
        if not config.aio_username or not config.aio_key:
            print("Cảnh báo: Chưa cấu hình AIO_USERNAME hoặc AIO_KEY trong .env; bỏ qua khởi động MQTT.")
            return
        self._stop_event.clear()
        self._task = asyncio.create_task(self._run_loop())

    async def stop(self) -> None:
        self._stop_event.set()
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass

    async def _save_point(self, ma_thiet_bi: int, feed_key: str, data: Any) -> bool:
        """Lưu một điểm dữ liệu; trả True nếu là điểm mới. Dữ liệu không hợp lệ chỉ bị bỏ qua."""
        try:
            return await save_telemetry_point(
                ma_thiet_bi=ma_thiet_bi,
                feed_key=feed_key,
                raw_value=data["value"],
                created_at_iso=data["created_at"],
            )
        except (ValueError, KeyError, TypeError) as exc:
            # ValueError: giá trị không phải số, created_at sai định dạng
            # KeyError: thiếu trường value hoặc created_at
            # TypeError: dữ liệu không phải object JSON, hoặc value rỗng
            print(f"Bỏ qua dữ liệu không hợp lệ từ {feed_key}: {exc!r}")
            return False

    async def _backfill_feed(self, client_http: httpx.AsyncClient, ma_thiet_bi: int, feed_key: str) -> None:
        """Đọc bù dữ liệu lịch sử qua REST API từ thời điểm ghi mới nhất trong MySQL."""
        async with SessionLocal() as session:
            latest_dt = await get_latest_recorded_at(session, ma_thiet_bi)

        url: str | None = f"https://io.adafruit.com/api/v2/{config.aio_username}/feeds/{feed_key}/data"
        params: dict[str, Any] | None = {"limit": PAGE_LIMIT}
        if latest_dt is not None:
            params["start_time"] = latest_dt.strftime("%Y-%m-%dT%H:%M:%SZ")

        headers = {"X-AIO-Key": config.aio_key}
        saved = 0
        while url:
            resp = await client_http.get(url, params=params, headers=headers)
            resp.raise_for_status()
            # REST trả sẵn danh sách điểm dữ liệu (không lồng trong "data" như MQTT /json).
            items = resp.json()
            for item in reversed(items):
                if await self._save_point(ma_thiet_bi, feed_key, item):
                    saved += 1

            if len(items) < PAGE_LIMIT:
                break  # trang chưa đầy là trang cuối: dừng, tránh lặp vô hạn
            match = LINK_NEXT_RE.search(resp.headers.get("Link", ""))
            url = match.group(1) if match else None
            params = None  # URL trang kế trong header Link đã chứa sẵn tham số

        print(f"Đọc bù {feed_key}: lưu {saved} điểm mới.")

    async def _run_loop(self) -> None:
        """Vòng lặp MQTT tự kết nối lại, subscribe trước rồi mới đọc bù qua REST."""
        tls_context = ssl.create_default_context()
        while not self._stop_event.is_set():
            try:
                async with SessionLocal() as session:
                    feeds = await get_sensor_feeds(session)

                feed_map = {item["feed_key"]: item["ma_thiet_bi"] for item in feeds}
                if not feed_map:
                    await asyncio.sleep(10)
                    continue

                async with aiomqtt.Client(
                    hostname=config.aio_mqtt_host,
                    port=config.aio_mqtt_port,
                    username=config.aio_username,
                    password=config.aio_key,
                    tls_context=tls_context,
                ) as mqtt_client:
                    for feed_key in feed_map:
                        await mqtt_client.subscribe(f"{config.aio_username}/feeds/{feed_key}/json")
                    print(f"Đã kết nối Adafruit IO, đang nghe {len(feed_map)} feed: {', '.join(feed_map)}")

                    # 1. Đọc bù qua REST sau khi đã subscribe; feed lỗi không ảnh hưởng feed khác
                    async with httpx.AsyncClient(timeout=20.0) as http_client:
                        for feed_key, ma_thiet_bi in feed_map.items():
                            try:
                                await self._backfill_feed(http_client, ma_thiet_bi, feed_key)
                            except httpx.HTTPError as exc:
                                # Ví dụ 404: feed có trong CSDL nhưng chưa tạo trên Adafruit IO; 429: vượt hạn mức
                                print(f"Không đọc bù được feed {feed_key}: {exc}")
                    print("Đọc bù xong, bắt đầu nhận dữ liệu tức thời.")

                    # 2. Lắng nghe tin MQTT tức thời
                    async for message in mqtt_client.messages:
                        # Dạng topic: {username}/feeds/{feed_key}/json
                        parts = str(message.topic).split("/")
                        if len(parts) < 4 or parts[1] != "feeds":
                            continue
                        feed_key = parts[2]
                        ma_thiet_bi = feed_map.get(feed_key)
                        if ma_thiet_bi is None:
                            continue
                        try:
                            message_json = json.loads(message.payload.decode("utf-8"))
                        except ValueError as exc:  # gồm cả lỗi giải mã UTF-8 và JSON hỏng
                            print(f"Bỏ qua tin MQTT không đọc được từ {feed_key}: {exc!r}")
                            continue
                        # Topic /json gửi thông tin cả feed; điểm dữ liệu (value, created_at) nằm trong "data".
                        point = message_json.get("data") if isinstance(message_json, dict) else None
                        if await self._save_point(ma_thiet_bi, feed_key, point):
                            print(f"Nhận {feed_key} = {point['value']} ({point['created_at']})")

            except asyncio.CancelledError:
                break
            except Exception as exc:  # noqa: BLE001 - mọi lỗi kết nối đều phải thử lại, không dừng vòng lặp
                print(f"Lỗi kết nối Adafruit IO ({exc!r}), thử kết nối lại sau 5s...")
                await asyncio.sleep(5)


iot_gateway = AdafruitIoTGateway()
