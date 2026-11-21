// Sao chép thành secrets.h (cùng thư mục với mã firmware) rồi điền giá trị.
// KHÔNG commit secrets.h (.gitignore có dòng **/secrets.h).
#pragma once

#define WIFI_SSID      ""          // WiFi 2,4 GHz
#define WIFI_PASSWORD  ""

#define AIO_USERNAME   ""          // username Adafruit IO
#define AIO_KEY        ""          // AIO Key (My Key trên io.adafruit.com)

#define AIO_SERVER     "io.adafruit.com"
#define AIO_PORT_TLS   8883

// Feed key (trùng với ThietBiIot.feed_key trong CSDL và feed trên Adafruit IO)
#define FEED_NHIET_DO  "a1-nhiet-do"
#define FEED_DO_AM     "a1-do-am"
#define FEED_AP_SUAT   "a1-ap-suat"
#define FEED_QUAT      "a1-quat"
#define FEED_CANH_BAO  "canh-bao"
#define FEED_PHAN_HOI  "phan-hoi"
#define FEED_TRANG_THAI "trang-thai"