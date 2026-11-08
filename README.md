# Hệ thống quản lý thiết bị IoT cho kho bảo quản thực phẩm tươi sống

Đồ án đa ngành – HK261.

## Cấu trúc thư mục
- `backend/` – mã nguồn backend
- `frontend/` – mã nguồn frontend
- `database/` – migration, dữ liệu mẫu, kiểm tra ràng buộc
- `docs/` – tài liệu thiết kế

## Yêu cầu cài đặt
- Docker Desktop
- Git

## Hướng dẫn chạy
1. Cài Docker Desktop, mở và chờ trạng thái Engine running.
2. Tạo file cấu hình: `Copy-Item .env.example .env`, rồi đổi mật khẩu trong `.env`.
3. Khởi động database: `docker compose up -d`
4. Kiểm tra: `docker compose ps` (cột STATUS báo `healthy`).
5. Kết nối DBeaver: localhost, cổng `MYSQL_PORT`, database `coldstore`, user `app`;
   Driver properties: `allowPublicKeyRetrieval=true`, `useSSL=false`.

Làm sạch database: `docker compose down -v` rồi `docker compose up -d`.