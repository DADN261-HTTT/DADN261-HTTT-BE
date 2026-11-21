-- =====================================================================
-- V4. BỔ SUNG DANH MỤC ÁP SUẤT VÀ CHỐNG TRÙNG BẢN GHI CẢM BIẾN
--   1. Danh mục: loại thiết bị "Cảm biến áp suất" (hPa) và rule áp suất mẫu
--      (bổ sung cho V3; V3 đã chạy nên không sửa V3)
--   2. BangGhiDuLieu: UNIQUE (ma_thiet_bi, thoi_gian_ghi) thay cho chỉ mục thường,
--      để backend ghi bằng INSERT IGNORE khi nhận qua MQTT và đọc bù qua REST
--      mà không sinh bản ghi trùng.
-- Đèn LED và còi không có trong CSDL (chỉ nhận lệnh qua feed cấu hình ở backend).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Danh mục
-- ---------------------------------------------------------------------
INSERT INTO PhanLoaiThietBi (ma_phan_loai_thiet_bi, ten_phan_loai, don_vi_do) VALUES
    (5, 'Cảm biến áp suất', 'hPa');

-- Áp suất tuyệt đối gần mặt nước biển dao động quanh 1013 hPa theo thời tiết;
-- khoảng rộng dưới đây chỉ bắt các giá trị bất thường (cảm biến lỗi, thay đổi lớn).
INSERT INTO RuleEngine (ma_rule, ten_rule, thong_tin_mo_ta, gioi_han_tren, gioi_han_duoi, ma_xu_ly) VALUES
    (7, 'Áp suất bất thường', 'Cảnh báo khi áp suất tuyệt đối ra ngoài khoảng 980 hPa đến 1040 hPa',
        1040, 980, 'CANH_BAO_NGOAI_KHOANG');

-- ---------------------------------------------------------------------
-- 2. Chống trùng bản ghi cảm biến
--    Thêm UNIQUE trước rồi mới xóa chỉ mục cũ: khóa ngoại BangGhiDuLieu_ThietBiIot
--    cần một chỉ mục bắt đầu bằng ma_thiet_bi; UNIQUE mới đảm nhận vai trò đó.
--    Điều kiện: mỗi thiết bị tối đa 1 bản ghi tại một thời điểm (firmware gửi 30 giây/lần).
-- ---------------------------------------------------------------------
ALTER TABLE BangGhiDuLieu
    ADD CONSTRAINT BangGhiDuLieu_uq_ThietBi_ThoiGian UNIQUE (ma_thiet_bi, thoi_gian_ghi);

ALTER TABLE BangGhiDuLieu
    DROP INDEX BangGhiDuLieu_idx_ThietBi_ThoiGian;
