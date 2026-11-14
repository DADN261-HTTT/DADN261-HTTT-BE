# DADN-HTTT-HK261 – Backend hệ thống quản lý thiết bị IoT kho lạnh

Kho mã nguồn backend và cơ sở dữ liệu của đồ án đa ngành: quản lý nhà kho, phòng kho, thiết bị IoT (qua Adafruit IO), dữ liệu cảm biến, lịch trình, rule, cảnh báo, nhật kí và tin nhắn nội bộ. Frontend nằm ở kho mã nguồn riêng.

Trạng thái hiện tại: hạ tầng CSDL đã xong (MySQL 8.4 trong Docker, migration bằng Flyway, dữ liệu danh mục, dữ liệu mẫu, kiểm thử ràng buộc). Ngôn ngữ backend chưa chốt.

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
│   │   └── V3__du_lieu_danh_muc.sql
│   ├── dev-data/
│   │   └── du_lieu_mau.sql     # dữ liệu mẫu cho môi trường phát triển
│   └── tests/
│       └── kiem_thu_rang_buoc.sql  # 62 ca kiểm thử CHECK, UNIQUE, khóa ngoại, trigger
├── docs/                       # tài liệu đặc tả (ERD, RD, quy trình)
├── .env.example                # mẫu biến môi trường (KHÔNG chứa mật khẩu thật)
├── .gitattributes              # quy định kiểu xuống dòng (file .sh phải là LF)
├── .gitignore                  # bỏ qua .env
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

Ba mật khẩu nên khác nhau. Đổi mật khẩu hoặc tên CSDL sau khi đã khởi tạo thì phải dựng lại từ đầu (mục 9, `down -v`).

### 3.2. Khởi động MySQL và chạy migration

```powershell
docker compose up -d mysql
docker compose ps                                   # chờ dadn-mysql ở trạng thái (healthy)

docker compose run --rm flyway migrate              # CSDL chính: V1 → V3
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

### 3.4. Chạy kiểm thử ràng buộc (CSDL test, tài khoản migration)

```powershell
docker compose cp database/tests/kiem_thu_rang_buoc.sql mysql:/tmp/kiem_thu.sql
docker compose exec mysql sh -c 'mysql -u"$MYSQL_MIGRATION_USER" -p"$MYSQL_MIGRATION_PASSWORD" --default-character-set=utf8mb4 -t "${MYSQL_DATABASE}_test" < /tmp/kiem_thu.sql'
```

Hoặc chạy cả file trong Workbench bằng connection **migration**. Xem mục 7 để đọc kết quả.

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
# 1. Tạo database/migration/V4__them_cot_x.sql
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

---

## 6. Dữ liệu mẫu

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

Ngoài ra có 10 thiết bị (gồm 1 thiết bị mất kết nối, 1 không phản hồi lệnh, 1 ngừng sử dụng), bản ghi cảm biến mỗi 30 phút trong 24 giờ qua, nhật kí thao tác từ người dùng / lịch trình / rule, 6 cảnh báo ở đủ các trạng thái, tin nhắn có đính kèm cảnh báo và chấm công của nhân viên lẫn quản lý. Thời gian được tính lùi từ lúc chạy script nên dữ liệu luôn "gần đây".

Nạp lại từ đầu: `docker compose down -v` → mục 3.2 → mục 3.3.

---

## 7. Kiểm thử ràng buộc

`database/tests/kiem_thu_rang_buoc.sql` chạy **62 ca** trên `DADN261_test`. Mỗi ca chạy một câu lệnh và so mã lỗi thực tế với mã lỗi kỳ vọng:

| Mã | Nghĩa |
| --- | --- |
| 0 | Thành công |
| 3819 | Vi phạm CHECK |
| 1062 | Trùng UNIQUE |
| 1644 | Trigger từ chối (SIGNAL) |
| 1451 | Xóa dòng đang được tham chiếu |
| 1452 | Tham chiếu tới dòng không tồn tại |

Toàn bộ dữ liệu thử nằm trong một transaction và bị **ROLLBACK** ở cuối, nên chạy lại bao nhiêu lần cũng được. Kết quả gồm ba bảng: tổng hợp, các ca **KHÔNG ĐẠT** (phải rỗng) và toàn bộ 62 ca. Mã `RB..` của mỗi ca ứng với ràng buộc ngữ nghĩa trong tài liệu đặc tả RD.

Thêm ca mới: gọi `kt_chay('T63', 'RBxx', 'mô tả', <mã lỗi kỳ vọng>, "<câu SQL>")` trước dòng `ROLLBACK;`, hoặc `kt_kiem_tra(...)` với một biểu thức phải trả về đúng.

---

## 8. Thiết kế CSDL tóm tắt

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

Chi tiết từng bảng, 28 ràng buộc ngữ nghĩa, CHECK và trigger: xem tài liệu đặc tả RD (đặt file `Dac_ta_luoc_do_quan_he_RD.docx` trong `docs/`).

---

## 9. Quy trình Git

- Nhánh `main` được bảo vệ (ruleset `bao-ve-main`): chỉ nhận thay đổi qua Pull Request.
- Tên nhánh: `feature/<STT>-<mo-ta-ngan>` theo số thứ tự nhiệm vụ, ví dụ `feature/3-docker-mysql`.
- Nên mỗi PR một nhiệm vụ; mô tả PR ghi số thứ tự nhiệm vụ và mã use case liên quan.
- Không commit `.env`, file dump CSDL hay mật khẩu.

---

## 10. Lệnh thường dùng

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

---

## 11. Xử lý sự cố

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