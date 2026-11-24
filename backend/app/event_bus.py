"""EventBus nội bộ giúp các module giao tiếp qua sự kiện."""
from collections import defaultdict
from typing import Any, Awaitable, Callable

EventHandler = Callable[[dict[str, Any]], Awaitable[None]]


class EventBus:
    def __init__(self) -> None:
        self._subscribers: dict[str, list[EventHandler]] = defaultdict(list)

    def subscribe(self, event_name: str, handler: EventHandler) -> None:
        self._subscribers[event_name].append(handler)

    async def publish(self, event_name: str, payload: dict[str, Any]) -> None:
        for handler in list(self._subscribers.get(event_name, [])):
            await handler(payload)


event_bus = EventBus()