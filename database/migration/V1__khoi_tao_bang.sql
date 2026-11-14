-- ---------------------------------------------------------------------
-- Người dùng và vai trò
-- ---------------------------------------------------------------------
-- Mã vai trò cố định, seed chèn tường minh (không tự tăng):
--   1 = Chủ doanh nghiệp · 2 = Quản lý kho · 3 = Nhân viên vận hành
CREATE TABLE VaiTro (
    ma_vai_tro              INT             NOT NULL,
    ten_vai_tro             VARCHAR(50),
    thong_tin_mo_ta         VARCHAR(255),
    PRIMARY KEY (ma_vai_tro)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE NguoiDung (
    ma_nguoi_dung           INT             NOT NULL AUTO_INCREMENT,
    ten_nguoi_dung          VARCHAR(100)    NOT NULL,  
    thong_tin_dang_nhap     VARCHAR(50)     NOT NULL,
    mat_khau                VARCHAR(255)    NOT NULL,
    trang_thai_tai_khoan    ENUM('HOAT_DONG', 'BI_KHOA') NOT NULL DEFAULT 'HOAT_DONG',
    ma_vai_tro              INT             NOT NULL,
    PRIMARY KEY (ma_nguoi_dung),
    CONSTRAINT NguoiDung_uq_ThongTinDangNhap UNIQUE (thong_tin_dang_nhap)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ---------------------------------------------------------------------
-- Cấu trúc kho
-- ---------------------------------------------------------------------

CREATE TABLE NhaKho (
    ma_nha_kho              INT             NOT NULL AUTO_INCREMENT,
    ma_chu_doanh_nghiep     INT             NOT NULL,
    ten_nha_kho             VARCHAR(100),
    vi_tri_nha_kho          VARCHAR(255)    NOT NULL,
    PRIMARY KEY (ma_nha_kho)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Người phụ trách: người dùng vai trò Quản lý kho (trigger ở V2).
-- Chủ doanh nghiệp không đứng tên phụ trách; quyền trên mọi phòng đến từ quan hệ quản lý nhà kho.
CREATE TABLE PhongKho (
    ma_phong_kho            INT             NOT NULL AUTO_INCREMENT,
    ma_nguoi_quan_ly        INT             NOT NULL,
    ma_nha_kho              INT             NOT NULL,
    ten_phong_kho           VARCHAR(100),
    vi_tri_phong_kho        VARCHAR(255),
    thong_tin_phong_kho     VARCHAR(255),                   -- gồm loại thực phẩm đang bảo quản
    PRIMARY KEY (ma_phong_kho)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Nhân viên vận hành làm việc tại phòng kho (N:M): mỗi dòng là một phân công
CREATE TABLE NhanVienLamViec (
    ma_nhan_vien            INT             NOT NULL,       -- mã người dùng vai trò Nhân viên vận hành
    ma_phong_kho            INT             NOT NULL,
    PRIMARY KEY (ma_nhan_vien, ma_phong_kho)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Thực thể yếu – chủ: NguoiDung. Người chấm công: Nhân viên vận hành hoặc Quản lý kho (trigger ở V2);
-- Chủ doanh nghiệp không chấm công.
CREATE TABLE NhatKiChamCong (
    ma_nhat_ki_cham_cong    BIGINT          NOT NULL AUTO_INCREMENT,
    ma_nguoi_dung           INT             NOT NULL,
    thoi_gian_nhan_ca       DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    thoi_gian_giao_ca       DATETIME(3),                    -- NULL: ca đang mở
    PRIMARY KEY (ma_nhat_ki_cham_cong, ma_nguoi_dung)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ---------------------------------------------------------------------
-- Thiết bị và dữ liệu cảm biến
-- ---------------------------------------------------------------------

CREATE TABLE PhanLoaiThietBi (
    ma_phan_loai_thiet_bi   INT             NOT NULL AUTO_INCREMENT,
    ten_phan_loai           VARCHAR(100),
    don_vi_do               VARCHAR(20),                    -- NULL: thiết bị điều khiển (relay, quạt…)
    PRIMARY KEY (ma_phan_loai_thiet_bi)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE ThietBiIot (
    ma_thiet_bi             INT             NOT NULL AUTO_INCREMENT,
    ma_phan_loai            INT             NOT NULL,
    ten_thiet_bi            VARCHAR(100),
    dia_chi_mac             VARCHAR(17),                    -- không duy nhất: 1 linh kiện có thể là 2 thiết bị logic
    feed_key                VARCHAR(100)    NOT NULL,       -- tên feed trên Adafruit IO
    dung_luong_pin          TINYINT UNSIGNED,
    trang_thai_hoat_dong    ENUM('HOAT_DONG', 'MAT_KET_NOI', 'NGUNG_SU_DUNG') NOT NULL DEFAULT 'HOAT_DONG',
    vi_tri_trong_phong      VARCHAR(100),
    ma_phong_kho            INT             NOT NULL,
    thoi_gian_hoat_dong_lan_cuoi        DATETIME(3),
    PRIMARY KEY (ma_thiet_bi),
    CONSTRAINT ThietBiIot_uq_FeedKey UNIQUE (feed_key)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Thực thể yếu – chủ: ThietBiIot (chỉ cảm biến mới có bản ghi)
CREATE TABLE BangGhiDuLieu (
    ma_ban_ghi              BIGINT          NOT NULL AUTO_INCREMENT,
    ma_thiet_bi             INT             NOT NULL,
    thoi_gian_ghi           DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    gia_tri_thong_so        DOUBLE          NOT NULL,
    PRIMARY KEY (ma_ban_ghi, ma_thiet_bi)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ---------------------------------------------------------------------
-- Lịch trình và rule
-- ---------------------------------------------------------------------

CREATE TABLE LichTrinhTuDong (
    ma_lich_trinh           INT             NOT NULL AUTO_INCREMENT,
    ten_lich_trinh          VARCHAR(100),
    thong_tin_mo_ta         VARCHAR(255),
    thoi_gian_bat_dau       DATETIME(3)     NOT NULL,
    thoi_gian_ket_thuc      DATETIME(3)     NOT NULL,       -- lịch qua đêm: kết thúc ở ngày hôm sau
    ma_xu_ly                VARCHAR(50)     NOT NULL,       -- khóa handler, ví dụ 'BAT_HANG_NGAY'
    PRIMARY KEY (ma_lich_trinh)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE ThietLapLich (
    ma_thiet_bi             INT             NOT NULL,
    ma_lich_trinh           INT             NOT NULL,
    PRIMARY KEY (ma_thiet_bi, ma_lich_trinh)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE RuleEngine (
    ma_rule                 INT             NOT NULL AUTO_INCREMENT,
    ten_rule                VARCHAR(100),
    thong_tin_mo_ta         VARCHAR(255),
    gioi_han_tren           DOUBLE,                         -- NULL nếu rule chỉ xét giới hạn dưới
    gioi_han_duoi           DOUBLE,                         -- NULL nếu rule chỉ xét giới hạn trên
    ma_xu_ly                VARCHAR(50)     NOT NULL,       -- khóa handler, ví dụ 'VUOT_NGUONG_TREN'
    PRIMARY KEY (ma_rule)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE ThietLapRule (
    ma_thiet_bi             INT             NOT NULL,
    ma_rule                 INT             NOT NULL,
    PRIMARY KEY (ma_thiet_bi, ma_rule)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ---------------------------------------------------------------------
-- Nhật kí thao tác
-- ---------------------------------------------------------------------

CREATE TABLE PhanLoaiThaoTac (
    ma_phan_loai_thao_tac   INT             NOT NULL AUTO_INCREMENT,
    ten_phan_loai_thao_tac  VARCHAR(100),
    thong_tin_mo_ta         VARCHAR(255),
    PRIMARY KEY (ma_phan_loai_thao_tac)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Thực thể yếu – chủ: ThietBiIot
CREATE TABLE NhatKiThaoTac (
    ma_nhat_ki_thao_tac     BIGINT          NOT NULL AUTO_INCREMENT,
    ma_thiet_bi             INT             NOT NULL,
    ma_nguoi_dung           INT,                            -- đúng một trong 3 tác nhân (CHECK ở V2)
    ma_lich_trinh           INT,
    ma_rule                 INT,
    thoi_gian_ghi           DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    thong_so_goc            VARCHAR(50),                    -- NULL ở lệnh đầu tiên của thiết bị (trigger tự điền)
    thong_so_moi            VARCHAR(50)     NOT NULL,
    ma_thao_tac             INT             NOT NULL,
    ket_qua_thao_tac        ENUM('THANH_CONG','THAT_BAI','HET_THOI_GIAN'),
    PRIMARY KEY (ma_nhat_ki_thao_tac, ma_thiet_bi)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ---------------------------------------------------------------------
-- Cảnh báo
-- ---------------------------------------------------------------------

CREATE TABLE PhanLoaiCanhBao (
    ma_phan_loai_canh_bao   INT             NOT NULL AUTO_INCREMENT,
    ten_phan_loai_canh_bao  VARCHAR(100),
    thong_tin_mo_ta         VARCHAR(500),                   -- mẫu nội dung cảnh báo
    PRIMARY KEY (ma_phan_loai_canh_bao)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Thực thể yếu – chủ: ThietBiIot
CREATE TABLE NhatKiCanhBao (
    ma_nhat_ki_canh_bao     BIGINT          NOT NULL AUTO_INCREMENT,
    ma_thiet_bi             INT             NOT NULL,
    ma_nguoi_dung           INT,                            -- người xử lý đầu tiên; không đổi sau khi đã gán
    ma_rule                 INT,                            -- NULL: cảnh báo mất tín hiệu / không phản hồi
    thoi_gian_phat          DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    gia_tri_canh_bao        DOUBLE,                         -- NULL: cảnh báo không có giá trị đo
    trang_thai_xu_ly        ENUM('CHUA_XU_LY', 'DA_LEO_THANG', 'DA_XU_LY') NOT NULL DEFAULT 'CHUA_XU_LY',
    thoi_gian_xu_ly         DATETIME(3),
    ghi_chu_xu_ly           TEXT,
    ma_canh_bao             INT             NOT NULL,       -- loại cảnh báo
    PRIMARY KEY (ma_nhat_ki_canh_bao, ma_thiet_bi)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ---------------------------------------------------------------------
-- Tin nhắn nội bộ (mỗi dòng là một tin gửi cho đúng một người nhận)
-- Cảnh báo đính kèm chỉ là liên kết tới NhatKiCanhBao: khóa ngoại ghép
-- (ma_nhat_ki_canh_bao, ma_thiet_bi_canh_bao), hai cột cùng NULL khi không đính kèm.
-- ---------------------------------------------------------------------

CREATE TABLE TinNhanNoiBo (
    ma_tin_nhan             BIGINT          NOT NULL AUTO_INCREMENT,
    ma_nguoi_gui            INT             NOT NULL,
    ma_nguoi_nhan           INT             NOT NULL,
    ma_nhat_ki_canh_bao     BIGINT,
    ma_thiet_bi_canh_bao    INT,
    noi_dung_tin_nhan       TEXT,
    thoi_gian_gui           DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    thoi_gian_nhan          DATETIME(3),
    tinh_trang_xac_nhan     BOOLEAN         NOT NULL DEFAULT 0,
    PRIMARY KEY (ma_tin_nhan)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;


-- =====================================================================
-- PHẦN 2. KHÓA NGOẠI
-- Tên: <BảngHiệnTại>_<BảngĐượcThamChiếu>
-- Ngoại lệ: TinNhanNoiBo tham chiếu NguoiDung hai lần → hậu tố _Gui / _Nhan
-- =====================================================================

ALTER TABLE NguoiDung
    ADD CONSTRAINT NguoiDung_VaiTro
        FOREIGN KEY (ma_vai_tro) REFERENCES VaiTro (ma_vai_tro);

ALTER TABLE NhaKho
    ADD CONSTRAINT NhaKho_NguoiDung
        FOREIGN KEY (ma_chu_doanh_nghiep) REFERENCES NguoiDung (ma_nguoi_dung);

ALTER TABLE PhongKho
    ADD CONSTRAINT PhongKho_NguoiDung
        FOREIGN KEY (ma_nguoi_quan_ly) REFERENCES NguoiDung (ma_nguoi_dung),
    ADD CONSTRAINT PhongKho_NhaKho
        FOREIGN KEY (ma_nha_kho) REFERENCES NhaKho (ma_nha_kho);

ALTER TABLE NhanVienLamViec
    ADD CONSTRAINT NhanVienLamViec_NguoiDung
        FOREIGN KEY (ma_nhan_vien) REFERENCES NguoiDung (ma_nguoi_dung),
    ADD CONSTRAINT NhanVienLamViec_PhongKho
        FOREIGN KEY (ma_phong_kho) REFERENCES PhongKho (ma_phong_kho);

ALTER TABLE NhatKiChamCong
    ADD CONSTRAINT NhatKiChamCong_NguoiDung
        FOREIGN KEY (ma_nguoi_dung) REFERENCES NguoiDung (ma_nguoi_dung);

ALTER TABLE ThietBiIot
    ADD CONSTRAINT ThietBiIot_PhanLoaiThietBi
        FOREIGN KEY (ma_phan_loai) REFERENCES PhanLoaiThietBi (ma_phan_loai_thiet_bi),
    ADD CONSTRAINT ThietBiIot_PhongKho
        FOREIGN KEY (ma_phong_kho) REFERENCES PhongKho (ma_phong_kho);

ALTER TABLE BangGhiDuLieu
    ADD CONSTRAINT BangGhiDuLieu_ThietBiIot
        FOREIGN KEY (ma_thiet_bi) REFERENCES ThietBiIot (ma_thiet_bi);

ALTER TABLE ThietLapLich
    ADD CONSTRAINT ThietLapLich_ThietBiIot
        FOREIGN KEY (ma_thiet_bi) REFERENCES ThietBiIot (ma_thiet_bi),
    ADD CONSTRAINT ThietLapLich_LichTrinhTuDong
        FOREIGN KEY (ma_lich_trinh) REFERENCES LichTrinhTuDong (ma_lich_trinh);

ALTER TABLE ThietLapRule
    ADD CONSTRAINT ThietLapRule_ThietBiIot
        FOREIGN KEY (ma_thiet_bi) REFERENCES ThietBiIot (ma_thiet_bi),
    ADD CONSTRAINT ThietLapRule_RuleEngine
        FOREIGN KEY (ma_rule) REFERENCES RuleEngine (ma_rule);

ALTER TABLE NhatKiThaoTac
    ADD CONSTRAINT NhatKiThaoTac_ThietBiIot
        FOREIGN KEY (ma_thiet_bi) REFERENCES ThietBiIot (ma_thiet_bi),
    ADD CONSTRAINT NhatKiThaoTac_NguoiDung
        FOREIGN KEY (ma_nguoi_dung) REFERENCES NguoiDung (ma_nguoi_dung),
    ADD CONSTRAINT NhatKiThaoTac_LichTrinhTuDong
        FOREIGN KEY (ma_lich_trinh) REFERENCES LichTrinhTuDong (ma_lich_trinh),
    ADD CONSTRAINT NhatKiThaoTac_RuleEngine
        FOREIGN KEY (ma_rule) REFERENCES RuleEngine (ma_rule),
    ADD CONSTRAINT NhatKiThaoTac_PhanLoaiThaoTac
        FOREIGN KEY (ma_thao_tac) REFERENCES PhanLoaiThaoTac (ma_phan_loai_thao_tac);

ALTER TABLE NhatKiCanhBao
    ADD CONSTRAINT NhatKiCanhBao_ThietBiIot
        FOREIGN KEY (ma_thiet_bi) REFERENCES ThietBiIot (ma_thiet_bi),
    ADD CONSTRAINT NhatKiCanhBao_NguoiDung
        FOREIGN KEY (ma_nguoi_dung) REFERENCES NguoiDung (ma_nguoi_dung),
    ADD CONSTRAINT NhatKiCanhBao_RuleEngine
        FOREIGN KEY (ma_rule) REFERENCES RuleEngine (ma_rule),
    ADD CONSTRAINT NhatKiCanhBao_PhanLoaiCanhBao
        FOREIGN KEY (ma_canh_bao) REFERENCES PhanLoaiCanhBao (ma_phan_loai_canh_bao);

ALTER TABLE TinNhanNoiBo
    ADD CONSTRAINT TinNhanNoiBo_NguoiDung_Gui
        FOREIGN KEY (ma_nguoi_gui) REFERENCES NguoiDung (ma_nguoi_dung),
    ADD CONSTRAINT TinNhanNoiBo_NguoiDung_Nhan
        FOREIGN KEY (ma_nguoi_nhan) REFERENCES NguoiDung (ma_nguoi_dung),
    ADD CONSTRAINT TinNhanNoiBo_NhatKiCanhBao
        FOREIGN KEY (ma_nhat_ki_canh_bao, ma_thiet_bi_canh_bao)
        REFERENCES NhatKiCanhBao (ma_nhat_ki_canh_bao, ma_thiet_bi);
