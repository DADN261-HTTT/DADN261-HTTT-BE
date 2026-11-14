-- =====================================================================
-- KIỂM THỬ RÀNG BUỘC (CHECK, UNIQUE, KHÓA NGOẠI, TRIGGER) CỦA V1–V3
--
-- Chạy trên CSDL DADN261_test bằng tài khoản dadn_migration
-- (cần quyền tạo thủ tục và bảng tạm). CSDL phải đã migrate tới V3.
--
-- Cách hoạt động:
--   - Hai thủ tục tạm kt_chay / kt_kiem_tra chạy từng câu lệnh, bắt lỗi và
--     ghi kết quả vào bảng tạm kt_ket_qua (ENGINE MEMORY, không bị rollback).
--   - Toàn bộ dữ liệu thử nằm trong MỘT transaction và bị ROLLBACK ở cuối,
--     nên chạy lại bao nhiêu lần cũng được, CSDL không đổi.
--   - Mã lỗi kỳ vọng: 0 = thành công · 3819 = vi phạm CHECK ·
--     1062 = trùng UNIQUE · 1644 = trigger từ chối (SIGNAL) ·
--     1451 = xóa dòng đang được tham chiếu · 1452 = tham chiếu không tồn tại
--   - Mỗi ca gắn mã ràng buộc ngữ nghĩa (RB..) theo tài liệu đặc tả RD.
--
-- Kết quả: 3 bảng ở cuối (tổng hợp, ca KHÔNG ĐẠT, toàn bộ). Cảnh báo 1196
-- "non-transactional tables couldn't be rolled back" là của bảng kết quả, bỏ qua.
-- =====================================================================

USE DADN261_test;
SET NAMES utf8mb4;
SET @kt_safe_updates_cu = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;          -- Workbench bật mặc định; tắt trong phiên kiểm thử

DROP PROCEDURE IF EXISTS kt_chay;
DROP PROCEDURE IF EXISTS kt_kiem_tra;
DROP TEMPORARY TABLE IF EXISTS kt_ket_qua;

CREATE TEMPORARY TABLE kt_ket_qua (
    stt         INT             NOT NULL AUTO_INCREMENT PRIMARY KEY,
    ma_ca       VARCHAR(10),
    rang_buoc   VARCHAR(10),
    mo_ta       VARCHAR(255),
    ky_vong     VARCHAR(30),
    thuc_te     VARCHAR(30),
    ket_qua     VARCHAR(12),
    thong_bao   VARCHAR(500)
) ENGINE = MEMORY;

DELIMITER $$

-- Chạy một câu lệnh, so mã lỗi thực tế với mã lỗi kỳ vọng (0 = thành công)
CREATE PROCEDURE kt_chay(IN p_ma VARCHAR(10), IN p_rb VARCHAR(10), IN p_mo_ta VARCHAR(255),
                         IN p_ma_loi_ky_vong INT, IN p_sql TEXT)
BEGIN
    DECLARE v_ma_loi INT DEFAULT 0;
    DECLARE v_thong_bao TEXT DEFAULT NULL;

    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
            GET DIAGNOSTICS CONDITION 1 v_ma_loi = MYSQL_ERRNO, v_thong_bao = MESSAGE_TEXT;
        SET @kt_sql = p_sql;
        PREPARE kt_lenh FROM @kt_sql;
        EXECUTE kt_lenh;
        DEALLOCATE PREPARE kt_lenh;
    END;

    INSERT INTO kt_ket_qua (ma_ca, rang_buoc, mo_ta, ky_vong, thuc_te, ket_qua, thong_bao)
    VALUES (p_ma, p_rb, p_mo_ta,
            IF(p_ma_loi_ky_vong = 0, 'Thành công', CONCAT('Lỗi ', p_ma_loi_ky_vong)),
            IF(v_ma_loi = 0, 'Thành công', CONCAT('Lỗi ', v_ma_loi)),
            IF(v_ma_loi = p_ma_loi_ky_vong, 'ĐẠT', 'KHÔNG ĐẠT'),
            LEFT(v_thong_bao, 500));
END$$

-- Kiểm tra một biểu thức trả về đúng (1), dùng cho các trigger tự điền dữ liệu
CREATE PROCEDURE kt_kiem_tra(IN p_ma VARCHAR(10), IN p_rb VARCHAR(10), IN p_mo_ta VARCHAR(255),
                             IN p_bieu_thuc TEXT)
BEGIN
    DECLARE v_ma_loi INT DEFAULT 0;
    DECLARE v_thong_bao TEXT DEFAULT NULL;
    SET @kt_gia_tri = NULL;

    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
            GET DIAGNOSTICS CONDITION 1 v_ma_loi = MYSQL_ERRNO, v_thong_bao = MESSAGE_TEXT;
        SET @kt_sql = CONCAT('SELECT (', p_bieu_thuc, ') INTO @kt_gia_tri');
        PREPARE kt_lenh FROM @kt_sql;
        EXECUTE kt_lenh;
        DEALLOCATE PREPARE kt_lenh;
    END;

    INSERT INTO kt_ket_qua (ma_ca, rang_buoc, mo_ta, ky_vong, thuc_te, ket_qua, thong_bao)
    VALUES (p_ma, p_rb, p_mo_ta, 'Đúng',
            IF(v_ma_loi <> 0, CONCAT('Lỗi ', v_ma_loi), IF(@kt_gia_tri = 1, 'Đúng', 'Sai')),
            IF(v_ma_loi = 0 AND @kt_gia_tri = 1, 'ĐẠT', 'KHÔNG ĐẠT'),
            LEFT(v_thong_bao, 500));
END$$

DELIMITER ;

-- =====================================================================
-- DỮ LIỆU THỬ (trong transaction, bị ROLLBACK ở cuối)
-- Danh mục dùng từ V3: phân loại thiết bị 1 (nhiệt độ), 3 (máy nén);
-- thao tác 1 (bật), 2 (tắt); cảnh báo 1 (vượt trên), 3 (mất kết nối); rule 1, 5.
-- =====================================================================
START TRANSACTION;
SET @t0 = NOW(3);

INSERT INTO NguoiDung (ten_nguoi_dung, thong_tin_dang_nhap, mat_khau, ma_vai_tro) VALUES ('KT Chủ 1', 'kt.chu1', 'x', 1);
SET @chu1 = LAST_INSERT_ID();
INSERT INTO NguoiDung (ten_nguoi_dung, thong_tin_dang_nhap, mat_khau, ma_vai_tro) VALUES ('KT Chủ 2', 'kt.chu2', 'x', 1);
SET @chu2 = LAST_INSERT_ID();
INSERT INTO NguoiDung (ten_nguoi_dung, thong_tin_dang_nhap, mat_khau, ma_vai_tro) VALUES ('KT Quản lý 1', 'kt.ql1', 'x', 2);
SET @ql1 = LAST_INSERT_ID();
INSERT INTO NguoiDung (ten_nguoi_dung, thong_tin_dang_nhap, mat_khau, ma_vai_tro) VALUES ('KT Quản lý 2', 'kt.ql2', 'x', 2);
SET @ql2 = LAST_INSERT_ID();
INSERT INTO NguoiDung (ten_nguoi_dung, thong_tin_dang_nhap, mat_khau, ma_vai_tro) VALUES ('KT Nhân viên 1', 'kt.nv1', 'x', 3);
SET @nv1 = LAST_INSERT_ID();
INSERT INTO NguoiDung (ten_nguoi_dung, thong_tin_dang_nhap, mat_khau, ma_vai_tro) VALUES ('KT Nhân viên 2', 'kt.nv2', 'x', 3);
SET @nv2 = LAST_INSERT_ID();
INSERT INTO NguoiDung (ten_nguoi_dung, thong_tin_dang_nhap, mat_khau, ma_vai_tro) VALUES ('KT Nhân viên chưa phân công', 'kt.nv.rong', 'x', 3);
SET @nv_rong = LAST_INSERT_ID();

INSERT INTO NhaKho (ma_chu_doanh_nghiep, ten_nha_kho, vi_tri_nha_kho) VALUES (@chu1, 'KT Kho 1', 'KT');
SET @kho1 = LAST_INSERT_ID();
INSERT INTO NhaKho (ma_chu_doanh_nghiep, ten_nha_kho, vi_tri_nha_kho) VALUES (@chu2, 'KT Kho 2', 'KT');
SET @kho2 = LAST_INSERT_ID();

INSERT INTO PhongKho (ma_nguoi_quan_ly, ma_nha_kho, ten_phong_kho) VALUES (@ql1, @kho1, 'KT Phòng 1');
SET @phong1 = LAST_INSERT_ID();
INSERT INTO PhongKho (ma_nguoi_quan_ly, ma_nha_kho, ten_phong_kho) VALUES (@ql1, @kho1, 'KT Phòng 2');
SET @phong2 = LAST_INSERT_ID();

INSERT INTO NhanVienLamViec (ma_nhan_vien, ma_phong_kho) VALUES (@nv1, @phong1);

INSERT INTO ThietBiIot (ma_phan_loai, ten_thiet_bi, feed_key, ma_phong_kho) VALUES (1, 'KT cảm biến', 'kt-cam-bien', @phong1);
SET @tb_cb = LAST_INSERT_ID();
INSERT INTO ThietBiIot (ma_phan_loai, ten_thiet_bi, feed_key, ma_phong_kho) VALUES (3, 'KT máy nén', 'kt-may-nen', @phong1);
SET @tb_mn = LAST_INSERT_ID();

INSERT INTO NhatKiChamCong (ma_nguoi_dung, thoi_gian_nhan_ca) VALUES (@nv1, @t0 - INTERVAL 1 HOUR);
SET @cc1 = LAST_INSERT_ID();

INSERT INTO NhatKiCanhBao (ma_thiet_bi, ma_rule, thoi_gian_phat, gia_tri_canh_bao, ma_canh_bao) VALUES (@tb_cb, 1, @t0, -15, 1);
SET @cb1 = LAST_INSERT_ID();
INSERT INTO NhatKiCanhBao (ma_thiet_bi, ma_rule, thoi_gian_phat, trang_thai_xu_ly, ma_canh_bao) VALUES (@tb_cb, NULL, @t0, 'DA_LEO_THANG', 3);
SET @cb2 = LAST_INSERT_ID();

INSERT INTO TinNhanNoiBo (ma_nguoi_gui, ma_nguoi_nhan, noi_dung_tin_nhan, thoi_gian_gui) VALUES (@ql1, @nv1, 'KT tin nhắn', @t0);
SET @tn1 = LAST_INSERT_ID();

-- =====================================================================
-- 1. CHECK
-- =====================================================================
CALL kt_chay('T01', 'RB13', 'Pin 101 % bị từ chối', 3819,
    "INSERT INTO ThietBiIot (ma_phan_loai, feed_key, dung_luong_pin, ma_phong_kho) VALUES (1, 'kt-pin-101', 101, @phong1)");
CALL kt_chay('T02', 'RB13', 'Pin 100 % hợp lệ', 0,
    "INSERT INTO ThietBiIot (ma_phan_loai, feed_key, dung_luong_pin, ma_phong_kho) VALUES (1, 'kt-pin-100', 100, @phong1)");
CALL kt_chay('T03', 'RB16', 'Lịch kết thúc trước khi bắt đầu', 3819,
    "INSERT INTO LichTrinhTuDong (thoi_gian_bat_dau, thoi_gian_ket_thuc, ma_xu_ly) VALUES ('2026-01-01 10:00:00', '2026-01-01 09:00:00', 'KT')");
CALL kt_chay('T04', 'RB16', 'Lịch qua đêm (kết thúc ngày hôm sau) hợp lệ', 0,
    "INSERT INTO LichTrinhTuDong (thoi_gian_bat_dau, thoi_gian_ket_thuc, ma_xu_ly) VALUES ('2026-01-01 22:00:00', '2026-01-02 06:00:00', 'KT')");
CALL kt_chay('T05', 'RB17', 'Rule không có giới hạn nào', 3819,
    "INSERT INTO RuleEngine (ma_xu_ly) VALUES ('KT')");
CALL kt_chay('T06', 'RB17', 'Rule có giới hạn dưới bằng giới hạn trên', 3819,
    "INSERT INTO RuleEngine (gioi_han_tren, gioi_han_duoi, ma_xu_ly) VALUES (5, 5, 'KT')");
CALL kt_chay('T07', 'RB17', 'Rule chỉ có giới hạn trên hợp lệ', 0,
    "INSERT INTO RuleEngine (gioi_han_tren, ma_xu_ly) VALUES (8, 'KT')");
CALL kt_chay('T08', 'RB18', 'Nhật kí thao tác không có tác nhân', 3819,
    "INSERT INTO NhatKiThaoTac (ma_thiet_bi, thong_so_moi, ma_thao_tac, ket_qua_thao_tac) VALUES (@tb_mn, '1', 1, 'THANH_CONG')");
CALL kt_chay('T09', 'RB18', 'Nhật kí thao tác có hai tác nhân', 3819,
    "INSERT INTO NhatKiThaoTac (ma_thiet_bi, ma_nguoi_dung, ma_rule, thong_so_moi, ma_thao_tac, ket_qua_thao_tac) VALUES (@tb_mn, @nv1, 5, '1', 1, 'THANH_CONG')");
CALL kt_chay('T10', 'RB23', 'Cảnh báo có thời gian xử lý trước thời gian phát', 3819,
    "INSERT INTO NhatKiCanhBao (ma_thiet_bi, thoi_gian_phat, thoi_gian_xu_ly, ma_canh_bao) VALUES (@tb_cb, @t0, @t0 - INTERVAL 1 HOUR, 3)");
CALL kt_chay('T11', 'RB24', 'Cảnh báo DA_XU_LY thiếu người xử lý', 3819,
    "INSERT INTO NhatKiCanhBao (ma_thiet_bi, thoi_gian_phat, trang_thai_xu_ly, thoi_gian_xu_ly, ma_canh_bao) VALUES (@tb_cb, @t0, 'DA_XU_LY', @t0, 3)");
CALL kt_chay('T12', 'RB11', 'Giao ca trước thời gian nhận ca', 3819,
    "UPDATE NhatKiChamCong SET thoi_gian_giao_ca = thoi_gian_nhan_ca - INTERVAL 1 MINUTE WHERE ma_nhat_ki_cham_cong = @cc1");
CALL kt_chay('T13', 'RB26', 'Tự gửi tin nhắn cho chính mình', 3819,
    "INSERT INTO TinNhanNoiBo (ma_nguoi_gui, ma_nguoi_nhan, noi_dung_tin_nhan) VALUES (@nv1, @nv1, 'KT')");
CALL kt_chay('T14', 'RB27', 'Đính kèm cảnh báo chỉ có một trong hai cột', 3819,
    "INSERT INTO TinNhanNoiBo (ma_nguoi_gui, ma_nguoi_nhan, ma_nhat_ki_canh_bao, noi_dung_tin_nhan) VALUES (@ql1, @nv1, @cb1, 'KT')");
CALL kt_chay('T15', 'RB28', 'Thời gian nhận trước thời gian gửi', 3819,
    "INSERT INTO TinNhanNoiBo (ma_nguoi_gui, ma_nguoi_nhan, thoi_gian_gui, thoi_gian_nhan) VALUES (@ql1, @nv1, @t0, @t0 - INTERVAL 1 MINUTE)");
CALL kt_chay('T16', 'RB28', 'Thêm tin đã xác nhận nhưng thiếu thời gian nhận', 3819,
    "INSERT INTO TinNhanNoiBo (ma_nguoi_gui, ma_nguoi_nhan, tinh_trang_xac_nhan) VALUES (@ql1, @nv1, 1)");

-- =====================================================================
-- 2. UNIQUE (kể cả UNIQUE trên cột sinh)
-- =====================================================================
CALL kt_chay('T17', 'RB01', 'Trùng tên đăng nhập', 1062,
    "INSERT INTO NguoiDung (ten_nguoi_dung, thong_tin_dang_nhap, mat_khau, ma_vai_tro) VALUES ('KT trùng', 'kt.chu1', 'x', 3)");
CALL kt_chay('T18', 'RB12', 'Trùng feed key', 1062,
    "INSERT INTO ThietBiIot (ma_phan_loai, feed_key, ma_phong_kho) VALUES (1, 'kt-cam-bien', @phong1)");
CALL kt_chay('T19', 'RB10', 'Mở ca thứ hai khi đang có ca mở', 1062,
    "INSERT INTO NhatKiChamCong (ma_nguoi_dung) VALUES (@nv1)");
CALL kt_chay('T20', 'RB21', 'Cảnh báo mở thứ hai cùng thiết bị và rule', 1062,
    "INSERT INTO NhatKiCanhBao (ma_thiet_bi, ma_rule, ma_canh_bao) VALUES (@tb_cb, 1, 1)");
CALL kt_chay('T21', 'RB22', 'Cảnh báo không có rule: DB cho phép, backend chống trùng', 0,
    "INSERT INTO NhatKiCanhBao (ma_thiet_bi, ma_canh_bao) VALUES (@tb_cb, 3)");
CALL kt_chay('T22', 'RB10', 'Giao ca hợp lệ', 0,
    "UPDATE NhatKiChamCong SET thoi_gian_giao_ca = @t0 WHERE ma_nhat_ki_cham_cong = @cc1");
CALL kt_chay('T23', 'RB10', 'Mở ca mới sau khi đã giao ca', 0,
    "INSERT INTO NhatKiChamCong (ma_nguoi_dung) VALUES (@nv1)");

-- =====================================================================
-- 3. Nhật kí thao tác: tự điền thông số gốc, chặn sửa và xóa
-- =====================================================================
CALL kt_chay('T24', 'RB19', 'Lệnh đầu tiên của thiết bị', 0,
    "INSERT INTO NhatKiThaoTac (ma_thiet_bi, ma_nguoi_dung, thoi_gian_ghi, thong_so_moi, ma_thao_tac, ket_qua_thao_tac) VALUES (@tb_mn, @nv1, @t0, '1', 1, 'THANH_CONG')");
CALL kt_kiem_tra('T25', 'RB19', 'Lệnh đầu tiên có thông số gốc NULL',
    "(SELECT thong_so_goc FROM NhatKiThaoTac WHERE ma_thiet_bi = @tb_mn ORDER BY ma_nhat_ki_thao_tac LIMIT 1) IS NULL");
CALL kt_chay('T26', 'RB19', 'Lệnh thứ hai của thiết bị', 0,
    "INSERT INTO NhatKiThaoTac (ma_thiet_bi, ma_nguoi_dung, thoi_gian_ghi, thong_so_moi, ma_thao_tac, ket_qua_thao_tac) VALUES (@tb_mn, @nv1, @t0 + INTERVAL 1 SECOND, '0', 2, 'THANH_CONG')");
CALL kt_kiem_tra('T27', 'RB19', 'Lệnh thứ hai tự điền thông số gốc = 1',
    "(SELECT thong_so_goc FROM NhatKiThaoTac WHERE ma_thiet_bi = @tb_mn ORDER BY ma_nhat_ki_thao_tac DESC LIMIT 1) = '1'");
CALL kt_chay('T28', 'RB20', 'Sửa nhật kí thao tác bị chặn', 1644,
    "UPDATE NhatKiThaoTac SET ket_qua_thao_tac = 'THAT_BAI' WHERE ma_thiet_bi = @tb_mn");
CALL kt_chay('T29', 'RB20', 'Xóa nhật kí thao tác bị chặn', 1644,
    "DELETE FROM NhatKiThaoTac WHERE ma_thiet_bi = @tb_mn");

-- =====================================================================
-- 4. Xử lý cảnh báo
-- =====================================================================
CALL kt_chay('T30', 'RB25', 'Người đầu tiên nhận xử lý (UPDATE có điều kiện như backend)', 0,
    "UPDATE NhatKiCanhBao SET ma_nguoi_dung = @nv1, ghi_chu_xu_ly = 'KT' WHERE ma_nhat_ki_canh_bao = @cb1 AND ma_nguoi_dung IS NULL");
CALL kt_kiem_tra('T31', 'RB25', 'Trigger tự chuyển DA_XU_LY và điền thời gian xử lý',
    "(SELECT trang_thai_xu_ly = 'DA_XU_LY' AND thoi_gian_xu_ly IS NOT NULL FROM NhatKiCanhBao WHERE ma_nhat_ki_canh_bao = @cb1)");
CALL kt_chay('T32', 'RB25', 'Người thứ hai nhận xử lý: không lỗi, không đổi dòng nào', 0,
    "UPDATE NhatKiCanhBao SET ma_nguoi_dung = @ql1 WHERE ma_nhat_ki_canh_bao = @cb1 AND ma_nguoi_dung IS NULL");
CALL kt_kiem_tra('T33', 'RB25', 'Người xử lý vẫn là người đầu tiên',
    "(SELECT ma_nguoi_dung FROM NhatKiCanhBao WHERE ma_nhat_ki_canh_bao = @cb1) = @nv1");
CALL kt_chay('T34', 'RB25', 'Đổi người xử lý trực tiếp bị chặn', 1644,
    "UPDATE NhatKiCanhBao SET ma_nguoi_dung = @ql1 WHERE ma_nhat_ki_canh_bao = @cb1");
CALL kt_chay('T35', 'RB25', 'Mở lại cảnh báo đã xử lý bị chặn', 1644,
    "UPDATE NhatKiCanhBao SET trang_thai_xu_ly = 'CHUA_XU_LY' WHERE ma_nhat_ki_canh_bao = @cb1");
CALL kt_chay('T36', 'RB25', 'DA_LEO_THANG quay về CHUA_XU_LY bị chặn', 1644,
    "UPDATE NhatKiCanhBao SET trang_thai_xu_ly = 'CHUA_XU_LY' WHERE ma_nhat_ki_canh_bao = @cb2");
CALL kt_chay('T37', 'RB21', 'Cảnh báo mới cùng thiết bị và rule sau khi cảnh báo cũ đã xử lý', 0,
    "INSERT INTO NhatKiCanhBao (ma_thiet_bi, ma_rule, ma_canh_bao) VALUES (@tb_cb, 1, 1)");

-- =====================================================================
-- 5. Tin nhắn
-- =====================================================================
CALL kt_chay('T38', 'RB28', 'Xác nhận tin nhắn', 0,
    "UPDATE TinNhanNoiBo SET tinh_trang_xac_nhan = 1 WHERE ma_tin_nhan = @tn1");
CALL kt_kiem_tra('T39', 'RB28', 'Trigger tự điền thời gian nhận khi xác nhận',
    "(SELECT thoi_gian_nhan IS NOT NULL FROM TinNhanNoiBo WHERE ma_tin_nhan = @tn1)");
CALL kt_chay('T40', 'RB28', 'Hủy xác nhận bị chặn', 1644,
    "UPDATE TinNhanNoiBo SET tinh_trang_xac_nhan = 0 WHERE ma_tin_nhan = @tn1");
CALL kt_chay('T41', 'RB27', 'Đính kèm cảnh báo hợp lệ', 0,
    "INSERT INTO TinNhanNoiBo (ma_nguoi_gui, ma_nguoi_nhan, ma_nhat_ki_canh_bao, ma_thiet_bi_canh_bao, noi_dung_tin_nhan) VALUES (@ql1, @nv1, @cb1, @tb_cb, 'KT')");
CALL kt_chay('T42', 'RB27', 'Đính kèm cảnh báo với sai thiết bị', 1452,
    "INSERT INTO TinNhanNoiBo (ma_nguoi_gui, ma_nguoi_nhan, ma_nhat_ki_canh_bao, ma_thiet_bi_canh_bao, noi_dung_tin_nhan) VALUES (@ql1, @nv1, @cb1, @tb_mn, 'KT')");

-- =====================================================================
-- 6. Vai trò (kiểm tra ở mức DB)
-- =====================================================================
CALL kt_chay('T43', 'RB03', 'Nhà kho có chủ là Quản lý kho', 1644,
    "INSERT INTO NhaKho (ma_chu_doanh_nghiep, vi_tri_nha_kho) VALUES (@ql1, 'KT')");
CALL kt_chay('T44', 'RB03', 'Đổi chủ nhà kho sang Nhân viên', 1644,
    "UPDATE NhaKho SET ma_chu_doanh_nghiep = @nv1 WHERE ma_nha_kho = @kho1");
CALL kt_chay('T45', 'RB03', 'Đổi chủ nhà kho sang Chủ doanh nghiệp khác', 0,
    "UPDATE NhaKho SET ma_chu_doanh_nghiep = @chu1 WHERE ma_nha_kho = @kho2");
CALL kt_chay('T46', 'RB04', 'Phòng kho có người phụ trách là Nhân viên', 1644,
    "INSERT INTO PhongKho (ma_nguoi_quan_ly, ma_nha_kho) VALUES (@nv1, @kho1)");
CALL kt_chay('T47', 'RB04', 'Chủ doanh nghiệp không đứng tên phụ trách phòng', 1644,
    "INSERT INTO PhongKho (ma_nguoi_quan_ly, ma_nha_kho) VALUES (@chu1, @kho1)");
CALL kt_chay('T48', 'RB04', 'Đổi người phụ trách sang Quản lý kho khác', 0,
    "UPDATE PhongKho SET ma_nguoi_quan_ly = @ql2 WHERE ma_phong_kho = @phong2");
CALL kt_chay('T49', 'RB04', 'Đổi người phụ trách sang Nhân viên', 1644,
    "UPDATE PhongKho SET ma_nguoi_quan_ly = @nv1 WHERE ma_phong_kho = @phong2");
CALL kt_chay('T50', 'RB06', 'Phân công Quản lý kho vào phòng như nhân viên', 1644,
    "INSERT INTO NhanVienLamViec (ma_nhan_vien, ma_phong_kho) VALUES (@ql1, @phong1)");
CALL kt_chay('T51', 'RB06', 'Phân công Nhân viên vào phòng', 0,
    "INSERT INTO NhanVienLamViec (ma_nhan_vien, ma_phong_kho) VALUES (@nv2, @phong2)");
CALL kt_chay('T52', 'RB09', 'Chủ doanh nghiệp chấm công', 1644,
    "INSERT INTO NhatKiChamCong (ma_nguoi_dung) VALUES (@chu1)");
CALL kt_chay('T53', 'RB09', 'Nhân viên chưa được phân công chấm công', 1644,
    "INSERT INTO NhatKiChamCong (ma_nguoi_dung) VALUES (@nv_rong)");
CALL kt_chay('T54', 'RB09', 'Quản lý đang phụ trách phòng chấm công', 0,
    "INSERT INTO NhatKiChamCong (ma_nguoi_dung) VALUES (@ql1)");
CALL kt_chay('T55', 'RB09', 'Nhân viên vừa được phân công chấm công', 0,
    "INSERT INTO NhatKiChamCong (ma_nguoi_dung) VALUES (@nv2)");
CALL kt_chay('T56', 'RB08', 'Đổi vai trò của người đang sở hữu nhà kho', 1644,
    "UPDATE NguoiDung SET ma_vai_tro = 2 WHERE ma_nguoi_dung = @chu1");
CALL kt_chay('T57', 'RB08', 'Đổi vai trò của quản lý đang phụ trách phòng', 1644,
    "UPDATE NguoiDung SET ma_vai_tro = 3 WHERE ma_nguoi_dung = @ql1");
CALL kt_chay('T58', 'RB08', 'Đổi vai trò của nhân viên đang có phân công', 1644,
    "UPDATE NguoiDung SET ma_vai_tro = 2 WHERE ma_nguoi_dung = @nv1");
CALL kt_chay('T59', 'RB08', 'Đổi vai trò của người chưa gắn dữ liệu nào', 0,
    "UPDATE NguoiDung SET ma_vai_tro = 2 WHERE ma_nguoi_dung = @nv_rong");

-- =====================================================================
-- 7. Khóa ngoại RESTRICT
-- =====================================================================
CALL kt_chay('T60', 'RB14', 'Xóa thiết bị đã có nhật kí', 1451,
    "DELETE FROM ThietBiIot WHERE ma_thiet_bi = @tb_mn");
CALL kt_chay('T61', 'RB05', 'Phòng kho thuộc nhà kho không tồn tại', 1452,
    "INSERT INTO PhongKho (ma_nguoi_quan_ly, ma_nha_kho) VALUES (@ql1, 999999999)");
CALL kt_chay('T62', 'FK', 'Thiết bị thuộc phòng kho không tồn tại', 1452,
    "INSERT INTO ThietBiIot (ma_phan_loai, feed_key, ma_phong_kho) VALUES (1, 'kt-khong-phong', 999999999)");

-- =====================================================================
-- HOÀN TÁC DỮ LIỆU THỬ, DỌN DẸP VÀ XEM KẾT QUẢ
-- =====================================================================
ROLLBACK;

DROP PROCEDURE IF EXISTS kt_chay;
DROP PROCEDURE IF EXISTS kt_kiem_tra;
SET SQL_SAFE_UPDATES = @kt_safe_updates_cu;

-- Tổng hợp
SELECT ket_qua, COUNT(*) AS so_ca FROM kt_ket_qua GROUP BY ket_qua;

-- Các ca KHÔNG ĐẠT (rỗng nghĩa là mọi ràng buộc hoạt động đúng)
SELECT ma_ca, rang_buoc, mo_ta, ky_vong, thuc_te, thong_bao
FROM kt_ket_qua WHERE ket_qua <> 'ĐẠT' ORDER BY stt;

-- Toàn bộ
SELECT ma_ca, rang_buoc, mo_ta, ky_vong, thuc_te, ket_qua, thong_bao
FROM kt_ket_qua ORDER BY stt;