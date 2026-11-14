-- =====================================================================
-- PHẦN 1. CHECK
-- =====================================================================

-- Thiết bị: dung lượng pin trong khoảng 0–100 (%)
ALTER TABLE ThietBiIot
    ADD CONSTRAINT ThietBiIot_chk_DungLuongPin
        CHECK (dung_luong_pin IS NULL OR dung_luong_pin BETWEEN 0 AND 100);

-- Lịch trình: kết thúc sau bắt đầu (lịch qua đêm lưu giờ kết thúc ở ngày hôm sau)
ALTER TABLE LichTrinhTuDong
    ADD CONSTRAINT LichTrinhTuDong_chk_ThoiGianKetThuc_ThoiGianBatDau
        CHECK (thoi_gian_ket_thuc > thoi_gian_bat_dau);

-- Rule: có ít nhất một giới hạn; nếu có cả hai thì dưới < trên
ALTER TABLE RuleEngine
    ADD CONSTRAINT RuleEngine_chk_GioiHanTren_GioiHanDuoi
        CHECK (
            (gioi_han_tren IS NOT NULL OR gioi_han_duoi IS NOT NULL)
            AND (gioi_han_tren IS NULL OR gioi_han_duoi IS NULL OR gioi_han_duoi < gioi_han_tren)
        );

-- Nhật kí thao tác: đúng một tác nhân (người dùng / lịch trình / rule)
ALTER TABLE NhatKiThaoTac
    ADD CONSTRAINT NhatKiThaoTac_chk_tac_nhan
        CHECK ((ma_nguoi_dung IS NOT NULL) + (ma_lich_trinh IS NOT NULL) + (ma_rule IS NOT NULL) = 1);

-- Nhật kí cảnh báo: thời gian xử lý không trước thời gian phát
ALTER TABLE NhatKiCanhBao
    ADD CONSTRAINT NhatKiCanhBao_chk_ThoiGianXuLy_ThoiGianPhat
        CHECK (thoi_gian_xu_ly IS NULL OR thoi_gian_xu_ly >= thoi_gian_phat);

-- Nhật kí cảnh báo: đã xử lý thì phải có người xử lý và thời gian xử lý
ALTER TABLE NhatKiCanhBao
    ADD CONSTRAINT NhatKiCanhBao_chk_DaXuLy_NguoiXuLy
        CHECK (
            trang_thai_xu_ly <> 'DA_XU_LY'
            OR (ma_nguoi_dung IS NOT NULL AND thoi_gian_xu_ly IS NOT NULL)
        );

-- Chấm công: giao ca sau nhận ca (NULL: ca đang mở)
ALTER TABLE NhatKiChamCong
    ADD CONSTRAINT NhatKiChamCong_chk_ThoiGianGiaoCa_ThoiGianNhanCa
        CHECK (thoi_gian_giao_ca IS NULL OR thoi_gian_giao_ca > thoi_gian_nhan_ca);

-- Tin nhắn: không tự gửi cho chính mình
ALTER TABLE TinNhanNoiBo
    ADD CONSTRAINT TinNhanNoiBo_chk_NguoiGui_NguoiNhan
        CHECK (ma_nguoi_nhan <> ma_nguoi_gui);

-- Tin nhắn: hai cột cảnh báo đính kèm cùng NULL hoặc cùng có giá trị
ALTER TABLE TinNhanNoiBo
    ADD CONSTRAINT TinNhanNoiBo_chk_DinhKemCanhBao
        CHECK ((ma_nhat_ki_canh_bao IS NULL) = (ma_thiet_bi_canh_bao IS NULL));

-- Tin nhắn: thời gian nhận không trước thời gian gửi
ALTER TABLE TinNhanNoiBo
    ADD CONSTRAINT TinNhanNoiBo_chk_ThoiGianNhan_ThoiGianGui
        CHECK (thoi_gian_nhan IS NULL OR thoi_gian_nhan >= thoi_gian_gui);

-- Tin nhắn: đã xác nhận thì phải có thời gian nhận
ALTER TABLE TinNhanNoiBo
    ADD CONSTRAINT TinNhanNoiBo_chk_XacNhan_ThoiGianNhan
        CHECK (tinh_trang_xac_nhan = 0 OR thoi_gian_nhan IS NOT NULL);


-- =====================================================================
-- PHẦN 2. "CHỈ MỘT BẢN GHI ĐANG MỞ" – CỘT SINH TỰ ĐỘNG + UNIQUE
-- MySQL không có chỉ mục UNIQUE có điều kiện. Cột sinh nhận 1 khi bản ghi
-- đang mở, NULL khi đã đóng; UNIQUE cho phép nhiều NULL nên chỉ chặn
-- hai bản ghi cùng mở.
-- =====================================================================

-- Mỗi người tối đa một ca đang mở
ALTER TABLE NhatKiChamCong
    ADD COLUMN ca_dang_mo TINYINT
        GENERATED ALWAYS AS (CASE WHEN thoi_gian_giao_ca IS NULL THEN 1 END) STORED,
    ADD CONSTRAINT NhatKiChamCong_uq_mot_ca_mo UNIQUE (ma_nguoi_dung, ca_dang_mo);

-- Mỗi cặp (thiết bị, rule) tối đa một cảnh báo chưa xử lý xong
-- (cảnh báo không có rule – mất tín hiệu, không phản hồi – do backend chống trùng)
ALTER TABLE NhatKiCanhBao
    ADD COLUMN canh_bao_mo TINYINT
        GENERATED ALWAYS AS (
            CASE WHEN trang_thai_xu_ly <> 'DA_XU_LY' AND ma_rule IS NOT NULL THEN 1 END
        ) STORED,
    ADD CONSTRAINT NhatKiCanhBao_uq_CanhBaoMo UNIQUE (ma_thiet_bi, ma_rule, canh_bao_mo);


-- =====================================================================
-- PHẦN 3. CHỈ MỤC
-- =====================================================================

-- Biểu đồ, báo cáo theo thiết bị và thời gian
CREATE INDEX BangGhiDuLieu_idx_ThietBi_ThoiGian
    ON BangGhiDuLieu (ma_thiet_bi, thoi_gian_ghi);

-- Tra cứu nhật kí; truy vấn lệnh gần nhất trong trigger lưu vết
CREATE INDEX NhatKiThaoTac_idx_ThietBi_ThoiGian
    ON NhatKiThaoTac (ma_thiet_bi, thoi_gian_ghi);


-- =====================================================================
-- PHẦN 4. TRIGGER
-- =====================================================================

DROP TRIGGER IF EXISTS NhatKiThaoTac_BI_luu_vet_du_lieu;
DROP TRIGGER IF EXISTS NhatKiThaoTac_BU_chan_sua;
DROP TRIGGER IF EXISTS NhatKiThaoTac_BD_chan_xoa;
DROP TRIGGER IF EXISTS NhatKiCanhBao_BU_xu_ly_canh_bao;
DROP TRIGGER IF EXISTS TinNhanNoiBo_BU_xac_nhan;
DROP TRIGGER IF EXISTS NhaKho_BI_kiem_tra_chu_doanh_nghiep;
DROP TRIGGER IF EXISTS NhaKho_BU_kiem_tra_chu_doanh_nghiep;
DROP TRIGGER IF EXISTS PhongKho_BI_kiem_tra_quan_ly;
DROP TRIGGER IF EXISTS PhongKho_BU_kiem_tra_quan_ly;
DROP TRIGGER IF EXISTS NhanVienLamViec_BI_kiem_tra_vai_tro;
DROP TRIGGER IF EXISTS NhanVienLamViec_BU_kiem_tra_vai_tro;
DROP TRIGGER IF EXISTS NhatKiChamCong_BI_kiem_tra_nguoi_cham_cong;
DROP TRIGGER IF EXISTS NhatKiChamCong_BU_kiem_tra_nguoi_cham_cong;
DROP TRIGGER IF EXISTS NguoiDung_BU_kiem_tra_doi_vai_tro;

DELIMITER $$

-- Tự điền thông số gốc = thông số mới của lệnh gần nhất gửi tới cùng thiết bị.
-- Chỉ điền khi backend không truyền giá trị. Lệnh đầu tiên: NULL.
CREATE TRIGGER NhatKiThaoTac_BI_luu_vet_du_lieu
BEFORE INSERT ON NhatKiThaoTac
FOR EACH ROW
BEGIN
    IF NEW.thong_so_goc IS NULL THEN
        SET NEW.thong_so_goc = (
            SELECT nk.thong_so_moi
            FROM NhatKiThaoTac nk
            WHERE nk.ma_thiet_bi = NEW.ma_thiet_bi
            ORDER BY nk.thoi_gian_ghi DESC, nk.ma_nhat_ki_thao_tac DESC
            LIMIT 1
        );
    END IF;
END$$

-- Xử lý cảnh báo:
--   1. Người xử lý đầu tiên được ghi nhận và không bị thay thế
--   2. Trạng thái chỉ đi tới: CHUA_XU_LY → DA_LEO_THANG → DA_XU_LY (hoặc thẳng DA_XU_LY)
--   3. Gán người xử lý → tự chuyển DA_XU_LY và điền thời gian xử lý nếu thiếu
CREATE TRIGGER NhatKiCanhBao_BU_xu_ly_canh_bao
BEFORE UPDATE ON NhatKiCanhBao
FOR EACH ROW
BEGIN
    IF OLD.ma_nguoi_dung IS NOT NULL AND NOT (NEW.ma_nguoi_dung <=> OLD.ma_nguoi_dung) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cảnh báo đã có người xử lý, không thể thay đổi người xử lý';
    END IF;

    IF OLD.trang_thai_xu_ly = 'DA_XU_LY' AND NEW.trang_thai_xu_ly <> 'DA_XU_LY' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cảnh báo đã xử lý không được mở lại';
    END IF;

    IF OLD.trang_thai_xu_ly = 'DA_LEO_THANG' AND NEW.trang_thai_xu_ly = 'CHUA_XU_LY' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không được chuyển cảnh báo về trạng thái chưa xử lý';
    END IF;

    IF OLD.ma_nguoi_dung IS NULL AND NEW.ma_nguoi_dung IS NOT NULL THEN
        SET NEW.trang_thai_xu_ly = 'DA_XU_LY';
        IF NEW.thoi_gian_xu_ly IS NULL THEN
            SET NEW.thoi_gian_xu_ly = NOW(3);
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- A3. Nhật kí thao tác chỉ được thêm, không được sửa hay xóa (dữ liệu truy vết)
-- ---------------------------------------------------------------------
CREATE TRIGGER NhatKiThaoTac_BU_chan_sua
BEFORE UPDATE ON NhatKiThaoTac
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nhật kí thao tác là dữ liệu truy vết, không được sửa';
END$$

CREATE TRIGGER NhatKiThaoTac_BD_chan_xoa
BEFORE DELETE ON NhatKiThaoTac
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nhật kí thao tác là dữ liệu truy vết, không được xóa';
END$$

-- ---------------------------------------------------------------------
-- A4. Xác nhận tin nhắn
--   - Chuyển tinh_trang_xac_nhan sang 1 mà chưa có thời gian nhận → tự điền NOW(3)
--   - Đã xác nhận thì không được hủy xác nhận
-- ---------------------------------------------------------------------
CREATE TRIGGER TinNhanNoiBo_BU_xac_nhan
BEFORE UPDATE ON TinNhanNoiBo
FOR EACH ROW
BEGIN
    IF OLD.tinh_trang_xac_nhan = 1 AND NEW.tinh_trang_xac_nhan = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Tin nhắn đã xác nhận không được hủy xác nhận';
    END IF;

    IF NEW.tinh_trang_xac_nhan = 1 AND NEW.thoi_gian_nhan IS NULL THEN
        SET NEW.thoi_gian_nhan = NOW(3);
    END IF;
END$$

-- ---------------------------------------------------------------------
-- A1. Vai trò khớp với vị trí của người dùng
--   1 = Chủ doanh nghiệp · 2 = Quản lý kho · 3 = Nhân viên vận hành
--   Chủ doanh nghiệp quản lý nhà kho (NhaKho); chỉ Quản lý kho phụ trách phòng kho (PhongKho).
-- ---------------------------------------------------------------------

-- Chủ của nhà kho phải có vai trò Chủ doanh nghiệp
CREATE TRIGGER NhaKho_BI_kiem_tra_chu_doanh_nghiep
BEFORE INSERT ON NhaKho
FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM NguoiDung
                   WHERE ma_nguoi_dung = NEW.ma_chu_doanh_nghiep AND ma_vai_tro = 1) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Chủ nhà kho phải là người dùng có vai trò Chủ doanh nghiệp';
    END IF;
END$$

-- Đổi chủ nhà kho: chủ mới phải có vai trò Chủ doanh nghiệp
CREATE TRIGGER NhaKho_BU_kiem_tra_chu_doanh_nghiep
BEFORE UPDATE ON NhaKho
FOR EACH ROW
BEGIN
    IF NOT (NEW.ma_chu_doanh_nghiep <=> OLD.ma_chu_doanh_nghiep)
       AND NOT EXISTS (SELECT 1 FROM NguoiDung
                       WHERE ma_nguoi_dung = NEW.ma_chu_doanh_nghiep AND ma_vai_tro = 1) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Chủ nhà kho phải là người dùng có vai trò Chủ doanh nghiệp';
    END IF;
END$$

-- Người phụ trách phòng kho phải có vai trò Quản lý kho
CREATE TRIGGER PhongKho_BI_kiem_tra_quan_ly
BEFORE INSERT ON PhongKho
FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM NguoiDung
                   WHERE ma_nguoi_dung = NEW.ma_nguoi_quan_ly AND ma_vai_tro = 2) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Người phụ trách phòng kho phải có vai trò Quản lý kho';
    END IF;
END$$

CREATE TRIGGER PhongKho_BU_kiem_tra_quan_ly
BEFORE UPDATE ON PhongKho
FOR EACH ROW
BEGIN
    IF NOT (NEW.ma_nguoi_quan_ly <=> OLD.ma_nguoi_quan_ly)
       AND NOT EXISTS (SELECT 1 FROM NguoiDung
                       WHERE ma_nguoi_dung = NEW.ma_nguoi_quan_ly AND ma_vai_tro = 2) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Người phụ trách phòng kho phải có vai trò Quản lý kho';
    END IF;
END$$

-- Phân công làm việc chỉ dành cho người dùng vai trò Nhân viên vận hành
CREATE TRIGGER NhanVienLamViec_BI_kiem_tra_vai_tro
BEFORE INSERT ON NhanVienLamViec
FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM NguoiDung
                   WHERE ma_nguoi_dung = NEW.ma_nhan_vien AND ma_vai_tro = 3) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Chỉ người dùng vai trò Nhân viên vận hành mới được phân công vào phòng kho';
    END IF;
END$$

CREATE TRIGGER NhanVienLamViec_BU_kiem_tra_vai_tro
BEFORE UPDATE ON NhanVienLamViec
FOR EACH ROW
BEGIN
    IF NOT (NEW.ma_nhan_vien <=> OLD.ma_nhan_vien)
       AND NOT EXISTS (SELECT 1 FROM NguoiDung
                       WHERE ma_nguoi_dung = NEW.ma_nhan_vien AND ma_vai_tro = 3) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Chỉ người dùng vai trò Nhân viên vận hành mới được phân công vào phòng kho';
    END IF;
END$$

-- Chấm công: chỉ người đang có nơi làm việc theo đúng vai trò
--   - Nhân viên vận hành: có ít nhất một phân công trong NhanVienLamViec
--   - Quản lý kho      : đang phụ trách ít nhất một phòng kho
--   Chủ doanh nghiệp không chấm công (không nằm ở NhanVienLamViec, không phụ trách phòng).
--   Dòng chấm công cũ vẫn giữ khi phân công / phụ trách bị gỡ.
CREATE TRIGGER NhatKiChamCong_BI_kiem_tra_nguoi_cham_cong
BEFORE INSERT ON NhatKiChamCong
FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM NhanVienLamViec
                   WHERE ma_nhan_vien = NEW.ma_nguoi_dung)
       AND NOT EXISTS (SELECT 1 FROM PhongKho
                       WHERE ma_nguoi_quan_ly = NEW.ma_nguoi_dung) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Chỉ nhân viên được phân công hoặc quản lý đang phụ trách phòng mới được chấm công';
    END IF;
END$$

CREATE TRIGGER NhatKiChamCong_BU_kiem_tra_nguoi_cham_cong
BEFORE UPDATE ON NhatKiChamCong
FOR EACH ROW
BEGIN
    IF NOT (NEW.ma_nguoi_dung <=> OLD.ma_nguoi_dung)
       AND NOT EXISTS (SELECT 1 FROM NhanVienLamViec
                       WHERE ma_nhan_vien = NEW.ma_nguoi_dung)
       AND NOT EXISTS (SELECT 1 FROM PhongKho
                       WHERE ma_nguoi_quan_ly = NEW.ma_nguoi_dung) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Chỉ nhân viên được phân công hoặc quản lý đang phụ trách phòng mới được chấm công';
    END IF;
END$$

-- Không đổi vai trò khi người dùng đang gắn với dữ liệu của vai trò cũ
CREATE TRIGGER NguoiDung_BU_kiem_tra_doi_vai_tro
BEFORE UPDATE ON NguoiDung
FOR EACH ROW
BEGIN
    IF NOT (NEW.ma_vai_tro <=> OLD.ma_vai_tro) THEN
        IF OLD.ma_vai_tro = 1
           AND EXISTS (SELECT 1 FROM NhaKho WHERE ma_chu_doanh_nghiep = OLD.ma_nguoi_dung) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Người dùng đang là chủ của nhà kho, không thể đổi vai trò';
        END IF;
        IF OLD.ma_vai_tro = 2
           AND EXISTS (SELECT 1 FROM PhongKho WHERE ma_nguoi_quan_ly = OLD.ma_nguoi_dung) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Người dùng đang phụ trách phòng kho, không thể đổi vai trò';
        END IF;
        IF OLD.ma_vai_tro = 3
           AND EXISTS (SELECT 1 FROM NhanVienLamViec WHERE ma_nhan_vien = OLD.ma_nguoi_dung) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Người dùng đang được phân công làm việc tại phòng kho, không thể đổi vai trò';
        END IF;
    END IF;
END$$

DELIMITER ;
