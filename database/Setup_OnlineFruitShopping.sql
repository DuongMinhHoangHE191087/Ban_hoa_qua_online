SET NOCOUNT ON;
GO
USE [master];
GO

IF DB_ID(N'OnlineFruitShopping') IS NOT NULL
BEGIN
    ALTER DATABASE [OnlineFruitShopping] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [OnlineFruitShopping];
END
GO

CREATE DATABASE [OnlineFruitShopping];
GO

USE [OnlineFruitShopping];
GO

SET NOCOUNT ON;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO

-- =========================================================
-- Schema creation
-- =========================================================

IF OBJECT_ID(N'dbo.users', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.users (
        user_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_users PRIMARY KEY,
        full_name NVARCHAR(100) NOT NULL,
        email NVARCHAR(255) NOT NULL CONSTRAINT UQ_users_email UNIQUE,
        password_hash NVARCHAR(255) NULL,
        phone NVARCHAR(15) NULL,
        role NVARCHAR(20) NOT NULL CONSTRAINT CK_users_role DEFAULT 'CUSTOMER' CHECK (role IN ('CUSTOMER', 'SHOP_OWNER', 'DELIVERY', 'ADMIN')),
        status NVARCHAR(20) NOT NULL CONSTRAINT CK_users_status DEFAULT 'INACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'LOCKED', 'SUSPENDED')),
        user_address NVARCHAR(500) NULL,
        avatar_url NVARCHAR(500) NULL,
        is_email_verified BIT NOT NULL CONSTRAINT DF_users_is_email_verified DEFAULT 0,
        email_verification_code_hash NVARCHAR(255) NULL,
        email_verification_expires_at DATETIME NULL,
        email_verification_resend_at DATETIME NULL,
        email_verification_sent_at DATETIME NULL,
        failed_login_count INT NOT NULL CONSTRAINT DF_users_failed_login_count DEFAULT 0,
        locked_until DATETIME NULL,
        created_at DATETIME NOT NULL CONSTRAINT DF_users_created_at DEFAULT GETDATE(),
        updated_at DATETIME NOT NULL CONSTRAINT DF_users_updated_at DEFAULT GETDATE()
    );

    EXEC('SET QUOTED_IDENTIFIER ON; CREATE UNIQUE NONCLUSTERED INDEX UX_users_phone ON dbo.users(phone) WHERE phone IS NOT NULL;');
END
GO

IF OBJECT_ID(N'dbo.user_sessions', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.user_sessions (
        session_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_user_sessions PRIMARY KEY,
        user_id INT NOT NULL,
        token NVARCHAR(100) NOT NULL CONSTRAINT UQ_user_sessions_token UNIQUE,
        expires_at DATETIME NOT NULL,
        CONSTRAINT FK_user_sessions_users FOREIGN KEY (user_id) REFERENCES dbo.users(user_id) ON DELETE CASCADE
    );
END
GO

IF OBJECT_ID(N'dbo.user_addresses', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.user_addresses (
        address_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_user_addresses PRIMARY KEY,
        user_id INT NOT NULL,
        recipient_name NVARCHAR(100) NOT NULL,
        recipient_phone NVARCHAR(15) NOT NULL,
        address_detail NVARCHAR(500) NOT NULL,
        is_default BIT NOT NULL CONSTRAINT DF_user_addresses_is_default DEFAULT 0,
        created_at DATETIME NOT NULL CONSTRAINT DF_user_addresses_created_at DEFAULT GETDATE(),
        CONSTRAINT FK_user_addresses_users FOREIGN KEY (user_id) REFERENCES dbo.users(user_id) ON DELETE CASCADE
    );
    PRINT 'Created user_addresses table.';
END
GO

IF OBJECT_ID(N'dbo.shop_owner_profiles', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.shop_owner_profiles (
        profile_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_shop_owner_profiles PRIMARY KEY,
        user_id INT NOT NULL CONSTRAINT UQ_shop_owner_profiles_user_id UNIQUE,
        shop_name NVARCHAR(150) NOT NULL,
        shop_description NVARCHAR(MAX) NULL,
        approval_status NVARCHAR(20) NOT NULL CONSTRAINT DF_shop_owner_profiles_approval_status DEFAULT 'PENDING' CONSTRAINT CK_shop_owner_profiles_approval_status CHECK (approval_status IN ('PENDING', 'APPROVED', 'REJECTED', 'SUSPENDED')),
        rejection_reason NVARCHAR(500) NULL,
        approved_at DATETIME NULL,
        delivery_address NVARCHAR(500) NULL,
        rating DECIMAL(3,2) NOT NULL CONSTRAINT DF_shop_owner_profiles_rating DEFAULT 0,
        preferred_categories NVARCHAR(500) NULL,
        doc_paths NVARCHAR(MAX) NULL,
        business_email NVARCHAR(255) NULL,
        logo_url NVARCHAR(500) NULL,
        cover_url NVARCHAR(500) NULL,
        expiry_warning_days INT NOT NULL CONSTRAINT DF_shop_owner_profiles_expiry_warning_days DEFAULT 3,
        low_stock_threshold INT NOT NULL CONSTRAINT DF_shop_owner_profiles_low_stock_threshold DEFAULT 5,
        created_at DATETIME NOT NULL CONSTRAINT DF_shop_owner_profiles_created_at DEFAULT GETDATE(),
        updated_at DATETIME NOT NULL CONSTRAINT DF_shop_owner_profiles_updated_at DEFAULT GETDATE(),
        CONSTRAINT FK_shop_owner_profiles_users FOREIGN KEY (user_id) REFERENCES dbo.users(user_id)
    );
    
    EXEC('SET QUOTED_IDENTIFIER ON; CREATE UNIQUE NONCLUSTERED INDEX UX_shop_owner_profiles_business_email ON dbo.shop_owner_profiles(business_email) WHERE business_email IS NOT NULL;');
END
GO

-- Migration: Add business_email column and its filtered unique index if they do not exist
IF OBJECT_ID(N'dbo.shop_owner_profiles', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.shop_owner_profiles') AND name = N'business_email')
    BEGIN
        ALTER TABLE dbo.shop_owner_profiles ADD business_email NVARCHAR(255) NULL;
        EXEC('SET QUOTED_IDENTIFIER ON; CREATE UNIQUE NONCLUSTERED INDEX UX_shop_owner_profiles_business_email ON dbo.shop_owner_profiles(business_email) WHERE business_email IS NOT NULL;');
    END
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.shop_owner_profiles') AND name = N'logo_url')
    BEGIN
        ALTER TABLE dbo.shop_owner_profiles ADD logo_url NVARCHAR(500) NULL;
    END
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.shop_owner_profiles') AND name = N'cover_url')
    BEGIN
        ALTER TABLE dbo.shop_owner_profiles ADD cover_url NVARCHAR(500) NULL;
    END
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.shop_owner_profiles') AND name = N'expiry_warning_days')
    BEGIN
        ALTER TABLE dbo.shop_owner_profiles ADD expiry_warning_days INT NOT NULL CONSTRAINT DF_shop_owner_profiles_expiry_warning_days DEFAULT 3;
    END
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.shop_owner_profiles') AND name = N'low_stock_threshold')
    BEGIN
        ALTER TABLE dbo.shop_owner_profiles ADD low_stock_threshold INT NOT NULL CONSTRAINT DF_shop_owner_profiles_low_stock_threshold DEFAULT 5;
    END
END
GO

IF OBJECT_ID(N'dbo.categories', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.categories (
        category_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_categories PRIMARY KEY,
        name NVARCHAR(100) NOT NULL CONSTRAINT UQ_categories_name UNIQUE,
        slug NVARCHAR(100) NOT NULL CONSTRAINT UQ_categories_slug UNIQUE,
        display_order INT NOT NULL CONSTRAINT DF_categories_display_order DEFAULT 0,
        is_active BIT NOT NULL CONSTRAINT DF_categories_is_active DEFAULT 1
    );
END
GO

IF OBJECT_ID(N'dbo.products', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.products (
        product_id          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_products PRIMARY KEY,
        owner_id            INT NOT NULL,
        category_id         INT NOT NULL,
        name                NVARCHAR(200) NOT NULL,
        description         NVARCHAR(MAX) NULL,
        origin_country      NVARCHAR(100) NULL,
        origin_region       NVARCHAR(150) NULL,
        harvest_date        DATE NULL,
        shelf_life_days     INT NULL,
        storage_instruction NVARCHAR(300) NULL,
        status              NVARCHAR(20) NOT NULL
                            CONSTRAINT DF_products_status  DEFAULT 'ACTIVE'
                            CONSTRAINT CK_products_status  CHECK (status IN ('ACTIVE','INACTIVE','DELETED','OUT_OF_SEASON')),
        view_count          INT NOT NULL CONSTRAINT DF_products_view_count     DEFAULT 0,
        rating              DECIMAL(3,2) NOT NULL CONSTRAINT DF_products_rating DEFAULT 0,
        sold_quantity       INT NOT NULL CONSTRAINT DF_products_sold_quantity   DEFAULT 0,
        -- === FEATURE COLUMNS (formerly product_features_migration.sql) ===
        is_organic          BIT NOT NULL CONSTRAINT DF_products_is_organic      DEFAULT 0,   -- Nhãn Hữu cơ
        is_imported         BIT NOT NULL CONSTRAINT DF_products_is_imported     DEFAULT 0,   -- Nhãn Nhập khẩu
        season_start_month  INT NULL                                                         -- Tháng bắt đầu mùa vụ (1-12)
                            CONSTRAINT CK_products_season_start CHECK (season_start_month BETWEEN 1 AND 12),
        season_end_month    INT NULL                                                         -- Tháng kết thúc mùa vụ (1-12)
                            CONSTRAINT CK_products_season_end   CHECK (season_end_month   BETWEEN 1 AND 12),
        -- === APPROVAL WORKFLOW COLUMNS (formerly product_approval_migration.sql) ===
        approval_status     NVARCHAR(20) NOT NULL
                            CONSTRAINT DF_products_approval_status  DEFAULT 'PENDING'
                            CONSTRAINT CK_products_approval_status  CHECK (approval_status IN ('PENDING','APPROVED','REJECTED')),
        verification_doc_path NVARCHAR(500) NULL,                                           -- Đường dẫn giấy tờ xác nhận
        rejection_reason    NVARCHAR(500) NULL,                                             -- Lý do từ chối của Admin
        created_at          DATETIME NOT NULL CONSTRAINT DF_products_created_at DEFAULT GETDATE(),
        updated_at          DATETIME NOT NULL CONSTRAINT DF_products_updated_at DEFAULT GETDATE(),
        CONSTRAINT FK_products_users       FOREIGN KEY (owner_id)    REFERENCES dbo.users(user_id),
        CONSTRAINT FK_products_categories  FOREIGN KEY (category_id) REFERENCES dbo.categories(category_id)
    );
    PRINT 'Created products table with full feature + approval columns.';
END
GO

-- === MIGRATION GUARDS: Nâng cấp DB cũ không có các cột này (idempotent - chạy nhiều lần vẫn an toàn) ===
IF OBJECT_ID(N'dbo.products', N'U') IS NOT NULL
BEGIN
    -- is_organic
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.products') AND name = N'is_organic')
        ALTER TABLE dbo.products ADD is_organic BIT NOT NULL CONSTRAINT DF_products_is_organic DEFAULT 0;
    -- is_imported
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.products') AND name = N'is_imported')
        ALTER TABLE dbo.products ADD is_imported BIT NOT NULL CONSTRAINT DF_products_is_imported DEFAULT 0;
    -- season_start_month
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.products') AND name = N'season_start_month')
        ALTER TABLE dbo.products ADD season_start_month INT NULL CONSTRAINT CK_products_season_start CHECK (season_start_month BETWEEN 1 AND 12);
    -- season_end_month
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.products') AND name = N'season_end_month')
        ALTER TABLE dbo.products ADD season_end_month INT NULL CONSTRAINT CK_products_season_end CHECK (season_end_month BETWEEN 1 AND 12);
    -- approval_status
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.products') AND name = N'approval_status')
        ALTER TABLE dbo.products ADD approval_status NVARCHAR(20) NOT NULL CONSTRAINT DF_products_approval_status DEFAULT 'PENDING'
            CONSTRAINT CK_products_approval_status CHECK (approval_status IN ('PENDING','APPROVED','REJECTED'));
    -- verification_doc_path
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.products') AND name = N'verification_doc_path')
        ALTER TABLE dbo.products ADD verification_doc_path NVARCHAR(500) NULL;
    -- rejection_reason
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.products') AND name = N'rejection_reason')
        ALTER TABLE dbo.products ADD rejection_reason NVARCHAR(500) NULL;
    -- Tương thích ngược: sản phẩm cũ trước khi có luồng duyệt — mặc định là APPROVED
    UPDATE dbo.products SET approval_status = 'APPROVED' WHERE approval_status = 'PENDING' AND name IS NOT NULL;
    PRINT 'Migration guards for products table applied successfully.';
END
GO

IF OBJECT_ID(N'dbo.product_images', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.product_images (
        image_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_product_images PRIMARY KEY,
        product_id INT NOT NULL,
        file_path NVARCHAR(500) NOT NULL,
        display_order INT NOT NULL CONSTRAINT DF_product_images_display_order DEFAULT 0,
        is_primary BIT NOT NULL CONSTRAINT DF_product_images_is_primary DEFAULT 0,
        uploaded_at DATETIME NOT NULL CONSTRAINT DF_product_images_uploaded_at DEFAULT GETDATE(),
        CONSTRAINT FK_product_images_products FOREIGN KEY (product_id) REFERENCES dbo.products(product_id) ON DELETE CASCADE
    );
END
GO

IF OBJECT_ID(N'dbo.product_variants', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.product_variants (
        variant_id      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_product_variants PRIMARY KEY,
        product_id      INT NOT NULL,
        sku             NVARCHAR(50) NOT NULL CONSTRAINT UQ_product_variants_sku UNIQUE,
        variant_label   NVARCHAR(100) NOT NULL,
        price           DECIMAL(12,2) NOT NULL,
        stock_quantity  INT NOT NULL CONSTRAINT DF_product_variants_stock_quantity DEFAULT 0,
        weight_kg       DECIMAL(6,3) NOT NULL CONSTRAINT DF_product_variants_weight_kg DEFAULT 1.000 CHECK (weight_kg > 0.000),
        is_active       BIT NOT NULL CONSTRAINT DF_product_variants_is_active DEFAULT 1,
        -- === GIÁ GIẢM GIÁ (formerly product_features_migration.sql) ===
        discount_price  DECIMAL(12,2) NULL,         -- Giá giảm, NULL = không giảm
        discount_start  DATETIME NULL,              -- Thời điểm bắt đầu giảm giá
        discount_end    DATETIME NULL,              -- Thời điểm kết thúc giảm giá (hết hạn → giá gốc tự động có hiệu lực)
        created_at      DATETIME NOT NULL CONSTRAINT DF_product_variants_created_at DEFAULT GETDATE(),
        updated_at      DATETIME NOT NULL CONSTRAINT DF_product_variants_updated_at DEFAULT GETDATE(),
        CONSTRAINT FK_product_variants_products FOREIGN KEY (product_id) REFERENCES dbo.products(product_id) ON DELETE CASCADE
    );
    PRINT 'Created product_variants table with discount pricing columns.';
END
GO

-- Migration guard: thêm các cột giảm giá vào DB cũ — idempotent
IF OBJECT_ID(N'dbo.product_variants', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.product_variants') AND name = N'discount_price')
        ALTER TABLE dbo.product_variants ADD discount_price DECIMAL(12,2) NULL;
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.product_variants') AND name = N'discount_start')
        ALTER TABLE dbo.product_variants ADD discount_start DATETIME NULL;
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.product_variants') AND name = N'discount_end')
        ALTER TABLE dbo.product_variants ADD discount_end DATETIME NULL;
    PRINT 'Migration guards for product_variants discount columns applied.';
END
GO

IF OBJECT_ID(N'dbo.inventory_logs', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.inventory_logs (
        log_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_inventory_logs PRIMARY KEY,
        variant_id INT NOT NULL,
        changed_by INT NOT NULL,
        change_type NVARCHAR(20) NOT NULL CONSTRAINT CK_inventory_logs_change_type CHECK (change_type IN ('MANUAL_ADJUST', 'ORDER_RESERVE', 'ORDER_RELEASE', 'ORDER_CONFIRM', 'RETURN', 'EXPIRED', 'SPOILED')),
        quantity_delta INT NOT NULL,
        quantity_after INT NOT NULL,
        note NVARCHAR(300) NULL,
        expires_at DATE NULL,
        is_expired BIT NOT NULL CONSTRAINT DF_inventory_logs_is_expired DEFAULT 0,
        remaining_quantity INT NULL,
        changed_at DATETIME NOT NULL CONSTRAINT DF_inventory_logs_changed_at DEFAULT GETDATE(),
        CONSTRAINT FK_inventory_logs_variants FOREIGN KEY (variant_id) REFERENCES dbo.product_variants(variant_id),
        CONSTRAINT FK_inventory_logs_users FOREIGN KEY (changed_by) REFERENCES dbo.users(user_id)
    );
END
GO

-- Migration guard for existing databases
IF OBJECT_ID(N'dbo.inventory_logs', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.inventory_logs') AND name = N'remaining_quantity')
    BEGIN
        ALTER TABLE dbo.inventory_logs ADD remaining_quantity INT NULL;
    END
END
GO


IF OBJECT_ID(N'dbo.promotions', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.promotions (
        promo_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_promotions PRIMARY KEY,
        code NVARCHAR(50) NOT NULL CONSTRAINT UQ_promotions_code UNIQUE,
        discount_type NVARCHAR(10) NOT NULL CONSTRAINT CK_promotions_discount_type CHECK (discount_type IN ('PERCENT', 'FIXED')),
        discount_scope NVARCHAR(50) NOT NULL CONSTRAINT CK_promotions_discount_scope CHECK (discount_scope IN ('SHOP', 'ALL')),
        discount_max DECIMAL(10,2) NOT NULL CONSTRAINT DF_promotions_discount_max DEFAULT 0,
        discount_value DECIMAL(10,2) NOT NULL,
        min_order_value DECIMAL(14,2) NOT NULL CONSTRAINT DF_promotions_min_order_value DEFAULT 0,
        scope NVARCHAR(15) NOT NULL CONSTRAINT CK_promotions_scope CHECK (scope IN ('ORDER', 'PRODUCT')),
        benefit_target NVARCHAR(20) NOT NULL CONSTRAINT DF_promotions_benefit_target DEFAULT N'MERCHANDISE'
            CONSTRAINT CK_promotions_benefit_target CHECK (benefit_target IN ('MERCHANDISE', 'SHIPPING', 'PRODUCT', 'PAYMENT_METHOD')),
        product_id INT NULL,
        max_uses INT NULL,
        used_count INT NOT NULL CONSTRAINT DF_promotions_used_count DEFAULT 0,
        can_stack BIT NOT NULL CONSTRAINT DF_promotions_can_stack DEFAULT 0,
        valid_from DATETIME NOT NULL,
        valid_until DATETIME NOT NULL,
        created_by INT NOT NULL,
        created_at DATETIME NOT NULL CONSTRAINT DF_promotions_created_at DEFAULT GETDATE(),
        updated_at DATETIME NOT NULL CONSTRAINT DF_promotions_updated_at DEFAULT GETDATE(),
        is_deleted BIT NOT NULL CONSTRAINT DF_promotions_is_deleted DEFAULT 0,
        is_active BIT NOT NULL CONSTRAINT DF_promotions_is_active DEFAULT 1,
        CONSTRAINT FK_promotions_products FOREIGN KEY (product_id) REFERENCES dbo.products(product_id),
        CONSTRAINT FK_promotions_users FOREIGN KEY (created_by) REFERENCES dbo.users(user_id)
    );
END
GO

IF COL_LENGTH(N'dbo.promotions', N'benefit_target') IS NULL
BEGIN
    ALTER TABLE dbo.promotions
    ADD benefit_target NVARCHAR(20) NOT NULL
        CONSTRAINT DF_promotions_benefit_target_migration DEFAULT N'MERCHANDISE' WITH VALUES;

    ALTER TABLE dbo.promotions
    ADD CONSTRAINT CK_promotions_benefit_target_migration
        CHECK (benefit_target IN ('MERCHANDISE', 'SHIPPING', 'PRODUCT', 'PAYMENT_METHOD'));
END
GO

UPDATE dbo.promotions
SET benefit_target = CASE
        WHEN scope = N'PRODUCT' THEN N'PRODUCT'
        WHEN benefit_target IS NULL OR LTRIM(RTRIM(benefit_target)) = N'' THEN N'MERCHANDISE'
        ELSE benefit_target
    END
WHERE benefit_target IS NULL
   OR LTRIM(RTRIM(benefit_target)) = N''
   OR (scope = N'PRODUCT' AND benefit_target <> N'PRODUCT');
GO

IF OBJECT_ID(N'dbo.cart', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.cart (
        cart_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_cart PRIMARY KEY,
        customer_id INT NOT NULL CONSTRAINT UQ_cart_customer_id UNIQUE,
        created_at DATETIME NOT NULL CONSTRAINT DF_cart_created_at DEFAULT GETDATE(),
        updated_at DATETIME NOT NULL CONSTRAINT DF_cart_updated_at DEFAULT GETDATE(),
        CONSTRAINT FK_cart_users FOREIGN KEY (customer_id) REFERENCES dbo.users(user_id)
    );
END
GO

IF OBJECT_ID(N'dbo.cart_items', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.cart_items (
        cart_item_id    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_cart_items PRIMARY KEY,
        cart_id         INT NOT NULL,
        variant_id      INT NOT NULL,
        quantity        INT NOT NULL CONSTRAINT CK_cart_items_quantity CHECK (quantity >= 1),
        packaging_id    INT NULL,   -- Lựa chọn đóng gói (nullable: khách không chọn giao thiết bao bì riêng)
        added_at        DATETIME NOT NULL CONSTRAINT DF_cart_items_added_at DEFAULT GETDATE(),
        CONSTRAINT FK_cart_items_cart     FOREIGN KEY (cart_id)  REFERENCES dbo.cart(cart_id) ON DELETE CASCADE,
        CONSTRAINT FK_cart_items_variants FOREIGN KEY (variant_id) REFERENCES dbo.product_variants(variant_id)
        -- FK tới product_packaging_options được thêm sau khi tạo bảng đó
    );
END
GO

-- Lựa chọn đóng gói sản phẩm (formerly product_features_migration.sql)
IF OBJECT_ID(N'dbo.product_packaging_options', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.product_packaging_options (
        packaging_id    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_product_packaging_options PRIMARY KEY,
        product_id      INT NOT NULL,
        label           NVARCHAR(100) NOT NULL,          -- Nhãn hiển thị (VD: 'Hộp gỗ', 'Túi lưới')
        price_add       DECIMAL(12,2) NOT NULL CONSTRAINT DF_packaging_price_add DEFAULT 0
                        CONSTRAINT CK_packaging_price_add CHECK (price_add >= 0),
        is_active       BIT NOT NULL CONSTRAINT DF_packaging_is_active DEFAULT 1,
        CONSTRAINT FK_packaging_products FOREIGN KEY (product_id) REFERENCES dbo.products(product_id) ON DELETE CASCADE
    );
    -- Thêm FK packaging vào cart_items nếu chưa có
    IF NOT EXISTS (
        SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'dbo.cart_items') AND name = N'FK_cart_items_packaging'
    )
        ALTER TABLE dbo.cart_items ADD CONSTRAINT FK_cart_items_packaging FOREIGN KEY (packaging_id) REFERENCES dbo.product_packaging_options(packaging_id);
    PRINT 'Created product_packaging_options table and linked FK on cart_items.';
END
GO

-- Migration guard: thêm cột packaging_id vào cart_items cũ — idempotent
IF OBJECT_ID(N'dbo.cart_items', N'U') IS NOT NULL AND OBJECT_ID(N'dbo.product_packaging_options', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.cart_items') AND name = N'packaging_id')
    BEGIN
        ALTER TABLE dbo.cart_items ADD packaging_id INT NULL CONSTRAINT FK_cart_items_packaging FOREIGN KEY REFERENCES dbo.product_packaging_options(packaging_id);
        PRINT 'Added packaging_id to cart_items (migration guard).';
    END
END
GO

IF OBJECT_ID(N'dbo.orders', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.orders (
        order_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_orders PRIMARY KEY,
        customer_id INT NOT NULL,
        owner_id INT NULL,
        parent_order_id INT NULL,
        order_type NVARCHAR(10) NOT NULL CONSTRAINT DF_orders_order_type DEFAULT 'CHILD' CONSTRAINT CK_orders_order_type CHECK (order_type IN ('PARENT', 'CHILD')),
        delivery_address NVARCHAR(500) NOT NULL,
        recipient_name NVARCHAR(100) NULL,
        recipient_phone NVARCHAR(15) NULL,
        delivery_time_slot NVARCHAR(100) NULL,
        notes NVARCHAR(300) NULL,
        cancelled_at DATETIME NULL,
        cancelled_by INT NULL,
        cancellation_reason NVARCHAR(500) NULL,
        status NVARCHAR(25) NOT NULL CONSTRAINT DF_orders_status DEFAULT 'PENDING_PAYMENT' CONSTRAINT CK_orders_status CHECK (status IN ('PENDING_PAYMENT', 'APPROVED', 'CONFIRMED', 'PREPARING', 'DISPATCHED', 'DELIVERED', 'CANCELLED', 'PAYMENT_FAILED', 'EXPIRED')),
        total_amount DECIMAL(14,2) NOT NULL,
        delivery_fee DECIMAL(10,2) NOT NULL CONSTRAINT DF_orders_delivery_fee DEFAULT 0,
        discount_amount DECIMAL(12,2) NOT NULL CONSTRAINT DF_orders_discount_amount DEFAULT 0,
        system_discount_amount DECIMAL(12,2) NOT NULL CONSTRAINT DF_orders_system_discount_amount DEFAULT 0,
        shop_discount_amount DECIMAL(12,2) NOT NULL CONSTRAINT DF_orders_shop_discount_amount DEFAULT 0,
        platform_fee DECIMAL(12,2) NOT NULL CONSTRAINT DF_orders_platform_fee DEFAULT 0,
        final_amount DECIMAL(14,2) NOT NULL,
        payment_method NVARCHAR(20) NOT NULL CONSTRAINT CK_orders_payment_method  CHECK (payment_method IN ('CK', 'COD')),
        refund_status NVARCHAR(20) NOT NULL CONSTRAINT DF_orders_refund_status DEFAULT 'NONE' CONSTRAINT CK_orders_refund_status CHECK (refund_status IN ('NONE', 'PENDING', 'APPROVED', 'REJECTED', 'PROCESSING', 'REFUNDED', 'FAILED')),
        received_status NVARCHAR(20) NOT NULL CONSTRAINT DF_orders_received_status DEFAULT 'PENDING' CONSTRAINT CK_orders_received_status CHECK (received_status IN ('PENDING', 'RECEIVED', 'NOT_RECEIVED')),
        shop_acceptance_deadline DATETIME NULL,
        shop_accepted_at DATETIME NULL,
        created_at DATETIME NOT NULL CONSTRAINT DF_orders_created_at DEFAULT GETDATE(),
        updated_at DATETIME NOT NULL CONSTRAINT DF_orders_updated_at DEFAULT GETDATE(),
        CONSTRAINT FK_orders_customer FOREIGN KEY (customer_id) REFERENCES dbo.users(user_id),
        CONSTRAINT FK_orders_owner FOREIGN KEY (owner_id) REFERENCES dbo.users(user_id),
        CONSTRAINT FK_orders_parent FOREIGN KEY (parent_order_id) REFERENCES dbo.orders(order_id),
        CONSTRAINT FK_orders_cancelled_by FOREIGN KEY (cancelled_by) REFERENCES dbo.users(user_id)
    );
END
GO

-- Migration: Parent/child order columns for multi-shop checkout.
IF OBJECT_ID(N'dbo.orders', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.orders') AND name = N'parent_order_id')
        ALTER TABLE dbo.orders ADD parent_order_id INT NULL;

    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.orders') AND name = N'order_type')
        ALTER TABLE dbo.orders ADD order_type NVARCHAR(10) NOT NULL CONSTRAINT DF_orders_order_type DEFAULT 'CHILD';

    EXEC(N'UPDATE dbo.orders SET order_type = ''CHILD'' WHERE order_type IS NULL');

    IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.orders') AND name = N'owner_id' AND is_nullable = 0)
    BEGIN
        DECLARE @OwnerFkName NVARCHAR(255);
        SELECT @OwnerFkName = fk.name
        FROM sys.foreign_keys fk
        JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
        JOIN sys.columns c ON c.object_id = fkc.parent_object_id AND c.column_id = fkc.parent_column_id
        WHERE fk.parent_object_id = OBJECT_ID(N'dbo.orders') AND c.name = N'owner_id';

        IF @OwnerFkName IS NOT NULL
        BEGIN
            DECLARE @DropOwnerFkSql NVARCHAR(MAX);
            SET @DropOwnerFkSql = N'ALTER TABLE dbo.orders DROP CONSTRAINT ' + QUOTENAME(@OwnerFkName);
            EXEC sp_executesql @DropOwnerFkSql;
        END

        ALTER TABLE dbo.orders ALTER COLUMN owner_id INT NULL;

        IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_orders_owner')
            ALTER TABLE dbo.orders ADD CONSTRAINT FK_orders_owner FOREIGN KEY (owner_id) REFERENCES dbo.users(user_id);
    END

    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_orders_parent')
        ALTER TABLE dbo.orders ADD CONSTRAINT FK_orders_parent FOREIGN KEY (parent_order_id) REFERENCES dbo.orders(order_id);

    IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_orders_order_type')
        EXEC(N'ALTER TABLE dbo.orders ADD CONSTRAINT CK_orders_order_type CHECK (order_type IN (''PARENT'', ''CHILD''))');
END
GO

-- Migration: Update check constraint for orders status to include 'APPROVED'
IF OBJECT_ID(N'dbo.orders', N'U') IS NOT NULL
BEGIN
    -- Drop check constraint on status column dynamically (handles both custom named and system named constraints)
    DECLARE @ConstraintName NVARCHAR(255);
    SELECT @ConstraintName = cc.name
    FROM sys.check_constraints cc
    JOIN sys.columns c ON cc.parent_column_id = c.column_id AND cc.parent_object_id = c.object_id
    WHERE cc.parent_object_id = OBJECT_ID(N'dbo.orders') AND c.name = N'status';

    IF @ConstraintName IS NOT NULL
    BEGIN
        EXEC('ALTER TABLE dbo.orders DROP CONSTRAINT ' + @ConstraintName);
    END
    
    ALTER TABLE dbo.orders ADD CONSTRAINT CK_orders_status CHECK (status IN ('PENDING_PAYMENT', 'APPROVED', 'CONFIRMED', 'PREPARING', 'DISPATCHED', 'DELIVERED', 'CANCELLED', 'PAYMENT_FAILED', 'EXPIRED'));
END
GO

-- Migration: customer delivery acknowledgement state.
IF OBJECT_ID(N'dbo.orders', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.orders') AND name = N'received_status')
    BEGIN
        ALTER TABLE dbo.orders ADD received_status NVARCHAR(20) NOT NULL CONSTRAINT DF_orders_received_status DEFAULT 'PENDING';
        PRINT 'Added received_status to orders (migration guard).';
    END

    UPDATE dbo.orders
    SET received_status = 'PENDING'
    WHERE received_status IS NULL;

    IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_orders_received_status')
        ALTER TABLE dbo.orders ADD CONSTRAINT DF_orders_received_status DEFAULT 'PENDING' FOR received_status;

    IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_orders_received_status')
        ALTER TABLE dbo.orders ADD CONSTRAINT CK_orders_received_status CHECK (received_status IN ('PENDING', 'RECEIVED', 'NOT_RECEIVED'));
END
GO

IF OBJECT_ID(N'dbo.order_items', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.order_items (
        order_item_id           INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_order_items PRIMARY KEY,
        order_id                INT NOT NULL,
        variant_id              INT NULL,
        product_name_snapshot   NVARCHAR(200) NOT NULL,
        variant_label_snapshot  NVARCHAR(100) NOT NULL,
        quantity                INT NOT NULL CONSTRAINT CK_order_items_quantity CHECK (quantity >= 1),
        unit_price              DECIMAL(12,2) NOT NULL,
        subtotal                DECIMAL(14,2) NOT NULL,
        -- === PACKAGING SNAPSHOT (formerly product_features_migration.sql) ===
        packaging_label_snapshot  NVARCHAR(100) NULL,      -- Nhãn đóng gói tại thời điểm đặt hàng (bất biến)
        packaging_price_snapshot  DECIMAL(12,2) NOT NULL   -- Giá đóng gói tại thời điểm đặt hàng
                                  CONSTRAINT DF_order_items_pkg_price_snapshot DEFAULT 0,
        CONSTRAINT FK_order_items_orders   FOREIGN KEY (order_id)   REFERENCES dbo.orders(order_id) ON DELETE CASCADE,
        CONSTRAINT FK_order_items_variants FOREIGN KEY (variant_id) REFERENCES dbo.product_variants(variant_id) ON DELETE SET NULL,
        CONSTRAINT UQ_order_items_order_item_order UNIQUE (order_item_id, order_id)
    );
    PRINT 'Created order_items table with packaging snapshot columns.';
END
GO

-- Migration guard: thêm cột snapshot đóng gói vào order_items cũ — idempotent
IF OBJECT_ID(N'dbo.order_items', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.order_items') AND name = N'packaging_label_snapshot')
        ALTER TABLE dbo.order_items ADD packaging_label_snapshot NVARCHAR(100) NULL;
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.order_items') AND name = N'packaging_price_snapshot')
        ALTER TABLE dbo.order_items ADD packaging_price_snapshot DECIMAL(12,2) NOT NULL CONSTRAINT DF_order_items_pkg_price_snapshot DEFAULT 0;
    PRINT 'Migration guards for order_items packaging snapshots applied.';
END
GO

IF OBJECT_ID(N'dbo.order_promotions', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.order_promotions (
        usage_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_order_promotions PRIMARY KEY,
        order_id INT NOT NULL,
        promo_id INT NOT NULL,
        customer_id INT NOT NULL,
        discount_applied DECIMAL(12,2) NOT NULL,
        coupon_code NVARCHAR(50) NULL,
        discount_scope NVARCHAR(50) NULL,
        benefit_target NVARCHAR(20) NULL CONSTRAINT CK_order_promotions_benefit_target
            CHECK (benefit_target IS NULL OR benefit_target IN ('MERCHANDISE', 'SHIPPING', 'PRODUCT', 'PAYMENT_METHOD')),
        used_at DATETIME NOT NULL CONSTRAINT DF_order_promotions_used_at DEFAULT GETDATE(),
        CONSTRAINT FK_order_promotions_orders FOREIGN KEY (order_id) REFERENCES dbo.orders(order_id) ON DELETE CASCADE,
        CONSTRAINT FK_order_promotions_promotions FOREIGN KEY (promo_id) REFERENCES dbo.promotions(promo_id),
        CONSTRAINT FK_order_promotions_users FOREIGN KEY (customer_id) REFERENCES dbo.users(user_id)
    );
END
GO

IF COL_LENGTH(N'dbo.order_promotions', N'coupon_code') IS NULL
BEGIN
    ALTER TABLE dbo.order_promotions ADD coupon_code NVARCHAR(50) NULL;
END
GO

IF COL_LENGTH(N'dbo.order_promotions', N'discount_scope') IS NULL
BEGIN
    ALTER TABLE dbo.order_promotions ADD discount_scope NVARCHAR(50) NULL;
END
GO

IF COL_LENGTH(N'dbo.order_promotions', N'benefit_target') IS NULL
BEGIN
    ALTER TABLE dbo.order_promotions
    ADD benefit_target NVARCHAR(20) NULL
        CONSTRAINT CK_order_promotions_benefit_target_migration
        CHECK (benefit_target IS NULL OR benefit_target IN ('MERCHANDISE', 'SHIPPING', 'PRODUCT', 'PAYMENT_METHOD'));
END
GO

UPDATE op
SET op.coupon_code = p.code,
    op.discount_scope = p.discount_scope,
    op.benefit_target = CASE
        WHEN p.scope = N'PRODUCT' THEN N'PRODUCT'
        WHEN p.benefit_target IS NULL OR LTRIM(RTRIM(p.benefit_target)) = N'' THEN N'MERCHANDISE'
        ELSE p.benefit_target
    END
FROM dbo.order_promotions op
JOIN dbo.promotions p ON p.promo_id = op.promo_id
WHERE op.coupon_code IS NULL
   OR op.discount_scope IS NULL
   OR op.benefit_target IS NULL;
GO

IF OBJECT_ID(N'dbo.return_requests', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.return_requests (
        return_request_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_return_requests PRIMARY KEY,
        order_id INT NOT NULL,
        order_item_id INT NULL,
        customer_id INT NOT NULL,
        request_type NVARCHAR(20) NOT NULL CONSTRAINT CK_return_requests_request_type CHECK (request_type IN ('CANCEL', 'RETURN', 'EXCHANGE')),
        reason_code NVARCHAR(50) NOT NULL CONSTRAINT CK_return_requests_reason_code CHECK (reason_code IN ('WRONG_ITEM', 'DAMAGED', 'MISSING_ITEM', 'LATE_DELIVERY', 'NOT_AS_DESCRIBED', 'OTHER')),
        description NVARCHAR(1000) NULL,
        evidence_url NVARCHAR(500) NULL,
        requested_quantity INT NOT NULL CONSTRAINT DF_return_requests_requested_quantity DEFAULT 1 CONSTRAINT CK_return_requests_requested_quantity CHECK (requested_quantity >= 1),
        resolution_type NVARCHAR(20) NULL CONSTRAINT CK_return_requests_resolution_type CHECK (resolution_type IN ('REFUND', 'REPLACE', 'DISCOUNT', 'REJECT')),
        replacement_variant_id INT NULL,
        refund_amount DECIMAL(14,2) NOT NULL CONSTRAINT DF_return_requests_refund_amount DEFAULT 0,
        status NVARCHAR(20) NOT NULL CONSTRAINT DF_return_requests_status DEFAULT 'REQUESTED' CONSTRAINT CK_return_requests_status CHECK (status IN ('REQUESTED', 'APPROVED', 'REJECTED', 'PROCESSING', 'COMPLETED', 'CANCELLED')),
        decided_by INT NULL,
        decision_reason NVARCHAR(500) NULL,
        resolved_at DATETIME NULL,
        created_at DATETIME NOT NULL CONSTRAINT DF_return_requests_created_at DEFAULT GETDATE(),
        updated_at DATETIME NOT NULL CONSTRAINT DF_return_requests_updated_at DEFAULT GETDATE(),
        CONSTRAINT FK_return_requests_orders FOREIGN KEY (order_id) REFERENCES dbo.orders(order_id),
        CONSTRAINT FK_return_requests_order_items FOREIGN KEY (order_item_id, order_id) REFERENCES dbo.order_items(order_item_id, order_id),
        CONSTRAINT FK_return_requests_customers FOREIGN KEY (customer_id) REFERENCES dbo.users(user_id),
        CONSTRAINT FK_return_requests_variants FOREIGN KEY (replacement_variant_id) REFERENCES dbo.product_variants(variant_id),
        CONSTRAINT FK_return_requests_decided_by FOREIGN KEY (decided_by) REFERENCES dbo.users(user_id)
    );
END
GO

-- Keep existing databases aligned with the composite relationship. NULL
-- order_item_id means the request targets the whole order.
IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ_order_items_order_item_order')
BEGIN
    ALTER TABLE dbo.order_items
        ADD CONSTRAINT UQ_order_items_order_item_order UNIQUE (order_item_id, order_id);
END
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_return_requests_order_items'
           AND parent_object_id = OBJECT_ID(N'dbo.return_requests'))
    ALTER TABLE dbo.return_requests DROP CONSTRAINT FK_return_requests_order_items;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_return_requests_order_items'
               AND parent_object_id = OBJECT_ID(N'dbo.return_requests'))
BEGIN
    ALTER TABLE dbo.return_requests ADD CONSTRAINT FK_return_requests_order_items
        FOREIGN KEY (order_item_id, order_id)
        REFERENCES dbo.order_items(order_item_id, order_id);
END
GO

IF OBJECT_ID(N'dbo.shop_settlements', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.shop_settlements (
        settlement_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_shop_settlements PRIMARY KEY,
        owner_id INT NOT NULL,
        period_start DATE NOT NULL,
        period_end DATE NOT NULL,
        gross_amount DECIMAL(14,2) NOT NULL CONSTRAINT DF_shop_settlements_gross_amount DEFAULT 0,
        platform_fee_amount DECIMAL(14,2) NOT NULL CONSTRAINT DF_shop_settlements_platform_fee_amount DEFAULT 0,
        refund_amount DECIMAL(14,2) NOT NULL CONSTRAINT DF_shop_settlements_refund_amount DEFAULT 0,
        adjustment_amount DECIMAL(14,2) NOT NULL CONSTRAINT DF_shop_settlements_adjustment_amount DEFAULT 0,
          net_amount DECIMAL(14,2) NOT NULL CONSTRAINT DF_shop_settlements_net_amount DEFAULT 0,
          status NVARCHAR(20) NOT NULL CONSTRAINT DF_shop_settlements_status DEFAULT 'PENDING' CONSTRAINT CK_shop_settlements_status CHECK (status IN ('PENDING', 'CONFIRMED', 'PAID', 'CANCELLED')),
          calculated_at DATETIME NOT NULL CONSTRAINT DF_shop_settlements_calculated_at DEFAULT GETDATE(),
          confirmed_at DATETIME NULL,
          confirmed_by INT NULL,
          confirm_note NVARCHAR(500) NULL,
          cancelled_at DATETIME NULL,
          cancelled_by INT NULL,
          cancel_reason NVARCHAR(500) NULL,
          paid_at DATETIME NULL,
          paid_by INT NULL,
          paid_reference NVARCHAR(100) NULL,
          paid_note NVARCHAR(500) NULL,
          payment_issue_status NVARCHAR(20) NOT NULL CONSTRAINT DF_shop_settlements_payment_issue_status DEFAULT 'NONE'
              CONSTRAINT CK_shop_settlements_payment_issue_status CHECK (payment_issue_status IN ('NONE', 'REPORTED', 'UNDER_REVIEW', 'RESOLVED')),
          payment_issue_at DATETIME NULL,
          payment_issue_by INT NULL,
          payment_issue_note NVARCHAR(500) NULL,
          payment_issue_resolved_at DATETIME NULL,
          payment_issue_resolved_by INT NULL,
          payment_issue_resolution_note NVARCHAR(500) NULL,
          created_by INT NOT NULL,
          note NVARCHAR(500) NULL,
          CONSTRAINT FK_shop_settlements_owner FOREIGN KEY (owner_id) REFERENCES dbo.users(user_id),
          CONSTRAINT FK_shop_settlements_created_by FOREIGN KEY (created_by) REFERENCES dbo.users(user_id),
          CONSTRAINT FK_shop_settlements_confirmed_by FOREIGN KEY (confirmed_by) REFERENCES dbo.users(user_id),
          CONSTRAINT FK_shop_settlements_cancelled_by FOREIGN KEY (cancelled_by) REFERENCES dbo.users(user_id),
          CONSTRAINT FK_shop_settlements_paid_by FOREIGN KEY (paid_by) REFERENCES dbo.users(user_id),
          CONSTRAINT FK_shop_settlements_payment_issue_by FOREIGN KEY (payment_issue_by) REFERENCES dbo.users(user_id),
          CONSTRAINT FK_shop_settlements_payment_issue_resolved_by FOREIGN KEY (payment_issue_resolved_by) REFERENCES dbo.users(user_id)
      );
END
GO

IF COL_LENGTH('dbo.shop_settlements', 'payment_issue_status') IS NULL
BEGIN
    ALTER TABLE dbo.shop_settlements
        ADD payment_issue_status NVARCHAR(20) NOT NULL CONSTRAINT DF_shop_settlements_payment_issue_status DEFAULT 'NONE';
    ALTER TABLE dbo.shop_settlements
        ADD CONSTRAINT CK_shop_settlements_payment_issue_status CHECK (payment_issue_status IN ('NONE', 'REPORTED', 'UNDER_REVIEW', 'RESOLVED'));
END
GO

IF COL_LENGTH('dbo.shop_settlements', 'payment_issue_at') IS NULL
BEGIN
    ALTER TABLE dbo.shop_settlements ADD payment_issue_at DATETIME NULL;
END
GO

IF COL_LENGTH('dbo.shop_settlements', 'payment_issue_by') IS NULL
BEGIN
    ALTER TABLE dbo.shop_settlements ADD payment_issue_by INT NULL;
END
GO

IF COL_LENGTH('dbo.shop_settlements', 'payment_issue_note') IS NULL
BEGIN
    ALTER TABLE dbo.shop_settlements ADD payment_issue_note NVARCHAR(500) NULL;
END
GO

IF COL_LENGTH('dbo.shop_settlements', 'payment_issue_resolved_at') IS NULL
BEGIN
    ALTER TABLE dbo.shop_settlements ADD payment_issue_resolved_at DATETIME NULL;
END
GO

IF COL_LENGTH('dbo.shop_settlements', 'payment_issue_resolved_by') IS NULL
BEGIN
    ALTER TABLE dbo.shop_settlements ADD payment_issue_resolved_by INT NULL;
END
GO

IF COL_LENGTH('dbo.shop_settlements', 'payment_issue_resolution_note') IS NULL
BEGIN
    ALTER TABLE dbo.shop_settlements ADD payment_issue_resolution_note NVARCHAR(500) NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_shop_settlements_payment_issue_by')
BEGIN
    ALTER TABLE dbo.shop_settlements
        ADD CONSTRAINT FK_shop_settlements_payment_issue_by FOREIGN KEY (payment_issue_by) REFERENCES dbo.users(user_id);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_shop_settlements_payment_issue_resolved_by')
BEGIN
    ALTER TABLE dbo.shop_settlements
        ADD CONSTRAINT FK_shop_settlements_payment_issue_resolved_by FOREIGN KEY (payment_issue_resolved_by) REFERENCES dbo.users(user_id);
END
GO

IF OBJECT_ID(N'dbo.shop_settlement_orders', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.shop_settlement_orders (
        settlement_order_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_shop_settlement_orders PRIMARY KEY,
        settlement_id INT NOT NULL,
        order_id INT NOT NULL CONSTRAINT UQ_shop_settlement_orders_order_id UNIQUE,
        order_amount DECIMAL(14,2) NOT NULL,
        platform_fee_amount DECIMAL(14,2) NOT NULL CONSTRAINT DF_shop_settlement_orders_platform_fee_amount DEFAULT 0,
        discount_amount DECIMAL(14,2) NOT NULL CONSTRAINT DF_shop_settlement_orders_discount_amount DEFAULT 0,
        refund_amount DECIMAL(14,2) NOT NULL CONSTRAINT DF_shop_settlement_orders_refund_amount DEFAULT 0,
        net_amount DECIMAL(14,2) NOT NULL,
        CONSTRAINT FK_shop_settlement_orders_settlement FOREIGN KEY (settlement_id) REFERENCES dbo.shop_settlements(settlement_id) ON DELETE CASCADE,
        CONSTRAINT FK_shop_settlement_orders_order FOREIGN KEY (order_id) REFERENCES dbo.orders(order_id)
    );
END
GO

IF OBJECT_ID(N'dbo.payment_transactions', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.payment_transactions (
        transaction_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_payment_transactions PRIMARY KEY,
        order_id INT NOT NULL CONSTRAINT UQ_payment_transactions_order_id UNIQUE,
        payment_method NVARCHAR(30) NOT NULL CONSTRAINT DF_payment_transactions_payment_method DEFAULT 'SEPAY',
        sepay_transaction_id NVARCHAR(100) NULL,
        sepay_reference NVARCHAR(100) NULL,
        sepay_qr_code NVARCHAR(500) NULL,
        amount DECIMAL(14,2) NOT NULL,
        currency NVARCHAR(3) NOT NULL CONSTRAINT DF_payment_transactions_currency DEFAULT 'VND',
        status NVARCHAR(20) NOT NULL CONSTRAINT DF_payment_transactions_status DEFAULT 'pending' CONSTRAINT CK_payment_transactions_status CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled', 'refunded', 'expired')),
        initiated_at DATETIME NOT NULL CONSTRAINT DF_payment_transactions_initiated_at DEFAULT GETDATE(),
        completed_at DATETIME NULL,
        expires_at DATETIME NULL,
        provider_response NVARCHAR(MAX) NULL,
        error_code NVARCHAR(50) NULL,
        error_message NVARCHAR(500) NULL,
        ip_address NVARCHAR(45) NULL,
        CONSTRAINT FK_payment_transactions_order FOREIGN KEY (order_id) REFERENCES dbo.orders(order_id)
    );
END
GO

IF OBJECT_ID(N'dbo.sepay_webhook_dedup', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.sepay_webhook_dedup (
        dedup_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_sepay_webhook_dedup PRIMARY KEY,
        sepay_transaction_id NVARCHAR(100) NOT NULL CONSTRAINT UQ_sepay_webhook_dedup_transaction_id UNIQUE,
        order_code NVARCHAR(100) NOT NULL,
        process_result NVARCHAR(30) NOT NULL CONSTRAINT DF_sepay_webhook_dedup_process_result DEFAULT 'processed',
        created_at DATETIME NOT NULL CONSTRAINT DF_sepay_webhook_dedup_created_at DEFAULT GETDATE()
    );
END
GO

IF OBJECT_ID(N'dbo.delivery_trips', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.delivery_trips (
        trip_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_delivery_trips PRIMARY KEY,
        parent_order_id INT NOT NULL,
        shipper_id INT NULL,
        status NVARCHAR(20) NOT NULL CONSTRAINT DF_delivery_trips_status DEFAULT 'PLANNED' CONSTRAINT CK_delivery_trips_status CHECK (status IN ('PLANNED','ASSIGNED','PICKED_UP','IN_TRANSIT','DELIVERED','FAILED','CANCELLED')),
        estimated_start_time DATETIME NULL,
        estimated_end_time DATETIME NULL,
        created_at DATETIME NOT NULL CONSTRAINT DF_delivery_trips_created_at DEFAULT GETDATE(),
        updated_at DATETIME NOT NULL CONSTRAINT DF_delivery_trips_updated_at DEFAULT GETDATE(),
        CONSTRAINT FK_delivery_trips_parent_order FOREIGN KEY (parent_order_id) REFERENCES dbo.orders(order_id),
        CONSTRAINT FK_delivery_trips_shipper FOREIGN KEY (shipper_id) REFERENCES dbo.users(user_id)
    );
END
GO

IF OBJECT_ID(N'dbo.deliveries', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.deliveries (
        delivery_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_deliveries PRIMARY KEY,
        order_id INT NOT NULL CONSTRAINT UQ_deliveries_order_id UNIQUE,
        delivery_trip_id INT NULL,
        trip_stop_seq INT NULL,
        staff_id INT NULL,
        status NVARCHAR(20) NOT NULL CONSTRAINT DF_deliveries_status DEFAULT 'ASSIGNED' CONSTRAINT CK_deliveries_status CHECK (status IN ('ASSIGNED', 'PICKED_UP', 'IN_TRANSIT', 'DELIVERED', 'FAILED')),
        picked_up_at DATETIME NULL,
        delivered_at DATETIME NULL,
        failure_reason NVARCHAR(300) NULL,
        proof_image_url NVARCHAR(500) NULL,
        estimated_delivery_time DATETIME NULL,
        created_at DATETIME NOT NULL CONSTRAINT DF_deliveries_created_at DEFAULT GETDATE(),
        updated_at DATETIME NOT NULL CONSTRAINT DF_deliveries_updated_at DEFAULT GETDATE(),
        CONSTRAINT FK_deliveries_order FOREIGN KEY (order_id) REFERENCES dbo.orders(order_id),
        CONSTRAINT FK_deliveries_delivery_trip FOREIGN KEY (delivery_trip_id) REFERENCES dbo.delivery_trips(trip_id),
        CONSTRAINT FK_deliveries_staff FOREIGN KEY (staff_id) REFERENCES dbo.users(user_id)
    );
END
GO

-- Migration: Add estimated_delivery_time and proof_image_url to deliveries if they do not exist
IF OBJECT_ID(N'dbo.deliveries', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.deliveries') AND name = N'proof_image_url')
    BEGIN
        ALTER TABLE dbo.deliveries ADD proof_image_url NVARCHAR(500) NULL;
    END
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.deliveries') AND name = N'estimated_delivery_time')
    BEGIN
        ALTER TABLE dbo.deliveries ADD estimated_delivery_time DATETIME NULL;
    END
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.deliveries') AND name = N'delivery_trip_id')
    BEGIN
        ALTER TABLE dbo.deliveries ADD delivery_trip_id INT NULL;
    END
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.deliveries') AND name = N'trip_stop_seq')
    BEGIN
        ALTER TABLE dbo.deliveries ADD trip_stop_seq INT NULL;
    END
    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_deliveries_delivery_trip')
    BEGIN
        ALTER TABLE dbo.deliveries ADD CONSTRAINT FK_deliveries_delivery_trip FOREIGN KEY (delivery_trip_id) REFERENCES dbo.delivery_trips(trip_id);
    END
END
GO

IF OBJECT_ID(N'dbo.reviews', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.reviews (
        review_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_reviews PRIMARY KEY,
        order_item_id INT NOT NULL,
        customer_id INT NOT NULL,
        rating TINYINT NOT NULL CONSTRAINT CK_reviews_rating CHECK (rating BETWEEN 1 AND 5),
        review_text NVARCHAR(1000) NULL,
        review_image_url NVARCHAR(500) NULL,
        is_hidden BIT NOT NULL CONSTRAINT DF_reviews_is_hidden DEFAULT 0,
        created_at DATETIME NOT NULL CONSTRAINT DF_reviews_created_at DEFAULT GETDATE(),
        CONSTRAINT UQ_review_customer_item UNIQUE (customer_id, order_item_id),
        CONSTRAINT FK_reviews_order_items FOREIGN KEY (order_item_id) REFERENCES dbo.order_items(order_item_id),
        CONSTRAINT FK_reviews_customers FOREIGN KEY (customer_id) REFERENCES dbo.users(user_id)
    );
END
GO

IF OBJECT_ID(N'dbo.chat_sessions', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.chat_sessions (
        session_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_chat_sessions PRIMARY KEY,
        customer_id INT NOT NULL,
        owner_id INT NOT NULL,
        status NVARCHAR(20) NOT NULL CONSTRAINT DF_chat_sessions_status DEFAULT 'ACTIVE' CONSTRAINT CK_chat_sessions_status CHECK (status IN ('ACTIVE', 'CLOSED')),
        created_at DATETIME NOT NULL CONSTRAINT DF_chat_sessions_created_at DEFAULT GETDATE(),
        updated_at DATETIME NOT NULL CONSTRAINT DF_chat_sessions_updated_at DEFAULT GETDATE(),
        closed_at DATETIME NULL,
        CONSTRAINT FK_chat_sessions_customer FOREIGN KEY (customer_id) REFERENCES dbo.users(user_id),
        CONSTRAINT FK_chat_sessions_owner FOREIGN KEY (owner_id) REFERENCES dbo.users(user_id)
    );
END
GO

IF OBJECT_ID(N'dbo.chat_messages', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.chat_messages (
        message_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_chat_messages PRIMARY KEY,
        session_id INT NOT NULL,
        sender_id INT NOT NULL,
        content NVARCHAR(MAX) NOT NULL,
        is_read BIT NOT NULL CONSTRAINT DF_chat_messages_is_read DEFAULT 0,
        created_at DATETIME NOT NULL CONSTRAINT DF_chat_messages_created_at DEFAULT GETDATE(),
        CONSTRAINT FK_chat_messages_session FOREIGN KEY (session_id) REFERENCES dbo.chat_sessions(session_id) ON DELETE CASCADE,
        CONSTRAINT FK_chat_messages_sender FOREIGN KEY (sender_id) REFERENCES dbo.users(user_id)
    );
END
GO

IF OBJECT_ID(N'dbo.notifications', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.notifications (
        notification_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_notifications PRIMARY KEY,
        user_id INT NOT NULL,
        type NVARCHAR(50) NOT NULL CONSTRAINT CK_notifications_type CHECK (type IN ('ORDER_UPDATE', 'PROMOTION', 'SYSTEM', 'INVENTORY_ALERT', 'PAYMENT')),
        title NVARCHAR(200) NOT NULL,
        message NVARCHAR(MAX) NOT NULL,
        action_url NVARCHAR(300) NULL,
        is_read BIT NOT NULL CONSTRAINT DF_notifications_is_read DEFAULT 0,
        created_at DATETIME NOT NULL CONSTRAINT DF_notifications_created_at DEFAULT GETDATE(),
        CONSTRAINT FK_notifications_users FOREIGN KEY (user_id) REFERENCES dbo.users(user_id) ON DELETE CASCADE
    );
END
GO

IF OBJECT_ID(N'dbo.system_config', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.system_config (
        config_key      NVARCHAR(100) NOT NULL CONSTRAINT PK_system_config PRIMARY KEY,
        config_value    NVARCHAR(500) NOT NULL,
        description     NVARCHAR(500) NULL,
        data_type       NVARCHAR(20)  NOT NULL CONSTRAINT DF_system_config_data_type DEFAULT 'STRING'
                        CONSTRAINT CK_system_config_data_type CHECK (data_type IN ('STRING','INT','DECIMAL','BOOLEAN')),
        effective_date  DATETIME NULL,
        previous_value  NVARCHAR(500) NULL,
        changed_by      INT NULL,
        changed_at      DATETIME NOT NULL CONSTRAINT DF_system_config_changed_at DEFAULT GETDATE(),
        updated_at      DATETIME NOT NULL CONSTRAINT DF_system_config_updated_at DEFAULT GETDATE(),
        CONSTRAINT FK_system_config_users FOREIGN KEY (changed_by) REFERENCES dbo.users(user_id)
    );

    -- Seed giá trị mặc định
    INSERT INTO dbo.system_config (config_key, config_value, description, data_type)
    VALUES
        ('platform_fee_rate',       '0.05', N'Tỷ lệ phí nền tảng (Platform Fee Rate). Mặc định 0.05 (5%).', 'DECIMAL'),
        ('settlement_freeze_days',  '15',   N'Số ngày đóng băng tiền quyết toán của shop.', 'INT'),
        ('shop_accept_timeout_min', '30',   N'Thời gian tối đa (phút) để shop chấp nhận đơn hàng trước khi tự hủy.', 'INT'),
        ('return_request_max_hours','24',   N'Thời gian tối đa (giờ) để khách hàng gửi return request sau DELIVERED.', 'INT'),
        ('sepay_bank_id',           'MBBank', N'Mã ngân hàng thụ hưởng nhận thanh toán SePay.', 'STRING'),
        ('sepay_account_no',         'SBSEPAY3NHWA061W5V2', N'Số tài khoản nhận thanh toán SePay.', 'STRING'),
        ('sepay_account_name',       'CONG TY TNHH METAFRUIT', N'Tên chủ tài khoản nhận thanh toán SePay.', 'STRING'),
        ('gemini_api_key',          '',                                               N'API Key cho Gemini 2.5 Flash. Có thể để trống để dùng biến môi trường GEMINI_API_KEY khi admin chưa cấu hình.', 'STRING'),
        ('product_auto_approve',    'false',  N'Tự động duyệt sản phẩm khi tạo mới hoặc cập nhật (true/false). Mặc định false.', 'BOOLEAN');

    PRINT 'Created system_config table and seeded defaults.';
END
GO

IF OBJECT_ID(N'dbo.system_config', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM dbo.system_config WHERE config_key = 'gemini_api_key')
BEGIN
    INSERT INTO dbo.system_config (config_key, config_value, description, data_type)
    VALUES (
        'gemini_api_key',
        '',
        N'API Key cho Gemini 2.5 Flash. Có thể để trống để dùng biến môi trường GEMINI_API_KEY khi admin chưa cấu hình.',
        'STRING'
    );
END
GO

IF OBJECT_ID(N'dbo.audit_logs', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.audit_logs (
        log_id      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_audit_logs PRIMARY KEY,
        user_id     INT NULL,
        action      NVARCHAR(100) NOT NULL,
        target_type NVARCHAR(50) NOT NULL,
        target_id   INT NULL,
        detail      NVARCHAR(MAX) NOT NULL,
        ip_address  NVARCHAR(45) NULL,
        created_at  DATETIME NOT NULL CONSTRAINT DF_audit_logs_created_at DEFAULT GETDATE(),
        CONSTRAINT FK_audit_logs_users FOREIGN KEY (user_id) REFERENCES dbo.users(user_id) ON DELETE SET NULL
    );

    CREATE NONCLUSTERED INDEX IX_audit_logs_user_id ON dbo.audit_logs(user_id);
    CREATE NONCLUSTERED INDEX IX_audit_logs_created_at ON dbo.audit_logs(created_at DESC);
    PRINT 'Created audit_logs table.';
END
GO

-- =========================================================
-- Indexes for hot DAO paths
-- =========================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_shop_owner_profiles_approval_status_profile_id')
BEGIN
    CREATE INDEX IX_shop_owner_profiles_approval_status_profile_id
        ON dbo.shop_owner_profiles (approval_status, profile_id DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_products_owner_id_product_id_desc')
BEGIN
    CREATE INDEX IX_products_owner_id_product_id_desc
        ON dbo.products (owner_id, product_id DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_products_category_id_product_id_desc')
BEGIN
    CREATE INDEX IX_products_category_id_product_id_desc
        ON dbo.products (category_id, product_id DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_products_status_approval_product_id')
BEGIN
    CREATE INDEX IX_products_status_approval_product_id
        ON dbo.products (status, approval_status, product_id DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_product_images_product_id_display_order')
BEGIN
    CREATE INDEX IX_product_images_product_id_display_order
        ON dbo.product_images (product_id, display_order ASC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_product_variants_product_id_is_active_price')
BEGIN
    CREATE INDEX IX_product_variants_product_id_is_active_price
        ON dbo.product_variants (product_id, is_active, price);
END
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_cart_items_cart_id_variant_id' AND object_id = OBJECT_ID(N'dbo.cart_items'))
BEGIN
    DROP INDEX UX_cart_items_cart_id_variant_id ON dbo.cart_items;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_cart_items_cart_id_variant_packaging_notnull' AND object_id = OBJECT_ID(N'dbo.cart_items'))
BEGIN
    CREATE UNIQUE INDEX UX_cart_items_cart_id_variant_packaging_notnull
        ON dbo.cart_items (cart_id, variant_id, packaging_id)
        WHERE packaging_id IS NOT NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_cart_items_cart_id_variant_no_packaging' AND object_id = OBJECT_ID(N'dbo.cart_items'))
BEGIN
    CREATE UNIQUE INDEX UX_cart_items_cart_id_variant_no_packaging
        ON dbo.cart_items (cart_id, variant_id)
        WHERE packaging_id IS NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_cart_items_cart_id_added_at')
BEGIN
    CREATE INDEX IX_cart_items_cart_id_added_at
        ON dbo.cart_items (cart_id, added_at DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_orders_customer_id_order_id_desc')
BEGIN
    CREATE INDEX IX_orders_customer_id_order_id_desc
        ON dbo.orders (customer_id, order_id DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_orders_parent_order_id')
BEGIN
    CREATE INDEX IX_orders_parent_order_id
        ON dbo.orders (parent_order_id, order_id);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_orders_owner_id_status_order_id_desc')
BEGIN
    CREATE INDEX IX_orders_owner_id_status_order_id_desc
        ON dbo.orders (owner_id, status, order_id DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_orders_owner_id_order_id_desc')
BEGIN
    CREATE INDEX IX_orders_owner_id_order_id_desc
        ON dbo.orders (owner_id, order_id DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_orders_status_order_id_desc')
BEGIN
    CREATE INDEX IX_orders_status_order_id_desc
        ON dbo.orders (status, order_id DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_order_items_order_id')
BEGIN
    CREATE INDEX IX_order_items_order_id
        ON dbo.order_items (order_id, order_item_id);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_order_items_variant_id')
BEGIN
    CREATE INDEX IX_order_items_variant_id
        ON dbo.order_items (variant_id, order_item_id);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_promotions_created_by_is_deleted_promo_id_desc')
BEGIN
    CREATE INDEX IX_promotions_created_by_is_deleted_promo_id_desc
        ON dbo.promotions (created_by, is_deleted, promo_id DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_promotions_product_scope_active_validity')
BEGIN
    CREATE INDEX IX_promotions_product_scope_active_validity
        ON dbo.promotions (product_id, scope, is_active, is_deleted, valid_from, valid_until);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_inventory_logs_variant_id_changed_at_desc')
BEGIN
    CREATE INDEX IX_inventory_logs_variant_id_changed_at_desc
        ON dbo.inventory_logs (variant_id, changed_at DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_return_requests_order_id_created_at_desc')
BEGIN
    CREATE INDEX IX_return_requests_order_id_created_at_desc
        ON dbo.return_requests (order_id, created_at DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_return_requests_customer_id_created_at_desc')
BEGIN
    CREATE INDEX IX_return_requests_customer_id_created_at_desc
        ON dbo.return_requests (customer_id, created_at DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_return_requests_status_created_at_desc')
BEGIN
    CREATE INDEX IX_return_requests_status_created_at_desc
        ON dbo.return_requests (status, created_at DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_shop_settlements_owner_id_settlement_id_desc')
BEGIN
    CREATE INDEX IX_shop_settlements_owner_id_settlement_id_desc
        ON dbo.shop_settlements (owner_id, settlement_id DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_shop_settlements_status_settlement_id_desc')
BEGIN
    CREATE INDEX IX_shop_settlements_status_settlement_id_desc
        ON dbo.shop_settlements (status, settlement_id DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_shop_settlement_orders_settlement_id_order_id')
BEGIN
    CREATE INDEX IX_shop_settlement_orders_settlement_id_order_id
        ON dbo.shop_settlement_orders (settlement_id, order_id);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_deliveries_staff_id_status_delivery_id_desc')
BEGIN
    CREATE INDEX IX_deliveries_staff_id_status_delivery_id_desc
        ON dbo.deliveries (staff_id, status, delivery_id DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_deliveries_delivery_trip_id')
BEGIN
    CREATE INDEX IX_deliveries_delivery_trip_id
        ON dbo.deliveries (delivery_trip_id, trip_stop_seq);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_deliveries_staff_id_delivery_id_desc')
BEGIN
    CREATE INDEX IX_deliveries_staff_id_delivery_id_desc
        ON dbo.deliveries (staff_id, delivery_id DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_reviews_order_item_id')
BEGIN
    CREATE INDEX IX_reviews_order_item_id
        ON dbo.reviews (order_item_id);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_chat_sessions_customer_owner')
BEGIN
    CREATE INDEX IX_chat_sessions_customer_owner
        ON dbo.chat_sessions (customer_id, owner_id);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_chat_sessions_customer_id_updated_at_desc')
BEGIN
    CREATE INDEX IX_chat_sessions_customer_id_updated_at_desc
        ON dbo.chat_sessions (customer_id, updated_at DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_chat_sessions_owner_id_updated_at_desc')
BEGIN
    CREATE INDEX IX_chat_sessions_owner_id_updated_at_desc
        ON dbo.chat_sessions (owner_id, updated_at DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_chat_messages_session_id_is_read_created_at_desc')
BEGIN
    CREATE INDEX IX_chat_messages_session_id_is_read_created_at_desc
        ON dbo.chat_messages (session_id, is_read, created_at DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_chat_messages_session_id_created_at_desc')
BEGIN
    CREATE INDEX IX_chat_messages_session_id_created_at_desc
        ON dbo.chat_messages (session_id, created_at DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_notifications_user_id_is_read_created_at_desc')
BEGIN
    CREATE INDEX IX_notifications_user_id_is_read_created_at_desc
        ON dbo.notifications (user_id, is_read, created_at DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_notifications_user_id_created_at_desc')
BEGIN
    CREATE INDEX IX_notifications_user_id_created_at_desc
        ON dbo.notifications (user_id, created_at DESC);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_payment_transactions_sepay_transaction_id')
BEGIN
    CREATE INDEX IX_payment_transactions_sepay_transaction_id
        ON dbo.payment_transactions (sepay_transaction_id);
END
GO

-- =========================================================
-- Seed data
-- =========================================================

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;

BEGIN TRY
    BEGIN TRAN;

    SET IDENTITY_INSERT dbo.users ON;
    INSERT INTO dbo.users (user_id, full_name, email, password_hash, phone, role, status, user_address, avatar_url, is_email_verified, email_verification_code_hash, email_verification_expires_at, email_verification_resend_at, email_verification_sent_at, failed_login_count, locked_until, created_at, updated_at)
    VALUES
        (1, N'Admin System', N'admin@fruitshop.local', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0900000001', N'ADMIN', N'ACTIVE', N'Central admin office', N'assets/images/default-avatar.svg', 1, NULL, NULL, NULL, NULL, 0, NULL, '2026-05-01T09:00:00', '2026-05-01T09:00:00'),
        (2, N'Delivery Nguyen', N'delivery@fruitshop.local', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0900000002', N'DELIVERY', N'ACTIVE', N'Delivery hub, HCMC', N'assets/images/default-avatar.svg', 1, NULL, NULL, NULL, NULL, 0, NULL, '2026-05-01T09:05:00', '2026-05-01T09:05:00'),
        (3, N'An Phu Orchard Owner', N'owner1@fruitshop.local', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0900000003', N'SHOP_OWNER', N'ACTIVE', N'12 Le Loi, District 1, HCMC', N'assets/images/default-avatar.svg', 1, NULL, NULL, NULL, NULL, 0, NULL, '2026-05-01T09:10:00', '2026-05-01T09:10:00'),
        (4, N'Mekong Fresh Owner', N'owner2@fruitshop.local', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0900000004', N'SHOP_OWNER', N'ACTIVE', N'88 Nguyen Trai, District 5, HCMC', N'assets/images/default-avatar.svg', 1, NULL, NULL, NULL, NULL, 0, NULL, '2026-05-01T09:15:00', '2026-05-01T09:15:00'),
        (5, N'Tran Minh Customer', N'customer1@fruitshop.local', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0900000005', N'CUSTOMER', N'ACTIVE', N'15 Pasteur, District 3, HCMC', N'assets/images/default-avatar.svg', 1, NULL, NULL, NULL, NULL, 0, NULL, '2026-05-01T09:20:00', '2026-05-01T09:20:00'),
        (6, N'Le Thu Customer', N'customer2@fruitshop.local', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0900000006', N'CUSTOMER', N'ACTIVE', N'90 Truong Chinh, Tan Binh, HCMC', N'assets/images/default-avatar.svg', 1, NULL, NULL, NULL, NULL, 0, NULL, '2026-05-01T09:25:00', '2026-05-01T09:25:00'),
        (7, N'Klever Premium Owner', N'owner3@fruitshop.local', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0900000007', N'SHOP_OWNER', N'ACTIVE', N'52 Vo Thi Sau, District 3, HCMC', N'assets/images/default-avatar.svg', 1, NULL, NULL, NULL, NULL, 0, NULL, '2026-05-01T09:30:00', '2026-05-01T09:30:00'),
        (10, N'Nguyễn Văn Hùng', N'hungnv@gmail.com', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0912345601', N'CUSTOMER', N'ACTIVE', N'12 Phố Cổ, Hà Nội', N'assets/images/default-avatar.svg', 1, NULL, NULL, NULL, NULL, 0, NULL, GETDATE(), GETDATE()),
        (11, N'Phạm Minh Tuấn', N'tuanpm@gmail.com', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0912345602', N'CUSTOMER', N'ACTIVE', N'85 Xuân Thủy, Cầu Giấy', N'assets/images/default-avatar.svg', 1, NULL, NULL, NULL, NULL, 0, NULL, GETDATE(), GETDATE()),
        (12, N'Trần Thị Mai', N'maitt@gmail.com', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0912345603', N'CUSTOMER', N'ACTIVE', N'45 Chùa Bộc, Đống Đa', N'assets/images/default-avatar.svg', 1, NULL, NULL, NULL, NULL, 0, NULL, GETDATE(), GETDATE()),
        (13, N'Lê Hoàng Nam', N'namlh@gmail.com', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0912345604', N'CUSTOMER', N'ACTIVE', N'102 Nguyễn Trãi, Thanh Xuân', N'assets/images/default-avatar.svg', 1, NULL, NULL, NULL, NULL, 0, NULL, GETDATE(), GETDATE()),
        (14, N'Đỗ Thùy Chi', N'chidt@gmail.com', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0912345605', N'CUSTOMER', N'ACTIVE', N'56 Bạch Mai, Hai Bạch Trưng', N'assets/images/default-avatar.svg', 1, NULL, NULL, NULL, NULL, 0, NULL, GETDATE(), GETDATE()),
        (15, N'Vũ Quốc Anh', N'anhvq@gmail.com', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0912345606', N'CUSTOMER', N'ACTIVE', N'29 Lạc Long Quân, Tây Hồ', N'assets/images/default-avatar.svg', 1, NULL, NULL, NULL, NULL, 0, NULL, GETDATE(), GETDATE()),
        (20, N'Test Admin', N'admin@metafruit.vn', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0988888001', N'ADMIN', N'ACTIVE', N'MetaFruit Office', N'assets/images/default-avatar.svg', 1, NULL, NULL, NULL, NULL, 0, NULL, GETDATE(), GETDATE()),
        (21, N'Test Shop Owner', N'shop@metafruit.vn', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0988888002', N'SHOP_OWNER', N'ACTIVE', N'100 Láng Hạ, Hà Nội', N'assets/images/default-avatar.svg', 1, NULL, NULL, NULL, NULL, 0, NULL, GETDATE(), GETDATE()),
        (22, N'Test Delivery', N'delivery@metafruit.vn', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0988888003', N'DELIVERY', N'ACTIVE', N'200 Cầu Giấy, Hà Nội', N'assets/images/default-avatar.svg', 1, NULL, NULL, NULL, NULL, 0, NULL, GETDATE(), GETDATE()),
        (23, N'Test Customer', N'customer@metafruit.vn', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0988888004', N'CUSTOMER', N'ACTIVE', N'300 Tây Sơn, Hà Nội', N'assets/images/default-avatar.svg', 1, NULL, NULL, NULL, NULL, 0, NULL, GETDATE(), GETDATE()),
        (8, N'Lê Minh Tuấn', N'customer3@fruitshop.local', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0900000008', N'CUSTOMER', N'ACTIVE', N'18 Nguyễn Du, District 1, HCMC', N'assets/images/default-avatar.svg', 1, NULL, NULL, NULL, NULL, 0, NULL, GETDATE(), GETDATE()),
        (9, N'Nguyễn Thị Lan', N'customer4@fruitshop.local', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0900000009', N'CUSTOMER', N'ACTIVE', N'45 Lê Lợi, Bến Nghé, HCMC', N'assets/images/default-avatar.svg', 1, NULL, NULL, NULL, NULL, 0, NULL, GETDATE(), GETDATE()),
        (26, N'Khách Hàng VIP', N'vipcustomer@fruitshop.local', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0988888005', N'CUSTOMER', N'ACTIVE', N'50 Lý Tự Trọng, HCMC', N'assets/images/default-avatar.svg', 1, NULL, NULL, NULL, NULL, 0, NULL, GETDATE(), GETDATE()),
        (27, N'Nguyễn Văn Đăng Ký', N'pending_shop1@fruitshop.local', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0911223344', N'CUSTOMER', N'ACTIVE', NULL, N'assets/images/default-avatar.svg', 0, NULL, NULL, NULL, NULL, 0, NULL, GETDATE(), GETDATE()),
        (28, N'Trần Thị Chờ Duyệt', N'pending_shop2@fruitshop.local', N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', N'0988776655', N'CUSTOMER', N'ACTIVE', NULL, N'assets/images/default-avatar.svg', 0, NULL, NULL, NULL, NULL, 0, NULL, GETDATE(), GETDATE());
    SET IDENTITY_INSERT dbo.users OFF;

    SET IDENTITY_INSERT dbo.user_sessions ON;
    INSERT INTO dbo.user_sessions (session_id, user_id, token, expires_at)
    VALUES
        (1, 1, N'sess-admin-001', '2026-05-17T23:59:00'),
        (2, 5, N'sess-customer-001', '2026-05-17T23:59:00'),
        (3, 3, N'sess-owner-001', '2026-05-10T23:59:00'),
        (4, 6, N'sess-customer-002', '2026-05-17T23:59:00');
    SET IDENTITY_INSERT dbo.user_sessions OFF;

    SET IDENTITY_INSERT dbo.shop_owner_profiles ON;
    INSERT INTO dbo.shop_owner_profiles (profile_id, user_id, shop_name, shop_description, approval_status, rejection_reason, approved_at, delivery_address, rating, preferred_categories, doc_paths, created_at, updated_at)
    VALUES
        (1, 3, N'An Phu Orchard', N'Premium citrus and banana supplier', N'APPROVED', NULL, '2026-05-02T10:00:00', N'12 Le Loi, District 1, HCMC', 4.88, N'[1,2,3]', N'["uploads/shop-docs/3/doc1.pdf"]', '2026-05-02T10:00:00', '2026-05-16T08:00:00'),
        (2, 4, N'Mekong Fresh Farm', N'Mango, berries, and grapes specialist', N'APPROVED', NULL, '2026-05-03T10:00:00', N'88 Nguyen Trai, District 5, HCMC', 4.76, N'[2,3,6]', N'["uploads/shop-docs/4/doc1.pdf"]', '2026-05-03T10:00:00', '2026-05-16T08:00:00'),
        (3, 7, N'Klever Premium Fruits', N'Imported fruits, gift boxes, and seasonal premium selections', N'APPROVED', NULL, '2026-05-04T10:00:00', N'52 Vo Thi Sau, District 3, HCMC', 4.91, N'[4,10]', N'["uploads/shop-docs/7/doc1.pdf"]', '2026-05-04T10:00:00', '2026-05-16T08:00:00'),
        (4, 21, N'MetaFruit Test Shop', N'Cửa hàng hoa quả tươi sạch phục vụ kiểm thử', N'APPROVED', NULL, GETDATE(), N'100 Láng Hạ, Hà Nội', 5.00, N'[1,2,5]', N'["uploads/shop-docs/21/doc1.pdf"]', GETDATE(), GETDATE()),
        (5, 27, N'Trái Cây Sạch Hữu Cơ', N'Cung cấp trái cây chuẩn VietGAP', N'PENDING', NULL, NULL, N'123 Đường VietGAP, Quận 1', 0, NULL, N'["uploads/docs/doc1.pdf"]', GETDATE(), GETDATE()),
        (6, 28, N'Đặc Sản Trái Cây Vùng Miền', N'Tất cả đặc sản trái cây 3 miền', N'PENDING', NULL, NULL, N'456 Vùng Miền, Quận 3', 0, NULL, N'["uploads/docs/doc2.pdf"]', GETDATE(), GETDATE());
    SET IDENTITY_INSERT dbo.shop_owner_profiles OFF;

    SET IDENTITY_INSERT dbo.categories ON;
    INSERT INTO dbo.categories (category_id, name, slug, display_order, is_active)
    VALUES
        (1, N'Cam, Bưởi, Quýt', N'cam-buoi-quyt', 1, 1),
        (2, N'Trái Cây Nhiệt Đới', N'trai-cay-nhiet-doi', 2, 1),
        (3, N'Quả Mọng & Dâu Tây', N'qua-mong-dau-tay', 3, 1),
        (4, N'Hộp Quà Trái Cây', N'hop-qua-trai-cay', 4, 1),
        (5, N'Táo Cao Cấp', N'tao-cao-cap', 5, 1),
        (6, N'Nho Không Hạt', N'nho-khong-hat', 6, 1),
        (7, N'Dưa Lưới & Dưa Hấu', N'dua-luoi-dua-hau', 7, 1),
        (8, N'Kiwi Tươi', N'kiwi-tuoi', 8, 1),
        (9, N'Cherry Nhập Khẩu', N'cherry-nhap-khau', 9, 1),
        (10, N'Trái Cây Hỗn Hợp', N'trai-cay-hon-hop', 10, 1);
    SET IDENTITY_INSERT dbo.categories OFF;

    SET IDENTITY_INSERT dbo.products ON;
    INSERT INTO dbo.products (product_id, owner_id, category_id, name, description, origin_country, origin_region, harvest_date, shelf_life_days, storage_instruction, status, view_count, rating, sold_quantity, created_at, updated_at)
    VALUES
        -- Category 1: Citrus
        (1, 3, 1, N'Cam Sành Cao Phong Hòa Bình', N'Cam sành Cao Phong nổi tiếng vỏ mỏng, mọng nước, vị ngọt thanh tự nhiên xen lẫn chua nhẹ thanh mát. Giàu Vitamin C, rất phù hợp làm nước ép giải nhiệt.', N'Việt Nam', N'Cao Phong, Hòa Bình', '2026-05-18', 12, N'Bảo quản mát ở nhiệt độ 6-10 độ C', N'ACTIVE', 1820, 4.80, 220, '2026-05-03T09:00:00', GETDATE()),
        (2, 3, 1, N'Bưởi Da Xanh Bến Tre loại đặc biệt', N'Bưởi da xanh ruột hồng tôm bưởi mọng nước, ráo nước, vị ngọt đậm đà không đắng, vỏ mỏng cực kỳ dễ bóc. Đạt tiêu chuẩn xuất khẩu.', N'Việt Nam', N'Chợ Lách, Bến Tre', '2026-05-06', 20, N'Bảo quản nơi khô ráo thoáng mát', N'ACTIVE', 1140, 4.92, 140, '2026-05-03T09:05:00', GETDATE()),
        -- Category 2: Tropical
        (3, 3, 2, N'Chuối Lùn Laba Đà Lạt', N'Chuối Laba trứ danh dẻo thơm, ngọt đậm, giàu chất xơ và kali. Sản xuất theo chuẩn hữu cơ không hóa chất, an toàn tuyệt đối cho trẻ nhỏ.', N'Việt Nam', N'Đức Trọng, Lâm Đồng', '2026-05-12', 7, N'Tránh ánh nắng trực tiếp, không để tủ lạnh khi chưa chín', N'ACTIVE', 980, 4.60, 260, '2026-05-03T09:10:00', GETDATE()),
        (4, 4, 2, N'Xoài Cát Hòa Lộc Tiền Giang', N'Đệ nhất xoài cát miền Tây, quả thon dài, khi chín vỏ vàng ươm, thịt quả vàng đậm, mịn không xơ, vị ngọt lịm thơm lừng khó quên.', N'Việt Nam', N'Cái Bè, Tiền Giang', '2026-05-07', 6, N'Bảo quản nhiệt độ phòng khi chín, giữ mát sau khi bổ', N'ACTIVE', 2150, 4.95, 180, '2026-05-03T09:15:00', GETDATE()),
        -- Category 3: Berries
        (5, 4, 3, N'Dâu Tây Đỏ Mỹ Nhập Khẩu Premium', N'Dâu tây đỏ nhập khẩu trực tiếp từ Mỹ, quả to đều, đỏ mọng nước, vị chua ngọt hài hòa đặc trưng, cùi dầy giòn ngọt thơm lừng.', N'Hoa Kỳ', N'California', '2026-05-10', 5, N'Giữ lạnh liên tục ở 2-4 độ C trong khay kín', N'ACTIVE', 760, 4.70, 96, '2026-05-03T09:20:00', GETDATE()),
        -- Category 7: Melons
        (6, 4, 7, N'Dưa Lưới Tươi Ruột Vàng VietGAP', N'Dưa lưới giống Nhật trồng nhà màng công nghệ cao, vỏ lưới dày đẹp mắt, cùi màu cam ruột vàng, giòn tan ngọt sắc mát lịm giải nhiệt.', N'Việt Nam', N'Đà Lạt, Lâm Đồng', '2026-05-09', 10, N'Giữ lạnh sau khi cắt để tăng độ giòn ngọt', N'ACTIVE', 840, 4.85, 72, '2026-05-03T09:25:00', GETDATE()),
        (7, 7, 7, N'Dưa Hấu Vuông Độc Lạ Tài Lộc', N'Quả dưa hấu được tạo hình vuông độc đáo mang ý nghĩa phong thủy may mắn tài lộc. Vỏ xanh thẫm mịn màng, ruột đỏ ngọt mát ít hạt.', N'Việt Nam', N'Vĩnh Long', '2026-05-11', 30, N'Trưng bày nơi khô ráo hoặc trữ lạnh ăn dần', N'ACTIVE', 1460, 4.78, 88, '2026-05-03T09:26:00', GETDATE()),
        -- Category 9: Cherries (Quả anh đào)
        (8, 7, 9, N'Cherry Đỏ Chile Nhập Khẩu Size Lớn', N'Cherry nhập khẩu chính ngạch từ nhà vườn Chile danh tiếng. Quả cứng trái màu đỏ sẫm óng ả, cuống tươi xanh, thịt ngọt giòn đậm đà.', N'Chile', N'O''Higgins', '2026-05-10', 7, N'Trữ lạnh ở 0-2 độ C, rửa sạch trước khi ăn', N'ACTIVE', 1325, 4.87, 64, '2026-05-03T09:27:00', GETDATE()),
        (9, 7, 9, N'Cherry Mỹ Premium Orchard View', N'Dòng Cherry Mỹ thượng hạng trứ danh thế giới từ thương hiệu Orchard View. Trái to vượt trội, giòn đôm đốp, ngọt lịm ngây ngất.', N'Hoa Kỳ', N'Washington', '2026-05-09', 6, N'Trữ tủ mát liên tục, tránh đè nén làm dập quả', N'ACTIVE', 1188, 4.90, 55, '2026-05-03T09:28:00', GETDATE()),
        -- Category 6: Grapes (Nho không hạt)
        (10, 7, 6, N'Nho Xanh Mẫu Đơn Không Hạt Chile', N'Nho xanh mẫu đơn không hạt Chile, chùm nho dày đặc quả tròn căng mọng, vỏ mỏng giòn sần sật, vị ngọt mát thơm hương sữa đặc trưng.', N'Chile', N'Maipo Valley', '2026-05-09', 12, N'Trữ mát tủ lạnh, không rửa trước khi cất trữ', N'ACTIVE', 1040, 4.83, 61, '2026-05-03T09:29:00', GETDATE()),
        -- Category 4: Gift Boxes (Hộp quà trái cây)
        (11, 7, 4, N'Hộp Quà Tết An Khang Phú Quý', N'Hộp quà tết sang trọng tinh tế kết hợp các loại trái cây nhập khẩu tươi ngon nhất. Món quà sức khỏe ý nghĩa kính tặng gia đình và đối tác.', N'Nhiều nước', N'Hộp quà cao cấp', '2026-05-08', 5, N'Bảo quản mát toàn bộ hộp quà tránh va đập', N'ACTIVE', 1575, 4.94, 44, '2026-05-03T09:30:00', GETDATE()),
        (12, 7, 4, N'Hộp Quà Trái Cây Tết Thịnh Vượng', N'Hộp quà tết rực rỡ màu sắc cát tường từ các loại quả cao cấp: dâu tây, táo, cam. Thiết kế hộp gỗ lót lụa sang trọng đẳng cấp.', N'Nhiều nước', N'Thiết kế VIP', '2026-05-09', 5, N'Giữ lạnh để giữ độ tươi ngon cao nhất', N'ACTIVE', 1210, 4.81, 73, '2026-05-03T09:31:00', GETDATE()),
        -- Category 10: Imported Mix (Trái cây hỗn hợp)
        (13, 7, 10, N'Giỏ Quả Trái Cây Sum Họp Ấm Áp', N'Giỏ trái cây đầy đặn sung túc tượng trưng cho gia đình đoàn viên ấm áp. Bao gồm lê Hàn Quốc, táo Mỹ, bưởi hồng đặc sản.', N'Nhiều nước', N'Lắp ráp thủ công', '2026-05-09', 6, N'Để nơi thoáng mát hoặc ngăn mát tủ lạnh', N'ACTIVE', 990, 4.79, 58, '2026-05-03T09:32:00', GETDATE()),
        (14, 7, 10, N'Giỏ Trái Cây Cát Tường Như Ý', N'Thiết kế giỏ quà kết hợp hoa tươi và trái cây nhập khẩu tinh tế. Thích hợp làm quà chúc mừng, khai trương, thăm hỏi cao cấp.', N'Nhiều nước', N'Giỏ hoa nghệ thuật', '2026-05-10', 4, N'Tránh nơi nhiệt độ cao, tưới ẩm hoa nhẹ nhàng', N'ACTIVE', 690, 4.88, 39, '2026-05-03T09:33:00', GETDATE()),
        (15, 7, 10, N'Giỏ Trái Cây Tài Lộc Thịnh Vượng', N'Giỏ quả được kết hợp tỉ mỉ từ nho đen ngón tay, lê vàng, hồng sấy thượng hạng đem lại tài lộc và phú quý cho người nhận.', N'Nhiều nước', N'Lắp ráp VIP', '2026-05-10', 6, N'Trữ mát để duy trì độ tươi giòn của quả', N'ACTIVE', 845, 4.84, 47, '2026-05-03T09:34:00', GETDATE()),
        -- Category 5: Apples (Táo cao cấp)
        (16, 7, 5, N'Táo Envy Mỹ Nhập Khẩu Premium', N'Táo Envy Mỹ giòn ngọt vượt trội, thịt táo trắng tinh khiết ít bị thâm khi cắt, hương thơm nồng nàn quyến rũ đặc trưng khó quên.', N'Hoa Kỳ', N'Washington', '2026-05-18', 15, N'Bảo quản mát ở nhiệt độ 2-4 độ C', N'ACTIVE', 1520, 4.88, 125, '2026-05-03T09:35:00', GETDATE()),
        -- Category 8: Kiwi (Kiwi tươi)
        (17, 7, 8, N'Kiwi Vàng New Zealand Zespri', N'Kiwi vàng Zespri thượng hạng từ New Zealand, vỏ mịn không lông, thịt quả màu vàng óng ả mọng nước, vị ngọt lịm như mật ong xen lẫn chua dịu thanh khiết.', N'New Zealand', N'Bay of Plenty', '2026-05-19', 14, N'Bảo quản mát tủ lạnh, ăn ngon hơn khi chín mềm tay', N'ACTIVE', 1380, 4.90, 110, '2026-05-03T09:36:00', GETDATE()),

        -- Category 1: Citrus (IDs 18-21)
        (18, 3, 1, N'Cam Vàng Navel Úc Nhập Khẩu', N'Cam vàng Navel nhập khẩu trực tiếp từ Úc, không hạt, quả to tròn láng mịn, vị ngọt lịm đậm đà mọng nước.', N'Australia', N'Mildura', '2026-05-18', 15, N'Bảo quản mát 2-4 độ C', N'ACTIVE', 620, 4.80, 45, GETDATE(), GETDATE()),
        (19, 3, 1, N'Chanh Không Hạt Vườn Long An', N'Chanh xanh không hạt trồng theo chuẩn VietGAP tại Long An. Vỏ mỏng, cực kỳ nhiều nước, vị chua thanh khiết đặc trưng.', N'Việt Nam', N'Bến Lức, Long An', '2026-05-20', 10, N'Bảo quản tủ mát', N'ACTIVE', 320, 4.65, 80, GETDATE(), GETDATE()),
        (20, 3, 1, N'Quất Đường Ngọt Hưng Yên', N'Quất ngọt (tắc ngọt) ăn cả vỏ ngọt lịm thơm mát, không đắng, ruột chua nhẹ giải nhiệt tiêu độc cực tốt.', N'Việt Nam', N'Khoái Châu, Hưng Yên', '2026-05-19', 8, N'Giữ lạnh tủ mát', N'ACTIVE', 450, 4.70, 35, GETDATE(), GETDATE()),
        (21, 3, 1, N'Bưởi Năm Roi Vĩnh Long Đậm Vị', N'Bưởi Năm Roi tép bưởi màu vàng nhạt, ráo nước, múi róc, vị chua ngọt hài hòa dễ ăn, quả càng héo ăn càng ngọt đậm.', N'Việt Nam', N'Bình Minh, Vĩnh Long', '2026-05-15', 30, N'Nơi khô ráo thoáng mát', N'ACTIVE', 780, 4.75, 92, GETDATE(), GETDATE()),

        -- Category 2: Tropical (IDs 22-39)
        (22, 3, 2, N'Sầu Riêng Ri6 Chín Hóa Bến Tre', N'Sầu riêng Ri6 cơm vàng hạt lép đệ nhất miền Tây. Cơm sầu riêng khô ráo, ngọt đậm đà béo ngậy ngây ngất lòng người.', N'Việt Nam', N'Chợ Lách, Bến Tre', '2026-05-22', 5, N'Nhiệt độ thường khi chưa khui, trữ lạnh cơm sầu riêng trong hộp kín', N'ACTIVE', 2500, 4.95, 230, GETDATE(), GETDATE()),
        (23, 4, 2, N'Măng Cụt Chín Đỏ Lái Thiêu', N'Măng cụt Lái Thiêu vỏ màu tím đỏ sẫm óng ả, múi măng cụt trắng ngần như hoa tuyết, vị chua ngọt thanh mát cực kỳ lôi cuốn.', N'Việt Nam', N'Thuận An, Bình Dương', '2026-05-21', 6, N'Bảo quản mát sau khi chín', N'ACTIVE', 1800, 4.88, 145, GETDATE(), GETDATE()),
        (24, 4, 2, N'Vải Thiều Lục Ngạn Bắc Giang loại 1', N'Vải thiều Lục Ngạn chính gốc, cùi dày giòn, hạt nhỏ lọt thỏm, vị ngọt sắc nước thơm đậm đà đặc trưng không đâu có được.', N'Việt Nam', N'Lục Ngạn, Bắc Giang', '2026-05-20', 4, N'Giữ lạnh ngăn mát tránh ẩm ướt để vỏ không thâm', N'ACTIVE', 1650, 4.92, 195, GETDATE(), GETDATE()),
        (25, 4, 2, N'Nhãn Xuồng Cơm Vàng Vũng Tàu', N'Nhãn xuồng cơm vàng trái to, vỏ mỏng màu da bò, cơm nhãn dày màu vàng nhạt, giòn tan vị ngọt mát thơm đậm đà.', N'Việt Nam', N'Đất Đỏ, Vũng Tàu', '2026-05-18', 6, N'Nơi thoáng mát hoặc trữ lạnh ăn dần', N'ACTIVE', 920, 4.78, 110, GETDATE(), GETDATE()),
        (26, 4, 2, N'Chôm Chôm Nhãn Bến Tre Giòn Ngọt', N'Chôm chôm nhãn (chôm chôm đường) quả nhỏ râu ngắn, vỏ đỏ pha vàng, cơm giòn tróc hạt, vị ngọt lịm đậm đà thơm mùi nhãn nhẹ.', N'Việt Nam', N'Mỏ Cày Bắc, Bến Tre', '2026-05-19', 5, N'Giữ ngăn mát tủ lạnh', N'ACTIVE', 850, 4.70, 130, GETDATE(), GETDATE()),
        (27, 4, 2, N'Thanh Long Ruột Đỏ Bình Thuận', N'Thanh long ruột đỏ vỏ hồng đậm mịn màng tai xanh mướt, ruột đỏ sậm mọng nước ngọt đậm đà giàu dinh dưỡng chống oxy hóa.', N'Việt Nam', N'Hàm Thuận Nam, Bình Thuận', '2026-05-17', 8, N'Bảo quản ngăn mát 6-8 độ C', N'ACTIVE', 1050, 4.82, 160, GETDATE(), GETDATE()),
        (28, 4, 2, N'Đu Đủ Ruột Đỏ Đài Loan Cần Thơ', N'Đu đủ giống Đài Loan ruột đỏ cam ngọt lịm không xơ, quả thuôn dài, giàu enzyme tiêu hóa tốt cho sức khỏe dạ dày.', N'Việt Nam', N'Phong Điền, Cần Thơ', '2026-05-16', 5, N'Nhiệt độ phòng khi chín, giữ lạnh sau khi gọt vỏ', N'ACTIVE', 580, 4.68, 75, GETDATE(), GETDATE()),
        (29, 3, 2, N'Dừa Xiêm Xanh Bến Tre Ngọt Mát', N'Dừa xiêm xanh nước ngọt lịm sảng khoái mát lành tự nhiên, cơm dừa non dẻo mềm bùi béo giải nhiệt mùa hè tuyệt đỉnh.', N'Việt Nam', N'Châu Thành, Bến Tre', '2026-05-15', 20, N'Trữ nơi khô ráo thoáng mát hoặc ướp lạnh nguyên quả', N'ACTIVE', 1450, 4.88, 310, GETDATE(), GETDATE()),
        (30, 3, 2, N'Mít Thái Ruột Đỏ Đắk Lắk Nguyên Khay', N'Mít Thái ruột đỏ xơ đỏ giòn sần sật ngọt lịm vị mật ong, hương thơm ngào ngạt đầy kích thích, đóng khay sạch sẽ tiện lợi.', N'Việt Nam', N'Buôn Ma Thuột, Đắk Lắk', '2026-05-16', 4, N'Giữ lạnh khay kín 4-6 độ C', N'ACTIVE', 960, 4.76, 85, GETDATE(), GETDATE()),
        (31, 3, 2, N'Vú Sữa Lò Rèn Vĩnh Kim Tiền Giang', N'Vú sữa Lò Rèn da láng mịn xanh trắng, ruột trắng sữa ngọt lịm thơm mát ngào ngạt như dòng sữa mẹ. Tinh hoa quả Việt.', N'Việt Nam', N'Vĩnh Kim, Tiền Giang', '2026-05-14', 6, N'Bảo quản mát, tránh xếp đè gây dập nát', N'ACTIVE', 890, 4.90, 68, GETDATE(), GETDATE()),
        (32, 4, 2, N'Na Dai Đông Triều Quảng Ninh', N'Na dai quả to đều mắt nở, cùi dày trắng tinh ít hạt, dai ngọt thơm nồng nàn. Đạt tiêu chuẩn an toàn VietGAP.', N'Việt Nam', N'Đông Triều, Quảng Ninh', '2026-05-13', 5, N'Nhiệt độ phòng cho chín mềm hẳn rồi trữ mát', N'ACTIVE', 740, 4.81, 52, GETDATE(), GETDATE()),
        (33, 4, 2, N'Dứa Mật Đơn Dương Lâm Đồng', N'Dứa mật Đơn Dương nhiều mật ngọt lịm không rát lưỡi, cùi dầy thơm nức phù hợp ăn trực tiếp hoặc ép nước uống giải độc.', N'Việt Nam', N'Đơn Dương, Lâm Đồng', '2026-05-14', 8, N'Nhiệt độ phòng, trữ mát sau khi gọt mắt', N'ACTIVE', 610, 4.70, 95, GETDATE(), GETDATE()),
        (34, 3, 2, N'Ổi Nữ Hoàng Sạch Long An Giòn Ngọt', N'Ổi Nữ Hoàng ruột nhỏ ít hạt giòn rau ráu thơm nhẹ thanh mát, giàu vitamin C vượt trội gấp nhiều lần cam chanh.', N'Việt Nam', N'Tân Thạnh, Long An', '2026-05-18', 7, N'Bảo quản mát tủ lạnh', N'ACTIVE', 530, 4.60, 140, GETDATE(), GETDATE()),
        (35, 3, 2, N'Cóc Non Ngọt Giòn Miền Tây Không Hạt', N'Cóc bao tử không hạt chua ngọt nhẹ giòn tan, ăn kèm muối ớt tây ninh cay nồng kích thích vị giác cực đỉnh.', N'Việt Nam', N'Vĩnh Long', '2026-05-16', 10, N'Giữ ngăn mát tủ lạnh ăn kèm muối ớt', N'ACTIVE', 480, 4.65, 115, GETDATE(), GETDATE()),
        (36, 7, 2, N'Bơ Sáp 034 Đắk Lắk Dẻo Bùi', N'Bơ sáp 034 hình dáng dài thon hạt cực nhỏ, thịt bơ vàng đậm dẻo quánh béo ngậy không xơ sơ chế sinh tố cực ngon.', N'Việt Nam', N'Cư M''gar, Đắk Lắk', '2026-05-18', 6, N'Ủ chín nhiệt độ thường, trữ lạnh sau khi bổ đôi bơ', N'ACTIVE', 1250, 4.83, 105, GETDATE(), GETDATE()),
        (37, 7, 2, N'Chanh Leo Ruột Vàng Đà Lạt Đậm Vị', N'Chanh leo ruột vàng (chanh dây) da trơn, dịch ruột vàng ươm thơm lừng chua ngọt đậm đà pha nước uống mùa hè mát lịm.', N'Việt Nam', N'Đức Trọng, Lâm Đồng', '2026-05-19', 15, N'Tránh ánh nắng, giữ tủ lạnh mát', N'ACTIVE', 670, 4.72, 88, GETDATE(), GETDATE()),
        (38, 7, 2, N'Mận Hậu Sơn La Giòn Chua Cay', N'Mận hậu Sơn La quả to đỏ mọng bao phủ phấn trắng cùi dầy giòn chua ngọt đậm đà đốn tim tín đồ ăn vặt.', N'Việt Nam', N'Mộc Châu, Sơn La', '2026-05-20', 12, N'Rửa sạch giữ lạnh ăn kèm muối tôm', N'ACTIVE', 1580, 4.85, 290, GETDATE(), GETDATE()),
        (39, 7, 2, N'Hồng Xiêm Xuân Đỉnh Ngọt Mát', N'Hồng xiêm (xa pô chê) cát mịn ngọt lịm mát lành, thơm dịu quý phái đặc trưng vùng đất tổ Xuân Đỉnh Hà Nội.', N'Việt Nam', N'Xuân Đỉnh, Hà Nội', '2026-05-17', 8, N'Để chín mềm hẳn sờ tay thấy mềm đều mới gọt vỏ ăn', N'ACTIVE', 420, 4.62, 40, GETDATE(), GETDATE()),

        -- Category 3: Berries (IDs 40-42)
        (40, 7, 3, N'Việt Quất Xanh Mỹ Hộp Lớn', N'Việt quất xanh (Blueberries) nhập khẩu Mỹ quả to tròn căng bóng phủ lớp phấn tự nhiên, vị ngọt thanh chứa nhiều chất bổ não.', N'Hoa Kỳ', N'Oregon', '2026-05-15', 8, N'Giữ lạnh liên tục 2-4 độ C trong hộp nhựa', N'ACTIVE', 930, 4.88, 62, GETDATE(), GETDATE()),
        (41, 7, 3, N'Dâu Tây Bạch Tuyết Nhật Bản VIP', N'Dâu tây trắng (Dâu Bạch Tuyết) giống Nhật Bản đắt đỏ bậc nhất thế giới. Hương vị thơm ngọt như dứa, cùi giòn trắng tuyết độc đáo.', N'Nhật Bản', N'Nara', '2026-05-16', 4, N'Nâng niu giữ mát hộp xốp tránh dập nát', N'ACTIVE', 1100, 4.96, 25, GETDATE(), GETDATE()),
        (42, 7, 3, N'Mâm Xôi Đỏ Đà Lạt VietGAP', N'Quả mâm xôi đỏ (Raspberry) Đà Lạt tơi xốp đỏ hồng mọng nước chua ngọt mát lạnh giàu dinh dưỡng làm kem mứt sang xịn.', N'Việt Nam', N'Đà Lạt, Lâm Đồng', '2026-05-17', 4, N'Giữ khay lạnh ăn ngay hoặc làm mứt đông lạnh', N'ACTIVE', 490, 4.70, 30, GETDATE(), GETDATE()),

        -- Category 5: Apples (IDs 43-44)
        (43, 7, 5, N'Táo Gala Pháp Giòn Ngọt Nhẹ', N'Táo Gala nhập khẩu chính ngạch từ Pháp vỏ sọc đỏ vàng bắt mắt cùi giòn ngọt vừa phải thanh mát thích hợp ăn hàng ngày.', N'Pháp', N'Val de Loire', '2026-05-18', 25, N'Giữ mát 2-6 độ C', N'ACTIVE', 690, 4.64, 78, GETDATE(), GETDATE()),
        (44, 7, 5, N'Táo Fuji Nhật Bản Quà Tặng VIP', N'Táo đỏ Fuji Nhật Bản trái siêu to tròn đẹp, vị ngọt đậm đà cùi chắc giòn tan thích hợp làm quà tặng ngoại giao đẳng cấp.', N'Nhật Bản', N'Aomori', '2026-05-20', 30, N'Giữ mát liên tục tủ lạnh', N'ACTIVE', 1250, 4.90, 38, GETDATE(), GETDATE()),

        -- Category 6: Grapes (IDs 45-46)
        (45, 7, 6, N'Nho Đen Ngón Tay Mỹ Sweet Sapphire', N'Nho đen ngón tay Sweet Sapphire Mỹ giống nho dài độc lạ giòn tan ngọt đậm lịm không hạt thơm thoang thoảng quý tộc.', N'Hoa Kỳ', N'California', '2026-05-19', 14, N'Trữ tủ mát tránh đè nén làm rụng quả', N'ACTIVE', 1450, 4.91, 85, GETDATE(), GETDATE()),
        (46, 7, 6, N'Nho Đỏ Không Hạt Úc Giòn Ngọt', N'Nho đỏ không hạt Úc chùm to khít quả tròn giòn đôm đốp vị ngọt dịu xen chút chua mát kích thích vị giác giải nhiệt cực tốt.', N'Australia', N'Sunraysia', '2026-05-18', 12, N'Giữ mát tủ lạnh không rửa trước khi cất trữ', N'ACTIVE', 890, 4.74, 94, GETDATE(), GETDATE()),

        -- Category 7: Melons (ID 47)
        (47, 7, 7, N'Dưa Hấu Không Hạt Mặt Trời Đỏ', N'Dưa hấu không hạt Mặt Trời Đỏ giống chất lượng vỏ sọc xanh ruột đỏ tươi ngọt lịm mọng nước giải nhiệt giải khát hè cực đã.', N'Việt Nam', N'Long An', '2026-05-19', 20, N'Trữ mát tủ lạnh ăn ngon hơn', N'ACTIVE', 1340, 4.80, 165, GETDATE(), GETDATE()),

        -- Category 8: Kiwi (ID 48)
        (48, 7, 8, N'Kiwi Xanh New Zealand Zespri Giòn Chua', N'Kiwi xanh Zespri nhiều lông tơ thịt quả xanh ngọc chấm hạt đen giòn giòn chua thanh đậm vị giàu chất xơ hỗ trợ giảm cân hiệu quả.', N'New Zealand', N'Bay of Plenty', '2026-05-18', 15, N'Giữ mát ăn ngon hơn khi chín hơi mềm tay', N'ACTIVE', 760, 4.70, 112, GETDATE(), GETDATE()),

        -- Category 9: Cherries (ID 49)
        (49, 7, 9, N'Cherry Vàng Rainier Mỹ Orchard View', N'Cherry vàng Rainier được ví như nữ hoàng cherry trái màu vàng ửng hồng cùi giòn chắc ngọt đậm đà bậc nhất thế giới.', N'Hoa Kỳ', N'Washington', '2026-05-18', 6, N'Trữ mát liên tục trong hộp kín', N'ACTIVE', 1050, 4.94, 32, GETDATE(), GETDATE()),

        -- Category 4: Gift Boxes (ID 50)
        (50, 7, 4, N'Hộp Quà Trái Cây Phú Quý Cát Tường', N'Hộp quà gỗ thắt nơ đỏ cao cấp kết hợp táo Envy, nho ngón tay và lê Hàn Quốc. Lựa chọn quà biếu tặng hoàn hảo nhất.', N'Nhiều nước', N'Lắp ráp VIP', '2026-05-19', 5, N'Giữ mát toàn bộ hộp quà tránh va đập', N'ACTIVE', 880, 4.92, 29, GETDATE(), GETDATE());

    -- Chèn thêm sản phẩm mới theo cấu trúc database nâng cấp
    INSERT INTO dbo.products (product_id, owner_id, category_id, name, description, origin_country, origin_region, harvest_date, shelf_life_days, storage_instruction, status, view_count, rating, sold_quantity, is_organic, is_imported, season_start_month, season_end_month, approval_status, verification_doc_path, rejection_reason, created_at, updated_at)
    VALUES
        (51, 3, 6, N'Nho Mẫu Đơn Hữu Cơ Cao Cấp', N'Nho mẫu đơn hữu cơ quả to tròn giòn ngọt thơm sữa đặc trưng giống Nhật Bản.', N'Nhật Bản', N'Okayama', '2026-06-01', 10, N'Bảo quản mát 2-4 độ C', N'ACTIVE', 150, 5.0, 10, 1, 1, NULL, NULL, N'APPROVED', NULL, NULL, GETDATE(), GETDATE()),
        (52, 7, 9, N'Cherry Hữu Cơ New Zealand', N'Cherry hữu cơ nhập khẩu chính ngạch từ New Zealand quả cứng giòn ngọt đậm đà.', N'New Zealand', N'Otago', '2026-06-02', 7, N'Bảo quản mát 0-2 độ C', N'ACTIVE', 80, 4.9, 5, 1, 1, 11, 2, N'APPROVED', NULL, NULL, GETDATE(), GETDATE()),
        (53, 3, 1, N'Bưởi Da Xanh Hữu Cơ VietGAP', N'Bưởi da xanh hữu cơ bóc sẵn tép mọng nước ráo nước ngọt thanh.', N'Việt Nam', N'Bến Tre', '2026-06-03', 15, N'Nơi thoáng mát', N'ACTIVE', 95, 4.8, 12, 1, 0, NULL, NULL, N'APPROVED', NULL, NULL, GETDATE(), GETDATE()),
        (54, 3, 1, N'Cam Sành Hữu Cơ Chờ Duyệt', N'Cam sành hữu cơ nhiều nước vỏ mỏng thơm mát đang chờ admin duyệt hồ sơ chứng nhận.', N'Việt Nam', N'Hòa Bình', '2026-06-04', 12, N'Bảo quản mát 6-10 độ C', N'ACTIVE', 0, 0.0, 0, 1, 0, NULL, NULL, N'PENDING', N'uploads/docs/cam_doc_confirm.pdf', NULL, GETDATE(), GETDATE()),
        (55, 7, 5, N'Táo Envy Nhập Khẩu Bị Từ Chối', N'Táo Envy nhập khẩu nhưng hồ sơ chứng nhận bị admin từ chối duyệt.', N'Hoa Kỳ', N'Washington', '2026-06-05', 15, N'Bảo quản mát 2-4 độ C', N'ACTIVE', 0, 0.0, 0, 0, 1, NULL, NULL, N'REJECTED', N'uploads/docs/tao_doc_rejection.pdf', N'Thiếu giấy tờ kiểm định thực vật nhập khẩu.', GETDATE(), GETDATE()),
        (56, 3, 2, N'Bơ Sáp Đắk Lắk Hữu Cơ VIP', N'Bơ sáp Đắk Lắk hữu cơ dẻo béo ngậy thơm ngon giàu dinh dưỡng tốt cho sức khỏe.', N'Việt Nam', N'Đắk Lắk', '2026-06-01', 7, N'Bảo quản nơi thoáng mát', N'ACTIVE', 120, 4.8, 15, 1, 0, NULL, NULL, N'APPROVED', NULL, NULL, GETDATE(), GETDATE()),
        (57, 7, 1, N'Cam Vàng Ai Cập Nhập Khẩu', N'Cam vàng Ai Cập nhập khẩu chính ngạch mọng nước vị chua ngọt thanh mát.', N'Ai Cập', N'Cairo', '2026-06-02', 20, N'Bảo quản mát tủ lạnh 4-8 độ C', N'ACTIVE', 90, 4.6, 8, 0, 1, NULL, NULL, N'APPROVED', NULL, NULL, GETDATE(), GETDATE()),
        (58, 7, 3, N'Dâu Tây Hàn Quốc Premium', N'Dâu tây Hàn Quốc quả to đều đỏ mọng thơm ngào ngạt vị ngọt thanh.', N'Hàn Quốc', N'Gyeonggi', '2026-06-03', 5, N'Bảo quản mát tủ lạnh 2-4 độ C', N'ACTIVE', 200, 4.9, 25, 0, 1, 12, 3, N'APPROVED', NULL, NULL, GETDATE(), GETDATE()),
        (59, 7, 6, N'Nho Đen Ngón Tay Úc Hữu Cơ', N'Nho đen ngón tay Úc hữu cơ giòn ngọt đầm đà không hạt cực kỳ sang trọng.', N'Úc', N'Mildura', '2026-06-02', 12, N'Bảo quản mát tủ lạnh 0-2 độ C', N'ACTIVE', 310, 4.95, 45, 1, 1, NULL, NULL, N'APPROVED', NULL, NULL, GETDATE(), GETDATE()),
        (60, 7, 2, N'Lê Nam Phi Nhập Khẩu Cao Cấp', N'Lê Nam Phi quả thon dài da sần đỏ vàng giòn ngọt mọng nước giải nhiệt cực tốt.', N'Nam Phi', N'Western Cape', '2026-06-01', 15, N'Bảo quản mát tủ lạnh 2-4 độ C', N'ACTIVE', 110, 4.7, 18, 0, 1, NULL, NULL, N'APPROVED', NULL, NULL, GETDATE(), GETDATE()),
        (61, 3, 2, N'Măng Cụt Bến Tre Hữu Cơ', N'Măng cụt Bến Tre hữu cơ vỏ mỏng múi trắng ngần vị chua ngọt hài hòa.', N'Việt Nam', N'Bến Tre', '2026-06-03', 8, N'Bảo quản mát hoặc nhiệt độ thường', N'ACTIVE', 145, 4.85, 30, 1, 0, 5, 8, N'APPROVED', NULL, NULL, GETDATE(), GETDATE()),
        (62, 3, 1, N'Quýt Đường Miền Tây Hữu Cơ', N'Quýt đường vỏ mỏng dễ bóc tép mọng nước ngọt đậm đà thơm tự nhiên.', N'Việt Nam', N'Đồng Tháp', '2026-06-02', 10, N'Bảo quản mát tủ lạnh hoặc nơi thoáng gió', N'ACTIVE', 85, 4.75, 14, 1, 0, NULL, NULL, N'APPROVED', NULL, NULL, GETDATE(), GETDATE()),
        (63, 7, 5, N'Táo Rockit New Zealand Nhập Khẩu', N'Táo Rockit ống 4 quả giòn đanh ngọt đậm vỏ đỏ đẹp mắt rất được ưa chuộng.', N'New Zealand', N'Hawkes Bay', '2026-06-01', 30, N'Bảo quản mát tủ lạnh 2-4 độ C', N'ACTIVE', 400, 4.9, 100, 0, 1, NULL, NULL, N'APPROVED', NULL, NULL, GETDATE(), GETDATE()),
        (64, 3, 7, N'Dưa Lưới Tabi Hữu Cơ VietGAP', N'Dưa lưới Tabi ruột cam giòn ngọt lịm thơm mát lưới dày đẹp mắt.', N'Việt Nam', N'Bình Dương', '2026-06-02', 14, N'Bảo quản mát hoặc nhiệt độ phòng', N'ACTIVE', 130, 4.8, 22, 1, 0, NULL, NULL, N'APPROVED', NULL, NULL, GETDATE(), GETDATE()),
        (65, 7, 3, N'Việt Quất Mỹ Nhập Khẩu Hộp 125g', N'Việt quất quả to tròn cứng giòn ngọt lịm mọng nước cực nhiều dinh dưỡng.', N'Hoa Kỳ', N'Oregon', '2026-06-01', 10, N'Bảo quản mát 2-4 độ C giữ trong hộp kín', N'ACTIVE', 180, 4.9, 35, 0, 1, 6, 9, N'APPROVED', NULL, NULL, GETDATE(), GETDATE()),
        (66, 7, 9, N'Cherry Đỏ Mỹ Size 9.5 Premium', N'Cherry đỏ Mỹ size lớn quả cứng như đá giòn ngọt đậm đà màu đỏ sẫm sang trọng.', N'Hoa Kỳ', N'California', '2026-06-02', 7, N'Bảo quản mát liên tục 0-2 độ C', N'ACTIVE', 280, 4.92, 50, 0, 1, 5, 8, N'APPROVED', NULL, NULL, GETDATE(), GETDATE()),
        (67, 3, 2, N'Hồng Giòn Đà Lạt Hữu Cơ', N'Hồng giòn Đà Lạt hữu cơ quả vàng cam ăn giòn rôm rốp ngọt thanh không chát.', N'Việt Nam', N'Lâm Đồng', '2026-06-03', 10, N'Bảo quản mát để giữ độ giòn', N'ACTIVE', 95, 4.7, 19, 1, 0, 9, 11, N'APPROVED', NULL, NULL, GETDATE(), GETDATE()),
        (68, 3, 2, N'Na Chi Lăng Lạng Sơn Hữu Cơ', N'Na Chi Lăng quả to mắt giãn đều thịt dày dai ngọt đậm đà thơm phức.', N'Việt Nam', N'Lạng Sơn', '2026-06-04', 5, N'Tránh va đập bảo quản nơi thoáng mát', N'ACTIVE', 110, 4.8, 12, 1, 0, 8, 10, N'APPROVED', NULL, NULL, GETDATE(), GETDATE()),
        (69, 7, 2, N'Sầu Riêng Musang King Malaysia', N'Sầu riêng Musang King nhập khẩu múi vàng đậm cơm dẻo mịn béo ngậy ngọt lịm.', N'Malaysia', N'Pahang', '2026-06-02', 15, N'Bảo quản ngăn mát hoặc đông lạnh', N'ACTIVE', 350, 4.96, 40, 0, 1, NULL, NULL, N'APPROVED', NULL, NULL, GETDATE(), GETDATE()),
        (70, 3, 2, N'Vải Thiều Lục Ngạn Hữu Cơ', N'Vải thiều Lục Ngạn hữu cơ quả to cùi dày hạt nhỏ ngọt lịm thơm nồng.', N'Việt Nam', N'Bắc Giang', '2026-06-05', 6, N'Bảo quản mát tránh để ngoài nhiệt độ cao', N'ACTIVE', 220, 4.88, 70, 1, 0, 5, 7, N'APPROVED', NULL, NULL, GETDATE(), GETDATE());
    SET IDENTITY_INSERT dbo.products OFF;

    SET IDENTITY_INSERT dbo.product_images ON;
    INSERT INTO dbo.product_images (image_id, product_id, file_path, display_order, is_primary, uploaded_at)
    VALUES
        (1, 1, N'assets/images/cam_sanh.png', 1, 1, GETDATE()),
        (2, 2, N'assets/images/buoi_da_xanh.png', 1, 1, GETDATE()),
        (3, 3, N'assets/images/chuoi_laba.png', 1, 1, GETDATE()),
        (4, 4, N'assets/images/xoai_cat.png', 1, 1, GETDATE()),
        (5, 5, N'assets/images/dau_tay.png', 1, 1, GETDATE()),
        (6, 5, N'assets/images/dau_tay.png', 2, 0, GETDATE()),
        (7, 6, N'assets/images/dua_luoi.png', 1, 1, GETDATE()),
        (8, 6, N'assets/images/dua_luoi.png', 2, 0, GETDATE()),
        (9, 7, N'assets/images/dua_hau_vuong.png', 1, 1, GETDATE()),
        (10, 8, N'assets/images/cherry_do.png', 1, 1, GETDATE()),
        (11, 9, N'assets/images/cherry_my.png', 1, 1, GETDATE()),
        (12, 10, N'assets/images/nho_xanh.png', 1, 1, GETDATE()),
        (13, 11, N'assets/images/hop_qua_tet.png', 1, 1, GETDATE()),
        (14, 11, N'assets/images/hop_qua_tet.png', 2, 0, GETDATE()),
        (15, 12, N'assets/images/hop_qua_thinh_vuong.png', 1, 1, GETDATE()),
        (16, 12, N'assets/images/hop_qua_thinh_vuong.png', 2, 0, GETDATE()),
        (17, 13, N'assets/images/gio_qua_sum_hop.png', 1, 1, GETDATE()),
        (18, 14, N'assets/images/gio_qua_cat_tuong.png', 1, 1, GETDATE()),
        (19, 15, N'assets/images/gio_qua_tai_loc.png', 1, 1, GETDATE()),
        (20, 15, N'assets/images/gio_qua_tai_loc.png', 2, 0, GETDATE()),
        -- Táo Envy Mỹ (16)
        (21, 16, N'assets/images/tao_envy.png', 1, 1, GETDATE()),
        -- Kiwi Vàng (17)
        (22, 17, N'assets/images/kiwi_vang.png', 1, 1, GETDATE()),

        -- Cam Vàng Navel Úc (18) -> Use local cam_sanh.png
        (23, 18, N'assets/images/cam_sanh.png', 1, 1, GETDATE()),
        -- Chanh Không Hạt (19) -> Use local chanh_khong_hat.png
        (24, 19, N'assets/images/chanh_khong_hat.png', 1, 1, GETDATE()),
        -- Quất Đường (20) -> Use local quat_duong.png
        (25, 20, N'assets/images/quat_duong.png', 1, 1, GETDATE()),
        -- Bưởi Năm Roi (21) -> Use local buoi_da_xanh.png
        (26, 21, N'assets/images/buoi_da_xanh.png', 1, 1, GETDATE()),
        -- Sầu Riêng Ri6 (22) -> Use generated sau_rieng_ri6.png
        (27, 22, N'assets/images/sau_rieng_ri6.png', 1, 1, GETDATE()),
        -- Măng Cụt (23) -> Use generated mang_cut.png
        (28, 23, N'assets/images/mang_cut.png', 1, 1, GETDATE()),
        -- Vải Thiều (24) -> Use local vai_thieu.png
        (29, 24, N'assets/images/vai_thieu.png', 1, 1, GETDATE()),
        -- Nhãn Xuồng (25) -> Use local nhan_xuong.png
        (30, 25, N'assets/images/nhan_xuong.png', 1, 1, GETDATE()),
        -- Chôm Chôm (26) -> Use local chom_chom.png
        (31, 26, N'assets/images/chom_chom.png', 1, 1, GETDATE()),
        -- Thanh Long (27) -> Use local thanh_long.png
        (32, 27, N'assets/images/thanh_long.png', 1, 1, GETDATE()),
        -- Đu Đủ (28) -> Use local du_du.png
        (33, 28, N'assets/images/du_du.png', 1, 1, GETDATE()),
        -- Dừa Xiêm (29) -> Use local chuoi_laba.png
        (34, 29, N'assets/images/chuoi_laba.png', 1, 1, GETDATE()),
        -- Mít Thái (30) -> Use local mit_thai.png
        (35, 30, N'assets/images/mit_thai.png', 1, 1, GETDATE()),
        -- Vú Sữa (31) -> Use local vu_sua.png
        (36, 31, N'assets/images/vu_sua.png', 1, 1, GETDATE()),
        -- Na Dai (32) -> Use local na_dai.png
        (37, 32, N'assets/images/na_dai.png', 1, 1, GETDATE()),
        -- Dứa Mật (33) -> Use local dua_mat.png
        (38, 33, N'assets/images/dua_mat.png', 1, 1, GETDATE()),
        -- Ổi Nữ Hoàng (34) -> Use local oi_nu_hoang.png
        (39, 34, N'assets/images/oi_nu_hoang.png', 1, 1, GETDATE()),
        -- Cóc Non (35) -> Use local coc_non.png
        (40, 35, N'assets/images/coc_non.png', 1, 1, GETDATE()),
        -- Bơ Sáp (36) -> Use local bo_sap.png
        (41, 36, N'assets/images/bo_sap.png', 1, 1, GETDATE()),
        -- Chanh Leo (37) -> Use local chanh_leo.png
        (42, 37, N'assets/images/chanh_leo.png', 1, 1, GETDATE()),
        -- Mận Hậu (38) -> Use local man_hau.png
        (43, 38, N'assets/images/man_hau.png', 1, 1, GETDATE()),
        -- Hồng Xiêm (39) -> Use local hong_xiem.png
        (44, 39, N'assets/images/hong_xiem.png', 1, 1, GETDATE()),
        -- Việt Quất (40) -> Use local nho_xanh.png
        (45, 40, N'assets/images/nho_xanh.png', 1, 1, GETDATE()),
        -- Dâu Tây Bạch Tuyết (41) -> Use local dau_tay.png
        (46, 41, N'assets/images/dau_tay.png', 1, 1, GETDATE()),
        -- Mâm Xôi Đỏ (42) -> Use local dau_tay.png
        (47, 42, N'assets/images/dau_tay.png', 1, 1, GETDATE()),
        -- Táo Gala (43) -> Use local tao_envy.png
        (48, 43, N'assets/images/tao_envy.png', 1, 1, GETDATE()),
        -- Táo Fuji (44) -> Use local tao_envy.png
        (49, 44, N'assets/images/tao_envy.png', 1, 1, GETDATE()),
        -- Nho Đen Ngón Tay (45) -> Use local nho_xanh.png
        (50, 45, N'assets/images/nho_xanh.png', 1, 1, GETDATE()),
        -- Nho Đỏ (46) -> Use local nho_xanh.png
        (51, 46, N'assets/images/nho_xanh.png', 1, 1, GETDATE()),
        -- Dưa Hấu Không Hạt (47) -> Use local dua_hau_vuong.png
        (52, 47, N'assets/images/dua_hau_vuong.png', 1, 1, GETDATE()),
        -- Kiwi Xanh (48) -> Use local kiwi_vang.png
        (53, 48, N'assets/images/kiwi_vang.png', 1, 1, GETDATE()),
        -- Cherry Vàng (49) -> Use local cherry_do.png
        (54, 49, N'assets/images/cherry_do.png', 1, 1, GETDATE()),
        -- Hộp Quà Phú Quý (50) -> Use local hop_qua_tet.png
        (55, 50, N'assets/images/hop_qua_tet.png', 1, 1, GETDATE()),
        -- Nho Mẫu Đơn Hữu Cơ (51)
        (56, 51, N'assets/images/nho_xanh.png', 1, 1, GETDATE()),
        -- Cherry Hữu Cơ (52)
        (57, 52, N'assets/images/cherry_do.png', 1, 1, GETDATE()),
        -- Bưởi Da Xanh Hữu Cơ (53)
        (58, 53, N'assets/images/buoi_da_xanh.png', 1, 1, GETDATE()),
        -- Cam Sành Hữu Cơ (54)
        (59, 54, N'assets/images/cam_sanh.png', 1, 1, GETDATE()),
        -- Táo Envy Nhập Khẩu (55)
        (60, 55, N'assets/images/tao_envy.png', 1, 1, GETDATE()),
        -- Bơ Sáp Đắk Lắk (56)
        (61, 56, N'assets/images/bo_sap.png', 1, 1, GETDATE()),
        -- Cam Vàng Ai Cập (57)
        (62, 57, N'assets/images/cam_sanh.png', 1, 1, GETDATE()),
        -- Dâu Tây Hàn Quốc (58)
        (63, 58, N'assets/images/dau_tay.png', 1, 1, GETDATE()),
        -- Nho Đen Ngón Tay (59)
        (64, 59, N'assets/images/nho_xanh.png', 1, 1, GETDATE()),
        -- Lê Nam Phi (60)
        (65, 60, N'assets/images/kiwi_vang.png', 1, 1, GETDATE()),
        -- Măng Cụt Bến Tre (61)
        (66, 61, N'assets/images/mang_cut.png', 1, 1, GETDATE()),
        -- Quýt Đường Miền Tây (62)
        (67, 62, N'assets/images/quat_duong.png', 1, 1, GETDATE()),
        -- Táo Rockit (63)
        (68, 63, N'assets/images/tao_envy.png', 1, 1, GETDATE()),
        -- Dưa Lưới Tabi (64)
        (69, 64, N'assets/images/dua_luoi.png', 1, 1, GETDATE()),
        -- Việt Quất Mỹ (65)
        (70, 65, N'assets/images/nho_xanh.png', 1, 1, GETDATE()),
        -- Cherry Đỏ Mỹ (66)
        (71, 66, N'assets/images/cherry_do.png', 1, 1, GETDATE()),
        -- Hồng Giòn Đà Lạt (67)
        (72, 67, N'assets/images/xoai_cat.png', 1, 1, GETDATE()),
        -- Na Chi Lăng (68)
        (73, 68, N'assets/images/na_dai.png', 1, 1, GETDATE()),
        -- Sầu Riêng Musang King (69)
        (74, 69, N'assets/images/sau_rieng_ri6.png', 1, 1, GETDATE()),
        -- Vải Thiều Lục Ngạn (70)
        (75, 70, N'assets/images/vai_thieu.png', 1, 1, GETDATE());
    SET IDENTITY_INSERT dbo.product_images OFF;

    SET IDENTITY_INSERT dbo.product_variants ON;
    INSERT INTO dbo.product_variants (variant_id, product_id, sku, variant_label, price, stock_quantity, is_active, created_at, updated_at)
    VALUES
        (1, 1, N'CAM-SANH-1KG', N'Hộp 1kg', 35000.00, 150, 1, '2026-05-03T09:40:00', '2026-05-16T08:10:00'),
        (2, 1, N'CAM-SANH-3KG', N'Combo 3kg', 95000.00, 80, 1, '2026-05-03T09:40:00', '2026-05-16T08:10:00'),
        (3, 2, N'BUOI-DX-1P2KG', N'Quả 1.2kg - 1.4kg', 65000.00, 120, 1, '2026-05-03T09:41:00', '2026-05-16T08:10:00'),
        (4, 2, N'BUOI-DX-1P5KG', N'Quả VIP >1.5kg', 85000.00, 60, 1, '2026-05-03T09:41:00', '2026-05-16T08:10:00'),
        (5, 3, N'CHUOI-LABA-1KG', N'Nải 1kg', 28000.00, 200, 1, '2026-05-03T09:42:00', '2026-05-16T08:10:00'),
        (6, 4, N'XOAI-CAT-1KG', N'Hộp 1kg', 89000.00, 90, 1, '2026-05-03T09:43:00', '2026-05-16T08:10:00'),
        (7, 4, N'XOAI-CAT-2KG', N'Hộp 2kg VIP', 169000.00, 45, 1, '2026-05-03T09:43:00', '2026-05-16T08:10:00'),
        (8, 5, N'DAU-TAY-250G', N'Hộp 250g', 125000.00, 75, 1, '2026-05-03T09:44:00', '2026-05-16T08:10:00'),
        (9, 5, N'DAU-TAY-500G', N'Hộp 500g', 239000.00, 40, 1, '2026-05-03T09:44:00', '2026-05-16T08:10:00'),
        (10, 6, N'DUA-LUOI-1QT', N'Quả 1.5kg', 90000.00, 110, 1, '2026-05-03T09:45:00', '2026-05-16T08:10:00'),
        (11, 7, N'DUA-HAU-VUONG', N'Quả vuông vẽ chữ', 299000.00, 30, 1, '2026-05-03T09:46:00', '2026-05-16T08:10:00'),
        (12, 8, N'CHERRY-CL-250G', N'Hộp 250g', 149000.00, 85, 1, '2026-05-03T09:47:00', '2026-05-16T08:10:00'),
        (13, 8, N'CHERRY-CL-500G', N'Hộp 500g', 289000.00, 50, 1, '2026-05-03T09:47:00', '2026-05-16T08:10:00'),
        (14, 8, N'CHERRY-CL-1KG', N'Hộp 1kg Premium', 550000.00, 25, 1, '2026-05-03T09:47:00', '2026-05-16T08:10:00'),
        (15, 9, N'CHERRY-US-500G', N'Hộp 500g Orchard', 320000.00, 60, 1, '2026-05-03T09:48:00', '2026-05-16T08:10:00'),
        (16, 9, N'CHERRY-US-1KG', N'Thùng 1kg VIP', 620000.00, 30, 1, '2026-05-03T09:48:00', '2026-05-16T08:10:00'),
        (17, 10, N'NHO-MD-500G', N'Khay 500g', 179000.00, 95, 1, '2026-05-03T09:49:00', '2026-05-16T08:10:00'),
        (18, 10, N'NHO-MD-1KG', N'Hộp 1kg', 345000.00, 50, 1, '2026-05-03T09:49:00', '2026-05-16T08:10:00'),
        (19, 11, N'HQ-AN-KHANG', N'Hộp gỗ Premium', 680000.00, 35, 1, '2026-05-03T09:50:00', '2026-05-16T08:10:00'),
        (20, 12, N'HQ-THINH-VUONG', N'Hộp lụa VIP', 880000.00, 28, 1, '2026-05-03T09:51:00', '2026-05-16T08:10:00'),
        (21, 13, N'GQ-SUM-HOP', N'Giỏ lục bình lớn', 550000.00, 40, 1, '2026-05-03T09:52:00', '2026-05-16T08:10:00'),
        (22, 14, N'GQ-CAT-TUONG', N'Giỏ tre hoa tươi', 750000.00, 25, 1, '2026-05-03T09:53:00', '2026-05-16T08:10:00'),
        (23, 15, N'GQ-TAI-LOC', N'Giỏ VIP đặc biệt', 1250000.00, 20, 1, '2026-05-03T09:54:00', '2026-05-16T08:10:00'),
        -- Táo Envy Mỹ (16)
        (24, 16, N'TAO-ENVY-1KG', N'Hộp 1kg', 119000.00, 120, 1, GETDATE(), GETDATE()),
        (25, 16, N'TAO-ENVY-3KG', N'Combo 3kg', 329000.00, 50, 1, GETDATE(), GETDATE()),
        -- Kiwi Vàng (17)
        (26, 17, N'KIWI-VANG-1KG', N'Hộp 1kg', 145000.00, 90, 1, GETDATE(), GETDATE()),
        (27, 17, N'KIWI-VANG-3KG', N'Combo 3kg', 399000.00, 40, 1, GETDATE(), GETDATE()),

        -- Cam Vàng Navel Úc (18)
        (28, 18, N'CAM-NAV-1KG', N'Hộp 1kg', 85000.00, 90, 1, GETDATE(), GETDATE()),
        (29, 18, N'CAM-NAV-3KG', N'Combo 3kg', 240000.00, 40, 1, GETDATE(), GETDATE()),
        -- Chanh Không Hạt (19)
        (30, 19, N'CHANH-KH-1KG', N'Túi lưới 1kg', 22000.00, 300, 1, GETDATE(), GETDATE()),
        -- Quất Đường (20)
        (31, 20, N'QUAT-D-1KG', N'Hộp 1kg', 45000.00, 150, 1, GETDATE(), GETDATE()),
        -- Bưởi Năm Roi (21)
        (32, 21, N'BUOI-5R-1QT', N'Quả 1kg - 1.2kg', 55000.00, 110, 1, GETDATE(), GETDATE()),
        -- Sầu Riêng Ri6 (22)
        (33, 22, N'SAU-RIENG-RI6-QA', N'Quả nguyên trái 3kg - 4kg', 360000.00, 85, 1, GETDATE(), GETDATE()),
        (34, 22, N'SAU-RIENG-RI6-BOX', N'Khay cơm khui sẵn 500g', 185000.00, 60, 1, GETDATE(), GETDATE()),
        -- Măng Cụt (23)
        (35, 23, N'MANG-CUT-LT-1KG', N'Túi 1kg', 75000.00, 120, 1, GETDATE(), GETDATE()),
        (36, 23, N'MANG-CUT-LT-3KG', N'Hộp 3kg Quà tặng', 210000.00, 50, 1, GETDATE(), GETDATE()),
        -- Vải Thiều (24)
        (37, 24, N'VAI-THIEU-1KG', N'Chùm 1kg', 42000.00, 400, 1, GETDATE(), GETDATE()),
        -- Nhãn Xuồng (25)
        (38, 25, N'NHAN-XUONG-1KG', N'Chùm 1kg', 68000.00, 180, 1, GETDATE(), GETDATE()),
        -- Chôm Chôm (26)
        (39, 26, N'CHOM-CHOM-1KG', N'Túi 1kg', 35000.00, 250, 1, GETDATE(), GETDATE()),
        -- Thanh Long (27)
        (40, 27, N'THANH-LONG-RD-1KG', N'Hộp 2 quả ~1.2kg', 40000.00, 190, 1, GETDATE(), GETDATE()),
        -- Đu Đủ (28)
        (41, 28, N'DU-DU-RD-1QT', N'Quả 1.5kg', 30000.00, 140, 1, GETDATE(), GETDATE()),
        -- Dừa Xiêm (29)
        (42, 29, N'DUA-XIEM-5QT', N'Combo 5 quả gọt trọc', 110000.00, 120, 1, GETDATE(), GETDATE()),
        -- Mít Thái (30)
        (43, 30, N'MIT-THAI-RD-500G', N'Khay bóc sẵn 500g', 60000.00, 90, 1, GETDATE(), GETDATE()),
        -- Vú Sữa (31)
        (44, 31, N'VU-SUA-LR-1KG', N'Hộp 1kg (3-4 quả)', 75000.00, 110, 1, GETDATE(), GETDATE()),
        -- Na Dai (32)
        (45, 32, N'NA-DAI-DT-1KG', N'Hộp 1kg', 60000.00, 95, 1, GETDATE(), GETDATE()),
        -- Dứa Mật (33)
        (46, 33, N'DUA-MAT-1QT', N'Quả gọt sẵn', 35000.00, 130, 1, GETDATE(), GETDATE()),
        -- Ổi Nữ Hoàng (34)
        (47, 34, N'OI-NH-1KG', N'Túi 1kg', 25000.00, 220, 1, GETDATE(), GETDATE()),
        -- Cóc Non (35)
        (48, 35, N'COC-NON-500G', N'Hộp 500g kèm muối', 30000.00, 180, 1, GETDATE(), GETDATE()),
        -- Bơ Sáp (36)
        (49, 36, N'BO-SAP-034-1KG', N'Túi 1kg', 55000.00, 160, 1, GETDATE(), GETDATE()),
        -- Chanh Leo (37)
        (50, 37, N'CHANH-LEO-1KG', N'Túi 1kg', 35000.00, 200, 1, GETDATE(), GETDATE()),
        -- Mận Hậu (38)
        (51, 38, N'MAN-HAU-MC-1KG', N'Hộp 1kg', 65000.00, 320, 1, GETDATE(), GETDATE()),
        -- Hồng Xiêm (39)
        (52, 39, N'HONG-XIEM-XD-1KG', N'Túi 1kg', 48000.00, 140, 1, GETDATE(), GETDATE()),
        -- Việt Quất (40)
        (53, 40, N'VIET-QUAT-125G', N'Hộp 125g', 69000.00, 150, 1, GETDATE(), GETDATE()),
        -- Dâu Tây Bạch Tuyết (41)
        (54, 41, N'DAU-TUYET-300G', N'Hộp xốp VIP 300g', 380000.00, 30, 1, GETDATE(), GETDATE()),
        -- Mâm Xôi Đỏ (42)
        (55, 42, N'MAM-XOI-150G', N'Hộp 150g', 65000.00, 80, 1, GETDATE(), GETDATE()),
        -- Táo Gala (43)
        (56, 43, N'TAO-GALA-1KG', N'Túi 1kg', 59000.00, 190, 1, GETDATE(), GETDATE()),
        -- Táo Fuji (44)
        (57, 44, N'TAO-FUJI-JP-1KG', N'Hộp 1kg VIP', 169000.00, 70, 1, GETDATE(), GETDATE()),
        -- Nho Đen Ngón Tay (45)
        (58, 45, N'NHO-SAPPHIRE-500G', N'Khay 500g', 189000.00, 110, 1, GETDATE(), GETDATE()),
        -- Nho Đỏ (46)
        (59, 46, N'NHO-DO-UC-1KG', N'Hộp 1kg', 135000.00, 140, 1, GETDATE(), GETDATE()),
        -- Dưa Hấu Không Hạt (47)
        (60, 47, N'DUA-HAU-KH-1QT', N'Quả 3kg - 4kg', 45000.00, 210, 1, GETDATE(), GETDATE()),
        -- Kiwi Xanh (48)
        (61, 48, N'KIWI-XANH-1KG', N'Hộp 1kg', 95000.00, 160, 1, GETDATE(), GETDATE()),
        -- Cherry Vàng (49)
        (62, 49, N'CHERRY-VANG-500G', N'Hộp 500g Orchard', 450000.00, 40, 1, GETDATE(), GETDATE()),
        -- Hộp Quà Phú Quý (50)
        (63, 50, N'HQ-PHU-QUY', N'Hộp gỗ VIP thắt nơ', 799000.00, 45, 1, GETDATE(), GETDATE());

    -- Chèn thêm các biến thể mới của sản phẩm mới với thông tin chiết khấu
    INSERT INTO dbo.product_variants (variant_id, product_id, sku, variant_label, price, stock_quantity, is_active, discount_price, discount_start, discount_end, created_at, updated_at)
    VALUES
        (64, 51, N'NHO-MAU-DON-500G', N'Hộp 500g', 250000.00, 100, 1, 199000.00, DATEADD(day, -2, GETDATE()), DATEADD(day, 5, GETDATE()), GETDATE(), GETDATE()),
        (65, 51, N'NHO-MAU-DON-1KG', N'Hộp 1kg', 480000.00, 50, 1, 399000.00, DATEADD(day, -10, GETDATE()), DATEADD(day, -1, GETDATE()), GETDATE(), GETDATE()),
        (66, 52, N'CHERRY-NZ-500G', N'Hộp 500g', 350000.00, 80, 1, 299000.00, DATEADD(day, -1, GETDATE()), DATEADD(day, 2, GETDATE()), GETDATE(), GETDATE()),
        (67, 53, N'BUOI-DX-HC-1KG', N'Quả 1kg', 95000.00, 120, 1, NULL, NULL, NULL, GETDATE(), GETDATE()),
        (68, 54, N'CAM-SANH-HC-1KG', N'Hộp 1kg', 45000.00, 150, 1, NULL, NULL, NULL, GETDATE(), GETDATE()),
        (69, 55, N'TAO-ENVY-TC-1KG', N'Túi 1kg', 120000.00, 60, 1, NULL, NULL, NULL, GETDATE(), GETDATE()),
        (70, 56, N'BO-SAP-HC-1KG', N'Hộp 1kg', 65000.00, 100, 1, NULL, NULL, NULL, GETDATE(), GETDATE()),
        (71, 57, N'CAM-EG-1KG', N'Túi 1kg', 75000.00, 150, 1, NULL, NULL, NULL, GETDATE(), GETDATE()),
        (72, 58, N'DAU-HQ-330G', N'Hộp 330g', 180000.00, 60, 1, 149000.00, DATEADD(day, -2, GETDATE()), DATEADD(day, 4, GETDATE()), GETDATE(), GETDATE()),
        (73, 59, N'NHO-NT-UC-500G', N'Hộp 500g', 220000.00, 80, 1, 199000.00, DATEADD(day, -1, GETDATE()), DATEADD(day, 5, GETDATE()), GETDATE(), GETDATE()),
        (74, 60, N'LE-NP-1KG', N'Túi 1kg', 89000.00, 120, 1, NULL, NULL, NULL, GETDATE(), GETDATE()),
        (75, 61, N'MANG-CUT-HC-1KG', N'Túi 1kg', 95000.00, 90, 1, NULL, NULL, NULL, GETDATE(), GETDATE()),
        (76, 62, N'QUYT-DUONG-1KG', N'Hộp 1kg', 55000.00, 140, 1, NULL, NULL, NULL, GETDATE(), GETDATE()),
        (77, 63, N'TAO-ROCKIT-4QT', N'Ống 4 quả', 135000.00, 200, 1, 119000.00, DATEADD(day, -3, GETDATE()), DATEADD(day, 6, GETDATE()), GETDATE(), GETDATE()),
        (78, 64, N'DUA-LUOI-TABI-1QT', N'Quả 1.5kg', 110000.00, 85, 1, NULL, NULL, NULL, GETDATE(), GETDATE()),
        (79, 65, N'VIET-QUAT-US-125G', N'Hộp 125g', 89000.00, 120, 1, 79000.00, DATEADD(day, -1, GETDATE()), DATEADD(day, 3, GETDATE()), GETDATE(), GETDATE()),
        (80, 66, N'CHERRY-US-95-500G', N'Hộp 500g', 420000.00, 50, 1, 380000.00, DATEADD(day, -2, GETDATE()), DATEADD(day, 5, GETDATE()), GETDATE(), GETDATE()),
        (81, 67, N'HONG-GIENT-1KG', N'Túi 1kg', 50000.00, 110, 1, NULL, NULL, NULL, GETDATE(), GETDATE()),
        (82, 68, N'NA-CHI-LANG-1KG', N'Hộp 1kg', 85000.00, 70, 1, NULL, NULL, NULL, GETDATE(), GETDATE()),
        (83, 69, N'SAU-RIENG-MSK-MUI', N'Khay múi 400g', 450000.00, 40, 1, NULL, NULL, NULL, GETDATE(), GETDATE()),
        (84, 70, N'VAI-THIEU-LN-1KG', N'Túi 1kg', 45000.00, 250, 1, 39000.00, DATEADD(day, -5, GETDATE()), DATEADD(day, 5, GETDATE()), GETDATE(), GETDATE());
    SET IDENTITY_INSERT dbo.product_variants OFF;

    SET IDENTITY_INSERT dbo.inventory_logs ON;
    INSERT INTO dbo.inventory_logs (log_id, variant_id, changed_by, change_type, quantity_delta, quantity_after, remaining_quantity, note, expires_at, is_expired, changed_at)
    VALUES
        (1, 1, 3, N'MANUAL_ADJUST', 150, 150, 150, N'Nhập kho ban đầu', DATEADD(day, 15, GETDATE()), 0, '2026-05-12T08:00:00'),
        (2, 3, 3, N'MANUAL_ADJUST', 120, 120, 120, N'Nhập kho đầu mùa bưởi', DATEADD(day, 15, GETDATE()), 0, '2026-05-15T09:05:00'),
        (3, 8, 4, N'MANUAL_ADJUST', 75, 75, 75, N'Nhập lô dâu tây Mỹ kiểm dịch', DATEADD(day, 15, GETDATE()), 0, '2026-05-16T08:20:00'),
        (4, 12, 7, N'MANUAL_ADJUST', 85, 85, 85, N'Nhập container Cherry Chile', DATEADD(day, 15, GETDATE()), 0, '2026-05-15T10:00:00'),
        (5, 19, 7, N'MANUAL_ADJUST', 35, 35, 35, N'Đóng hộp quà tết', DATEADD(day, 15, GETDATE()), 0, '2026-05-14T18:00:00'),
        (6, 24, 7, N'MANUAL_ADJUST', 120, 120, 120, N'Nhập kho táo Envy Mỹ', DATEADD(day, 15, GETDATE()), 0, '2026-05-18T09:00:00'),
        (7, 26, 7, N'MANUAL_ADJUST', 90, 90, 90, N'Nhập kho Kiwi Vàng', DATEADD(day, 15, GETDATE()), 0, '2026-05-19T09:00:00'),

        (8, 28, 3, N'MANUAL_ADJUST', 90, 90, 90, N'Nhập kho Cam Navel', DATEADD(day, 15, GETDATE()), 0, GETDATE()),
        (9, 30, 3, N'MANUAL_ADJUST', 300, 300, 300, N'Nhập kho Chanh Long An', DATEADD(day, 15, GETDATE()), 0, GETDATE()),
        (10, 33, 3, N'MANUAL_ADJUST', 85, 85, 85, N'Nhập kho sầu riêng Ri6 quả', DATEADD(day, 15, GETDATE()), 0, GETDATE()),
        (11, 35, 4, N'MANUAL_ADJUST', 120, 120, 120, N'Nhập kho Măng Cụt', DATEADD(day, 15, GETDATE()), 0, GETDATE()),
        (12, 37, 4, N'MANUAL_ADJUST', 400, 400, 400, N'Nhập kho Vải Thiều Bắc Giang', DATEADD(day, 15, GETDATE()), 0, GETDATE()),
        (13, 54, 7, N'MANUAL_ADJUST', 30, 30, 30, N'Nhập kho Dâu Bạch Tuyết Nhật', DATEADD(day, 15, GETDATE()), 0, GETDATE()),
        (14, 58, 7, N'MANUAL_ADJUST', 110, 110, 110, N'Nhập kho Nho sapphire ngón tay', DATEADD(day, 15, GETDATE()), 0, GETDATE()),
        (15, 32, 3, N'MANUAL_ADJUST', 110, 110, 110, N'Nhập kho Bưởi Năm Roi', DATEADD(day, 15, GETDATE()), 0, GETDATE());
    SET IDENTITY_INSERT dbo.inventory_logs OFF;

    SET IDENTITY_INSERT dbo.promotions ON;
    INSERT INTO dbo.promotions (promo_id, code, discount_type, discount_scope, discount_max, discount_value, min_order_value, scope, benefit_target, product_id, max_uses, used_count, can_stack, valid_from, valid_until, created_by, created_at, updated_at, is_deleted, is_active)
    VALUES
        (1, N'FLASHSALE-DAUTAY', N'FIXED', N'ALL', 0.00, 30000.00, 100000.00, N'PRODUCT', N'PRODUCT', 5, 200, 12, 1, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 1, '2026-05-01T10:00:00', '2026-05-16T08:00:00', 0, 1),
        (2, N'FLASHSALE-CHERRYCL', N'PERCENT', N'ALL', 100000.00, 20.00, 150000.00, N'PRODUCT', N'PRODUCT', 8, 150, 8, 1, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 1, '2026-05-01T10:05:00', '2026-05-16T08:00:00', 0, 1),
        (3, N'FLASHSALE-DUAVUONG', N'PERCENT', N'ALL', 50000.00, 15.00, 200000.00, N'PRODUCT', N'PRODUCT', 7, 100, 3, 1, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 1, '2026-05-01T10:10:00', '2026-05-16T08:00:00', 0, 1),
        (4, N'FLASHSALE-NHOMD', N'FIXED', N'ALL', 0.00, 50000.00, 150000.00, N'PRODUCT', N'PRODUCT', 10, 120, 5, 1, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 1, '2026-05-01T10:15:00', '2026-05-16T08:00:00', 0, 1),
        (5, N'WELCOME10', N'PERCENT', N'ALL', 50000.00, 10.00, 120000.00, N'ORDER', N'MERCHANDISE', NULL, 1000, 36, 0, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 1, '2026-05-01T10:20:00', '2026-05-16T08:00:00', 0, 1),
        (6, N'FREESHIP50', N'FIXED', N'ALL', 0.00, 20000.00, 300000.00, N'ORDER', N'SHIPPING', NULL, 500, 45, 0, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 1, '2026-05-01T10:25:00', '2026-05-16T08:00:00', 0, 1),
        (7, N'FLASHSALE-CAMSANH', N'PERCENT', N'ALL', 20000.00, 20.00, 50000.00, N'PRODUCT', N'PRODUCT', 1, 300, 0, 1, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 1, '2026-05-01T10:30:00', '2026-05-16T08:00:00', 0, 1),
        (8, N'FLASHSALE-BUOI', N'FIXED', N'ALL', 0.00, 15000.00, 80000.00, N'PRODUCT', N'PRODUCT', 2, 200, 0, 1, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 1, '2026-05-01T10:35:00', '2026-05-16T08:00:00', 0, 1),
        (9, N'FLASHSALE-XOAI', N'PERCENT', N'ALL', 30000.00, 10.00, 100000.00, N'PRODUCT', N'PRODUCT', 4, 150, 0, 1, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 1, '2026-05-01T10:40:00', '2026-05-16T08:00:00', 0, 1),
        (10, N'FLASHSALE-TAOENVY', N'PERCENT', N'ALL', 40000.00, 15.00, 120000.00, N'PRODUCT', N'PRODUCT', 16, 250, 0, 1, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 1, '2026-05-01T10:45:00', '2026-05-16T08:00:00', 0, 1),
        (11, N'FLASHSALE-KIWI', N'FIXED', N'ALL', 0.00, 25000.00, 100000.00, N'PRODUCT', N'PRODUCT', 17, 180, 0, 1, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 1, '2026-05-01T10:50:00', '2026-05-16T08:00:00', 0, 1),
        -- Voucher của Shop (discount_scope = 'SHOP') — hiển thị trên trang chi tiết sản phẩm
        (12, N'ANPHU-GIAM30K', N'FIXED', N'SHOP', 0.00, 30000.00, 200000.00, N'ORDER', N'MERCHANDISE', NULL, 500, 17, 0, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 3, '2026-05-02T08:00:00', '2026-05-16T08:00:00', 0, 1),
        (13, N'ANPHU-GIAM15P', N'PERCENT', N'SHOP', 50000.00, 15.00, 350000.00, N'ORDER', N'MERCHANDISE', NULL, 300, 8, 0, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 3, '2026-05-02T08:05:00', '2026-05-16T08:00:00', 0, 1),
        (14, N'MEKONG-GIAM20K', N'FIXED', N'SHOP', 0.00, 20000.00, 150000.00, N'ORDER', N'MERCHANDISE', NULL, 400, 12, 0, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 4, '2026-05-03T08:00:00', '2026-05-16T08:00:00', 0, 1),
        (15, N'MEKONG-GIAM10P', N'PERCENT', N'SHOP', 40000.00, 10.00, 250000.00, N'ORDER', N'MERCHANDISE', NULL, 350, 5, 0, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 4, '2026-05-03T08:05:00', '2026-05-16T08:00:00', 0, 1),
        (16, N'KLEVER-GIAM50K', N'FIXED', N'SHOP', 0.00, 50000.00, 400000.00, N'ORDER', N'MERCHANDISE', NULL, 250, 3, 0, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 7, '2026-05-04T08:00:00', '2026-05-16T08:00:00', 0, 1),
        (17, N'KLEVER-GIAM20P', N'PERCENT', N'SHOP', 80000.00, 20.00, 500000.00, N'ORDER', N'MERCHANDISE', NULL, 200, 1, 0, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 7, '2026-05-04T08:05:00', '2026-05-16T08:00:00', 0, 1),
        (18, N'SHOP10', N'PERCENT', N'SHOP', 50000.00, 10.00, 100000.00, N'ORDER', N'MERCHANDISE', NULL, 1000, 0, 1, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 7, GETDATE(), GETDATE(), 0, 1),
        (19, N'SAAN5', N'FIXED', N'ALL', 0.00, 5000.00, 50000.00, N'ORDER', N'MERCHANDISE', NULL, 1000, 0, 1, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 1, GETDATE(), GETDATE(), 0, 1),
        (20, N'SALE20', N'PERCENT', N'ALL', 100000.00, 20.00, 200000.00, N'ORDER', N'MERCHANDISE', NULL, 1000, 0, 1, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 1, GETDATE(), GETDATE(), 0, 1),
        (21, N'METAFRUIT50', N'PERCENT', N'ALL', 150000.00, 15.00, 300000.00, N'ORDER', N'MERCHANDISE', NULL, 500, 0, 1, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 1, GETDATE(), GETDATE(), 0, 1),
        (22, N'FREESHIPALL', N'FIXED', N'ALL', 0.00, 15000.00, 150000.00, N'ORDER', N'SHIPPING', NULL, 2000, 0, 1, '2026-01-01T00:00:00', '2026-12-31T23:59:59', 1, GETDATE(), GETDATE(), 0, 1);
    SET IDENTITY_INSERT dbo.promotions OFF;

    -- Gieo dữ liệu đóng gói sản phẩm (product_packaging_options)
    SET IDENTITY_INSERT dbo.product_packaging_options ON;
    INSERT INTO dbo.product_packaging_options (packaging_id, product_id, label, price_add, is_active)
    VALUES
        (1, 1, N'Túi giấy thân thiện môi trường', 5000.00, 1),
        (2, 1, N'Hộp gỗ thông sang trọng', 35000.00, 1),
        (3, 51, N'Hộp giấy Carton cao cấp', 10000.00, 1),
        (4, 51, N'Hộp quà thắt nơ nghệ thuật', 45000.00, 1),
        (5, 52, N'Túi giữ nhiệt bảo quản lạnh', 15000.00, 1),
        (6, 52, N'Hộp gỗ lót lụa Premium', 50000.00, 1);
    SET IDENTITY_INSERT dbo.product_packaging_options OFF;

    SET IDENTITY_INSERT dbo.cart ON;
    INSERT INTO dbo.cart (cart_id, customer_id, created_at, updated_at)
    VALUES
        (1, 5, '2026-05-15T08:10:00', '2026-05-16T08:00:00'),
        (2, 6, '2026-05-15T09:10:00', '2026-05-16T08:00:00'),
        (3, 21, GETDATE(), GETDATE()),
        (4, 23, GETDATE(), GETDATE());
    SET IDENTITY_INSERT dbo.cart OFF;

    SET IDENTITY_INSERT dbo.cart_items ON;
    INSERT INTO dbo.cart_items (cart_item_id, cart_id, variant_id, quantity, packaging_id, added_at)
    VALUES
        (1, 1, 1, 1, NULL, '2026-05-15T08:12:00'),
        (2, 1, 3, 1, NULL, '2026-05-15T08:12:00'),
        (3, 2, 6, 1, NULL, '2026-05-15T09:12:00'),
        (4, 2, 8, 1, NULL, '2026-05-15T09:12:00'),
        (5, 4, 64, 2, 3, GETDATE());
    SET IDENTITY_INSERT dbo.cart_items OFF;

    SET IDENTITY_INSERT dbo.orders ON;
    INSERT INTO dbo.orders (order_id, customer_id, owner_id, delivery_address, delivery_time_slot, notes, cancelled_at, cancelled_by, cancellation_reason, status, total_amount, delivery_fee, discount_amount, system_discount_amount, shop_discount_amount, platform_fee, final_amount, payment_method, refund_status, created_at, updated_at, parent_order_id, order_type)
    VALUES
        (1, 5, 3, N'15 Pasteur, District 3, HCMC', N'08:00-12:00', N'Leave at reception', NULL, NULL, NULL, N'DELIVERED', 130000.00, 15000.00, 13000.00, 10000.00, 3000.00, 6500.00, 132000.00, N'CK', N'NONE', '2026-05-15T09:10:00', '2026-05-16T12:30:00', NULL, 'CHILD'),
        (2, 6, 4, N'90 Truong Chinh, Tan Binh, HCMC', N'14:00-18:00', N'Call on arrival', NULL, NULL, NULL, N'DELIVERED', 214000.00, 20000.00, 15000.00, 0.00, 15000.00, 10700.00, 219000.00, N'COD', N'NONE', '2026-05-15T10:20:00', '2026-05-16T13:10:00', NULL, 'CHILD'),
        (3, 5, 3, N'15 Pasteur, District 3, HCMC', N'18:00-21:00', N'Ring the bell twice', NULL, NULL, NULL, N'DELIVERED', 142000.00, 12000.00, 14200.00, 14200.00, 0.00, 7100.00, 139800.00, N'CK', N'PENDING', '2026-05-16T08:00:00', '2026-05-16T18:00:00', NULL, 'CHILD'),
        (10, 10, 3, N'12 Phố Cổ, Hà Nội', NULL, NULL, NULL, NULL, NULL, N'DELIVERED', 35000.00, 15000.00, 0.00, 0.00, 0.00, 1750.00, 50000.00, N'COD', N'NONE', '2026-05-18T08:00:00', '2026-05-18T14:00:00', NULL, 'CHILD'),
        (11, 11, 3, N'85 Xuân Thủy, Cầu Giấy', NULL, NULL, NULL, NULL, NULL, N'DELIVERED', 35000.00, 15000.00, 0.00, 0.00, 0.00, 1750.00, 50000.00, N'COD', N'NONE', '2026-05-19T09:00:00', '2026-05-19T15:00:00', NULL, 'CHILD'),
        (12, 12, 3, N'45 Chùa Bộc, Đống Đa', NULL, NULL, NULL, NULL, NULL, N'DELIVERED', 95000.00, 20000.00, 0.00, 0.00, 0.00, 4750.00, 115000.00, N'CK', N'NONE', '2026-05-20T10:00:00', '2026-05-20T16:00:00', NULL, 'CHILD'),
        (13, 13, 3, N'102 Nguyễn Trãi, Thanh Xuân', NULL, NULL, NULL, NULL, NULL, N'DELIVERED', 35000.00, 15000.00, 0.00, 0.00, 0.00, 1750.00, 50000.00, N'COD', N'NONE', '2026-05-21T11:00:00', '2026-05-21T17:00:00', NULL, 'CHILD'),
        (14, 14, 3, N'56 Bạch Mai, Hai Bà Trưng', NULL, NULL, NULL, NULL, NULL, N'DELIVERED', 35000.00, 15000.00, 0.00, 0.00, 0.00, 1750.00, 50000.00, N'CK', N'NONE', '2026-05-22T13:00:00', '2026-05-22T19:00:00', NULL, 'CHILD'),
        (15, 15, 3, N'29 Lạc Long Quân, Tây Hồ', NULL, NULL, NULL, NULL, NULL, N'DELIVERED', 95000.00, 20000.00, 0.00, 0.00, 0.00, 4750.00, 115000.00, N'COD', N'NONE', '2026-05-23T08:00:00', '2026-05-23T12:00:00', NULL, 'CHILD'),
        
        -- Multi-shop parent order
        (100, 5, NULL, N'15 Pasteur, Quận 3, TP. Hồ Chí Minh', NULL, N'Multi-shop test parent order', NULL, NULL, NULL, N'CONFIRMED', 344000.00, 35000.00, 28000.00, 10000.00, 18000.00, 17200.00, 351000.00, N'CK', N'NONE', '2026-05-24T09:00:00', '2026-05-24T09:10:00', NULL, 'PARENT'),
        -- Child order 1 for Shop 3
        (101, 5, 3, N'15 Pasteur, Quận 3, TP. Hồ Chí Minh', NULL, N'Child order part 1', NULL, NULL, NULL, N'CONFIRMED', 130000.00, 15000.00, 13000.00, 10000.00, 3000.00, 6500.00, 132000.00, N'CK', N'NONE', '2026-05-24T09:00:00', '2026-05-24T09:10:00', 100, 'CHILD'),
        -- Child order 2 for Shop 4
        (102, 5, 4, N'15 Pasteur, Quận 3, TP. Hồ Chí Minh', NULL, N'Child order part 2', NULL, NULL, NULL, N'CONFIRMED', 214000.00, 20000.00, 15000.00, 0.00, 15000.00, 10700.00, 219000.00, N'CK', N'NONE', '2026-05-24T09:00:00', '2026-05-24T09:10:00', 100, 'CHILD');
    SET IDENTITY_INSERT dbo.orders OFF;

    UPDATE dbo.orders
    SET received_status = 'RECEIVED'
    WHERE status = 'DELIVERED';

    SET IDENTITY_INSERT dbo.order_items ON;
    INSERT INTO dbo.order_items (order_item_id, order_id, variant_id, product_name_snapshot, variant_label_snapshot, quantity, unit_price, subtotal)
    VALUES
        (1, 1, 1, N'Cam Sành Cao Phong Hòa Bình', N'Hộp 1kg', 1, 35000.00, 35000.00),
        (2, 1, 2, N'Cam Sành Cao Phong Hòa Bình', N'Combo 3kg', 1, 95000.00, 95000.00),
        (3, 2, 6, N'Xoài Cát Hòa Lộc Tiền Giang', N'Hộp 1kg', 1, 89000.00, 89000.00),
        (4, 2, 8, N'Dâu Tây Đỏ Mỹ Nhập Khẩu Premium', N'Hộp 250g', 1, 125000.00, 125000.00),
        (5, 3, 3, N'Bưởi Da Xanh Bến Tre loại đặc biệt', N'Quả 1.2kg - 1.4kg', 1, 86000.00, 86000.00),
        (6, 3, 5, N'Chuối Lùn Laba Đà Lạt', N'Nải 1kg', 2, 28000.00, 56000.00),
        (10, 10, 1, N'Cam Sành Cao Phong Hòa Bình', N'Hộp 1kg', 1, 35000.00, 35000.00),
        (11, 11, 1, N'Cam Sành Cao Phong Hòa Bình', N'Hộp 1kg', 1, 35000.00, 35000.00),
        (12, 12, 2, N'Cam Sành Cao Phong Hòa Bình', N'Combo 3kg', 1, 95000.00, 95000.00),
        (13, 13, 1, N'Cam Sành Cao Phong Hòa Bình', N'Hộp 1kg', 1, 35000.00, 35000.00),
        (14, 14, 1, N'Cam Sành Cao Phong Hòa Bình', N'Hộp 1kg', 1, 35000.00, 35000.00),
        (15, 15, 2, N'Cam Sành Cao Phong Hòa Bình', N'Combo 3kg', 1, 95000.00, 95000.00),
        
        -- Items for multi-shop child order 1
        (101, 101, 1, N'Cam Sành Cao Phong Hòa Bình', N'Hộp 1kg', 1, 35000.00, 35000.00),
        (102, 101, 2, N'Cam Sành Cao Phong Hòa Bình', N'Combo 3kg', 1, 95000.00, 95000.00),
        -- Items for multi-shop child order 2
        (103, 102, 6, N'Xoài Cát Hòa Lộc Tiền Giang', N'Hộp 1kg', 1, 89000.00, 89000.00),
        (104, 102, 8, N'Dâu Tây Đỏ Mỹ Nhập Khẩu Premium', N'Hộp 250g', 1, 125000.00, 125000.00);
    SET IDENTITY_INSERT dbo.order_items OFF;

    SET IDENTITY_INSERT dbo.order_promotions ON;
    INSERT INTO dbo.order_promotions (usage_id, order_id, promo_id, customer_id, discount_applied, coupon_code, discount_scope, benefit_target, used_at)
    VALUES
        (1, 1, 5, 5, 13000.00, N'WELCOME10', N'ALL', N'MERCHANDISE', '2026-05-15T09:20:00'),
        (2, 2, 1, 6, 15000.00, N'FLASHSALE-DAUTAY', N'ALL', N'PRODUCT', '2026-05-15T10:30:00'),
        (3, 3, 5, 5, 14200.00, N'WELCOME10', N'ALL', N'MERCHANDISE', '2026-05-16T08:10:00');
    SET IDENTITY_INSERT dbo.order_promotions OFF;

    SET IDENTITY_INSERT dbo.return_requests ON;
    INSERT INTO dbo.return_requests (return_request_id, order_id, order_item_id, customer_id, request_type, reason_code, description, evidence_url, requested_quantity, resolution_type, replacement_variant_id, refund_amount, status, decided_by, decision_reason, resolved_at, created_at, updated_at)
    VALUES
        (1, 3, 6, 5, N'RETURN', N'DAMAGED', N'Một nải chuối laba bị dập nát khi vận chuyển', N'/evidence/returns/rr-001.jpg', 1, N'REFUND', NULL, 28000.00, N'REQUESTED', NULL, NULL, NULL, '2026-05-16T19:00:00', '2026-05-16T19:00:00');
    SET IDENTITY_INSERT dbo.return_requests OFF;

    SET IDENTITY_INSERT dbo.shop_settlements ON;
    INSERT INTO dbo.shop_settlements (settlement_id, owner_id, period_start, period_end, gross_amount, platform_fee_amount, refund_amount, adjustment_amount, net_amount, status, calculated_at, confirmed_at, paid_at, created_by, note)
    VALUES
        (1, 3, '2026-05-01', '2026-05-15', 272000.00, 13600.00, 0.00, 0.00, 231200.00, N'PENDING', '2026-05-16T20:00:00', NULL, NULL, 1, N'Pending because order 3 has an open return request'),
        (2, 4, '2026-05-01', '2026-05-15', 214000.00, 10700.00, 0.00, 0.00, 188300.00, N'PAID', '2026-05-16T20:00:00', '2026-05-16T20:30:00', '2026-05-16T22:00:00', 1, N'Includes order 2');
    SET IDENTITY_INSERT dbo.shop_settlements OFF;

    SET IDENTITY_INSERT dbo.shop_settlement_orders ON;
    INSERT INTO dbo.shop_settlement_orders (settlement_order_id, settlement_id, order_id, order_amount, platform_fee_amount, discount_amount, refund_amount, net_amount)
    VALUES
        (1, 1, 1, 130000.00, 6500.00, 13000.00, 0.00, 110500.00),
        (2, 1, 3, 142000.00, 7100.00, 14200.00, 0.00, 120700.00),
        (3, 2, 2, 214000.00, 10700.00, 15000.00, 0.00, 188300.00);
    SET IDENTITY_INSERT dbo.shop_settlement_orders OFF;

    SET IDENTITY_INSERT dbo.payment_transactions ON;
    INSERT INTO dbo.payment_transactions (transaction_id, order_id, payment_method, sepay_transaction_id, sepay_reference, sepay_qr_code, amount, currency, status, initiated_at, completed_at, expires_at, provider_response, error_code, error_message, ip_address)
    VALUES
        (1, 1, N'SEPAY', N'SP20260516001', N'DH-0001', N'/payments/qr/DH-0001.png', 132000.00, N'VND', N'completed', '2026-05-15T09:11:00', '2026-05-15T09:13:00', '2026-05-15T09:26:00', N'success', NULL, NULL, N'127.0.0.1'),
        (2, 2, N'COD', NULL, NULL, NULL, 219000.00, N'VND', N'completed', '2026-05-15T10:21:00', '2026-05-16T13:15:00', NULL, NULL, NULL, NULL, N'127.0.0.1'),
        (3, 3, N'SEPAY', N'SP20260516003', N'DH-0003', N'/payments/qr/DH-0003.png', 139800.00, N'VND', N'completed', '2026-05-16T08:01:00', '2026-05-16T08:03:00', '2026-05-16T08:16:00', N'success', NULL, NULL, N'127.0.0.1');
    SET IDENTITY_INSERT dbo.payment_transactions OFF;

    SET IDENTITY_INSERT dbo.sepay_webhook_dedup ON;
    INSERT INTO dbo.sepay_webhook_dedup (dedup_id, sepay_transaction_id, order_code, process_result, created_at)
    VALUES
        (1, N'SP20260516001', N'DH-0001', N'processed', '2026-05-15T09:14:00'),
        (2, N'SP20260516003', N'DH-0003', N'processed', '2026-05-16T08:04:00');
    SET IDENTITY_INSERT dbo.sepay_webhook_dedup OFF;

    SET IDENTITY_INSERT dbo.delivery_trips ON;
    INSERT INTO dbo.delivery_trips (trip_id, parent_order_id, shipper_id, status, estimated_start_time, estimated_end_time, created_at, updated_at)
    VALUES
        (1, 100, 2, N'ASSIGNED', '2026-05-24T10:00:00', '2026-05-24T12:00:00', '2026-05-24T09:15:00', '2026-05-24T09:15:00');
    SET IDENTITY_INSERT dbo.delivery_trips OFF;

    SET IDENTITY_INSERT dbo.deliveries ON;
    INSERT INTO dbo.deliveries (delivery_id, order_id, staff_id, status, picked_up_at, delivered_at, failure_reason, created_at, updated_at, delivery_trip_id, trip_stop_seq)
    VALUES
        (1, 1, 2, N'DELIVERED', '2026-05-15T11:00:00', '2026-05-15T11:45:00', NULL, '2026-05-15T09:15:00', '2026-05-15T11:45:00', NULL, NULL),
        (2, 2, 2, N'DELIVERED', '2026-05-15T14:10:00', '2026-05-15T16:00:00', NULL, '2026-05-15T10:25:00', '2026-05-15T16:00:00', NULL, NULL),
        (3, 3, 2, N'DELIVERED', '2026-05-16T10:00:00', '2026-05-16T10:40:00', NULL, '2026-05-16T08:20:00', '2026-05-16T10:40:00', NULL, NULL),
        -- Deliveries linked to multi-shop delivery trip 1
        (10, 101, 2, N'ASSIGNED', NULL, NULL, NULL, '2026-05-24T09:15:00', '2026-05-24T09:15:00', 1, 1),
        (11, 102, 2, N'ASSIGNED', NULL, NULL, NULL, '2026-05-24T09:15:00', '2026-05-24T09:15:00', 1, 2);
    SET IDENTITY_INSERT dbo.deliveries OFF;

    SET IDENTITY_INSERT dbo.reviews ON;
    INSERT INTO dbo.reviews (review_id, order_item_id, customer_id, rating, review_text, review_image_url, is_hidden, created_at)
    VALUES
        (1, 1, 5, 5, N'Cam Cao Phong cực kỳ nhiều nước, vị ngọt thanh tự nhiên xen chua nhẹ ăn cực đã. Giao hàng nhanh và đóng gói chuyên nghiệp!', N'https://images.unsplash.com/photo-1611080626919-7cf5a9dbab5b?w=600&auto=format&fit=crop&q=80', 0, '2026-05-15T12:00:00'),
        (2, 3, 6, 4, N'Xoài cát chất lượng chín ngọt thơm ngon, đóng gói rất cẩn thận.', NULL, 0, '2026-05-15T17:00:00'),
        (10, 10, 10, 5, N'Quả cam tươi rói, vỏ mỏng, nước nhiều. Vắt nước uống cho các bé ở nhà rất thích, sẽ tiếp tục ủng hộ shop lâu dài.', N'https://images.unsplash.com/photo-1547514701-42782101795e?w=600&auto=format&fit=crop&q=80', 0, '2026-05-18T15:00:00'),
        (11, 11, 11, 4, N'Cam ngon, thơm ngọt thanh. Giao hàng trong vòng 2 tiếng rất đúng hẹn. Tuy nhiên có vài quả hơi nhỏ hơn so với mô tả một chút.', NULL, 0, '2026-05-19T16:30:00'),
        (12, 12, 12, 5, N'Combo 3kg rẻ hơn nhiều so với mua lẻ. Trái cây tươi sạch sẽ, vỏ xanh bóng bẩy cực bắt mắt. Khuyên mọi người nên mua nha!', N'https://images.unsplash.com/photo-1618897996318-5a901fa6ca71?w=600&auto=format&fit=crop&q=80', 0, '2026-05-20T17:45:00'),
        (13, 13, 13, 3, N'Cam ăn cũng tạm được, nước vừa phải chứ không nhiều lắm. Giao hàng trễ mất 30 phút nên trừ 2 sao.', NULL, 0, '2026-05-21T18:20:00'),
        (14, 14, 14, 2, N'Quả cam nhận được bị dập 2 quả ở dưới đáy hộp do khâu vận chuyển xếp đè lên. Vị ngọt bình thường không đặc sắc.', N'https://images.unsplash.com/photo-1590080875515-8a3a8dc5735e?w=600&auto=format&fit=crop&q=80', 0, '2026-05-22T20:10:00'),
        (15, 15, 15, 1, N'Giao hàng quá chậm, cam thì bị héo vỏ và rụng cuống hết cả chùm. Quá thất vọng về trải nghiệm mua hàng lần này.', NULL, 0, '2026-05-23T10:15:00');
    SET IDENTITY_INSERT dbo.reviews OFF;

    SET IDENTITY_INSERT dbo.chat_sessions ON;
    INSERT INTO dbo.chat_sessions (session_id, customer_id, owner_id, status, created_at, updated_at, closed_at)
    VALUES
        (1, 5, 3, N'ACTIVE', '2026-05-15T08:30:00', '2026-05-16T18:15:00', NULL),
        (2, 6, 4, N'CLOSED', '2026-05-15T09:00:00', '2026-05-15T17:30:00', '2026-05-15T17:30:00');
    SET IDENTITY_INSERT dbo.chat_sessions OFF;

    SET IDENTITY_INSERT dbo.chat_messages ON;
    INSERT INTO dbo.chat_messages (message_id, session_id, sender_id, content, is_read, created_at)
    VALUES
        (1, 1, 5, N'Hello shop, can you deliver before noon?', 1, '2026-05-15T08:35:00'),
        (2, 1, 3, N'Yes, we will prioritize your delivery slot.', 1, '2026-05-15T08:40:00'),
        (3, 2, 6, N'My order has arrived, thanks.', 1, '2026-05-15T17:00:00'),
        (4, 2, 4, N'Thank you for your purchase.', 1, '2026-05-15T17:05:00');
    SET IDENTITY_INSERT dbo.chat_messages OFF;

    SET IDENTITY_INSERT dbo.notifications ON;
    INSERT INTO dbo.notifications (notification_id, user_id, type, title, message, action_url, is_read, created_at)
    VALUES
        (1, 5, N'ORDER_UPDATE', N'Order 1 confirmed', N'Your order has been confirmed and is being prepared.', N'/orders/1', 1, '2026-05-15T09:12:00'),
        (2, 5, N'PAYMENT', N'Payment received', N'Payment for order 1 was completed successfully.', N'/payments/1', 1, '2026-05-15T09:14:00'),
        (3, 6, N'ORDER_UPDATE', N'Delivery update', N'Your order 2 is out for delivery.', N'/orders/2', 0, '2026-05-15T14:05:00'),
        (4, 3, N'INVENTORY_ALERT', N'Stock notice', N'Variant 2 is below the preferred threshold.', N'/shop/inventory', 0, '2026-05-16T07:00:00'),
        (5, 4, N'PROMOTION', N'New promotion active', N'MANGO15 is ready for your product page.', N'/shop/promotions', 0, '2026-05-16T07:10:00'),
        (6, 1, N'SYSTEM', N'Settlement batch complete', N'Daily settlement snapshots were created successfully.', N'/admin/settlements', 0, '2026-05-16T20:05:00');
    SET IDENTITY_INSERT dbo.notifications OFF;

    SET IDENTITY_INSERT dbo.user_addresses ON;
    INSERT INTO dbo.user_addresses (address_id, user_id, recipient_name, recipient_phone, address_detail, is_default, created_at)
    VALUES
        (1, 5, N'Trần Minh', N'0900000005', N'15 Pasteur, Quận 3, TP. Hồ Chí Minh', 1, GETDATE()),
        (2, 5, N'Trần Minh (Công ty)', N'0909999888', N'Tòa nhà Bitexco, 2 Hải Triều, Bến Nghé, Quận 1, TP. Hồ Chí Minh', 0, GETDATE()),
        (3, 6, N'Lê Thu', N'0900000006', N'90 Trường Chinh, Tân Bình, TP. Hồ Chí Minh', 1, GETDATE()),
        (4, 23, N'Test Customer', N'0988888004', N'300 Tây Sơn, Ngã Tư Sở, Đống Đa, Hà Nội', 1, GETDATE()),
        (5, 23, N'Test Customer (Nhà riêng)', N'0988123456', N'Ngõ 10 Láng Hạ, Ba Đình, Hà Nội', 0, GETDATE()),
        (6, 8, N'Lê Minh Tuấn', N'0900000008', N'18 Nguyễn Du, District 1, HCMC', 1, GETDATE()),
        (7, 9, N'Nguyễn Thị Lan', N'0900000009', N'45 Lê Lợi, Bến Nghé, HCMC', 1, GETDATE()),
        (8, 26, N'Khách Hàng VIP', N'0988888005', N'50 Lý Tự Trọng, HCMC', 1, GETDATE());
    SET IDENTITY_INSERT dbo.user_addresses OFF;

    -- Đảm bảo tất cả 50 sản phẩm hạt giống ban đầu được phê duyệt hoạt động
    UPDATE dbo.products SET approval_status = 'APPROVED' WHERE approval_status = 'PENDING' AND product_id <= 50;

    COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK;
    THROW;
END CATCH;
GO

-- 1. Xóa hồ sơ shop cũ liên quan đến email hoặc số điện thoại này nếu có
DELETE FROM dbo.shop_owner_profiles 
WHERE user_id IN (SELECT user_id FROM dbo.users WHERE email = 'shop@gmail.com' OR phone = '0966668888');
-- 2. Xóa tài khoản cũ trùng email hoặc số điện thoại này để tránh lỗi UQ_users_phone
DELETE FROM dbo.users WHERE email = 'shop@gmail.com' OR phone = '0966668888';
-- 3. Khai báo biến tạm lưu ID tự sinh
DECLARE @new_user_id INT;
-- 4. Tạo tài khoản Shop Owner hoạt động ngay lập tức
INSERT INTO dbo.users (
    full_name, 
    email, 
    password_hash, 
    phone, 
    role, 
    status, 
    is_email_verified, 
    created_at, 
    updated_at
)
VALUES (
    N'Chủ Shop MetaFruit', 
    N'shop@gmail.com', 
    N'$2a$10$eJtSBoFU9dxFcylt020R/.ZGPp7ngnFUZJ6haG9bHNCzGPzPyzryK', -- BCrypt hash của '123456'
    N'0966668888', -- Số điện thoại mới sạch hoàn toàn
    N'SHOP_OWNER', 
    N'ACTIVE', 
    1, -- Đã kích hoạt không cần qua OTP
    GETDATE(), 
    GETDATE()
);
-- Lấy ID của User mới tạo
SET @new_user_id = SCOPE_IDENTITY();
-- 5. Tạo hồ sơ cửa hàng trạng thái APPROVED hoạt động ngay
INSERT INTO dbo.shop_owner_profiles (
    user_id, 
    shop_name, 
    shop_description, 
    approval_status, 
    delivery_address, 
    rating, 
    created_at, 
    updated_at
)
VALUES (
    @new_user_id, 
    N'Cửa Hàng Hoa Quả Sạch MetaFruit', 
    N'Chuyên cung cấp hoa quả hữu cơ nhập khẩu sạch đạt tiêu chuẩn quốc tế!', 
    N'APPROVED', 
    N'123 Đường Bưởi, Ba Đình, Hà Nội', 
    5.00, 
    GETDATE(), 
    GETDATE()
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_orders_acceptance_auto_cancel')
BEGIN
    CREATE INDEX IX_orders_acceptance_auto_cancel
    ON dbo.orders (status, shop_acceptance_deadline)
    WHERE status = 'CONFIRMED' AND shop_acceptance_deadline IS NOT NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_return_requests_status')
BEGIN
    CREATE INDEX IX_return_requests_status ON dbo.return_requests(status, created_at);
END
GO

-- =========================================================
-- Print Seed Info Log for debugging and testing
-- =========================================================
PRINT '========================================================================='
PRINT '                      ONLINE FRUIT SHOPPING SEED DATA                     '
PRINT '========================================================================='
PRINT '--- USERS & ACCOUNTS ---'
PRINT '  * ADMIN:           admin@fruitshop.local       / mật khẩu: 123456'
PRINT '  * TEST ADMIN:      admin@metafruit.vn          / mật khẩu: 123456'
PRINT '  * SHOP OWNER 1:    owner1@fruitshop.local      / mật khẩu: 123456  (An Phu Orchard)'
PRINT '  * SHOP OWNER 2:    owner2@fruitshop.local      / mật khẩu: 123456  (Mekong Fresh Farm)'
PRINT '  * SHOP OWNER 3:    owner3@fruitshop.local      / mật khẩu: 123456  (Klever Premium Fruits)'
PRINT '  * TEST SHOP OWNER: shop@metafruit.vn           / mật khẩu: 123456  (MetaFruit Test Shop)'
PRINT '  * DELIVERY STAFF:  delivery@fruitshop.local    / mật khẩu: 123456'
PRINT '  * TEST DELIVERY:   delivery@metafruit.vn       / mật khẩu: 123456'
PRINT '  * CUSTOMER 1:      customer1@fruitshop.local   / mật khẩu: 123456'
PRINT '  * CUSTOMER 2:      customer2@fruitshop.local   / mật khẩu: 123456'
PRINT '  * TEST CUSTOMER:   customer@metafruit.vn       / mật khẩu: 123456'
PRINT '  * CUSTOMER 3 (NEW):customer3@fruitshop.local   / mật khẩu: 123456'
PRINT '  * CUSTOMER 4 (NEW):customer4@fruitshop.local   / mật khẩu: 123456'
PRINT '  * CUSTOMER VIP:    vipcustomer@fruitshop.local / mật khẩu: 123456'
PRINT ''
PRINT '--- ACTIVE COUPONS & PROMOTIONS ---'
PRINT '  * SHOP10 (Shop 7 - Klever): Giảm 10% (Tối đa 50k) cho đơn từ 100k'
PRINT '  * SAAN5 (Hệ thống):         Giảm cố định 5k cho đơn từ 50k'
PRINT '  * SALE20 (Hệ thống):        Giảm 20% (Tối đa 100k) cho đơn từ 200k'
PRINT '  * METAFRUIT50 (Hệ thống):   Giảm 15% (Tối đa 150k) cho đơn từ 300k'
PRINT '  * FREESHIPALL (Hệ thống):   Giảm 15k phí vận chuyển cho đơn từ 150k'
PRINT '  * WELCOME10 (Hệ thống):     Giảm 10% (Tối đa 50k) cho đơn từ 120k'
PRINT '  * FREESHIP50 (Hệ thống):    Giảm 20k phí vận chuyển cho đơn từ 300k'
PRINT '  * ANPHU-GIAM30K (An Phu):   Giảm cố định 30k cho đơn từ 200k'
PRINT '  * MEKONG-GIAM20K (Mekong):  Giảm cố định 20k cho đơn từ 150k'
PRINT '  * KLEVER-GIAM50K (Klever):  Giảm cố định 50k cho đơn từ 400k'
PRINT '========================================================================='

-- Dynamic Test Data Seed Overwrites (Relative Dates)
-- Loại A: Chưa hết hạn (Vẫn giữ ACTIVE trên shop)
UPDATE dbo.products SET harvest_date = CAST(GETDATE() AS DATE), shelf_life_days = 30, status = 'ACTIVE' WHERE product_id = 1;
UPDATE dbo.products SET harvest_date = CAST(DATEADD(day, -2, GETDATE()) AS DATE), shelf_life_days = 7, status = 'ACTIVE' WHERE product_id = 3;
UPDATE dbo.products SET harvest_date = CAST(DATEADD(day, -3, GETDATE()) AS DATE), shelf_life_days = 10, status = 'ACTIVE' WHERE product_id = 6;
UPDATE dbo.products SET harvest_date = CAST(DATEADD(day, -1, GETDATE()) AS DATE), shelf_life_days = 7, status = 'ACTIVE' WHERE product_id = 8;
UPDATE dbo.products SET harvest_date = CAST(DATEADD(day, -2, GETDATE()) AS DATE), shelf_life_days = 12, status = 'ACTIVE' WHERE product_id = 10;
UPDATE dbo.products SET harvest_date = CAST(DATEADD(day, -1, GETDATE()) AS DATE), shelf_life_days = 5, status = 'ACTIVE' WHERE product_id = 12;
UPDATE dbo.products SET harvest_date = CAST(DATEADD(day, -3, GETDATE()) AS DATE), shelf_life_days = 4, status = 'ACTIVE' WHERE product_id = 14;
UPDATE dbo.products SET harvest_date = CAST(GETDATE() AS DATE), shelf_life_days = 30, status = 'ACTIVE' WHERE product_id = 16;
UPDATE dbo.products SET harvest_date = CAST(DATEADD(day, -5, GETDATE()) AS DATE), shelf_life_days = 14, status = 'ACTIVE' WHERE product_id = 17;

-- Loại B: Đã hết hạn thực tế (Tự động chuyển thành OUT_OF_SEASON khi load trang)
UPDATE dbo.products SET harvest_date = CAST(DATEADD(day, -45, GETDATE()) AS DATE), shelf_life_days = 20, status = 'ACTIVE' WHERE product_id = 2;
UPDATE dbo.products SET harvest_date = CAST(DATEADD(day, -10, GETDATE()) AS DATE), shelf_life_days = 6, status = 'ACTIVE' WHERE product_id = 4;
UPDATE dbo.products SET harvest_date = CAST(DATEADD(day, -50, GETDATE()) AS DATE), shelf_life_days = 30, status = 'ACTIVE' WHERE product_id = 7;
UPDATE dbo.products SET harvest_date = CAST(DATEADD(day, -15, GETDATE()) AS DATE), shelf_life_days = 6, status = 'ACTIVE' WHERE product_id = 9;

-- Loại C: Các sản phẩm khác (đặt hạn sử dụng = 5 ngày, luôn giữ ACTIVE)
UPDATE dbo.products SET harvest_date = CAST(GETDATE() AS DATE), shelf_life_days = 5, status = 'ACTIVE' WHERE product_id = 5;
UPDATE dbo.products SET harvest_date = CAST(GETDATE() AS DATE), shelf_life_days = 5, status = 'ACTIVE' WHERE product_id = 11;

-- Loại D: Các sản phẩm hữu cơ/nhập khẩu nâng cấp (51-53, 56-70) giữ ACTIVE
UPDATE dbo.products SET harvest_date = CAST(GETDATE() AS DATE), shelf_life_days = 30, status = 'ACTIVE' WHERE product_id BETWEEN 51 AND 53;
UPDATE dbo.products SET harvest_date = CAST(GETDATE() AS DATE), shelf_life_days = 30, status = 'ACTIVE' WHERE product_id BETWEEN 56 AND 70;

-- =========================================================
-- Migration v2: Chat WebSocket — session_type + unread index
-- =========================================================

-- Thêm cột session_type vào chat_sessions nếu chưa có
IF OBJECT_ID(N'dbo.chat_sessions', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.chat_sessions') AND name = N'session_type')
    BEGIN
        ALTER TABLE dbo.chat_sessions ADD session_type NVARCHAR(10) NOT NULL
            CONSTRAINT DF_chat_sessions_session_type DEFAULT 'SHOP'
            CONSTRAINT CK_chat_sessions_session_type CHECK (session_type IN ('SHOP', 'ADMIN'));
        PRINT 'Migration v2: Added session_type to chat_sessions.';
    END
END
GO

-- Index hỗ trợ đếm unread nhanh (dùng bởi ChatDAO.countUnread)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_chat_messages_session_unread' AND object_id = OBJECT_ID(N'dbo.chat_messages'))
BEGIN
    CREATE INDEX IX_chat_messages_session_unread
        ON dbo.chat_messages (session_id, is_read, sender_id);
    PRINT 'Migration v2: Created IX_chat_messages_session_unread.';
END
GO

-- =========================================================
-- Migration v3: Chat Media Support (ảnh/video)
-- =========================================================

IF OBJECT_ID(N'dbo.chat_messages', N'U') IS NOT NULL
BEGIN
    -- Cho phép content NULL (để chỉ gửi ảnh/video không có text)
    ALTER TABLE dbo.chat_messages ALTER COLUMN content NVARCHAR(MAX) NULL;
    PRINT 'Migration v3: Altered chat_messages.content to NULL.';

    -- Thêm cột media_url nếu chưa có
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.chat_messages') AND name = N'media_url')
    BEGIN
        ALTER TABLE dbo.chat_messages ADD media_url NVARCHAR(500) NULL;
        PRINT 'Migration v3: Added media_url to chat_messages.';
    END

    -- Thêm cột media_type nếu chưa có
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.chat_messages') AND name = N'media_type')
    BEGIN
        ALTER TABLE dbo.chat_messages ADD media_type NVARCHAR(10) NULL 
            CONSTRAINT CK_chat_messages_media_type CHECK (media_type IN ('IMAGE', 'VIDEO'));
        PRINT 'Migration v3: Added media_type to chat_messages.';
    END
END
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/*
  Embedded extended test seed.
  This block adds richer data for inventory and coupon testing.

  benefit_target meaning:
  - PRODUCT: discount applies to a specific product / product page sale
  - MERCHANDISE: discount applies to merchandise subtotal in checkout
  - SHIPPING: discount applies to shipping fee
  - PAYMENT_METHOD: discount applies after checkout, at the payment stage

  product_variants.discount_price / discount_start / discount_end:
  - Use these columns for time-based sale pricing on a variant.
*/

BEGIN TRY
    BEGIN TRAN;

    PRINT N'1/4 - Seeding extra product variants...';
    SET IDENTITY_INSERT dbo.product_variants ON;
    INSERT INTO dbo.product_variants (
        variant_id,
        product_id,
        sku,
        variant_label,
        price,
        stock_quantity,
        is_active,
        discount_price,
        discount_start,
        discount_end,
        created_at,
        updated_at
    )
    SELECT
        src.variant_id,
        src.product_id,
        src.sku,
        src.variant_label,
        src.price,
        src.stock_quantity,
        src.is_active,
        src.discount_price,
        src.discount_start,
        src.discount_end,
        src.created_at,
        src.updated_at
    FROM (VALUES
        (901, 16, N'TAO-ENVY-TET-1KG', N'Hộp 1kg Tết', 129000.00, 140, 1, 109000.00, DATEADD(day, -3, GETDATE()), DATEADD(day, 4, GETDATE()), DATEADD(day, -3, GETDATE()), GETDATE()),
        (902, 16, N'TAO-ENVY-TET-2KG', N'Combo 2kg Tết', 249000.00, 70, 1, 219000.00, DATEADD(day, -2, GETDATE()), DATEADD(day, 5, GETDATE()), DATEADD(day, -2, GETDATE()), GETDATE()),
        (903, 22, N'SAU-RIENG-RI6-CAO-CAP', N'Quả 3kg - 4kg', 390000.00, 42, 1, CAST(NULL AS DECIMAL(12,2)), CAST(NULL AS DATETIME), CAST(NULL AS DATETIME), DATEADD(day, -1, GETDATE()), GETDATE()),
        (904, 41, N'DAU-TUYET-HOP-500G', N'Hộp 500g Premium', 420000.00, 28, 1, 369000.00, DATEADD(day, -1, GETDATE()), DATEADD(day, 2, GETDATE()), GETDATE(), GETDATE()),
        (905, 51, N'NHO-MAU-DON-1KG', N'Hộp 1kg', 298000.00, 96, 1, CAST(NULL AS DECIMAL(12,2)), CAST(NULL AS DATETIME), CAST(NULL AS DATETIME), GETDATE(), GETDATE()),
        (906, 58, N'NHO-SAPPHIRE-GIFT-1KG', N'Hộp 1kg Gift', 199000.00, 110, 1, 179000.00, DATEADD(day, -4, GETDATE()), DATEADD(day, 6, GETDATE()), GETDATE(), GETDATE()),
        (907, 63, N'TAO-ROCKIT-HOP-6QT', N'Hộp 6 quả', 139000.00, 125, 1, 119000.00, DATEADD(day, -1, GETDATE()), DATEADD(day, 7, GETDATE()), DATEADD(day, -1, GETDATE()), GETDATE()),
        (908, 70, N'VAI-THIEU-LN-5KG', N'Túi 5kg', 189000.00, 90, 1, CAST(NULL AS DECIMAL(12,2)), CAST(NULL AS DATETIME), CAST(NULL AS DATETIME), GETDATE(), GETDATE())
    ) AS src (
        variant_id,
        product_id,
        sku,
        variant_label,
        price,
        stock_quantity,
        is_active,
        discount_price,
        discount_start,
        discount_end,
        created_at,
        updated_at
    )
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.product_variants pv
        WHERE pv.sku = src.sku
    );
    SET IDENTITY_INSERT dbo.product_variants OFF;

    PRINT N'2/4 - Seeding inventory logs...';
    SET IDENTITY_INSERT dbo.inventory_logs ON;
    INSERT INTO dbo.inventory_logs (
        log_id,
        variant_id,
        changed_by,
        change_type,
        quantity_delta,
        quantity_after,
        remaining_quantity,
        note,
        expires_at,
        is_expired,
        changed_at
    )
    SELECT
        src.log_id,
        src.variant_id,
        src.changed_by,
        src.change_type,
        src.quantity_delta,
        src.quantity_after,
        src.remaining_quantity,
        src.note,
        src.expires_at,
        src.is_expired,
        src.changed_at
    FROM (VALUES
        (5001, 901, 3, N'MANUAL_ADJUST', 140, 140, 124, N'Nhập kho lô Tết cho kênh online', CAST(DATEADD(day, 12, GETDATE()) AS date), 0, DATEADD(hour, -12, GETDATE())),
        (5002, 901, 5, N'ORDER_RESERVE', -8, 132, NULL, N'Giữ hàng cho 8 đơn flash sale', CAST(DATEADD(day, 12, GETDATE()) AS date), 0, DATEADD(hour, -11, GETDATE())),
        (5003, 901, 5, N'ORDER_CONFIRM', -8, 124, NULL, N'Xác nhận xuất kho cho 8 đơn', CAST(DATEADD(day, 12, GETDATE()) AS date), 0, DATEADD(hour, -10, GETDATE())),
        (5004, 902, 3, N'MANUAL_ADJUST', 70, 70, 70, N'Nhập bổ sung combo 2kg', CAST(DATEADD(day, 10, GETDATE()) AS date), 0, DATEADD(hour, -9, GETDATE())),
        (5005, 902, 4, N'ORDER_RESERVE', -10, 60, NULL, N'Dự trữ 10 combo cho chiến dịch', CAST(DATEADD(day, 10, GETDATE()) AS date), 0, DATEADD(hour, -8, GETDATE())),
        (5006, 902, 4, N'ORDER_RELEASE', 10, 70, NULL, N'Khách hủy 10 combo, trả lại kho', CAST(DATEADD(day, 10, GETDATE()) AS date), 0, DATEADD(hour, -7, GETDATE())),
        (5007, 904, 4, N'MANUAL_ADJUST', 28, 28, 24, N'Nhập hàng lạnh premium', CAST(DATEADD(day, 5, GETDATE()) AS date), 0, DATEADD(hour, -6, GETDATE())),
        (5008, 904, 4, N'EXPIRED', -4, 24, NULL, N'Loại 4 hộp hết hạn lưu kho', CAST(DATEADD(day, -2, GETDATE()) AS date), 1, DATEADD(hour, -5, GETDATE())),
        (5009, 906, 7, N'MANUAL_ADJUST', 110, 110, 107, N'Nhập kho nho sapphire gift', CAST(DATEADD(day, 15, GETDATE()) AS date), 0, DATEADD(hour, -4, GETDATE())),
        (5010, 906, 7, N'SPOILED', -3, 107, NULL, N'Loại bỏ 3 hộp bị dập mép', CAST(DATEADD(day, 15, GETDATE()) AS date), 0, DATEADD(hour, -3, GETDATE())),
        (5011, 907, 3, N'MANUAL_ADJUST', 125, 125, 95, N'Nhập kho táo Rockit hộp 6 quả', CAST(DATEADD(day, 8, GETDATE()) AS date), 0, DATEADD(hour, -2, GETDATE())),
        (5012, 907, 5, N'ORDER_RESERVE', -15, 110, NULL, N'Dự trữ 15 hộp cho đặt trước', CAST(DATEADD(day, 8, GETDATE()) AS date), 0, DATEADD(hour, -1, GETDATE())),
        (5013, 907, 5, N'ORDER_CONFIRM', -15, 95, NULL, N'Xuất kho đơn đặt trước đã xác nhận', CAST(DATEADD(day, 8, GETDATE()) AS date), 0, GETDATE()),
        (5014, 908, 4, N'MANUAL_ADJUST', 90, 90, 92, N'Nhập kho vải thiều Lục Ngạn', CAST(DATEADD(day, 6, GETDATE()) AS date), 0, GETDATE()),
        (5015, 908, 4, N'RETURN', 2, 92, NULL, N'Nhận lại 2 túi từ đơn đổi trả', CAST(DATEADD(day, 6, GETDATE()) AS date), 0, DATEADD(minute, 10, GETDATE()))
    ) AS src (
        log_id,
        variant_id,
        changed_by,
        change_type,
        quantity_delta,
        quantity_after,
        remaining_quantity,
        note,
        expires_at,
        is_expired,
        changed_at
    )
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.inventory_logs il
        WHERE il.log_id = src.log_id
    );
    SET IDENTITY_INSERT dbo.inventory_logs OFF;

    -- Tự động khởi tạo remaining_quantity cho các lô chưa có dữ liệu tồn
    UPDATE dbo.inventory_logs
    SET remaining_quantity = quantity_delta
    WHERE remaining_quantity IS NULL AND change_type = 'MANUAL_ADJUST' AND quantity_delta > 0;

    -- Tự động tạo lô nhập kho ban đầu cho tất cả sản phẩm đang có tồn kho > 0 mà chưa có lô trong inventory_logs
    INSERT INTO dbo.inventory_logs (variant_id, changed_by, change_type, quantity_delta, quantity_after, remaining_quantity, note, expires_at, is_expired, changed_at)
    SELECT
        pv.variant_id,
        p.owner_id,
        'MANUAL_ADJUST',
        pv.stock_quantity,
        pv.stock_quantity,
        pv.stock_quantity,
        N'Lô hàng khởi tạo hệ thống',
        CAST(DATEADD(day, ISNULL(p.shelf_life_days, 15), GETDATE()) AS DATE),
        0,
        pv.created_at
    FROM dbo.product_variants pv
    JOIN dbo.products p ON pv.product_id = p.product_id
    WHERE pv.stock_quantity > 0
      AND NOT EXISTS (
          SELECT 1 FROM dbo.inventory_logs il
          WHERE il.variant_id = pv.variant_id AND il.change_type = 'MANUAL_ADJUST' AND il.quantity_delta > 0
      );

    PRINT N'3/4 - Seeding promotions...';
    PRINT N'    benefit_target = PRODUCT / MERCHANDISE / SHIPPING / PAYMENT_METHOD';
    SET IDENTITY_INSERT dbo.promotions ON;
    INSERT INTO dbo.promotions (
        promo_id,
        code,
        discount_type,
        discount_scope,
        discount_max,
        discount_value,
        min_order_value,
        scope,
        benefit_target,
        product_id,
        max_uses,
        used_count,
        can_stack,
        valid_from,
        valid_until,
        created_by,
        created_at,
        updated_at,
        is_deleted,
        is_active
    )
    SELECT
        src.promo_id,
        src.code,
        src.discount_type,
        src.discount_scope,
        src.discount_max,
        src.discount_value,
        src.min_order_value,
        src.scope,
        src.benefit_target,
        src.product_id,
        src.max_uses,
        src.used_count,
        src.can_stack,
        src.valid_from,
        src.valid_until,
        src.created_by,
        src.created_at,
        src.updated_at,
        src.is_deleted,
        src.is_active
    FROM (VALUES
        (7001, N'TEST-ENVY-12P', N'PERCENT', N'ALL', 45000.00, 12.00, 30000.00, N'PRODUCT', N'PRODUCT', 16, 500, 12, 1, DATEADD(day, -30, GETDATE()), DATEADD(day, 60, GETDATE()), 3, DATEADD(day, -5, GETDATE()), DATEADD(day, -1, GETDATE()), 0, 1),
        (7002, N'TEST-ROCKIT-20K', N'FIXED', N'ALL', 0.00, 20000.00, 30000.00, N'PRODUCT', N'PRODUCT', 63, 200, 20, 1, DATEADD(day, -20, GETDATE()), DATEADD(day, 45, GETDATE()), 3, DATEADD(day, -4, GETDATE()), GETDATE(), 0, 1),
        (7003, N'TEST-DAU-TUYET-15P', N'PERCENT', N'ALL', 60000.00, 15.00, 50000.00, N'PRODUCT', N'PRODUCT', 41, 150, 9, 0, DATEADD(day, -15, GETDATE()), DATEADD(day, 30, GETDATE()), 4, DATEADD(day, -3, GETDATE()), GETDATE(), 0, 1),
        (7004, N'TEST-MERCH-5P', N'PERCENT', N'SHOP', 70000.00, 5.00, 30000.00, N'ORDER', N'MERCHANDISE', NULL, 1000, 35, 0, DATEADD(day, -60, GETDATE()), DATEADD(day, 90, GETDATE()), 3, DATEADD(day, -8, GETDATE()), GETDATE(), 0, 1),
        (7005, N'TEST-MERCH-35K', N'FIXED', N'ALL', 0.00, 35000.00, 50000.00, N'ORDER', N'MERCHANDISE', NULL, 600, 18, 1, DATEADD(day, -45, GETDATE()), DATEADD(day, 120, GETDATE()), 4, DATEADD(day, -7, GETDATE()), GETDATE(), 0, 1),
        (7006, N'TEST-SHIP-20K', N'FIXED', N'ALL', 0.00, 20000.00, 30000.00, N'ORDER', N'SHIPPING', NULL, 400, 11, 0, DATEADD(day, -45, GETDATE()), DATEADD(day, 60, GETDATE()), 7, DATEADD(day, -6, GETDATE()), GETDATE(), 0, 1),
        (7007, N'TEST-SHIP-FREE', N'FIXED', N'SHOP', 0.00, 30000.00, 50000.00, N'ORDER', N'SHIPPING', NULL, 250, 4, 0, DATEADD(day, -30, GETDATE()), DATEADD(day, 75, GETDATE()), 7, DATEADD(day, -5, GETDATE()), GETDATE(), 0, 1),
        (7008, N'TEST-EXPIRED-ENVY', N'PERCENT', N'ALL', 50000.00, 18.00, 30000.00, N'PRODUCT', N'PRODUCT', 16, 50, 50, 0, DATEADD(day, -90, GETDATE()), DATEADD(day, -1, GETDATE()), 1, DATEADD(day, -60, GETDATE()), DATEADD(day, -1, GETDATE()), 0, 0),
        (7009, N'TEST-STACK-10K', N'FIXED', N'ALL', 0.00, 10000.00, 30000.00, N'ORDER', N'MERCHANDISE', NULL, 1000, 0, 1, DATEADD(day, -10, GETDATE()), DATEADD(day, 120, GETDATE()), 1, DATEADD(day, -2, GETDATE()), GETDATE(), 0, 1),
        (7010, N'TEST-SHIPPING-10P', N'PERCENT', N'ALL', 40000.00, 10.00, 50000.00, N'ORDER', N'SHIPPING', NULL, 300, 5, 1, DATEADD(day, -10, GETDATE()), DATEADD(day, 120, GETDATE()), 4, DATEADD(day, -2, GETDATE()), GETDATE(), 0, 1),
        (7011, N'TEST-PAY-8K', N'FIXED', N'ALL', 0.00, 8000.00, 100000.00, N'ORDER', N'PAYMENT_METHOD', NULL, 500, 0, 1, DATEADD(day, -10, GETDATE()), DATEADD(day, 90, GETDATE()), 1, DATEADD(day, -2, GETDATE()), GETDATE(), 0, 1),
        (7012, N'TEST-PAY-12P-NOSTACK', N'PERCENT', N'ALL', 60000.00, 12.00, 150000.00, N'ORDER', N'PAYMENT_METHOD', NULL, 200, 0, 0, DATEADD(day, -10, GETDATE()), DATEADD(day, 90, GETDATE()), 1, DATEADD(day, -2, GETDATE()), GETDATE(), 0, 1)
    ) AS src (
        promo_id,
        code,
        discount_type,
        discount_scope,
        discount_max,
        discount_value,
        min_order_value,
        scope,
        benefit_target,
        product_id,
        max_uses,
        used_count,
        can_stack,
        valid_from,
        valid_until,
        created_by,
        created_at,
        updated_at,
        is_deleted,
        is_active
    )
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.promotions p
        WHERE p.code = src.code
    );
    SET IDENTITY_INSERT dbo.promotions OFF;

    PRINT N'4/4 - Seeding coupon usage history...';
    SET IDENTITY_INSERT dbo.order_promotions ON;
    INSERT INTO dbo.order_promotions (
        usage_id,
        order_id,
        promo_id,
        customer_id,
        discount_applied,
        coupon_code,
        discount_scope,
        benefit_target,
        used_at
    )
    SELECT
        src.usage_id,
        src.order_id,
        src.promo_id,
        src.customer_id,
        src.discount_applied,
        src.coupon_code,
        src.discount_scope,
        src.benefit_target,
        src.used_at
    FROM (VALUES
        (8001, 10, 7004, 10, 5000.00, N'TEST-MERCH-5P', N'SHOP', N'MERCHANDISE', DATEADD(hour, -4, GETDATE())),
        (8002, 11, 7006, 11, 15000.00, N'TEST-SHIP-20K', N'ALL', N'SHIPPING', DATEADD(hour, -3, GETDATE())),
        (8003, 12, 7001, 12, 12000.00, N'TEST-ENVY-12P', N'ALL', N'PRODUCT', DATEADD(hour, -2, GETDATE())),
        (8004, 13, 7005, 13, 35000.00, N'TEST-MERCH-35K', N'ALL', N'MERCHANDISE', DATEADD(hour, -1, GETDATE())),
        (8005, 14, 7007, 14, 15000.00, N'TEST-SHIP-FREE', N'SHOP', N'SHIPPING', GETDATE()),
        (8006, 15, 7002, 15, 20000.00, N'TEST-ROCKIT-20K', N'ALL', N'PRODUCT', DATEADD(minute, -30, GETDATE())),
        (8007, 100, 7011, 5, 8000.00, N'TEST-PAY-8K', N'ALL', N'PAYMENT_METHOD', DATEADD(minute, -20, GETDATE())),
        (8008, 101, 7012, 5, 12000.00, N'TEST-PAY-12P-NOSTACK', N'ALL', N'PAYMENT_METHOD', DATEADD(minute, -10, GETDATE()))
    ) AS src (
        usage_id,
        order_id,
        promo_id,
        customer_id,
        discount_applied,
        coupon_code,
        discount_scope,
        benefit_target,
        used_at
    )
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.order_promotions op
        WHERE op.usage_id = src.usage_id
    );
    SET IDENTITY_INSERT dbo.order_promotions OFF;

    COMMIT TRAN;
    PRINT N'Extended test seed completed successfully.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRAN;

    SET IDENTITY_INSERT dbo.product_variants OFF;
    SET IDENTITY_INSERT dbo.inventory_logs OFF;
    SET IDENTITY_INSERT dbo.promotions OFF;
    SET IDENTITY_INSERT dbo.order_promotions OFF;

    THROW;
END CATCH;
GO

PRINT N'=== Copy-ready result sets ===';

SELECT
    N'product_variants' AS section,
    variant_id,
    product_id,
    sku,
    variant_label,
    price,
    stock_quantity,
    discount_price,
    discount_start,
    discount_end,
    is_active,
    created_at,
    updated_at
FROM dbo.product_variants
WHERE variant_id BETWEEN 901 AND 908
ORDER BY variant_id;

SELECT
    N'inventory_logs' AS section,
    log_id,
    variant_id,
    changed_by,
    change_type,
    quantity_delta,
    quantity_after,
    note,
    expires_at,
    is_expired,
    changed_at
FROM dbo.inventory_logs
WHERE log_id BETWEEN 5001 AND 5015
ORDER BY log_id;

SELECT
    N'promotions' AS section,
    promo_id,
    code,
    discount_type,
    discount_scope,
    discount_max,
    discount_value,
    min_order_value,
    scope,
    benefit_target,
    product_id,
    max_uses,
    used_count,
    can_stack,
    valid_from,
    valid_until,
    is_active
FROM dbo.promotions
WHERE promo_id BETWEEN 7001 AND 7012
ORDER BY promo_id;

SELECT
    N'order_promotions' AS section,
    usage_id,
    order_id,
    promo_id,
    customer_id,
    discount_applied,
    coupon_code,
    discount_scope,
    benefit_target,
    used_at
FROM dbo.order_promotions
WHERE usage_id BETWEEN 8001 AND 8008
ORDER BY usage_id;

SELECT
    (SELECT COUNT(*) FROM dbo.product_variants WHERE variant_id BETWEEN 901 AND 908) AS seeded_product_variants,
    (SELECT COUNT(*) FROM dbo.inventory_logs WHERE log_id BETWEEN 5001 AND 5015) AS seeded_inventory_logs,
    (SELECT COUNT(*) FROM dbo.promotions WHERE promo_id BETWEEN 7001 AND 7012) AS seeded_promotions,
    (SELECT COUNT(*) FROM dbo.order_promotions WHERE usage_id BETWEEN 8001 AND 8008) AS seeded_order_promotions;


-- Migration guard for settlement tracking columns
IF COL_LENGTH('dbo.shop_settlements', 'confirmed_at') IS NULL
BEGIN
    ALTER TABLE dbo.shop_settlements ADD confirmed_at DATETIME NULL;
    ALTER TABLE dbo.shop_settlements ADD confirmed_by INT NULL;
    ALTER TABLE dbo.shop_settlements ADD confirm_note NVARCHAR(500) NULL;
    ALTER TABLE dbo.shop_settlements ADD cancelled_at DATETIME NULL;
    ALTER TABLE dbo.shop_settlements ADD cancelled_by INT NULL;
    ALTER TABLE dbo.shop_settlements ADD cancel_reason NVARCHAR(500) NULL;
    ALTER TABLE dbo.shop_settlements ADD paid_at DATETIME NULL;
    ALTER TABLE dbo.shop_settlements ADD paid_by INT NULL;
    ALTER TABLE dbo.shop_settlements ADD paid_reference NVARCHAR(100) NULL;
    ALTER TABLE dbo.shop_settlements ADD paid_note NVARCHAR(500) NULL;
    ALTER TABLE dbo.shop_settlements ADD CONSTRAINT FK_shop_settlements_confirmed_by FOREIGN KEY (confirmed_by) REFERENCES dbo.users(user_id);
    ALTER TABLE dbo.shop_settlements ADD CONSTRAINT FK_shop_settlements_cancelled_by FOREIGN KEY (cancelled_by) REFERENCES dbo.users(user_id);
    ALTER TABLE dbo.shop_settlements ADD CONSTRAINT FK_shop_settlements_paid_by FOREIGN KEY (paid_by) REFERENCES dbo.users(user_id);
END
GO
