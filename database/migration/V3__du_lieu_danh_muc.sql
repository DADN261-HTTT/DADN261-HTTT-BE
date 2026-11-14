-- Vai trò (mã cố định, trigger ở V2 dựa vào các mã này)
-- ---------------------------------------------------------------------
INSERT INTO VaiTro (ma_vai_tro, ten_vai_tro, thong_tin_mo_ta) VALUES
    (1, 'Chủ doanh nghiệp',   'Sở hữu nhà kho; toàn quyền cấu hình và vận hành trong nhà kho của mình'),
    (2, 'Quản lý kho',        'Phụ trách phòng kho; theo dõi nhật kí, lập báo cáo, điều khiển và xử lý sự cố'),
    (3, 'Nhân viên vận hành', 'Làm việc tại phòng kho được phân công; theo dõi, điều khiển, xử lý sự cố');

-- ---------------------------------------------------------------------
-- Phân loại thiết bị (don_vi_do NULL = thiết bị điều khiển, không có bản ghi đo)
-- ---------------------------------------------------------------------
INSERT INTO PhanLoaiThietBi (ma_phan_loai_thiet_bi, ten_phan_loai, don_vi_do) VALUES
    (1, 'Cảm biến nhiệt độ',   '°C'),
    (2, 'Cảm biến độ ẩm',      '%'),
    (3, 'Máy nén (relay)',     NULL),
    (4, 'Quạt thông gió',      NULL);

-- ---------------------------------------------------------------------
-- Phân loại thao tác
-- ---------------------------------------------------------------------
INSERT INTO PhanLoaiThaoTac (ma_phan_loai_thao_tac, ten_phan_loai_thao_tac, thong_tin_mo_ta) VALUES
    (1, 'Bật',          'Bật thiết bị (thông số mới = 1)'),
    (2, 'Tắt',          'Tắt thiết bị (thông số mới = 0)'),
    (3, 'Đặt giá trị',  'Đặt giá trị điều khiển, ví dụ nhiệt độ mục tiêu hoặc tốc độ quạt');

-- ---------------------------------------------------------------------
-- Phân loại cảnh báo (thong_tin_mo_ta là mẫu nội dung; {…} do backend thay)
-- ---------------------------------------------------------------------
INSERT INTO PhanLoaiCanhBao (ma_phan_loai_canh_bao, ten_phan_loai_canh_bao, thong_tin_mo_ta) VALUES
    (1, 'Vượt ngưỡng trên',     '{thiet_bi} đo được {gia_tri}{don_vi}, cao hơn ngưỡng trên {gioi_han_tren}{don_vi}'),
    (2, 'Dưới ngưỡng dưới',     '{thiet_bi} đo được {gia_tri}{don_vi}, thấp hơn ngưỡng dưới {gioi_han_duoi}{don_vi}'),
    (3, 'Mất kết nối',          '{thiet_bi} không gửi dữ liệu từ {thoi_gian_hoat_dong_lan_cuoi}'),
    (4, 'Không phản hồi lệnh',  '{thiet_bi} không phản hồi lệnh {thao_tac} trong thời gian chờ'),
    (5, 'Pin yếu',              '{thiet_bi} còn {gia_tri}% pin');

-- ---------------------------------------------------------------------
-- Rule cấu hình sẵn (ma_xu_ly = khóa handler ở backend)
-- ---------------------------------------------------------------------
INSERT INTO RuleEngine (ma_rule, ten_rule, thong_tin_mo_ta, gioi_han_tren, gioi_han_duoi, ma_xu_ly) VALUES
    (1, 'Nhiệt độ phòng cấp đông', 'Cảnh báo khi nhiệt độ ra ngoài khoảng -25 °C đến -18 °C', -18, -25, 'CANH_BAO_NGOAI_KHOANG'),
    (2, 'Nhiệt độ phòng mát',      'Cảnh báo khi nhiệt độ ra ngoài khoảng 0 °C đến 5 °C',      5,   0,  'CANH_BAO_NGOAI_KHOANG'),
    (3, 'Độ ẩm bảo quản',          'Cảnh báo khi độ ẩm ra ngoài khoảng 85 % đến 95 %',         95,  85, 'CANH_BAO_NGOAI_KHOANG'),
    (4, 'Nhiệt độ phòng sữa',      'Cảnh báo khi nhiệt độ ra ngoài khoảng 2 °C đến 6 °C',      6,   2,  'CANH_BAO_NGOAI_KHOANG'),
    (5, 'Bật quạt khi quá nóng',   'Bật quạt thông gió cùng phòng khi nhiệt độ vượt 6 °C',     6,   NULL, 'BAT_KHI_VUOT_NGUONG_TREN'),
    (6, 'Pin yếu',                 'Cảnh báo khi dung lượng pin dưới 20 %',                    NULL, 20, 'CANH_BAO_PIN_YEU');

-- ---------------------------------------------------------------------
-- Lịch trình cấu hình sẵn
-- Lịch lặp hằng ngày: chỉ dùng phần giờ; ngày 2026-01-01 là mốc.
-- Lịch qua đêm lưu giờ kết thúc ở ngày hôm sau (CHECK kết thúc > bắt đầu).
-- ---------------------------------------------------------------------
INSERT INTO LichTrinhTuDong (ma_lich_trinh, ten_lich_trinh, thong_tin_mo_ta, thoi_gian_bat_dau, thoi_gian_ket_thuc, ma_xu_ly) VALUES
    (1, 'Xả đá hằng ngày',      'Tắt máy nén để xả đá từ 02:00 đến 02:30',      '2026-01-01 02:00:00.000', '2026-01-01 02:30:00.000', 'TAT_TRONG_KHOANG_HANG_NGAY'),
    (2, 'Thông gió ban đêm',    'Bật quạt thông gió từ 22:00 đến 06:00 hôm sau', '2026-01-01 22:00:00.000', '2026-01-02 06:00:00.000', 'BAT_TRONG_KHOANG_HANG_NGAY');