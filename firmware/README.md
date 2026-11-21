# Firmware – bộ thiết bị kho lạnh kết nối Adafruit IO

Thư mục chứa mã firmware cho bo ESP32 DevKit / Yolo UNO và các công cụ thử kết nối với Adafruit IO. Firmware đọc cảm biến (nhiệt độ, độ ẩm, áp suất), gửi lên Adafruit IO, nhận lệnh điều khiển quạt và cảnh báo (LED, còi), rồi gửi phản hồi và trạng thái bo mạch.

Danh sách feed, định dạng giá trị và giới hạn của Adafruit IO: xem **mục 6 của `README.md` ở thư mục gốc**.

---

## 1. Các file trong thư mục

| File | Nội dung | Commit |
| --- | --- | --- |
| `README.md` | Hướng dẫn này | Có |
| `adafruit.http` | Bộ lệnh REST API Adafruit IO đã lưu, chạy bằng extension REST Client | Có (không chứa khóa) |
| `.env.example` | Mẫu `AIO_USERNAME`, `AIO_KEY` cho `adafruit.http` | Có |
| `.env` | Giá trị thật của `AIO_USERNAME`, `AIO_KEY` | **Không** |
| `secrets.example.h` | Mẫu cấu hình WiFi, Adafruit IO và feed key cho mã firmware | Có |
| `secrets.h` | Giá trị thật, được mã firmware `#include` | **Không** |

---

## 2. Chuẩn bị thông tin 

1. Lấy **Username** và **Active Key** (hỏi người quản lý tài khoản nhóm).
2. Tạo `.env` cho REST Client:
   ```powershell
   copy firmware\.env.example firmware\.env
   ```
   Điền `AIO_USERNAME` và `AIO_KEY`.
3. Tạo `secrets.h` cho mã firmware:
   ```powershell
   copy firmware\secrets.example.h firmware\secrets.h
   ```
   Điền WiFi (băng tần 2,4 GHz), `AIO_USERNAME`, `AIO_KEY`.
4. Kiểm tra Git đã bỏ qua hai file trên:
   ```powershell
   git check-ignore -v firmware/.env firmware/secrets.h
   ```
   Mỗi file phải in ra một dòng từ `.gitignore` (`.env` và `**/secrets.h`). Nếu không in gì, thêm hai mẫu đó vào `.gitignore` trước khi commit.

Không gửi khóa qua ảnh chụp màn hình hay nhóm chat chung. Khóa bị lộ thì **Regenerate Key** trên Adafruit IO và cập nhật lại `firmware/.env`, `firmware/secrets.h`, `.env` của backend.

---

## 3. Cài extension REST Client

1. VS Code → `Ctrl + Shift + X` → tìm **REST Client** (tác giả **Huachao Mao**, mã `humao.rest-client`) → **Install**.
2. Mở `firmware/adafruit.http`. Góc dưới phải VS Code phải hiện chế độ **HTTP**, và phía trên mỗi dòng `###` có chữ nhỏ **Send Request**.
3. Nếu không thấy **Send Request**: bấm vào chế độ ngôn ngữ ở góc dưới phải, chọn **HTTP**; hoặc khởi động lại VS Code sau khi cài.

---

## 4. Cấu trúc file `adafruit.http`

**Biến ở đầu file.** REST Client thay `{{...}}` bằng giá trị đọc từ `firmware/.env`. File `.env` phải nằm **cùng thư mục** với `adafruit.http`:

```http
@user = {{$dotenv AIO_USERNAME}}
@key  = {{$dotenv AIO_KEY}}
@base = https://io.adafruit.com/api/v2/{{user}}
```

**Mỗi khối bắt đầu bằng `###` là một lệnh:**

```http
### A1. Gửi nhiệt độ                          ← tên lệnh
POST {{base}}/feeds/a1-nhiet-do/data          ← phương thức + địa chỉ
X-AIO-Key: {{key}}                            ← header xác thực
Content-Type: application/json                ← header kiểu dữ liệu
                                              ← bắt buộc một dòng trống
{ "value": "-19.6" }                          ← nội dung gửi đi
```

---

## 5. Sử dụng

1. Mở `firmware/adafruit.http`, bấm **Send Request** phía trên lệnh cần chạy.
2. Kết quả hiện ở khung bên phải. Gửi thành công có dạng:
   ```
   HTTP/1.1 200 OK
   { "id": "0F...", "value": "-19.6", "feed_key": "a1-nhiet-do", "created_at": "2026-11-21T10:32:05Z", ... }
   ```
3. Đối chiếu: trang feed trên io.adafruit.com có điểm mới; MQTT Explorer (nếu đang mở) nhận được tin tương ứng.
4. Thử giá trị khác: sửa phần nội dung rồi gửi lại. Thêm lệnh mới: chép một khối `###` và sửa.
5. Thời gian trong các lệnh (`created_at`, `start_time`) viết theo UTC, đuôi `Z`. Giờ Việt Nam = UTC + 7.

**Mỗi lệnh gửi dữ liệu (POST) tính 1 điểm** vào giới hạn 30 điểm/phút của cả tài khoản (lệnh gửi nhiều điểm tính theo số điểm). Không bấm gửi liên tục, nhất là khi người khác trong nhóm đang chạy firmware.

### Danh sách lệnh

**A. Phía firmware** (đường chính của firmware là MQTT; REST dùng cho các trường hợp dưới đây)

| Lệnh | Việc làm | Firmware dùng khi |
| --- | --- | --- |
| A1–A3 | Gửi nhiệt độ, độ ẩm, áp suất | Thử nghiệm; dự phòng khi không dùng được MQTT |
| A4 | Gửi bù một điểm kèm `created_at` (chỉ được ở quá khứ) | Có mạng lại sau khi mất kết nối, nếu firmware có đệm dữ liệu |
| A5 | Gửi bù nhiều điểm một lần (`/data/batch`) | Như A4, khi đệm nhiều điểm |
| A6 | Gửi phản hồi lệnh `feed\|giá trị\|kết quả` | Thử định dạng phản hồi |
| A7 | Gửi trạng thái `MAC\|pin\|RSSI\|thời gian chạy` | Thử định dạng trạng thái |
| A8 | Lấy lệnh cuối của quạt (`/data/last_value`, trả về giá trị thuần) | Khởi động: khôi phục trạng thái quạt |
| A9 | Lấy trạng thái cảnh báo cuối | Khởi động: khôi phục LED, còi |

**B. Phía backend** (thử trước khi viết mã backend)

| Lệnh | Việc làm |
| --- | --- |
| B1 | Danh sách feed: kiểm tra key và Feed History |
| B2–B3 | Gửi lệnh bật / tắt quạt |
| B4–B5 | Bật / tắt LED và còi |
| B6 | Đọc bù từ một mốc thời gian (tối đa 1000 điểm/lần; trang tiếp theo trong header `Link`) |
| B7 | 5 điểm gần nhất |
| B8 | Điểm cuối cùng, đầy đủ thông tin |

### Lỗi thường gặp

| Mã trả về | Nguyên nhân | Cách xử lý |
| --- | --- | --- |
| `401` | AIO Key sai; hoặc `firmware/.env` không cùng thư mục với `adafruit.http` | Kiểm tra `firmware/.env` |
| `404` | Sai username hoặc feed key | Đối chiếu danh sách feed (mục 6.2 README gốc) |
| `400` | `created_at` ở tương lai; hoặc gửi nhiều điểm vào feed đã tắt Feed History | Sửa thời gian; bật lại Feed History |
| `429` | Vượt 30 điểm/phút | Chờ khoảng 1 phút |
| URL còn chữ `{{user}}` | REST Client không đọc được `.env` | Kiểm tra tên biến và vị trí `firmware/.env` |

---

## 6. Từ lệnh đã lưu sang mã firmware

Quy trình: chạy thử lệnh trong `adafruit.http` cho đúng trước, rồi chép **địa chỉ, header, nội dung** sang mã. Ví dụ với ESP32 (Arduino) cho lệnh **A1** và **A8**:

```cpp
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include "secrets.h"

const String BASE = String("https://io.adafruit.com/api/v2/") + AIO_USERNAME;

// Lệnh A1: POST {{base}}/feeds/<feed>/data
bool guiGiaTri(const String& feed, const String& giaTri) {
  WiFiClientSecure client;
  client.setInsecure();          // chỉ dùng khi thử; bản chính dùng client.setCACert(...)
  HTTPClient http;
  http.begin(client, BASE + "/feeds/" + feed + "/data");
  http.addHeader("X-AIO-Key", AIO_KEY);
  http.addHeader("Content-Type", "application/json");
  int ma = http.POST("{\"value\":\"" + giaTri + "\"}");
  http.end();
  return ma >= 200 && ma < 300;
}

// Lệnh A8: GET {{base}}/feeds/<feed>/data/last_value  → "1" hoặc "0"
String layGiaTriCuoi(const String& feed) {
  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;
  http.begin(client, BASE + "/feeds/" + feed + "/data/last_value");
  http.addHeader("X-AIO-Key", AIO_KEY);
  String kq = (http.GET() == 200) ? http.getString() : "";
  http.end();
  return kq;
}
```

---

## 7. Yêu cầu kết nối MQTT (đường chính của firmware)

| Hạng mục | Yêu cầu |
| --- | --- |
| Mạng | WiFi 2,4 GHz |
| Máy chủ | `io.adafruit.com`, cổng `8883` (TLS); `1883` chỉ dùng khi thử |
| Xác thực | Username = `AIO_USERNAME`; password = `AIO_KEY` |
| Client ID | Duy nhất mỗi bo, ví dụ `kho-a1-<MAC>` (trùng ID thì hai bo ngắt kết nối nhau) |
| Gửi dữ liệu | Topic `{username}/feeds/<feed key>`, QoS 0 cho cảm biến |
| Nhận lệnh | Subscribe `{username}/feeds/a1-quat` và `{username}/feeds/canh-bao`, QoS 1 |
| Phản hồi | Gửi `feed\|giá trị\|kết quả` lên `phan-hoi` trong vòng 2 giây sau khi thực hiện lệnh |
| Trạng thái | Gửi `MAC\|pin\|RSSI\|thời gian chạy` lên `trang-thai` mỗi 60 giây |
| Tần suất | Mỗi feed cảm biến 30 giây/lần; không gửi hai điểm cùng feed trong một giây |
| Giá trị | Số dùng dấu chấm thập phân, 1 chữ số lẻ, không kèm đơn vị; bỏ giá trị lỗi (NaN, -127) trước khi gửi |
| Thời gian | Không cần gửi; backend dùng `created_at` của Adafruit IO |
| Kết nối lại | Thời gian chờ tăng dần 1, 2, 4… tối đa 60 giây; không dừng đọc cảm biến và hiển thị |