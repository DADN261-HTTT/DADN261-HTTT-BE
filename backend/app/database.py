"""Kết nối MySQL. Cấu trúc bảng do Flyway quản lý; backend chỉ đọc và ghi dữ liệu."""

from sqlalchemy.engine import URL
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.configuration import config

url = URL.create(
    "mysql+aiomysql",
    username=config.db_user,
    password=config.db_password,
    host=config.db_host,
    port=config.db_port,
    database=config.db_name,
    query={"charset": "utf8mb4"},
)

engine = create_async_engine(url, pool_pre_ping=True)
SessionLocal = async_sessionmaker(engine, expire_on_commit=False)


async def get_session():
    """Mỗi request được một phiên làm việc với CSDL; xong request thì tự đóng."""
    async with SessionLocal() as session:
        yield session
