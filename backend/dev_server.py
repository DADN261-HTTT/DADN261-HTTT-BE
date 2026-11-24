"""Chạy backend trên máy phát triển (dùng được cho cả debug của VS Code).

aiomqtt cần SelectorEventLoop. Trên Windows, Python mặc định dùng ProactorEventLoop,
loại này không hỗ trợ add_reader/add_writer. File này tự tạo đúng loại vòng lặp,
nên chạy được trên mọi hệ điều hành.

Chạy ở thư mục backend/:  python dev_server.py
"""

import asyncio

import uvicorn


async def main() -> None:
    config = uvicorn.Config("app.main:app", host="127.0.0.1", port=8000)
    await uvicorn.Server(config).serve()


if __name__ == "__main__":
    asyncio.run(main(), loop_factory=asyncio.SelectorEventLoop)