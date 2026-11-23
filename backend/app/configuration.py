"""Đọc cấu hình từ file backend/.env."""
from pydantic_settings import BaseSettings


class Configuration(BaseSettings):
    db_host: str #= "127.0.0.1"
    db_port: int #= 3307
    db_name: str #= "DADN261"
    db_user: str #= "app"
    db_password: str #= ""
    cors_origins: str #= "http://localhost:5173"

    model_config = {"env_file": ".env", "extra": "ignore"}

config = Configuration()