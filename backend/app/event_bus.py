"""EventBus nội bộ giúp các module giao tiếp qua sự kiện."""

from collections import defaultdict
from collections.abc import Awaitable, Callable
from typing import Any

EventHandler = Callable[[dict[str, Any]], Awaitable[None]]


class EventBus:
    def __init__(self) -> None:
        self._subscribers: dict[str, list[EventHandler]] = defaultdict(list)

    def subscribe(self, event_name: str, handler: EventHandler) -> None:
        self._subscribers[event_name].append(handler)

    async def publish(self, event_name: str, payload: dict[str, Any]) -> None:
        for handler in list(self._subscribers.get(event_name, [])):
            try:
                await handler(payload)
            except Exception as exc:  # noqa: BLE001 - một bộ nhận lỗi không được làm hỏng luồng thu nhận
                print(f"Lỗi khi xử lý sự kiện {event_name}: {exc}")


event_bus = EventBus()
