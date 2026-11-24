# Backend – Hệ thống kho lạnh IoT (DADN261)

Backend viết bằng **FastAPI** (Python 3.12), đọc và ghi dữ liệu trên MySQL. Cấu trúc bảng do **Flyway** quản lý (thư mục `database/` ở gốc repo); backend không tạo hay sửa bảng.

## Cấu trúc

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py            # tạo ứng dụng, CORS, gắn router, khởi động/dừng iot_gateway, endpoint sức khỏe
│   ├── configuration.py   # đọc cấu hình từ .env
│   ├── database.py        # kết nối MySQL, cấp phiên CSDL cho mỗi request
│   ├── auth.py            # người dùng hiện tại, phạm vi phòng kho theo vai trò
│   ├── storage_rooms.py   # danh sách phòng kho, dashboard của một phòng
│   ├── event_bus.py       # EventBus nội bộ (mẫu Observer)
│   ├── telemetry.py       # lưu dữ liệu cảm biến, chống trùng, phát sự kiện "dữ liệu mới"
│   ├── iot_gateway.py     # kết nối Adafruit IO: MQTT tức thời + REST đọc bù
│   └── realtime.py        # WebSocket đẩy dữ liệu mới lên dashboard theo từng phòng
├── dev_server.py          # chạy backend trên Windows/khi debug (xem mục "Chạy trên Windows")
├── requirements.txt       # thư viện khi chạy
├── requirements-dev.txt   # thêm pytest, ruff
├── pyproject.toml         # cấu hình ruff
├── .env.example           # mẫu cấu hình (commit)
└── .env                   # cấu hình thật, có mật khẩu và khóa (KHÔNG commit)
```

Luồng dữ liệu cảm biến:

```
Bo ESP32 ─► Adafruit IO ─MQTT/REST─► iot_gateway ─► telemetry: lưu BangGhiDuLieu
                                                          │ có điểm mới
                                                          ▼
                                     event_bus ("telemetry.created") ─► realtime ─WebSocket─► dashboard
```

## Cài đặt và chạy

Yêu cầu: MySQL trong Docker đang chạy và đã migrate (`docker compose run --rm flyway migrate`). Chạy các lệnh dưới đây trong thư mục `backend/`:

```powershell
py -3.12 -m venv venv
venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt
copy .env.example .env          # rồi điền DB_PASSWORD, AIO_USERNAME, AIO_KEY
uvicorn app.main:app --reload
```

- Tài liệu API tự sinh: http://127.0.0.1:8000/docs (không hiển thị WebSocket).
- Kiểm tra code: `ruff check app --fix` và `ruff format app`.
- Chỉ chạy **một worker** (không dùng `--workers`); nhiều worker sẽ nhận trùng tin MQTT.
- Python **3.12 trở lên** (`dev_server.py` cần `asyncio.run(..., loop_factory=...)`).

### Chạy trên Windows

`aiomqtt` cần vòng lặp sự kiện loại **Selector**, trong khi Windows mặc định dùng loại **Proactor**. Nếu thiếu, phần Adafruit báo `NotImplementedError` (`add_reader`/`add_writer`).

- `uvicorn app.main:app --reload`: chạy được, vì uvicorn tự dùng Selector khi có `--reload`.
- `python dev_server.py`: chạy được, file này tự tạo vòng lặp Selector. Không tự tải lại khi sửa code.
- `uvicorn app.main:app` (không `--reload`): **lỗi** trên Windows.

### Debug bằng VS Code

File `.vscode/launch.json` ở gốc repo:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Backend: FastAPI (uvicorn)",
      "type": "debugpy",
      "request": "launch",
      "program": "${workspaceFolder}/backend/dev_server.py",
      "cwd": "${workspaceFolder}/backend",
      "justMyCode": true,
      "console": "integratedTerminal"
    }
  ]
}
```

Chọn Python của `backend\venv` (`Ctrl+Shift+P` → **Python: Select Interpreter**), đặt điểm dừng, nhấn **F5**. Sau khi sửa code, khởi động lại phiên debug bằng `Ctrl+Shift+F5`.

## Cấu hình (`.env`)

| Biến | Mặc định | Ý nghĩa |
|---|---|---|
| `DB_HOST` | `127.0.0.1` | Máy chạy MySQL |
| `DB_PORT` | `3307` | Cổng MySQL (theo `docker-compose.yml`) |
| `DB_NAME` | `DADN261` | Tên CSDL |
| `DB_USER` | `app` | Tài khoản chỉ có quyền đọc/ghi dữ liệu |
| `DB_PASSWORD` | – | Mật khẩu tài khoản `app` (`MYSQL_PASSWORD` ở `.env` gốc) |
| `CORS_ORIGINS` | `http://localhost:5173` | Địa chỉ frontend được gọi API; nhiều địa chỉ phân cách bằng dấu phẩy |
| `AIO_USERNAME` | – | Tên tài khoản Adafruit IO. Thiếu thì backend bỏ qua phần thu nhận dữ liệu |
| `AIO_KEY` | – | Khóa Adafruit IO (**bí mật**, chỉ backend và firmware giữ) |
| `AIO_MQTT_HOST` | `io.adafruit.com` | Máy chủ MQTT |
| `AIO_MQTT_PORT` | `8883` | Cổng MQTT có mã hóa TLS |
| `AIO_FEED_CANH_BAO` | `canh-bao` | Feed bật/tắt LED và còi tại chỗ |
| `AIO_FEED_PHAN_HOI` | `phan-hoi` | Feed bo mạch xác nhận lệnh (nhiệm vụ 10) |
| `AIO_FEED_TRANG_THAI` | `trang-thai` | Feed trạng thái bo mạch (nhiệm vụ 14.3) |

## Các file trong `app/`

- **`configuration.py`**: lớp `Configuration` (pydantic-settings) đọc `.env`. Biến `config` dùng chung cho các file khác.
- **`database.py`**:
  - `engine` giữ pool kết nối; `pool_pre_ping` giúp tự kết nối lại khi MySQL khởi động lại.
  - `SessionLocal` tạo phiên. Endpoint dùng `get_session()` qua `Depends`; tác vụ nền (không có request) tự mở phiên bằng `SessionLocal()`.
- **`auth.py`**:
  - `get_current_user()`: xác định người gọi qua header `X-User-Id`. Trả 401 nếu người dùng không tồn tại, 403 nếu tài khoản bị khóa.
  - `get_room_ids()`: các phòng kho người dùng được truy cập. Chủ doanh nghiệp thấy mọi phòng trong kho mình sở hữu; quản lý kho thấy các phòng mình phụ trách; nhân viên thấy các phòng được phân công.
- **`storage_rooms.py`**:
  - Endpoint danh sách phòng kho và dashboard của một phòng.
  - `to_json_row()` chuyển dòng kết quả thành `dict` và gắn múi giờ UTC cho giá trị ngày giờ.
- **`event_bus.py`**: `subscribe(ten_su_kien, ham)` và `publish(ten_su_kien, du_lieu)`. Lỗi của một bộ nhận không làm hỏng luồng thu nhận.
- **`telemetry.py`**:
  - `get_sensor_feeds()`: các **cảm biến** (loại có `don_vi_do`) chưa ngừng sử dụng và có `feed_key`.
  - `save_telemetry_point()`: `INSERT IGNORE` vào `BangGhiDuLieu`, cập nhật `thoi_gian_hoat_dong_lan_cuoi` và trạng thái `HOAT_DONG` của thiết bị, rồi phát sự kiện `telemetry.created` nếu là điểm mới.
- **`iot_gateway.py`**: tác vụ nền chạy suốt thời gian backend hoạt động (xem mục "Thu nhận dữ liệu").
- **`realtime.py`**: WebSocket theo từng phòng (xem mục "Dữ liệu thời gian thực").
- **`main.py`**: tạo `app`, bật CORS, gắn router của `auth`, `storage_rooms`, `realtime`; gọi `iot_gateway.start()`/`stop()` trong `lifespan`; khai báo `/api/health`.

## Endpoint

Mọi endpoint REST (trừ `/api/health`) cần header **`X-User-Id`**.

| Endpoint | Mô tả |
|---|---|
| `GET /api/health` | Backend còn chạy và kết nối được CSDL; lỗi thì trả 503 |
| `GET /api/users/me` | Người dùng hiện tại, vai trò, danh sách mã phòng trong phạm vi |
| `GET /api/storage-rooms` | Các phòng trong phạm vi, kèm `so_thiet_bi` và `so_mat_ket_noi` |
| `GET /api/storage-rooms/{room_id}` | Dashboard một phòng: thông tin phòng và các cảm biến kèm giá trị đo mới nhất. Phòng ngoài phạm vi trả 404 |
| `WS /api/ws/storage-rooms/{room_id}?user_id=` | Nhận dữ liệu mới của các thiết bị trong phòng (mục "Dữ liệu thời gian thực") |

> **TẠM THỜI:** header `X-User-Id` và tham số `?user_id=` chỉ dùng khi phát triển, vì ai cũng có thể khai mã bất kỳ. Nhiệm vụ 6 thay bằng đăng nhập JWT: REST dùng `Authorization: Bearer <token>`, WebSocket dùng `?token=<JWT>` (nhiệm vụ 6.1).

## Thu nhận dữ liệu từ Adafruit IO

`iot_gateway.py` chạy theo thứ tự sau mỗi lần kết nối (tự kết nối lại sau 5 giây nếu lỗi):

1. Đọc danh sách cảm biến từ CSDL, **đăng ký** topic MQTT `{AIO_USERNAME}/feeds/{feed_key}/json` cho từng feed.
2. **Đọc bù** qua REST từng feed, từ thời điểm mới nhất đã có trong CSDL. Đăng ký trước rồi mới đọc bù để không lỡ tin trong khoảng giữa.
3. **Nhận tức thời** qua MQTT.

Quy tắc dữ liệu:

- **Định dạng khác nhau giữa hai đường.** REST trả danh sách điểm dữ liệu (`value`, `created_at` ở cấp ngoài). Topic MQTT `/json` trả **thông tin cả feed**, điểm dữ liệu nằm trong trường `data`. `created_at` ở cấp ngoài của tin MQTT là **ngày tạo feed**, không dùng.
- **`thoi_gian_ghi` = `created_at` của Adafruit, giờ UTC, cắt về đơn vị giây.** MQTT gửi kèm phần nghìn giây còn REST thì không; cắt về giây để cùng một điểm đo nhận qua hai đường có cùng thời điểm.
- **Chống trùng:** `UNIQUE(ma_thiet_bi, thoi_gian_ghi)` (migration V4) kết hợp `INSERT IGNORE`.
- **Giao dịch:** ghi trong `async with SessionLocal() as session, session.begin():`. Thiếu `session.begin()` thì dữ liệu bị hủy khi đóng phiên dù `rowcount = 1`.
- Tin hoặc điểm dữ liệu không hợp lệ (không phải số, thiếu trường) chỉ bị bỏ qua và ghi log, không làm ngắt kết nối.

Log khi chạy bình thường:

| Log | Ý nghĩa |
|---|---|
| `Đã kết nối Adafruit IO, đang nghe N feed: ...` | Kết nối MQTT thành công |
| `Đọc bù a1-nhiet-do: lưu N điểm mới.` | Kết quả đọc bù của một feed |
| `Không đọc bù được feed a2-nhiet-do: ... 404 ...` | Feed có trong CSDL nhưng chưa tạo trên Adafruit IO (bình thường với dữ liệu mẫu) |
| `Đọc bù xong, bắt đầu nhận dữ liệu tức thời.` | Bắt đầu nhận tin MQTT |
| `Nhận a1-nhiet-do = -19.6 (...)` | Một điểm mới nhận qua MQTT đã được lưu |
| `Bỏ qua dữ liệu không hợp lệ từ ...` | Điểm dữ liệu lỗi bị bỏ qua |
| `Lỗi kết nối Adafruit IO (...), thử kết nối lại sau 5s...` | Lỗi bất kỳ trong vòng lặp; xem tên loại lỗi trong ngoặc |

Gửi dữ liệu thử: file `firmware/adafruit.http` (extension **REST Client**, đọc `AIO_USERNAME`/`AIO_KEY` từ `firmware/.env`) hoặc nút **Add Data** trên trang feed của io.adafruit.com.

## Dữ liệu thời gian thực (WebSocket)

```
ws://<host>/api/ws/storage-rooms/{room_id}?user_id=<ma_nguoi_dung>
```

- Bị từ chối khi người dùng không tồn tại, bị khóa, thiếu `user_id`, hoặc phòng ngoài phạm vi. Backend từ chối trước khi bắt tay xong, nên trình duyệt báo mã đóng **1006** và log uvicorn ghi `403 [rejected]`.
- Chỉ nhận dữ liệu của các thiết bị **thuộc phòng đó tại lúc kết nối**. Thiết bị mới thêm vào phòng cần kết nối lại (sẽ cải thiện ở nhiệm vụ 14.2).
- Mỗi tin có dạng (thời gian cùng định dạng với REST):

  ```json
  {"event": "telemetry.created",
   "data": {"ma_thiet_bi": 1, "feed_key": "a1-nhiet-do",
            "gia_tri_thong_so": -19.6, "thoi_gian_ghi": "2026-11-24T19:07:11+00:00"}}
  ```

Cách dùng ở dashboard phòng ("ảnh chụp + dòng cập nhật"):

1. Gọi `GET /api/storage-rooms/{room_id}` để lấy ảnh chụp ban đầu.
2. Mở WebSocket; mỗi tin `telemetry.created` cập nhật giá trị của `ma_thiet_bi` tương ứng.
3. Khi mất kết nối: kết nối lại, rồi gọi lại bước 1 để lấp khoảng dữ liệu bị lỡ.

### Kịch bản kiểm thử (đã chạy tay, đều đạt)

Mở `http://127.0.0.1:8000/docs`, F12 → Console, dán hàm trợ giúp:

```js
function ketNoi(roomId, userId, ten) {
  const url = `ws://127.0.0.1:8000/api/ws/storage-rooms/${roomId}` + (userId ? `?user_id=${userId}` : "");
  const ws = new WebSocket(url);
  ws.onopen = () => console.log(`[${ten}] ĐÃ KẾT NỐI`);
  ws.onmessage = (e) => console.log(`[${ten}] NHẬN:`, JSON.parse(e.data));
  ws.onclose = (e) => console.log(`[${ten}] ĐÓNG, code = ${e.code}`);
  return ws;
}
```

| Ca | Lệnh | Gửi lên | Mong đợi |
|---|---|---|---|
| T1 | `t1 = ketNoi(1, 1, "T1")` | `a1-nhiet-do` | Kết nối được; nhận sự kiện của thiết bị 1 |
| T2 | `t2 = ketNoi(2, 1, "T2")` | `a1-nhiet-do` | Kết nối được; **không** nhận (thiết bị 1 thuộc phòng 1) |
| T3 | `ketNoi(1, 2, "T3")` | – | Bị từ chối (phòng của chủ doanh nghiệp khác) |
| T4 | `ketNoi(3, 3, "T4")` | – | Bị từ chối (quản lý không phụ trách phòng 3) |
| T5 | `t5 = ketNoi(1, 5, "T5")` | `a1-ap-suat` | Nhân viên được phân công: nhận sự kiện của thiết bị 11 |
| T6 | `ketNoi(1, 10, ...)`, `ketNoi(1, 999, ...)`, `ketNoi(1, null, ...)` | – | Cả ba bị từ chối (bị khóa, không tồn tại, thiếu `user_id`) |
| T7 | `t7a = ketNoi(1, 1, "T7a")`, `t7b = ketNoi(1, 1, "T7b")` | `a1-do-am` | Cả hai cùng nhận |
| T8 | `t7a.close()` | `a1-do-am` | T7a đóng (mã 1005); T7b vẫn nhận; log uvicorn không lỗi |

## Quy ước

- **Tiếng Anh:** đường dẫn (chữ thường, nối bằng `-`), tên file, hàm, lớp, tag, thông báo lỗi.
- **Tiếng Việt:** trường JSON, trùng tên cột CSDL (`ma_phong_kho`, `gia_tri_thong_so`…). Trường tính toán đặt cùng kiểu (`so_thiet_bi`).
- **Mỗi file nghiệp vụ** có một router với `prefix="/api"` và một tag riêng.
- **Thời gian:** CSDL lưu UTC; REST và WebSocket đều trả dạng `...+00:00`, frontend tự đổi sang giờ Việt Nam. Xem giờ Việt Nam trong Workbench: `CONVERT_TZ(thoi_gian_ghi, '+00:00', '+07:00')`.
- **SQL:** giá trị luôn truyền qua tham số `:ten`, không ghép chuỗi (chống SQL injection). Kiểm tra rỗng bằng `IS NULL`/`IS NOT NULL`, so sánh giá trị bằng `=`/`<>`.
- **Phạm vi:** mọi endpoint lọc dữ liệu qua `get_room_ids()`. Ngoài phạm vi trả 404, không trả 403, để không lộ dữ liệu của tổ chức khác.
- **Bắt lỗi chung `Exception`** chỉ ở nơi cố ý (vòng kết nối lại, EventBus, gửi WebSocket), kèm `# noqa: BLE001` và lý do.

## Kiểm tra nhanh (dữ liệu mẫu)

| `X-User-Id` | Tài khoản | Vai trò | Phòng truy cập được |
|---|---|---|---|
| 1 | chu.an | Chủ doanh nghiệp | 1, 2, 3 |
| 2 | chu.binh | Chủ doanh nghiệp | 4 |
| 3 | ql.cuong | Quản lý kho | 1, 2 |
| 5 | nv.em | Nhân viên vận hành | 1, 2 |
| 10 | nv.khoa | Bị khóa | – (403) |

Ví dụ: `GET /api/storage-rooms/1` với `X-User-Id: 1` trả các cảm biến của phòng 1. Cùng endpoint với `X-User-Id: 2` trả 404.

Thiết bị thật đang dùng feed `a1-nhiet-do` (thiết bị 1), `a1-do-am` (2), `a1-ap-suat` (11). Các feed `a2-*`, `a3-*`, `b1-*` chỉ có trong dữ liệu mẫu.

## Việc tiếp theo

- Nhiệm vụ 19: `GET /api/storage-rooms/{room_id}/devices` (danh sách thiết bị để điều khiển), bản ghi và chuỗi thời gian cho biểu đồ.
- Nhiệm vụ 7.1: tái cấu trúc `iot_gateway.py` thành `app/iot/` theo mẫu Adapter (`IoTAdapter`, `AdafruitAdapter`, `FakeAdapter`, chọn qua `IOT_PROVIDER`).
- Nhiệm vụ 14.1–14.3: nghe feed thiết bị mới không cần khởi động lại, cập nhật danh sách thiết bị cho WebSocket, đọc feed `trang-thai`.
- Nhiệm vụ 6 và 6.1: đăng nhập JWT cho REST và WebSocket.
- Nhiệm vụ 27.1: kiểm thử tự động phần thu nhận và thời gian thực.