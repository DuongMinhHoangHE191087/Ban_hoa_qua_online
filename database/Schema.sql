-- ==========================================================================
-- Schema.sql — Tham khảo cấu trúc bảng của OnlineFruitShopping
-- 
-- Mục đích: Đây là tài liệu tham khảo schema chức năng (conceptual DDL).
-- ⓘ  Để khởi tạo và seed dữ liệu, hãy dùng: Setup_OnlineFruitShopping.sql
-- ⓘ  Setup_OnlineFruitShopping.sql là nguồn thực thi duy nhất (idempotent).
-- ==========================================================================
-- USE [master];
-- GO
-- CREATE DATABASE OnlineFruitShopping;
-- GO
-- USE OnlineFruitShopping;
-- GO

-- 1. users [cite: 36]
CREATE TABLE users (
    user_id INT IDENTITY(1,1) PRIMARY KEY,
    full_name NVARCHAR(100) NOT NULL,
    email NVARCHAR(255) NOT NULL UNIQUE,
    password_hash NVARCHAR(255) NULL,
    phone NVARCHAR(15) NULL,
    role NVARCHAR(20) NOT NULL DEFAULT 'CUSTOMER' CHECK (role IN ('CUSTOMER','SHOP_OWNER','DELIVERY','ADMIN')),
    status NVARCHAR(20) NOT NULL DEFAULT 'INACTIVE' CHECK (status IN ('ACTIVE','INACTIVE','LOCKED','SUSPENDED')),
    user_address NVARCHAR(500) NULL,
    avatar_url NVARCHAR(500) NULL,
 
    is_email_verified BIT NOT NULL DEFAULT 0,
    email_verification_code_hash NVARCHAR(255) NULL,
    email_verification_expires_at DATETIME NULL,
    email_verification_resend_at DATETIME NULL,
    email_verification_sent_at DATETIME NULL,
    failed_login_count INT NOT NULL DEFAULT 0,
    locked_until DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT GETDATE(), -- [cite: 29]
    updated_at DATETIME NOT NULL DEFAULT GETDATE()  -- [cite: 29]
);

-- Index for users phone (allow multiple NULL values)
-- [BUGFIX] SET QUOTED_IDENTIFIER ON is required to create a filtered index
GO
SET QUOTED_IDENTIFIER ON;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_users_phone' AND object_id = OBJECT_ID(N'dbo.users'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_users_phone 
        ON dbo.users(phone) 
        WHERE phone IS NOT NULL;
END
GO


-- 2. user_sessions [cite: 40]
CREATE TABLE user_sessions (
    session_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL FOREIGN KEY REFERENCES users(user_id) ON DELETE CASCADE,
    token NVARCHAR(100) NOT NULL UNIQUE,
    expires_at DATETIME NOT NULL
);

-- 3. user_addresses
CREATE TABLE user_addresses (
    address_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL FOREIGN KEY REFERENCES users(user_id) ON DELETE CASCADE,
    recipient_name NVARCHAR(100) NOT NULL,
    recipient_phone NVARCHAR(15) NOT NULL,
    address_detail NVARCHAR(500) NOT NULL,
    is_default BIT NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT GETDATE()
);



-- 4. shop_owner_profiles [cite: 47]
CREATE TABLE shop_owner_profiles (
    profile_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL UNIQUE FOREIGN KEY REFERENCES users(user_id),
    shop_name NVARCHAR(150) NOT NULL,
    shop_description NVARCHAR(MAX) NULL,
    approval_status NVARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (approval_status IN ('PENDING','APPROVED','REJECTED','SUSPENDED')),
    rejection_reason NVARCHAR(500) NULL,
    approved_at DATETIME NULL,
    delivery_address NVARCHAR(500) NULL,
    rating DECIMAL(3,2) NOT NULL DEFAULT 0,
    preferred_categories NVARCHAR(500) NULL,
    doc_paths NVARCHAR(MAX) NULL,
    business_email NVARCHAR(255) NULL,
    logo_url NVARCHAR(500) NULL,
    cover_url NVARCHAR(500) NULL,
    expiry_warning_days INT NOT NULL DEFAULT 3,
    low_stock_threshold INT NOT NULL DEFAULT 5,
    created_at DATETIME NOT NULL DEFAULT GETDATE(), -- [cite: 29]
    updated_at DATETIME NOT NULL DEFAULT GETDATE()  -- [cite: 29]
);

-- Index for shop_owner_profiles business_email
-- [BUGFIX] SET QUOTED_IDENTIFIER ON is required to create a filtered index
GO
SET QUOTED_IDENTIFIER ON;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_shop_owner_profiles_business_email' AND object_id = OBJECT_ID(N'dbo.shop_owner_profiles'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_shop_owner_profiles_business_email 
        ON dbo.shop_owner_profiles(business_email) 
        WHERE business_email IS NOT NULL;
END
GO


-- 5. categories [cite: 50]
CREATE TABLE categories (
    category_id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL UNIQUE,
    slug NVARCHAR(100) NOT NULL UNIQUE,
    display_order INT NOT NULL DEFAULT 0,
    is_active BIT NOT NULL DEFAULT 1

);

-- 6. products
CREATE TABLE products (
    product_id            INT IDENTITY(1,1) PRIMARY KEY,
    owner_id              INT NOT NULL FOREIGN KEY REFERENCES users(user_id),
    category_id           INT NOT NULL FOREIGN KEY REFERENCES categories(category_id),
    name                  NVARCHAR(200) NOT NULL,
    description           NVARCHAR(MAX) NULL,
    origin_country        NVARCHAR(100) NULL,
    origin_region         NVARCHAR(150) NULL,
    harvest_date          DATE NULL,
    shelf_life_days       INT NULL,
    storage_instruction   NVARCHAR(300) NULL,
    status                NVARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
                          CHECK (status IN ('ACTIVE','INACTIVE','DELETED','OUT_OF_SEASON')),
    view_count            INT NOT NULL DEFAULT 0,
    rating                DECIMAL(3,2) NOT NULL DEFAULT 0,
    sold_quantity         INT NOT NULL DEFAULT 0,
    -- NHÃN VÀ MÙA VỤ
    is_organic            BIT NOT NULL DEFAULT 0,       -- Nhãn Hữu cơ
    is_imported           BIT NOT NULL DEFAULT 0,       -- Nhãn Nhập khẩu
    season_start_month    INT NULL CHECK (season_start_month BETWEEN 1 AND 12),
    season_end_month      INT NULL CHECK (season_end_month   BETWEEN 1 AND 12),
    -- PHÊ DUYỆT
    approval_status       NVARCHAR(20) NOT NULL DEFAULT 'PENDING'
                          CHECK (approval_status IN ('PENDING','APPROVED','REJECTED')),
    verification_doc_path NVARCHAR(500) NULL,           -- Giấy tờ xác nhận của shop
    rejection_reason      NVARCHAR(500) NULL,           -- Lý do Admin từ chối
    created_at            DATETIME NOT NULL DEFAULT GETDATE(),
    updated_at            DATETIME NOT NULL DEFAULT GETDATE()
);

-- 7. product_images [cite: 57]
CREATE TABLE product_images (
    image_id INT IDENTITY(1,1) PRIMARY KEY,
    product_id INT NOT NULL FOREIGN KEY REFERENCES products(product_id) ON DELETE CASCADE,
    file_path NVARCHAR(500) NOT NULL,
    display_order INT NOT NULL DEFAULT 0,
    is_primary BIT NOT NULL DEFAULT 0,
    uploaded_at DATETIME NOT NULL DEFAULT GETDATE()
);

-- 8. product_variants
CREATE TABLE product_variants (
    variant_id     INT IDENTITY(1,1) PRIMARY KEY,
    product_id     INT NOT NULL FOREIGN KEY REFERENCES products(product_id) ON DELETE CASCADE,
    sku            NVARCHAR(50) NOT NULL UNIQUE,
    variant_label  NVARCHAR(100) NOT NULL,
    price          DECIMAL(12,2) NOT NULL,
    stock_quantity INT NOT NULL DEFAULT 0,
    weight_kg      DECIMAL(6,3) NOT NULL DEFAULT 1.000 CHECK (weight_kg > 0.000),
    -- GIẢM GIÁ THEO THỜI GIAN
    discount_price DECIMAL(12,2) NULL,       -- NULL = không giảm giá
    discount_start DATETIME NULL,            -- Thời điểm bắt đầu khuyến mãi
    discount_end   DATETIME NULL,            -- Hết hạn → tự động quày về giá gốc
    is_active      BIT NOT NULL DEFAULT 1,
    created_at     DATETIME NOT NULL DEFAULT GETDATE(),
    updated_at     DATETIME NOT NULL DEFAULT GETDATE()
);

-- 8b. product_packaging_options — Lựa chọn đóng gói kèm theo sản phẩm
CREATE TABLE product_packaging_options (
    packaging_id INT IDENTITY(1,1) PRIMARY KEY,
    product_id   INT NOT NULL FOREIGN KEY REFERENCES products(product_id) ON DELETE CASCADE,
    label        NVARCHAR(100) NOT NULL,     -- VD: 'Hộp gỗ cao cấp', 'Túi lưới thân thiện'
    price_add    DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (price_add >= 0),
    is_active    BIT NOT NULL DEFAULT 1
);

-- 9. inventory_logs [cite: 65]
CREATE TABLE inventory_logs (
    log_id INT IDENTITY(1,1) PRIMARY KEY,
    variant_id INT NOT NULL FOREIGN KEY REFERENCES product_variants(variant_id),
    changed_by INT NOT NULL FOREIGN KEY REFERENCES users(user_id),
    change_type NVARCHAR(20) NOT NULL CHECK (change_type IN ('MANUAL_ADJUST','ORDER_RESERVE','ORDER_RELEASE','ORDER_CONFIRM','RETURN','EXPIRED','SPOILED')),
    quantity_delta INT NOT NULL,
    quantity_after INT NOT NULL,
    note NVARCHAR(300) NULL,
    expires_at DATE NULL,
    is_expired BIT NOT NULL DEFAULT 0,
    remaining_quantity INT NULL,
    changed_at DATETIME NOT NULL DEFAULT GETDATE()
);


-- 10. promotions [cite: 93]
CREATE TABLE promotions (
    promo_id INT IDENTITY(1,1) PRIMARY KEY,
    code NVARCHAR(50) NOT NULL UNIQUE,
    discount_type NVARCHAR(10) NOT NULL CHECK (discount_type IN ('PERCENT','FIXED')),
    discount_scope NVARCHAR(50) NOT NULL CHECK (discount_scope IN ('SHOP','ALL')),
    discount_max DECIMAL(10,2) NOT NULL DEFAULT 0,
    discount_value DECIMAL(10,2) NOT NULL,
    min_order_value DECIMAL(14,2) NOT NULL DEFAULT 0,
    scope NVARCHAR(15) NOT NULL CHECK (scope IN ('ORDER','PRODUCT')),
    benefit_target NVARCHAR(20) NOT NULL DEFAULT 'MERCHANDISE'
        CHECK (benefit_target IN ('MERCHANDISE','SHIPPING','PRODUCT','PAYMENT_METHOD')),
    product_id INT NULL FOREIGN KEY REFERENCES products(product_id),
    max_uses INT NULL,
    used_count INT NOT NULL DEFAULT 0,
    can_stack BIT NOT NULL DEFAULT 0,
    valid_from DATETIME NOT NULL,
    valid_until DATETIME NOT NULL,
    created_by INT NOT NULL FOREIGN KEY REFERENCES users(user_id),
    created_at DATETIME NOT NULL DEFAULT GETDATE(), -- [cite: 29]
    updated_at DATETIME NOT NULL DEFAULT GETDATE(),  -- [cite: 29]
    is_deleted BIT NOT NULL DEFAULT 0,
    is_active BIT NOT NULL DEFAULT 1
);

-- 11. cart [cite: 69]
CREATE TABLE cart (
    cart_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_id INT NOT NULL UNIQUE FOREIGN KEY REFERENCES users(user_id),
    created_at DATETIME NOT NULL DEFAULT GETDATE(), -- [cite: 29]
    updated_at DATETIME NOT NULL DEFAULT GETDATE()  -- [cite: 29]
);

-- 12. cart_items
CREATE TABLE cart_items (
    cart_item_id INT IDENTITY(1,1) PRIMARY KEY,
    cart_id      INT NOT NULL FOREIGN KEY REFERENCES cart(cart_id) ON DELETE CASCADE,
    variant_id   INT NOT NULL FOREIGN KEY REFERENCES product_variants(variant_id),
    quantity     INT NOT NULL CHECK (quantity >= 1),
    packaging_id INT NULL FOREIGN KEY REFERENCES product_packaging_options(packaging_id), -- Lựa chọn đóng gói
    added_at     DATETIME NOT NULL DEFAULT GETDATE()
);

-- 13. orders [cite: 75]
CREATE TABLE orders (
    order_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_id INT NOT NULL FOREIGN KEY REFERENCES users(user_id),
    owner_id INT NULL FOREIGN KEY REFERENCES users(user_id),
    parent_order_id INT NULL FOREIGN KEY REFERENCES orders(order_id),
    order_type NVARCHAR(10) NOT NULL DEFAULT 'CHILD' CHECK (order_type IN ('PARENT','CHILD')),
    delivery_address NVARCHAR(500) NOT NULL,
    recipient_name NVARCHAR(100) NULL,
    recipient_phone NVARCHAR(15) NULL,
    delivery_time_slot NVARCHAR(100) NULL,
    notes NVARCHAR(300) NULL,
    cancelled_at DATETIME NULL,
    cancelled_by INT NULL FOREIGN KEY REFERENCES users(user_id),
    cancellation_reason NVARCHAR(500) NULL,
    status NVARCHAR(25) NOT NULL DEFAULT 'PENDING_PAYMENT' CHECK (status IN 
    ('PENDING_PAYMENT','APPROVED','CONFIRMED','PREPARING','DISPATCHED','DELIVERED','CANCELLED','PAYMENT_FAILED','EXPIRED')),
    total_amount DECIMAL(14,2) NOT NULL,
    delivery_fee DECIMAL(10,2) NOT NULL DEFAULT 0,
    
    discount_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    system_discount_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    shop_discount_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    platform_fee DECIMAL(12,2) NOT NULL DEFAULT 0,
    final_amount DECIMAL(14,2) NOT NULL,
    payment_method NVARCHAR(20) NOT NULL CHECK (payment_method IN ('CK','COD')),
    refund_status NVARCHAR(20) NOT NULL DEFAULT 'NONE' CHECK (refund_status IN ('NONE','PENDING','APPROVED','REJECTED','PROCESSING','REFUNDED','FAILED')),
    received_status NVARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (received_status IN ('PENDING','RECEIVED','NOT_RECEIVED')),
    shop_acceptance_deadline DATETIME NULL,
    shop_accepted_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT GETDATE(), -- [cite: 29]
    updated_at DATETIME NOT NULL DEFAULT GETDATE()  -- [cite: 29]
);

-- 14. order_items
CREATE TABLE order_items (
    order_item_id            INT IDENTITY(1,1) PRIMARY KEY,
    order_id                 INT NOT NULL FOREIGN KEY REFERENCES orders(order_id) ON DELETE CASCADE,
    variant_id               INT NULL FOREIGN KEY REFERENCES product_variants(variant_id) ON DELETE SET NULL,
    product_name_snapshot    NVARCHAR(200) NOT NULL,
    variant_label_snapshot   NVARCHAR(100) NOT NULL,
    quantity                 INT NOT NULL CHECK (quantity >= 1),
    unit_price               DECIMAL(12,2) NOT NULL,
    subtotal                 DECIMAL(14,2) NOT NULL,
    -- SNAPSHOT ĐÓNG GÓI (bất biến theo thời gian)
    packaging_label_snapshot NVARCHAR(100) NULL,
    packaging_price_snapshot DECIMAL(12,2) NOT NULL DEFAULT 0,
    CONSTRAINT UQ_order_items_order_item_order UNIQUE (order_item_id, order_id)
);

CREATE TABLE order_promotions (
    usage_id INT IDENTITY(1,1) PRIMARY KEY,
    order_id INT NOT NULL FOREIGN KEY REFERENCES orders(order_id) ON DELETE CASCADE,
    promo_id INT NOT NULL FOREIGN KEY REFERENCES promotions(promo_id),
    customer_id INT NOT NULL FOREIGN KEY REFERENCES users(user_id), -- Thêm để dễ check giới hạn per user
    discount_applied DECIMAL(12,2) NOT NULL, -- Lưu số tiền giảm thực tế từ mã này
    coupon_code NVARCHAR(50) NULL,
    discount_scope NVARCHAR(50) NULL,
    benefit_target NVARCHAR(20) NULL
        CHECK (benefit_target IS NULL OR benefit_target IN ('MERCHANDISE','SHIPPING','PRODUCT','PAYMENT_METHOD')),
    used_at DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE return_requests (
    return_request_id INT IDENTITY(1,1) PRIMARY KEY,
    order_id INT NOT NULL FOREIGN KEY REFERENCES orders(order_id) ON DELETE CASCADE,
    order_item_id INT NULL,
    customer_id INT NOT NULL FOREIGN KEY REFERENCES users(user_id),
    request_type NVARCHAR(20) NOT NULL CHECK (request_type IN ('CANCEL','RETURN','EXCHANGE')),
    reason_code NVARCHAR(50) NOT NULL CHECK (reason_code IN ('WRONG_ITEM','DAMAGED','MISSING_ITEM','LATE_DELIVERY','NOT_AS_DESCRIBED','OTHER')),
    description NVARCHAR(1000) NULL,
    evidence_url NVARCHAR(500) NULL,
    requested_quantity INT NOT NULL DEFAULT 1 CHECK (requested_quantity >= 1),
    resolution_type NVARCHAR(20) NULL CHECK (resolution_type IN ('REFUND','REPLACE','DISCOUNT','REJECT')),
    replacement_variant_id INT NULL FOREIGN KEY REFERENCES product_variants(variant_id),
    refund_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
    status NVARCHAR(20) NOT NULL DEFAULT 'REQUESTED' CHECK (status IN ('REQUESTED','APPROVED','REJECTED','PROCESSING','COMPLETED','CANCELLED')),
    decided_by INT NULL FOREIGN KEY REFERENCES users(user_id),
    decision_reason NVARCHAR(500) NULL,
    resolved_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_return_requests_order_items FOREIGN KEY (order_item_id, order_id)
        REFERENCES dbo.order_items(order_item_id, order_id)
);

CREATE TABLE shop_settlements (
    settlement_id INT IDENTITY(1,1) PRIMARY KEY,
    owner_id INT NOT NULL FOREIGN KEY REFERENCES users(user_id),
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    gross_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
    platform_fee_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
    refund_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
    adjustment_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
    net_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
    status NVARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','CONFIRMED','PAID','CANCELLED')),
    calculated_at DATETIME NOT NULL DEFAULT GETDATE(),
    confirmed_at DATETIME NULL,
    confirmed_by INT NULL FOREIGN KEY REFERENCES users(user_id),
    confirm_note NVARCHAR(500) NULL,
    cancelled_at DATETIME NULL,
    cancelled_by INT NULL FOREIGN KEY REFERENCES users(user_id),
    cancel_reason NVARCHAR(500) NULL,
    paid_at DATETIME NULL,
    paid_by INT NULL FOREIGN KEY REFERENCES users(user_id),
    paid_reference NVARCHAR(100) NULL,
    paid_note NVARCHAR(500) NULL,
    payment_issue_status NVARCHAR(20) NOT NULL DEFAULT 'NONE' CHECK (payment_issue_status IN ('NONE','REPORTED','UNDER_REVIEW','RESOLVED')),
    payment_issue_at DATETIME NULL,
    payment_issue_by INT NULL FOREIGN KEY REFERENCES users(user_id),
    payment_issue_note NVARCHAR(500) NULL,
    payment_issue_resolved_at DATETIME NULL,
    payment_issue_resolved_by INT NULL FOREIGN KEY REFERENCES users(user_id),
    payment_issue_resolution_note NVARCHAR(500) NULL,
    created_by INT NOT NULL FOREIGN KEY REFERENCES users(user_id),
    note NVARCHAR(500) NULL
);

CREATE TABLE shop_settlement_orders (
    settlement_order_id INT IDENTITY(1,1) PRIMARY KEY,
    settlement_id INT NOT NULL FOREIGN KEY REFERENCES shop_settlements(settlement_id) ON DELETE CASCADE,
    order_id INT NOT NULL UNIQUE FOREIGN KEY REFERENCES orders(order_id),
    order_amount DECIMAL(14,2) NOT NULL,
    platform_fee_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
    discount_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
    refund_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
    net_amount DECIMAL(14,2) NOT NULL
);

-- 15. payments [cite: 83]
CREATE TABLE payment_transactions (
    transaction_id INT IDENTITY(1,1) PRIMARY KEY,
    order_id INT NOT NULL UNIQUE FOREIGN KEY REFERENCES orders(order_id), -- Đảm bảo 1 đơn hàng 1 giao dịch active
    payment_method NVARCHAR(30) NOT NULL DEFAULT 'SEPAY', -- Lưu 'SEPAY' hoặc 'COD'
    sepay_transaction_id NVARCHAR(100) NULL, -- Mã GD thực tế trên ngân hàng do SePay trả về
    sepay_reference NVARCHAR(100) NULL,      -- Nội dung chuyển khoản (VD: DH101)
    sepay_qr_code NVARCHAR(500) NULL,        -- Link ảnh QR Code để hiển thị lên UI
    amount DECIMAL(14,2) NOT NULL,           -- Khớp với orders.final_amount
    currency NVARCHAR(3) NOT NULL DEFAULT 'VND',
    status NVARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending', 'processing', 'completed', 'failed', 'cancelled', 'refunded', 'expired'
    )),
    initiated_at DATETIME NOT NULL DEFAULT GETDATE(),
    completed_at DATETIME NULL,
    expires_at DATETIME NULL,                -- Thời hạn quét mã (VD: sau 15 phút)
    provider_response NVARCHAR(MAX) NULL,    -- Lưu log cục JSON webhook của SePay để đối soát
    error_code NVARCHAR(50) NULL,
    error_message NVARCHAR(500) NULL,
    ip_address NVARCHAR(45) NULL
);

CREATE TABLE sepay_webhook_dedup (
    dedup_id INT IDENTITY(1,1) PRIMARY KEY,
    sepay_transaction_id NVARCHAR(100) NOT NULL UNIQUE, -- Đảm bảo mã GD ngân hàng này chỉ được xử lý 1 lần
    order_code NVARCHAR(100) NOT NULL,                  -- Nội dung CK (VD: DH101)
    process_result NVARCHAR(30) NOT NULL DEFAULT 'processed',
    created_at DATETIME NOT NULL DEFAULT GETDATE()
);

-- 16. deliveries [cite: 86]
CREATE TABLE delivery_trips (
    trip_id INT IDENTITY(1,1) PRIMARY KEY,
    parent_order_id INT NOT NULL FOREIGN KEY REFERENCES orders(order_id),
    shipper_id INT NULL FOREIGN KEY REFERENCES users(user_id),
    status NVARCHAR(20) NOT NULL DEFAULT 'PLANNED' CHECK (status IN ('PLANNED','ASSIGNED','PICKED_UP','IN_TRANSIT','DELIVERED','FAILED','CANCELLED')),
    estimated_start_time DATETIME NULL,
    estimated_end_time DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE deliveries (
    delivery_id INT IDENTITY(1,1) PRIMARY KEY,
    order_id INT NOT NULL UNIQUE FOREIGN KEY REFERENCES orders(order_id),
    delivery_trip_id INT NULL FOREIGN KEY REFERENCES delivery_trips(trip_id),
    trip_stop_seq INT NULL,
    staff_id INT NULL FOREIGN KEY REFERENCES users(user_id),
    status NVARCHAR(20) NOT NULL DEFAULT 'ASSIGNED' CHECK (status IN ('ASSIGNED','PICKED_UP','IN_TRANSIT','DELIVERED','FAILED')),
    picked_up_at DATETIME NULL,
    delivered_at DATETIME NULL,
    failure_reason NVARCHAR(300) NULL,
    proof_image_url NVARCHAR(500) NULL,
    estimated_delivery_time DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT GETDATE(), -- [cite: 29]
    updated_at DATETIME NOT NULL DEFAULT GETDATE()  -- [cite: 29]
);

-- 17. reviews [cite: 89]
CREATE TABLE reviews (
    review_id INT IDENTITY(1,1) PRIMARY KEY,
    order_item_id INT NOT NULL FOREIGN KEY REFERENCES order_items(order_item_id),
    customer_id INT NOT NULL FOREIGN KEY REFERENCES users(user_id),
    rating TINYINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review_text NVARCHAR(1000) NULL,
    review_image_url NVARCHAR(500) NULL,
    is_hidden BIT NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT GETDATE(), -- [cite: 29]
    CONSTRAINT UQ_review_customer_item UNIQUE (customer_id, order_item_id)
);

CREATE TABLE chat_sessions (
    session_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_id INT NOT NULL FOREIGN KEY REFERENCES users(user_id),
    owner_id INT NOT NULL FOREIGN KEY REFERENCES users(user_id),
    
    -- Phân loại session: SHOP = Chat với cửa hàng, ADMIN = Chat hỗ trợ admin
    session_type NVARCHAR(10) NOT NULL DEFAULT 'SHOP' CHECK (session_type IN ('SHOP','ADMIN')),
    
    -- Trạng thái để biết khung chat đang mở hay đã bị khóa/đóng
    status NVARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','CLOSED')),
    
    created_at DATETIME NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME NOT NULL DEFAULT GETDATE(), -- Dùng để sort các phiên chat mới nhất lên đầu
    closed_at DATETIME NULL
);


CREATE TABLE chat_messages (
    message_id INT IDENTITY(1,1) PRIMARY KEY,
    session_id INT NOT NULL FOREIGN KEY REFERENCES chat_sessions(session_id) ON DELETE CASCADE,
    sender_id INT NOT NULL FOREIGN KEY REFERENCES users(user_id), -- Ai là người gửi (Customer hay Owner)
    
    content NVARCHAR(MAX) NULL, -- Dùng MAX để hỗ trợ tin nhắn dài, cho phép NULL nếu chỉ gửi ảnh/video
    media_url NVARCHAR(500) NULL, -- Link ảnh/video
    media_type NVARCHAR(10) NULL CHECK (media_type IN ('IMAGE','VIDEO')), -- Phân loại media
    is_read BIT NOT NULL DEFAULT 0, -- Cờ đánh dấu đã đọc chưa (rất quan trọng cho UI)
    
    created_at DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE notifications (
    notification_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL FOREIGN KEY REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- Phân loại thông báo để Frontend có thể hiển thị icon tương ứng (Ví dụ: 🔔, 📦, 💰)
    type NVARCHAR(50) NOT NULL CHECK (type IN ('ORDER_UPDATE', 'PROMOTION', 'SYSTEM', 'INVENTORY_ALERT', 'PAYMENT')),
    
    title NVARCHAR(200) NOT NULL,
    message NVARCHAR(MAX) NOT NULL, -- Dùng MAX để linh hoạt độ dài nội dung
    
    -- Đổi 'link' thành 'action_url' cho rõ nghĩa. Chứa đường dẫn khi click vào thông báo.
    action_url NVARCHAR(300) NULL, 
    
    is_read BIT NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE system_config (
    config_key NVARCHAR(100) PRIMARY KEY,
    config_value NVARCHAR(500) NOT NULL,
    description NVARCHAR(500) NULL,
    data_type NVARCHAR(20) NOT NULL DEFAULT 'STRING' CHECK (data_type IN ('STRING','INT','DECIMAL','BOOLEAN')),
    effective_date DATETIME NULL,
    previous_value NVARCHAR(500) NULL,
    changed_by INT NULL FOREIGN KEY REFERENCES users(user_id),
    changed_at DATETIME NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME NOT NULL DEFAULT GETDATE()
);

IF NOT EXISTS (SELECT 1 FROM system_config WHERE config_key = 'gemini_api_key')
BEGIN
    INSERT INTO system_config (config_key, config_value, description, data_type)
    VALUES (
        'gemini_api_key',
        '',
        N'API Key cho Gemini 2.5 Flash. Có thể để trống để dùng biến môi trường GEMINI_API_KEY khi admin chưa cấu hình.',
        'STRING'
    );
END

IF NOT EXISTS (SELECT 1 FROM system_config WHERE config_key = 'product_auto_approve')
BEGIN
    INSERT INTO system_config (config_key, config_value, description, data_type)
    VALUES (
        'product_auto_approve',
        'false',
        N'Tự động duyệt sản phẩm khi tạo mới hoặc cập nhật (true/false). Mặc định false.',
        'BOOLEAN'
    );
END

-- 18. audit_logs
CREATE TABLE audit_logs (
    log_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NULL FOREIGN KEY REFERENCES users(user_id) ON DELETE SET NULL,
    action NVARCHAR(100) NOT NULL,
    target_type NVARCHAR(50) NOT NULL,
    target_id INT NULL,
    detail NVARCHAR(MAX) NOT NULL,
    ip_address NVARCHAR(45) NULL,
    created_at DATETIME NOT NULL DEFAULT GETDATE()
);

-- (replenishment_logs đã được khai báo ở mục 9b phía trên — bỏ block trùng lập này)

CREATE INDEX IX_orders_acceptance_auto_cancel ON orders (status, shop_acceptance_deadline) WHERE status = 'CONFIRMED' AND shop_acceptance_deadline IS NOT NULL;
CREATE INDEX IX_return_requests_status ON return_requests(status, created_at);
CREATE INDEX IX_products_status_approval_product_id ON products(status, approval_status, product_id DESC);
CREATE INDEX IX_cart_items_cart_id_added_at ON cart_items (cart_id, added_at DESC);
CREATE UNIQUE INDEX UX_cart_items_cart_id_variant_packaging_notnull ON cart_items (cart_id, variant_id, packaging_id) WHERE packaging_id IS NOT NULL;
CREATE UNIQUE INDEX UX_cart_items_cart_id_variant_no_packaging ON cart_items (cart_id, variant_id) WHERE packaging_id IS NULL;
CREATE INDEX IX_orders_customer_id_order_id_desc ON orders (customer_id, order_id DESC);
CREATE INDEX IX_orders_parent_order_id ON orders (parent_order_id, order_id);
CREATE INDEX IX_orders_owner_id_status_order_id_desc ON orders (owner_id, status, order_id DESC);
CREATE INDEX IX_orders_owner_id_order_id_desc ON orders (owner_id, order_id DESC);
CREATE INDEX IX_orders_status_order_id_desc ON orders (status, order_id DESC);
CREATE INDEX IX_order_items_order_id ON order_items (order_id, order_item_id);
CREATE INDEX IX_order_items_variant_id ON order_items (variant_id, order_item_id);
CREATE INDEX IX_promotions_created_by_is_deleted_promo_id_desc ON promotions (created_by, is_deleted, promo_id DESC);
CREATE INDEX IX_promotions_product_scope_active_validity ON promotions (product_id, scope, is_active, is_deleted, valid_from, valid_until);
CREATE INDEX IX_inventory_logs_variant_id_changed_at_desc ON inventory_logs (variant_id, changed_at DESC);
CREATE INDEX IX_return_requests_order_id_created_at_desc ON return_requests (order_id, created_at DESC);
CREATE INDEX IX_return_requests_customer_id_created_at_desc ON return_requests (customer_id, created_at DESC);
CREATE INDEX IX_return_requests_status_created_at_desc ON return_requests (status, created_at DESC);
CREATE INDEX IX_shop_settlements_owner_id_settlement_id_desc ON shop_settlements (owner_id, settlement_id DESC);
CREATE INDEX IX_shop_settlements_status_settlement_id_desc ON shop_settlements (status, settlement_id DESC);
CREATE INDEX IX_shop_settlement_orders_settlement_id_order_id ON shop_settlement_orders (settlement_id, order_id);
CREATE INDEX IX_deliveries_staff_id_status_delivery_id_desc ON deliveries (staff_id, status, delivery_id DESC);
CREATE INDEX IX_deliveries_delivery_trip_id ON deliveries (delivery_trip_id, trip_stop_seq);
CREATE INDEX IX_deliveries_staff_id_delivery_id_desc ON deliveries (staff_id, delivery_id DESC);
CREATE INDEX IX_reviews_order_item_id ON reviews (order_item_id);
CREATE INDEX IX_chat_sessions_customer_owner ON chat_sessions (customer_id, owner_id);
CREATE INDEX IX_chat_sessions_customer_id_updated_at_desc ON chat_sessions (customer_id, updated_at DESC);
CREATE INDEX IX_chat_sessions_owner_id_updated_at_desc ON chat_sessions (owner_id, updated_at DESC);
CREATE INDEX IX_chat_messages_session_id_is_read_created_at_desc ON chat_messages (session_id, is_read, created_at DESC);
CREATE INDEX IX_chat_messages_session_id_created_at_desc ON chat_messages (session_id, created_at DESC);
CREATE INDEX IX_notifications_user_id_is_read_created_at_desc ON notifications (user_id, is_read, created_at DESC);
CREATE INDEX IX_notifications_user_id_created_at_desc ON notifications (user_id, created_at DESC);
CREATE INDEX IX_payment_transactions_sepay_transaction_id ON payment_transactions (sepay_transaction_id);
CREATE INDEX IX_audit_logs_user_id ON audit_logs (user_id);
CREATE INDEX IX_audit_logs_created_at_desc ON audit_logs (created_at DESC);


-- Optional: Create Full-Text Search configuration [cite: 19]
-- CREATE FULLTEXT CATALOG ftCatalog AS DEFAULT;
-- CREATE UNIQUE INDEX UX_products_product_id ON products(product_id);
-- CREATE FULLTEXT INDEX ON products(name, description) KEY INDEX UX_products_product_id;
