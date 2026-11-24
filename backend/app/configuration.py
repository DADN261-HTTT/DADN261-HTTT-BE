"""Đọc cấu hình từ file backend/.env."""
from pydantic_settings import BaseSettings


class Configuration(BaseSettings):
    db_host: str #= "127.0.0.1"
    db_port: int #= 3307
    db_name: str #= "DADN261"
    db_user: str #= "app"
    db_password: str #= ""
    cors_origins: str #= "http://localhost:5173"
    
    # Cấu hình Adafruit IO
    aio_username: str = ""
    aio_key: str = ""
    aio_mqtt_host: str = "io.adafruit.com"
    aio_mqtt_port: int = 8883
    aio_feed_phan_hoi: str = "phan-hoi"
    aio_feed_trang_thai: str = "trang-thai"
    aio_feed_canh_bao: str = "canh-bao"

    model_config = {"env_file": ".env", "extra": "ignore"}

config = Configuration()