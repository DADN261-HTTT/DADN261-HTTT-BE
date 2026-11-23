# Backend – Hệ thống kho lạnh IoT (DADN261)

Backend viết bằng **FastAPI** (Python), đọc và ghi dữ liệu trên MySQL. Cấu trúc bảng do **Flyway** quản lý (thư mục `database/` ở gốc repo); backend không tạo hay sửa bảng.

## Cấu trúc

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py            # tạo ứng dụng, CORS, gắn router, endpoint sức khỏe
│   ├── configuration.py   # đọc cấu hình từ .env
│   ├── database.py        # kết nối MySQL, cấp phiên CSDL cho mỗi request
│   ├── auth.py            # người dùng hiện tại, phạm vi phòng kho theo vai trò
│   └── storage_rooms.py    # danh sách phòng kho, dashboard của một phòng
├── requirements.txt       # thư viện khi chạy
├── requirements-dev.txt   # thêm pytest, ruff
├── pyproject.toml         # cấu hình ruff
├── .env.example           # mẫu cấu hình (commit)
└── .env                   # cấu hình thật, có mật khẩu (KHÔNG commit)
```

Chiều phụ thuộc: `configuration.py` → `database.py` → `auth.py` → `storage_room.py` → `main.py`.

## Cài đặt và chạy

Yêu cầu: MySQL trong Docker đang chạy và đã migrate (`docker compose run --rm flyway migrate`). Chạy các lệnh dưới đây trong thư mục `backend/`:

```powershell
py -m venv venv
venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt
copy .env.example .env          # rồi điền DB_PASSWORD
uvicorn app.main:app --reload
```

- Tài liệu API tự sinh: http://127.0.0.1:8000/docs
- Kiểm tra code: `ruff check app --fix`

## Cấu hình (`.env`)

| Biến | Mặc định | Ý nghĩa |
|---|---|---|
| `DB_HOST` | `127.0.0.1` | Máy chạy MySQL |
| `DB_PORT` | `3307` | Cổng MySQL (theo `docker-compose.yml`) |
| `DB_NAME` | `DADN261` | Tên CSDL |
| `DB_USER` | `app` | Tài khoản chỉ có quyền đọc/ghi dữ liệu |
| `DB_PASSWORD` | – | Mật khẩu tài khoản `app` (`MYSQL_PASSWORD` ở `.env` gốc) |
| `CORS_ORIGINS` | `http://localhost:5173` | Địa chỉ frontend được gọi API; nhiều địa chỉ phân cách bằng dấu phẩy |

## Các file trong `app/`

- **`configuration.py`**: lớp `Configuration` (pydantic-settings) đọc `.env`. Biến `config` dùng chung cho các file khác.
- **`database.py`**:
  - `engine` giữ pool kết nối; `pool_pre_ping` giúp tự kết nối lại khi MySQL khởi động lại.
  - `SessionLocal` tạo phiên.
  - `get_session()` là dependency cấp một phiên cho mỗi request.
- **`auth.py`**:
  - `get_current_user()`: dependency xác định người gọi qua header `X-User-Id`. Trả 401 nếu người dùng không tồn tại, 403 nếu tài khoản bị khóa.
  - `get_room_ids()`: hàm tiện ích trả các phòng kho người dùng được truy cập. Chủ doanh nghiệp thấy mọi phòng trong kho mình sở hữu; quản lý kho thấy các phòng mình phụ trách; nhân viên thấy các phòng được phân công.
- **`storage_rooms.py`**:
  - Endpoint danh sách phòng kho và dashboard của một phòng.
  - `to_json_row()` chuyển dòng kết quả thành `dict` và gắn múi giờ UTC cho giá trị ngày giờ.
- **`main.py`**: tạo `app`, bật CORS, gắn router của `auth` và `storage_room`, khai báo `/api/health`.

## Endpoint

Mọi endpoint (trừ `/api/health`) cần header **`X-User-Id`**.

| Endpoint | Mô tả |
|---|---|
| `GET /api/health` | Backend còn chạy và kết nối được CSDL; lỗi thì trả 503 |
| `GET /api/users/me` | Người dùng hiện tại, vai trò, danh sách mã phòng trong phạm vi |
| `GET /api/storage-rooms` | Các phòng trong phạm vi, kèm `so_thiet_bi` và `so_mat_ket_noi` |
| `GET /api/storage-rooms/{room_id}` | Dashboard một phòng: thông tin phòng và các cảm biến kèm giá trị đo mới nhất. Phòng ngoài phạm vi trả 404 |

> **TẠM THỜI:** header `X-User-Id` chỉ dùng khi phát triển, vì ai cũng có thể khai mã bất kỳ. Nhiệm vụ 6 sẽ thay bằng đăng nhập JWT (`Authorization: Bearer <token>`); khi đó chỉ sửa hàm `get_current_user`.

## Quy ước

- **Tiếng Anh:** đường dẫn (chữ thường, nối bằng `-`), tên file, hàm, lớp, tag, thông báo lỗi.
- **Tiếng Việt:** trường JSON, trùng tên cột CSDL (`ma_phong_kho`, `gia_tri_thong_so`…). Trường tính toán đặt cùng kiểu (`so_thiet_bi`).
- **Mỗi file nghiệp vụ** có một router với `prefix="/api"` và một tag riêng.
- **Thời gian:** CSDL lưu UTC; JSON trả về có hậu tố `+00:00`, frontend tự đổi sang giờ Việt Nam.
- **SQL:** giá trị luôn truyền qua tham số `:ten`, không ghép chuỗi (chống SQL injection).
- **Phạm vi:** mọi endpoint lọc dữ liệu qua `get_room_ids()`. Ngoài phạm vi trả 404, không trả 403, để không lộ dữ liệu của tổ chức khác.

## Kiểm tra nhanh (dữ liệu mẫu)

| `X-User-Id` | Tài khoản | Vai trò | Phòng truy cập được |
|---|---|---|---|
| 1 | chu.an | Chủ doanh nghiệp | 1, 2, 3 |
| 2 | chu.binh | Chủ doanh nghiệp | 4 |
| 3 | ql.cuong | Quản lý kho | 1, 2 |
| 5 | nv.em | Nhân viên vận hành | 1, 2 |
| 10 | nv.khoa | Bị khóa | – (403) |

Ví dụ: `GET /api/storage-rooms/1` với `X-User-Id: 1` trả cảm biến 1, 2. Cùng endpoint với `X-User-Id: 2` trả 404.

## Việc tiếp theo

- `GET /api/storage-rooms/{room_id}/devices`: danh sách thiết bị của phòng để điều khiển.
- Endpoint điều khiển thiết bị, bản ghi và chuỗi thời gian cho biểu đồ.
- `tests/` (pytest) và đăng nhập JWT (nhiệm vụ 6).