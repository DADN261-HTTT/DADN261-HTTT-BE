"""Adapter kết nối Adafruit IO (MQTT tức thời + REST đọc bù theo header Link)."""
import asyncio
import json
import re
import ssl
from typing import Any

import httpx
import aiomqtt

from app.configuration import config
from app.database import SessionLocal
from app.telemetry import get_latest_recorded_at, get_sensor_feeds, save_telemetry_point

LINK_NEXT_RE = re.compile(r'<([^>]+)>;\s*rel="next"')


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

    async def _backfill_feed(self, client_http: httpx.AsyncClient, ma_thiet_bi: int, feed_key: str) -> None:
        """Đọc bù dữ liệu lịch sử qua REST API từ thời điểm ghi mới nhất trong MySQL."""
        async with SessionLocal() as session:
            latest_dt = await get_latest_recorded_at(session, ma_thiet_bi)

        url: str | None = (
            f"https://io.adafruit.com/api/v2/{config.aio_username}/feeds/{feed_key}/data"
        )
        params: dict[str, Any] | None = {"limit": 1000}
        if latest_dt is not None:
            params["start_time"] = latest_dt.strftime("%Y-%m-%dT%H:%M:%SZ")

        headers = {"X-AIO-Key": config.aio_key}
        while url:
            resp = await client_http.get(url, params=params, headers=headers)
            resp.raise_for_status()
            items = resp.json()
            for item in reversed(items):
                if "value" in item and "created_at" in item:
                    await save_telemetry_point(
                        ma_thiet_bi=ma_thiet_bi,
                        feed_key=feed_key,
                        raw_value=item["value"],
                        created_at_iso=item["created_at"],
                    )
            link_header = resp.headers.get("Link", "")
            match = LINK_NEXT_RE.search(link_header)
            url = match.group(1) if match else None
            params = None  # next URL trong Link header đã chứa query params

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
                    # 1. Subscribe trước để không lỡ tin nhắn tức thời
                    for feed_key in feed_map:
                        topic = f"{config.aio_username}/feeds/{feed_key}/json"
                        await mqtt_client.subscribe(topic)

                    # 2. Đọc bù qua REST sau khi đã subscribe
                    async with httpx.AsyncClient(timeout=20.0) as http_client:
                        for feed_key, ma_thiet_bi in feed_map.items():
                            await self._backfill_feed(http_client, ma_thiet_bi, feed_key)

                    # 3. Lắng nghe tin MQTT tức thời
                    async for message in mqtt_client.messages:
                        topic_str = str(message.topic)
                        parts = topic_str.split("/")
                        # Dạng topic: {username}/feeds/{feed_key}/json
                        if len(parts) >= 4 and parts[1] == "feeds":
                            feed_key = parts[2]
                            ma_thiet_bi = feed_map.get(feed_key)
                            if ma_thiet_bi is None:
                                continue
                            payload = json.loads(message.payload.decode("utf-8"))
                            if "value" in payload and "created_at" in payload:
                                await save_telemetry_point(
                                    ma_thiet_bi=ma_thiet_bi,
                                    feed_key=feed_key,
                                    raw_value=payload["value"],
                                    created_at_iso=payload["created_at"],
                                )
            except asyncio.CancelledError:
                break
            except Exception as exc:
                print(f"Lỗi kết nối Adafruit IO ({exc}), thử kết nối lại sau 5s...")
                await asyncio.sleep(5)


iot_gateway = AdafruitIoTGateway()