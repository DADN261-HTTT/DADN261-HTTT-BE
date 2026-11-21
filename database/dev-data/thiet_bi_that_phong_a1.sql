-- =====================================================================
-- THIẾT BỊ THẬT CHO PHÒNG A1 (bộ thiết bị demo nối với Adafruit IO)
-- Chạy SAU V4 và SAU du_lieu_mau.sql, trên CSDL DADN261, bằng tài khoản app.
-- Trước khi chạy: thay @mac_bo_a1 bằng địa chỉ MAC thật của bo ESP32 / Yolo UNO
-- (firmware in ra khi khởi động). Backend dùng MAC trong feed trang-thai để cập nhật
-- pin và thời điểm hoạt động cho mọi thiết bị trên bo.
--
-- Feed trên Adafruit IO tương ứng:
--   a1-nhiet-do (thiết bị 1, đã có) · a1-do-am (thiết bị 2, đã có)
--   a1-ap-suat  (thiết bị 11, mới)  · a1-quat  (thiết bị 12, mới)
--   canh-bao, phan-hoi, trang-thai: feed dùng chung, không có trong CSDL
-- =====================================================================

SET NAMES utf8mb4;
SET @mac_bo_a1 = 'A4:CF:12:3B:5E:01';      -- THAY bằng MAC thật

START TRANSACTION;

-- Cảm biến nhiệt độ, độ ẩm đã có trong dữ liệu mẫu: gắn MAC của bo thật
UPDATE ThietBiIot SET dia_chi_mac = @mac_bo_a1 WHERE ma_thiet_bi IN (1, 2);

-- Thiết bị mới: cảm biến áp suất (loại 5, thêm ở V4) và quạt (loại 4)
INSERT INTO ThietBiIot (ma_thiet_bi, ma_phan_loai, ten_thiet_bi, dia_chi_mac, feed_key,
                        trang_thai_hoat_dong, vi_tri_trong_phong, ma_phong_kho) VALUES
    (11, 5, 'Áp suất A1', @mac_bo_a1, 'a1-ap-suat', 'HOAT_DONG', 'Giữa phòng', 1),
    (12, 4, 'Quạt A1',    @mac_bo_a1, 'a1-quat',    'HOAT_DONG', 'Nắp thùng',  1);

-- Rule cho bộ demo trong thùng đá (khoảng 0–10 °C):
--   - cảm biến nhiệt độ A1 dùng rule 2 (0–5 °C) thay cho rule 1 (cấp đông, thùng đá không đạt)
--   - rule 5: nhiệt độ vượt 6 °C thì bật quạt A1
--   - rule 7: áp suất bất thường
DELETE FROM ThietLapRule WHERE ma_thiet_bi = 1 AND ma_rule = 1;
INSERT INTO ThietLapRule (ma_thiet_bi, ma_rule) VALUES
    (1, 2),
    (1, 5), (12, 5),
    (11, 7);

COMMIT;

SELECT ma_thiet_bi, ten_thiet_bi, feed_key, dia_chi_mac, ma_phan_loai
FROM ThietBiIot WHERE ma_phong_kho = 1 ORDER BY ma_thiet_bi;
