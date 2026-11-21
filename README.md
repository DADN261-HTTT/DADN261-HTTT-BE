# DADN-HTTT-HK261 – Backend hệ thống quản lý thiết bị IoT kho lạnh

Kho mã nguồn backend và cơ sở dữ liệu của đồ án đa ngành: quản lý nhà kho, phòng kho, thiết bị IoT (qua Adafruit IO), dữ liệu cảm biến, lịch trình, rule, cảnh báo, nhật kí và tin nhắn nội bộ. Frontend nằm ở kho mã nguồn riêng.

Trạng thái hiện tại: hạ tầng CSDL đã xong (MySQL 8.4 trong Docker, migration bằng Flyway, dữ liệu danh mục, dữ liệu mẫu, kiểm thử ràng buộc); Adafruit IO đã có đủ 7 feed và bộ lệnh REST mẫu cho firmware. Ngôn ngữ backend chưa chốt.

---

## 1. Cấu trúc thư mục

```
DADN-HTTT-HK261/
├── .github/                    # cấu hình GitHub
├── backend/                    # mã nguồn backend (chưa chọn ngôn ngữ)
├── database/
│   ├── init/                   # chạy MỘT lần khi volume MySQL còn trống
│   │   ├── 01-tao-db-test.sh   #   tạo CSDL <MYSQL_DATABASE>_test
│   │   └── 02-tao-tai-khoan.sh #   tạo tài khoản migration, hạ quyền tài khoản app
│   ├── migration/              # Flyway đọc thư mục này (nguồn chuẩn duy nhất của cấu trúc CSDL)
│   │   ├── V1__khoi_tao_bang.sql
│   │   ├── V2__rang_buoc_ngu_nghia.sql
│   │   ├── V3__du_lieu_danh_muc.sql
│   │   └── V4__ap_suat_va_chong_trung_ban_ghi.sql
│   ├── dev-data/
│   │   ├── du_lieu_mau.sql             # dữ liệu mẫu cho môi trường phát triển
│   │   └── thiet_bi_that_phong_a1.sql  # thiết bị thật của bộ demo (gắn với feed Adafruit IO)
│   └── tests/
│       └── kiem_thu_rang_buoc.sql  # 67 ca kiểm thử CHECK, UNIQUE, khóa ngoại, trigger
├── firmware/                   # mã firmware ESP32 / Yolo UNO (xem firmware/README.md)
│   ├── README.md               #   cài REST Client, dùng adafruit.http, yêu cầu kết nối
│   ├── adafruit.http           #   bộ lệnh REST API Adafruit IO đã lưu
│   ├── .env.example            #   mẫu AIO_USERNAME, AIO_KEY cho adafruit.http
│   └── secrets.example.h       #   mẫu WiFi + Adafruit cho mã firmware
├── docs/                       # tài liệu đặc tả (ERD, RD, cấu hình thiết bị, quy trình)
├── .env.example                # mẫu biến môi trường (KHÔNG chứa mật khẩu thật)
├── .gitattributes              # quy định kiểu xuống dòng (file .sh phải là LF)
├── .gitignore                  # bỏ qua .env và secrets.h
├── docker-compose.yml
└── README.md
```

---

## 2. Yêu cầu

| Công cụ | Ghi chú |
| --- | --- |
| Docker Desktop | Bật sẵn trước khi chạy mọi lệnh `docker compose` |
| Git | Làm việc theo nhánh, không đẩy thẳng lên `main` |
| VS Code | Khuyến nghị; kiểm tra file `.sh` đang dùng **LF** (góc dưới phải) |
| MySQL Workbench 8.x | Tùy chọn, để xem dữ liệu. Cảnh báo "not supported" với MySQL 8.4 bỏ qua được |
| Tài khoản Adafruit IO | Một tài khoản chung cho cả nhóm (mục 6) |
| REST Client (extension VS Code) | Gửi thử các lệnh trong `firmware/adafruit.http` |
| MQTT Explorer | Tùy chọn, để xem tin MQTT như backend sẽ nhận |

Không cần cài MySQL Server lên máy: MySQL chạy trong container.

---

## 3. Cài đặt lần đầu

Mọi lệnh chạy ở **thư mục gốc dự án** (nơi có `docker-compose.yml` và `.env`).

### 3.1. Tạo file `.env`

```powershell
copy .env.example .env      # Windows PowerShell
# cp .env.example .env      # macOS / Linux
```

Điền mật khẩu vào `.env`. File này đã được `.gitignore` bỏ qua: không commit, không chụp màn hình gửi lên nhóm.

| Biến | Ý nghĩa | Ví dụ |
| --- | --- | --- |
| `MYSQL_ROOT_PASSWORD` | Mật khẩu root, chỉ dùng để quản trị | (mật khẩu mạnh) |
| `MYSQL_DATABASE` | Tên CSDL chính; CSDL test là `<tên>_test` | `DADN261` |
| `MYSQL_USER` / `MYSQL_PASSWORD` | Tài khoản backend dùng khi chạy | `app` / (mật khẩu) |
| `MYSQL_MIGRATION_USER` / `MYSQL_MIGRATION_PASSWORD` | Tài khoản Flyway dùng để đổi cấu trúc | `dadn_migration` / (mật khẩu) |
| `MYSQL_PORT` | Cổng trên máy của bạn trỏ vào MySQL trong container | `3307` |
| `AIO_USERNAME` / `AIO_KEY` | Tài khoản và khóa Adafruit IO (mục 6.1) | (tên tài khoản) / (khóa) |
| `AIO_MQTT_HOST` / `AIO_MQTT_PORT` | Máy chủ MQTT của Adafruit IO | `io.adafruit.com` / `8883` |
| `AIO_FEED_PHAN_HOI` / `AIO_FEED_TRANG_THAI` / `AIO_FEED_CANH_BAO` | Tên 3 feed dùng chung | `phan-hoi` / `trang-thai` / `canh-bao` |

Ba mật khẩu nên khác nhau. Đổi mật khẩu hoặc tên CSDL sau khi đã khởi tạo thì phải dựng lại từ đầu (`docker compose down -v`, mục 11).

### 3.2. Khởi động MySQL và chạy migration

```powershell
docker compose up -d mysql
docker compose ps                                   # chờ dadn-mysql ở trạng thái (healthy)

docker compose run --rm flyway migrate              # CSDL chính: V1 → V4
docker compose run --rm flyway "-url=jdbc:mysql://mysql:3306/DADN261_test?allowPublicKeyRetrieval=true" migrate
docker compose run --rm flyway info                 # mọi phiên bản phải ở trạng thái Success
```

Khi migrate lần đầu sẽ có 14 dòng `WARNING: DB: Trigger does not exist (1360)`: đó là ghi chú của các câu `DROP TRIGGER IF EXISTS` trong V2 trên CSDL trống, **không phải lỗi**.

### 3.3. Nạp dữ liệu mẫu (CSDL chính, tài khoản `app`)

```powershell
docker compose cp database/dev-data/du_lieu_mau.sql mysql:/tmp/du_lieu_mau.sql
docker compose exec mysql sh -c 'mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --default-character-set=utf8mb4 "$MYSQL_DATABASE" < /tmp/du_lieu_mau.sql'
```

Hoặc mở file trong Workbench bằng connection **app**, chọn CSDL `DADN261` rồi chạy cả file. Cuối file có bảng đếm số dòng của từng bảng. File chỉ chạy **một lần** trên CSDL vừa migrate; chạy lần hai sẽ báo trùng khóa.

Sau đó nạp thiết bị thật của bộ demo. **Trước khi chạy**, mở file và thay `@mac_bo_a1` bằng địa chỉ MAC thật của bo mạch (firmware in ra khi khởi động):

```powershell
docker compose cp database/dev-data/thiet_bi_that_phong_a1.sql mysql:/tmp/thiet_bi_that.sql
docker compose exec mysql sh -c 'mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --default-character-set=utf8mb4 "$MYSQL_DATABASE" < /tmp/thiet_bi_that.sql'
```

### 3.4. Chạy kiểm thử ràng buộc (CSDL test, tài khoản migration)

```powershell
docker compose cp database/tests/kiem_thu_rang_buoc.sql mysql:/tmp/kiem_thu.sql
docker compose exec mysql sh -c 'mysql -u"$MYSQL_MIGRATION_USER" -p"$MYSQL_MIGRATION_PASSWORD" --default-character-set=utf8mb4 -t "${MYSQL_DATABASE}_test" < /tmp/kiem_thu.sql'
```

Hoặc chạy cả file trong Workbench bằng connection **migration**. Xem mục 8 để đọc kết quả.

---

## 4. Tài khoản CSDL và connection Workbench

Tất cả kết nối tới `127.0.0.1`, cổng `MYSQL_PORT` (`3307`). Mỗi tài khoản có một vai trò riêng:

| Connection | Tài khoản | Quyền | Dùng để | Không dùng để |
| --- | --- | --- | --- | --- |
| **root** | `root` | Toàn quyền server | Quản trị tài khoản, quyền, trạng thái server | Chạy backend, chạy migration, làm việc hằng ngày |
| **migration** | `dadn_migration` | Toàn quyền trên `DADN261` và `DADN261_test` | Flyway đổi cấu trúc; chạy script kiểm thử; xem cấu trúc | Chạy tay file migration hay câu DDL |
| **app** | `app` | `SELECT, INSERT, UPDATE, DELETE, EXECUTE` trên hai CSDL | Backend kết nối; nạp dữ liệu mẫu; thử dữ liệu như backend | Thay đổi cấu trúc (bị lỗi 1142) |

Quyền được cấp **tự động** khi container khởi động với volume trống: image MySQL tạo CSDL và tài khoản `app`, sau đó lần lượt chạy `database/init/01-tao-db-test.sh` và `02-tao-tai-khoan.sh`. Thư mục `init/` không chạy lại khi volume đã có dữ liệu.

Chuỗi kết nối cho backend:

| Backend chạy ở | Host:port | Ví dụ JDBC |
| --- | --- | --- |
| Trong `docker compose` | `mysql:3306` | `jdbc:mysql://mysql:3306/DADN261` |
| Trực tiếp trên máy | `127.0.0.1:3307` | `jdbc:mysql://127.0.0.1:3307/DADN261` |

---

## 5. Migration với Flyway

**Cách hoạt động:** service `flyway` (image `flyway/flyway:11.13.3`, bản đầu tiên hỗ trợ MySQL 8.4) là công cụ chạy rồi tắt, không tự khởi động cùng `docker compose up` (`profiles: ["tools"]`). Flyway chạy các file `database/migration/V<n>__<mo_ta>.sql` theo thứ tự số phiên bản và ghi lại từng file đã chạy (kèm checksum) trong bảng `flyway_schema_history` của mỗi CSDL. `migrate` chỉ chạy những phiên bản chưa có, nên chạy lại nhiều lần vẫn an toàn.

**Quy tắc:**

1. Mọi thay đổi cấu trúc hoặc danh mục là **một file mới** `V<n+1>__mo_ta.sql`. Tên phải có hai dấu gạch dưới sau số phiên bản.
2. **Không sửa file đã được migrate** ở bất kỳ máy nào trong nhóm. Flyway sẽ báo `validate` lỗi vì checksum thay đổi.
3. **Không chạy tay file migration hay câu DDL** trong Workbench. CSDL có bảng mà không có lịch sử Flyway sẽ báo lỗi "non-empty schema".
4. File migration và mã backend dùng thay đổi đó nằm **trong cùng một PR**.
5. Không bật `flyway clean`.

**Thêm một thay đổi:**

```powershell
# 1. Tạo database/migration/V5__them_cot_x.sql
docker compose run --rm flyway migrate
docker compose run --rm flyway "-url=jdbc:mysql://mysql:3306/DADN261_test?allowPublicKeyRetrieval=true" migrate
# 2. Chạy lại kiểm thử ràng buộc (mục 3.4)
```

**Thành viên khác cập nhật:**

```powershell
git pull
docker compose up -d mysql
docker compose run --rm flyway migrate
docker compose run --rm flyway "-url=jdbc:mysql://mysql:3306/DADN261_test?allowPublicKeyRetrieval=true" migrate
```

| File | Nội dung |
| --- | --- |
| `V1__khoi_tao_bang.sql` | 18 bảng, kiểu dữ liệu, NOT NULL, DEFAULT, khóa chính, 2 UNIQUE, 26 khóa ngoại (RESTRICT) |
| `V2__rang_buoc_ngu_nghia.sql` | 11 CHECK, 2 cột sinh + UNIQUE, 2 chỉ mục, 14 trigger |
| `V3__du_lieu_danh_muc.sql` | Vai trò 1/2/3, phân loại thiết bị / thao tác / cảnh báo, 6 rule, 2 lịch trình |
| `V4__ap_suat_va_chong_trung_ban_ghi.sql` | Loại thiết bị 5 "Cảm biến áp suất" (hPa), rule 7 "Áp suất bất thường"; UNIQUE (ma_thiet_bi, thoi_gian_ghi) trên `BangGhiDuLieu` thay cho chỉ mục thường |

---

## 6. Adafruit IO

Adafruit IO là **MQTT broker trên đám mây kiêm nơi lưu trữ đầu tiên** của dữ liệu cảm biến (giữ 30 ngày). Firmware gửi dữ liệu lên feed; backend nhận ngay qua MQTT, đọc bù qua REST khi bị gián đoạn, rồi ghi vào MySQL để lưu lâu dài. Ứng dụng chỉ đọc từ backend, không gọi Adafruit IO.

### 6.1. Tài khoản và khóa

- Cả nhóm dùng **một tài khoản chung**, vì mọi giới hạn tính theo tài khoản.
- Lấy **Username** và **Active Key** ở biểu tượng chìa khóa (**My Key**) trên io.adafruit.com.

| Nơi dùng | Lưu ở đâu | Commit |
| --- | --- | --- |
| Backend | `.env` ở thư mục gốc (`AIO_USERNAME`, `AIO_KEY`, các biến `AIO_*` ở mục 3.1) | Không |
| Thử lệnh REST | `firmware/.env` (`AIO_USERNAME`, `AIO_KEY`), cùng thư mục với `adafruit.http` | Không |
| Mã firmware | `firmware/secrets.h` (WiFi, username, khóa) | Không |
| Mẫu cho nhóm | `.env.example`, `firmware/.env.example`, `firmware/secrets.example.h` (để trống giá trị) | Có |

Kiểm tra Git đã bỏ qua các file bí mật: `git check-ignore -v .env firmware/.env firmware/secrets.h` (phải in ra dòng tương ứng trong `.gitignore`). Gửi khóa cho thành viên bằng tin nhắn riêng. Khi khóa bị lộ hoặc có người rời nhóm: **Regenerate Key** trên Adafruit IO rồi cập nhật cả ba nơi.

### 6.2. Danh sách feed

Mỗi thiết bị logic dùng một feed; key trùng với `ThietBiIot.feed_key`. Ba feed cuối dùng chung, không có trong CSDL (tên đặt trong `.env`).

| Feed key | Nội dung | Chiều | Định dạng giá trị | Tần suất |
| --- | --- | --- | --- | --- |
| `a1-nhiet-do` | Nhiệt độ (°C) | Firmware → Backend | Số, dấu chấm thập phân, 1 chữ số lẻ, không kèm đơn vị. Ví dụ `-19.6` | 30 giây |
| `a1-do-am` | Độ ẩm (%) | Firmware → Backend | Ví dụ `91.2` | 30 giây |
| `a1-ap-suat` | Áp suất (hPa) | Firmware → Backend | Ví dụ `1008.3` | 30 giây |
| `a1-quat` | Lệnh quạt | Backend → Firmware | Relay: `1` bật, `0` tắt. MOSFET: `0`–`100` (% tốc độ) | Khi có lệnh |
| `canh-bao` | Lệnh LED và còi | Backend → Firmware | `1` bật, `0` tắt | Khi có / hết cảnh báo |
| `phan-hoi` | Kết quả lệnh | Firmware → Backend | `feed\|giá trị\|kết quả`. Ví dụ `a1-quat\|1\|THANH_CONG` | Sau mỗi lệnh |
| `trang-thai` | Trạng thái bo mạch | Firmware → Backend | `MAC\|pin %\|RSSI\|thời gian chạy (giây)`. Ví dụ `A4:CF:12:3B:5E:01\|78\|-61\|3600` | 60 giây |

Quy tắc khi tạo feed:

- **Tên feed đặt đúng bằng key** (Adafruit sinh key từ tên; tên có dấu sinh key khó đoán). Kiểm tra lại key ở **Feed Info**.
- **Để feed trong nhóm Default**: feed trong nhóm khác có key dạng `nhom.feed`, làm topic và `feed_key` phức tạp.
- **Giữ Feed History bật** (mặc định). Tắt thì Adafruit chỉ giữ giá trị cuối và backend không đọc bù được.
- Feed `phan-hoi`, `trang-thai` dùng chuỗi phân tách `|` thay cho JSON, vì Adafruit tự phân tích JSON gửi lên feed theo các trường riêng của nó.
- Không dùng **Actions/Triggers** của Adafruit: rule và cảnh báo đều nằm ở backend để có lưu vết trong CSDL.

### 6.3. Giới hạn gói Free

| Giới hạn | Ảnh hưởng |
| --- | --- |
| 10 feed | Bộ demo dùng 7 feed; bộ thứ hai chỉ nên có 1–2 cảm biến |
| 30 điểm dữ liệu/phút (mọi thao tác ghi, kể cả lệnh backend gửi và nút toggle trên dashboard) | Firmware gửi 30 giây/lần; một bộ thiết bị dùng khoảng 9 điểm/phút. Nhiều người cùng thử dễ chạm giới hạn |
| Lưu 30 ngày | MySQL là nơi lưu lâu dài |
| 300 yêu cầu HTTP/phút | Đọc bù chia trang, tối đa 1000 điểm/lần |
| Vượt giới hạn | REST trả `429`; vượt nhiều lần qua MQTT có thể bị chặn tạm thời; thông báo gửi tới topic `{username}/throttle` |

### 6.4. Kiểm tra hạ tầng Adafruit IO

1. **Giả lập firmware và backend gửi/đọc qua REST:** dùng `firmware/adafruit.http` với extension REST Client. Hướng dẫn chi tiết trong `firmware/README.md`.
2. **Giả lập backend nhận qua MQTT:** MQTT Explorer kết nối `io.adafruit.com:8883` (bật TLS), username Adafruit, mật khẩu là AIO Key. Xóa topic mặc định `#` và `$SYS/#`, thêm từng topic `{username}/feeds/<feed key>/json`, `{username}/throttle`, `{username}/errors`. Gửi một giá trị qua REST thì tin dạng JSON (có `id`, `value`, `created_at`) phải hiện ngay.
3. **Dashboard (tùy chọn):** toggle cho `a1-quat` và `canh-bao` phải đặt **On = `1`, Off = `0`** (mặc định là `ON`/`OFF`, sai định dạng).

### 6.5. Backend lấy dữ liệu về MySQL

- **MQTT (tức thời):** một tiến trình duy nhất subscribe `{username}/feeds/<feed key>/json` cho từng feed cảm biến cùng `phan-hoi`, `trang-thai`; mỗi tin ghi `BangGhiDuLieu` với `thoi_gian_ghi = created_at` (UTC).
- **REST (đọc bù):** khi khởi động hoặc kết nối lại, với mỗi feed cảm biến gọi `GET /api/v2/{username}/feeds/<feed key>/data?start_time=<thời gian ghi mới nhất trong MySQL>&limit=1000`, đọc tiếp theo header `Link`.
- **Chống trùng:** subscribe MQTT trước, đọc bù sau; ghi bằng `INSERT IGNORE`. Ràng buộc UNIQUE (ma_thiet_bi, thoi_gian_ghi) ở V4 tự loại phần trùng giữa hai kênh. `ma_ban_ghi` chỉ là thứ tự ghi; mọi truy vấn sắp theo `thoi_gian_ghi`.
- **Trạng thái bo:** tin `trang-thai` cập nhật `dung_luong_pin`, `thoi_gian_hoat_dong_lan_cuoi` cho mọi thiết bị có cùng `dia_chi_mac`, nên MAC của thiết bị thật phải đúng (mục 3.3).

---

## 7. Dữ liệu mẫu

Mật khẩu mọi tài khoản mẫu: **`Kho@12345`** (chỉ dùng cho môi trường phát triển). Mật khẩu được lưu dạng băm bcrypt.

| Tên đăng nhập | Vai trò | Phạm vi |
| --- | --- | --- |
| `chu.an` | Chủ doanh nghiệp | Nhà kho 1 (phòng A1, A2, A3) |
| `chu.binh` | Chủ doanh nghiệp | Nhà kho 2 (phòng B1) |
| `ql.cuong` | Quản lý kho | Phòng A1, A2 |
| `ql.dung` | Quản lý kho | Phòng A3 |
| `ql.lan` | Quản lý kho | Phòng B1 |
| `nv.em` | Nhân viên vận hành | Phòng A1, A2 |
| `nv.giang` | Nhân viên vận hành | Phòng A2, A3 |
| `nv.huy` | Nhân viên vận hành | Phòng A3 |
| `nv.tam` | Nhân viên vận hành | Phòng B1 |
| `nv.khoa` | Nhân viên vận hành, **bị khóa** | Phòng A1 |

Ngoài ra có 10 thiết bị mẫu (gồm 1 thiết bị mất kết nối, 1 không phản hồi lệnh, 1 ngừng sử dụng) và 2 thiết bị thật của bộ demo (`a1-ap-suat`, `a1-quat`, nạp ở mục 3.3), bản ghi cảm biến mỗi 30 phút trong 24 giờ qua, nhật kí thao tác từ người dùng / lịch trình / rule, 6 cảnh báo ở đủ các trạng thái, tin nhắn có đính kèm cảnh báo và chấm công của nhân viên lẫn quản lý. Thời gian được tính lùi từ lúc chạy script nên dữ liệu luôn "gần đây".

Chỉ thiết bị phòng A1 (`a1-nhiet-do`, `a1-do-am`, `a1-ap-suat`, `a1-quat`) có feed thật trên Adafruit IO; thiết bị các phòng khác chỉ để hiển thị và thử phân quyền.

Nạp lại từ đầu: `docker compose down -v` → mục 3.2 → mục 3.3.

---

## 8. Kiểm thử ràng buộc

`database/tests/kiem_thu_rang_buoc.sql` chạy **67 ca** trên `DADN261_test` (CSDL phải đã migrate tới V4). Mỗi ca chạy một câu lệnh và so mã lỗi thực tế với mã lỗi kỳ vọng:

| Mã | Nghĩa |
| --- | --- |
| 0 | Thành công |
| 3819 | Vi phạm CHECK |
| 1062 | Trùng UNIQUE |
| 1644 | Trigger từ chối (SIGNAL) |
| 1451 | Xóa dòng đang được tham chiếu |
| 1452 | Tham chiếu tới dòng không tồn tại |

Toàn bộ dữ liệu thử nằm trong một transaction và bị **ROLLBACK** ở cuối, nên chạy lại bao nhiêu lần cũng được. Kết quả gồm ba bảng: tổng hợp, các ca **KHÔNG ĐẠT** (phải rỗng) và toàn bộ 67 ca. Mã `RB..` của mỗi ca ứng với ràng buộc ngữ nghĩa trong tài liệu đặc tả RD.

Thêm ca mới: gọi `kt_chay('T68', 'RBxx', 'mô tả', <mã lỗi kỳ vọng>, "<câu SQL>")` trước dòng `ROLLBACK;`, hoặc `kt_kiem_tra(...)` với một biểu thức phải trả về đúng.

---

## 9. Thiết kế CSDL tóm tắt

- **18 bảng**, 6 nhóm: người dùng và vai trò · cấu trúc kho và nhân sự · thiết bị và dữ liệu cảm biến · lịch trình và rule · nhật kí thao tác và cảnh báo · tin nhắn nội bộ.
- **Vai trò cố định:** 1 Chủ doanh nghiệp · 2 Quản lý kho · 3 Nhân viên vận hành. Trigger kiểm tra vai trò dựa trên các mã này.
  - Chủ doanh nghiệp sở hữu nhà kho.
  - Quản lý kho phụ trách phòng kho (1:N).
  - Nhân viên vận hành làm việc tại phòng kho (N:M, bảng `NhanVienLamViec`).
  - Quản lý và nhân viên chấm công; chủ doanh nghiệp không chấm công.
- **DB giữ toàn vẹn dữ liệu, backend giữ phân quyền.**
  - DB: CHECK, UNIQUE, trigger. Ví dụ: người phụ trách phòng phải là Quản lý kho; nhật kí thao tác chỉ được thêm, không sửa hay xóa.
  - Backend: ai được làm gì, ở kho/phòng nào, vì DB không biết người đang đăng nhập (backend dùng một tài khoản `app` duy nhất).
- **Nhật kí thao tác chỉ được thêm.** Backend chờ phản hồi từ thiết bị (hoặc hết thời gian chờ) rồi mới ghi, kèm `ket_qua_thao_tac`; không cập nhật được về sau.
- **Xử lý cảnh báo:** backend dùng `UPDATE … WHERE ma_nguoi_dung IS NULL` để chỉ người đầu tiên được ghi nhận; trigger tự chuyển trạng thái `DA_XU_LY` và điền thời gian.
- **Bản ghi cảm biến:** mỗi thiết bị tối đa một bản ghi tại một thời điểm (UNIQUE ở V4, ràng buộc RB29), để ghi từ MQTT và đọc bù từ REST không bị trùng.
- **Đèn LED và còi** không có trong CSDL: chỉ nhận lệnh bật/tắt qua feed `canh-bao`.

Chi tiết từng bảng, các ràng buộc ngữ nghĩa (RB01–RB28; RB29 bổ sung ở V4), CHECK và trigger: xem tài liệu đặc tả RD (đặt file `Dac_ta_luoc_do_quan_he_RD.docx` trong `docs/`). Cấu hình linh kiện và quy trình firmware – Adafruit IO – backend: `docs/cau_hinh_va_quy_trinh_ket_noi.docx`.

---

## 10. Quy trình Git

- Nhánh `main` được bảo vệ (ruleset `bao-ve-main`): chỉ nhận thay đổi qua Pull Request.
- Tên nhánh: `feature/<STT>-<mo-ta-ngan>` theo số thứ tự nhiệm vụ, ví dụ `feature/3-docker-mysql`.
- Nên mỗi PR một nhiệm vụ; mô tả PR ghi số thứ tự nhiệm vụ và mã use case liên quan.
- Không commit `.env`, `firmware/.env`, `firmware/secrets.h`, file dump CSDL hay mật khẩu. `.gitignore` cần có `.env` và `**/secrets.h`.

---

## 11. Lệnh thường dùng

| Việc | Lệnh |
| --- | --- |
| Khởi động MySQL | `docker compose up -d mysql` |
| Xem trạng thái, cổng | `docker compose ps` |
| Xem log MySQL | `docker compose logs --tail 50 mysql` |
| Dừng (giữ dữ liệu) | `docker compose stop` |
| Xóa sạch, dựng lại | `docker compose down -v` rồi làm lại mục 3.2 |
| Migrate CSDL chính | `docker compose run --rm flyway migrate` |
| Trạng thái migration | `docker compose run --rm flyway info` |
| Kiểm tra checksum | `docker compose run --rm flyway validate` |
| Kiểm tra file bí mật bị Git bỏ qua | `git check-ignore -v .env firmware/.env firmware/secrets.h` |

---

## 12. Xử lý sự cố

| Triệu chứng | Nguyên nhân | Cách xử lý |
| --- | --- | --- |
| `Found non-empty schema(s) … but no schema history table` | Đã chạy tay file SQL trong Workbench trước khi Flyway chạy | `docker compose down -v`, làm lại mục 3.2. Không dùng `baseline` |
| `WARNING: DB: Trigger does not exist (1360)` | Ghi chú của `DROP TRIGGER IF EXISTS` trên CSDL trống | Bỏ qua |
| `Using MySQL 8.4 which is newer than … verified` | Flyway chỉ liệt kê bản đã kiểm thử | Bỏ qua |
| `Validate failed: Migration checksum mismatch` | File migration đã chạy bị sửa | Hoàn tác thay đổi trong file đó; đưa thay đổi vào file `V` mới |
| Workbench: `Unable to connect to 127.0.0.1` | Container không chạy, hoặc sai cổng | `docker compose ps`; cổng phải là `127.0.0.1:3307->3306/tcp` |
| `Access denied for user …` sau `down -v` | Tài khoản được tạo lại theo mật khẩu hiện tại trong `.env` | Workbench: **Clear** mật khẩu cũ, **Store in Vault** mật khẩu mới |
| `Chua khai bao … trong .env` | Thiếu biến trong `.env` hoặc chạy lệnh ở sai thư mục | Lưu `.env`, chạy lệnh ở thư mục gốc dự án |
| Lỗi 1175 `safe update mode` trong Workbench | Workbench chặn UPDATE/DELETE không có WHERE theo khóa | Thêm WHERE theo khóa; script kiểm thử tự tắt trong phiên |
| Lỗi 1142 `command denied` | Đang dùng tài khoản `app` để đổi cấu trúc | Đúng thiết kế; đổi cấu trúc bằng migration |
| Lỗi 1419 khi tạo trigger | Thiếu cờ `--log-bin-trust-function-creators=1` | Kiểm tra `command` của service `mysql` |
| Script `init/*.sh` lỗi `\r` / `bad interpreter` | File `.sh` dùng CRLF | Chuyển sang LF trong VS Code, rồi `down -v` |
| Sửa script trong `init/` mà không có tác dụng | `init/` chỉ chạy khi volume trống | `docker compose down -v` |
| Flyway hoặc Workbench: `Access denied for user 'dadn_migration'` | Script `02-tao-tai-khoan.sh` không chạy (thường do `01`/`02` dùng CRLF) nên tài khoản không được tạo | Đổi `.sh` sang LF, `docker compose down -v`, kiểm tra log có `running …/02-tao-tai-khoan.sh` |
| `docker compose exec … -e "SQL có dấu cách"` báo lỗi 1064 | Windows PowerShell 5.1 làm mất dấu nháy kép bên trong tham số | Gọi trực tiếp: `docker compose exec mysql mysql -uroot -p -e "…"` |
| Adafruit IO trả `401` | AIO Key sai, hoặc `.env` không cùng thư mục với `adafruit.http` | Kiểm tra `firmware/.env` |
| Adafruit IO trả `404` | Sai username hoặc feed key | Đối chiếu bảng mục 6.2 |
| Adafruit IO trả `429` / có tin ở topic `throttle` | Vượt 30 điểm/phút trên cả tài khoản | Chờ khoảng 1 phút; dừng các script gửi lặp |
| Firmware nhận `ON`/`OFF` thay vì `1`/`0` | Toggle trên dashboard để giá trị mặc định | Đặt On = `1`, Off = `0` |