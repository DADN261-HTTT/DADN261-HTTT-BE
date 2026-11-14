-- =====================================================================
-- DỮ LIỆU MẪU CHO MÔI TRƯỜNG PHÁT TRIỂN
-- Chạy SAU khi Flyway đã migrate tới V3, trên CSDL DADN261, bằng tài khoản app.
-- Chỉ chạy MỘT lần trên CSDL vừa migrate. Muốn nạp lại từ đầu:
--   docker compose down -v → up -d mysql → flyway migrate → chạy lại file này.
-- Mật khẩu của mọi tài khoản mẫu: Kho@12345 (chuỗi băm bcrypt bên dưới).
-- Thời gian tính lùi từ lúc chạy (@t0) để dữ liệu luôn "gần đây".
-- =====================================================================

SET NAMES utf8mb4;
SET @t0      = NOW(3);
SET @mat_khau = '$2b$10$pe8BftNRcGDu0KPzR6JhquYW5NicmHvNWXLaVxpm4OdaL85gswfDK';

START TRANSACTION;

-- ---------------------------------------------------------------------
-- 1. Người dùng (vai trò 1/2/3 có sẵn từ V3)
-- ---------------------------------------------------------------------
INSERT INTO NguoiDung (ma_nguoi_dung, ten_nguoi_dung, thong_tin_dang_nhap, mat_khau, trang_thai_tai_khoan, ma_vai_tro) VALUES
    ( 1, 'Nguyễn Văn An',   'chu.an',    @mat_khau, 'HOAT_DONG', 1),
    ( 2, 'Trần Thị Bình',   'chu.binh',  @mat_khau, 'HOAT_DONG', 1),
    ( 3, 'Lê Minh Cường',   'ql.cuong',  @mat_khau, 'HOAT_DONG', 2),
    ( 4, 'Phạm Thu Dung',   'ql.dung',   @mat_khau, 'HOAT_DONG', 2),
    ( 5, 'Hoàng Văn Em',    'nv.em',     @mat_khau, 'HOAT_DONG', 3),
    ( 6, 'Võ Thị Giang',    'nv.giang',  @mat_khau, 'HOAT_DONG', 3),
    ( 7, 'Đặng Quốc Huy',   'nv.huy',    @mat_khau, 'HOAT_DONG', 3),
    ( 8, 'Bùi Ngọc Lan',    'ql.lan',    @mat_khau, 'HOAT_DONG', 2),
    ( 9, 'Ngô Đức Tâm',     'nv.tam',    @mat_khau, 'HOAT_DONG', 3),
    (10, 'Lý Văn Khoa',     'nv.khoa',   @mat_khau, 'BI_KHOA',   3);

-- ---------------------------------------------------------------------
-- 2. Nhà kho, phòng kho, phân công
--    Nhà kho 1 (chủ: An) có 3 phòng; nhà kho 2 (chủ: Bình) có 1 phòng
--    → dùng để kiểm tra phạm vi truy cập giữa hai chủ doanh nghiệp.
-- ---------------------------------------------------------------------
INSERT INTO NhaKho (ma_nha_kho, ma_chu_doanh_nghiep, ten_nha_kho, vi_tri_nha_kho) VALUES
    (1, 1, 'Kho lạnh số 1', 'Khu công nghiệp A, TP. Hồ Chí Minh'),
    (2, 2, 'Kho lạnh số 2', 'Khu công nghiệp B, tỉnh Bình Dương');

INSERT INTO PhongKho (ma_phong_kho, ma_nguoi_quan_ly, ma_nha_kho, ten_phong_kho, vi_tri_phong_kho, thong_tin_phong_kho) VALUES
    (1, 3, 1, 'Phòng cấp đông A1', 'Tầng trệt, dãy A', 'Thịt, hải sản đông lạnh; -25 °C đến -18 °C'),
    (2, 3, 1, 'Phòng mát A2',      'Tầng trệt, dãy A', 'Rau củ, trái cây; 0 °C đến 5 °C'),
    (3, 4, 1, 'Phòng sữa A3',      'Tầng 1, dãy A',    'Sữa và chế phẩm từ sữa; 2 °C đến 6 °C'),
    (4, 8, 2, 'Phòng cấp đông B1', 'Tầng trệt, dãy B', 'Thủy sản đông lạnh; -25 °C đến -18 °C');

INSERT INTO NhanVienLamViec (ma_nhan_vien, ma_phong_kho) VALUES
    (5, 1), (5, 2),
    (6, 2), (6, 3),
    (7, 3),
    (9, 4),
    (10, 1);

-- ---------------------------------------------------------------------
-- 3. Thiết bị
--    Cảm biến nhiệt độ và độ ẩm cùng phòng dùng chung một linh kiện (cùng MAC).
--    Thiết bị 7 mất kết nối 2 giờ; thiết bị 8 không phản hồi lệnh gần nhất;
--    thiết bị 10 đã ngừng sử dụng (giữ lại vì có lịch sử).
-- ---------------------------------------------------------------------
INSERT INTO ThietBiIot (ma_thiet_bi, ma_phan_loai, ten_thiet_bi, dia_chi_mac, feed_key, dung_luong_pin,
                        trang_thai_hoat_dong, vi_tri_trong_phong, ma_phong_kho, thoi_gian_hoat_dong_lan_cuoi) VALUES
    ( 1, 1, 'Nhiệt độ A1',  'A4:CF:12:3B:5E:01', 'a1-nhiet-do', 85,   'HOAT_DONG',     'Giữa phòng',   1, @t0 - INTERVAL 20 SECOND),
    ( 2, 2, 'Độ ẩm A1',     'A4:CF:12:3B:5E:01', 'a1-do-am',    85,   'HOAT_DONG',     'Giữa phòng',   1, @t0 - INTERVAL 20 SECOND),
    ( 3, 3, 'Máy nén A1',   'A4:CF:12:3B:5E:11', 'a1-may-nen',  NULL, 'HOAT_DONG',     'Cạnh cửa',     1, @t0 - INTERVAL 570 MINUTE),
    ( 4, 1, 'Nhiệt độ A2',  'A4:CF:12:3B:5E:02', 'a2-nhiet-do', 64,   'HOAT_DONG',     'Kệ số 3',      2, @t0 - INTERVAL 25 SECOND),
    ( 5, 2, 'Độ ẩm A2',     'A4:CF:12:3B:5E:02', 'a2-do-am',    18,   'HOAT_DONG',     'Kệ số 3',      2, @t0 - INTERVAL 25 SECOND),
    ( 6, 4, 'Quạt A2',      'A4:CF:12:3B:5E:12', 'a2-quat',     NULL, 'HOAT_DONG',     'Trần phòng',   2, @t0 - INTERVAL 150 MINUTE),
    ( 7, 1, 'Nhiệt độ A3',  'A4:CF:12:3B:5E:03', 'a3-nhiet-do', 72,   'MAT_KET_NOI',   'Giữa phòng',   3, @t0 - INTERVAL 120 MINUTE),
    ( 8, 3, 'Máy nén A3',   'A4:CF:12:3B:5E:13', 'a3-may-nen',  NULL, 'MAT_KET_NOI',   'Cạnh cửa',     3, @t0 - INTERVAL 26 HOUR),
    ( 9, 1, 'Nhiệt độ B1',  'A4:CF:12:3B:5E:04', 'b1-nhiet-do', 90,   'HOAT_DONG',     'Giữa phòng',   4, @t0 - INTERVAL 15 SECOND),
    (10, 4, 'Quạt cũ A1',   'A4:CF:12:3B:5E:14', 'a1-quat-cu',  NULL, 'NGUNG_SU_DUNG', 'Đã tháo',      1, @t0 - INTERVAL 30 DAY);

-- Gán rule (V3: 1 cấp đông, 2 mát, 3 độ ẩm, 4 sữa, 5 bật quạt, 6 pin yếu)
INSERT INTO ThietLapRule (ma_thiet_bi, ma_rule) VALUES
    (1, 1), (9, 1),
    (4, 2),
    (2, 3), (5, 3),
    (7, 4),
    (4, 5), (6, 5),          -- rule điều khiển: đọc cảm biến 4, bật quạt 6 cùng phòng
    (5, 6), (7, 6);

-- Gán lịch (V3: 1 xả đá 02:00–02:30, 2 thông gió 22:00–06:00)
INSERT INTO ThietLapLich (ma_thiet_bi, ma_lich_trinh) VALUES
    (3, 1),
    (6, 2);

-- ---------------------------------------------------------------------
-- 4. Bản ghi cảm biến: 48 mốc, mỗi 30 phút trong 24 giờ qua
--    Có các điểm vượt ngưỡng khớp với cảnh báo ở mục 6.
--    Thiết bị 7 không có bản ghi trong 2 giờ gần nhất (mất kết nối).
-- ---------------------------------------------------------------------
INSERT INTO BangGhiDuLieu (ma_thiet_bi, thoi_gian_ghi, gia_tri_thong_so)
WITH RECURSIVE moc (n) AS (
    SELECT 0
    UNION ALL
    SELECT n + 1 FROM moc WHERE n < 47
)
SELECT tb.ma_thiet_bi,
       @t0 - INTERVAL (moc.n * 30) MINUTE,
       ROUND(CASE
           WHEN tb.ma_thiet_bi = 1 AND moc.n = 8 THEN -16.5
           WHEN tb.ma_thiet_bi = 1 THEN -20.5 + 1.2 * SIN(moc.n / 3)
           WHEN tb.ma_thiet_bi = 2 AND moc.n = 2 THEN 97
           WHEN tb.ma_thiet_bi = 2 THEN 90 + 3 * SIN(moc.n / 5)
           WHEN tb.ma_thiet_bi = 4 AND moc.n = 6 THEN 6.8
           WHEN tb.ma_thiet_bi = 4 THEN 3 + 1.2 * SIN(moc.n / 4)
           WHEN tb.ma_thiet_bi = 5 THEN 88 + 2 * COS(moc.n / 6)
           WHEN tb.ma_thiet_bi = 7 THEN 4 + SIN(moc.n / 5)
           WHEN tb.ma_thiet_bi = 9 THEN -21 + COS(moc.n / 4)
       END, 1)
FROM moc
CROSS JOIN (SELECT 1 AS ma_thiet_bi UNION ALL SELECT 2 UNION ALL SELECT 4
            UNION ALL SELECT 5 UNION ALL SELECT 7 UNION ALL SELECT 9) AS tb
WHERE NOT (tb.ma_thiet_bi = 7 AND moc.n < 4);

-- ---------------------------------------------------------------------
-- 5. Nhật kí thao tác (chèn từng dòng theo thứ tự thời gian để trigger
--    NhatKiThaoTac_BI_luu_vet_du_lieu tự điền thong_so_goc)
--    Thao tác: 1 Bật, 2 Tắt, 3 Đặt giá trị. Đúng một tác nhân mỗi dòng.
-- ---------------------------------------------------------------------
-- Máy nén A1: quản lý bật, lịch xả đá tắt rồi bật lại
INSERT INTO NhatKiThaoTac (ma_thiet_bi, ma_nguoi_dung, ma_lich_trinh, ma_rule, thoi_gian_ghi, thong_so_moi, ma_thao_tac, ket_qua_thao_tac)
VALUES (3, 3, NULL, NULL, @t0 - INTERVAL 20 HOUR, '1', 1, 'THANH_CONG');
INSERT INTO NhatKiThaoTac (ma_thiet_bi, ma_nguoi_dung, ma_lich_trinh, ma_rule, thoi_gian_ghi, thong_so_moi, ma_thao_tac, ket_qua_thao_tac)
VALUES (3, NULL, 1, NULL, @t0 - INTERVAL 600 MINUTE, '0', 2, 'THANH_CONG');
INSERT INTO NhatKiThaoTac (ma_thiet_bi, ma_nguoi_dung, ma_lich_trinh, ma_rule, thoi_gian_ghi, thong_so_moi, ma_thao_tac, ket_qua_thao_tac)
VALUES (3, NULL, 1, NULL, @t0 - INTERVAL 570 MINUTE, '1', 1, 'THANH_CONG');

-- Quạt A2: rule bật khi nhiệt độ vượt 6 °C, nhân viên tắt sau khi xử lý
INSERT INTO NhatKiThaoTac (ma_thiet_bi, ma_nguoi_dung, ma_lich_trinh, ma_rule, thoi_gian_ghi, thong_so_moi, ma_thao_tac, ket_qua_thao_tac)
VALUES (6, NULL, NULL, 5, @t0 - INTERVAL 180 MINUTE, '1', 1, 'THANH_CONG');
INSERT INTO NhatKiThaoTac (ma_thiet_bi, ma_nguoi_dung, ma_lich_trinh, ma_rule, thoi_gian_ghi, thong_so_moi, ma_thao_tac, ket_qua_thao_tac)
VALUES (6, 5, NULL, NULL, @t0 - INTERVAL 150 MINUTE, '0', 2, 'THANH_CONG');

-- Máy nén A3: bật hôm qua; lệnh đặt nhiệt độ mục tiêu gần nhất không được phản hồi
INSERT INTO NhatKiThaoTac (ma_thiet_bi, ma_nguoi_dung, ma_lich_trinh, ma_rule, thoi_gian_ghi, thong_so_moi, ma_thao_tac, ket_qua_thao_tac)
VALUES (8, 4, NULL, NULL, @t0 - INTERVAL 26 HOUR, '1', 1, 'THANH_CONG');
INSERT INTO NhatKiThaoTac (ma_thiet_bi, ma_nguoi_dung, ma_lich_trinh, ma_rule, thoi_gian_ghi, thong_so_moi, ma_thao_tac, ket_qua_thao_tac)
VALUES (8, 4, NULL, NULL, @t0 - INTERVAL 121 MINUTE, '4', 3, 'HET_THOI_GIAN');

-- ---------------------------------------------------------------------
-- 6. Nhật kí cảnh báo (loại: 1 vượt trên, 2 dưới ngưỡng, 3 mất kết nối,
--    4 không phản hồi lệnh, 5 pin yếu)
--    Mỗi cặp (thiết bị, rule) chỉ có một cảnh báo chưa xử lý xong.
-- ---------------------------------------------------------------------
INSERT INTO NhatKiCanhBao (ma_nhat_ki_canh_bao, ma_thiet_bi, ma_nguoi_dung, ma_rule, thoi_gian_phat, gia_tri_canh_bao,
                           trang_thai_xu_ly, thoi_gian_xu_ly, ghi_chu_xu_ly, ma_canh_bao) VALUES
    (1, 1, 5,    1,    @t0 - INTERVAL 240 MINUTE, -16.5, 'DA_XU_LY',     @t0 - INTERVAL 230 MINUTE,
        'Cửa phòng A1 bị hở, đã đóng lại; nhiệt độ về -19 °C', 1),
    (2, 4, NULL, 2,    @t0 - INTERVAL 180 MINUTE, 6.8,   'DA_LEO_THANG', NULL, NULL, 1),
    (3, 7, NULL, NULL, @t0 - INTERVAL 110 MINUTE, NULL,  'CHUA_XU_LY',   NULL, NULL, 3),
    (4, 8, NULL, NULL, @t0 - INTERVAL 119 MINUTE, NULL,  'CHUA_XU_LY',   NULL, NULL, 4),
    (5, 2, NULL, 3,    @t0 - INTERVAL 60 MINUTE,  97,    'CHUA_XU_LY',   NULL, NULL, 1),
    (6, 5, NULL, 6,    @t0 - INTERVAL 30 MINUTE,  18,    'CHUA_XU_LY',   NULL, NULL, 5);

-- ---------------------------------------------------------------------
-- 7. Tin nhắn nội bộ (mỗi dòng một người nhận; cảnh báo đính kèm là liên kết)
-- ---------------------------------------------------------------------
INSERT INTO TinNhanNoiBo (ma_nguoi_gui, ma_nguoi_nhan, ma_nhat_ki_canh_bao, ma_thiet_bi_canh_bao,
                          noi_dung_tin_nhan, thoi_gian_gui, thoi_gian_nhan, tinh_trang_xac_nhan) VALUES
    (5, 3, NULL, NULL, 'Cửa phòng A1 đã đóng, nhiệt độ về lại -19 °C.',
        @t0 - INTERVAL 225 MINUTE, @t0 - INTERVAL 220 MINUTE, 1),
    (3, 5, 2, 4, 'Phòng A2 vượt 5 °C, kiểm tra cửa và quạt giúp anh.',
        @t0 - INTERVAL 175 MINUTE, @t0 - INTERVAL 170 MINUTE, 1),
    (3, 6, 2, 4, 'Phòng A2 vượt 5 °C, kiểm tra cửa và quạt giúp anh.',
        @t0 - INTERVAL 175 MINUTE, NULL, 0),
    (1, 3, NULL, NULL, 'Gửi tôi báo cáo nhiệt độ tuần này trước thứ Sáu.',
        @t0 - INTERVAL 60 MINUTE, NULL, 0);

-- ---------------------------------------------------------------------
-- 8. Chấm công (nhân viên có phân công, quản lý đang phụ trách phòng)
--    Mỗi người tối đa một ca đang mở (thoi_gian_giao_ca NULL).
-- ---------------------------------------------------------------------
INSERT INTO NhatKiChamCong (ma_nguoi_dung, thoi_gian_nhan_ca, thoi_gian_giao_ca) VALUES
    (5, @t0 - INTERVAL 30 HOUR, @t0 - INTERVAL 22 HOUR),
    (5, @t0 - INTERVAL 6 HOUR,  NULL),
    (6, @t0 - INTERVAL 30 HOUR, @t0 - INTERVAL 22 HOUR),
    (7, @t0 - INTERVAL 6 HOUR,  NULL),
    (3, @t0 - INTERVAL 8 HOUR,  NULL),
    (9, @t0 - INTERVAL 28 HOUR, @t0 - INTERVAL 20 HOUR);

COMMIT;

-- ---------------------------------------------------------------------
-- Kiểm tra nhanh số dòng đã nạp
-- ---------------------------------------------------------------------
SELECT 'NguoiDung' AS bang, COUNT(*) AS so_dong FROM NguoiDung
UNION ALL SELECT 'NhaKho',          COUNT(*) FROM NhaKho
UNION ALL SELECT 'PhongKho',        COUNT(*) FROM PhongKho
UNION ALL SELECT 'NhanVienLamViec', COUNT(*) FROM NhanVienLamViec
UNION ALL SELECT 'ThietBiIot',      COUNT(*) FROM ThietBiIot
UNION ALL SELECT 'ThietLapRule',    COUNT(*) FROM ThietLapRule
UNION ALL SELECT 'ThietLapLich',    COUNT(*) FROM ThietLapLich
UNION ALL SELECT 'BangGhiDuLieu',   COUNT(*) FROM BangGhiDuLieu
UNION ALL SELECT 'NhatKiThaoTac',   COUNT(*) FROM NhatKiThaoTac
UNION ALL SELECT 'NhatKiCanhBao',   COUNT(*) FROM NhatKiCanhBao
UNION ALL SELECT 'TinNhanNoiBo',    COUNT(*) FROM TinNhanNoiBo
UNION ALL SELECT 'NhatKiChamCong',  COUNT(*) FROM NhatKiChamCong;