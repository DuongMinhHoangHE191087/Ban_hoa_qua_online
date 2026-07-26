package config;

/**
 * AppConfig — Hằng số toàn cục của ứng dụng.
 *
 * Đây là nơi DUY NHẤT chứa các magic number và string literals dùng chung.
 * Khi cần thay đổi giá trị config, chỉ sửa ở đây.
 *
 * @author fruitmkt-team
 */
public final class AppConfig {
        public static final String APP_ENV = "development";

        // ——————————————————————————————————————————————————————————————————
        // Database
        // ------------------------------------------------------------------
        public static final String DB_HOST     = "localhost";
        public static final String DB_PORT     = "1433";
        public static final String DB_NAME     = "OnlineFruitShopping";
        public static final String DB_USER     = "sa";
        public static final String DB_PASSWORD = "123";
        public static final String DB_DRIVER_CLASS = "com.microsoft.sqlserver.jdbc.SQLServerDriver";
        public static final String DB_JDBC_URL = "jdbc:sqlserver://" + DB_HOST + ":" + DB_PORT
                        + ";databaseName=" + DB_NAME
                        + ";encrypt=true;trustServerCertificate=true;keepAlive=true";

        public static final String GOOGLE_CLIENT_ID = "710006759532-tnve0ctpc8d6m88qidm8g65in482rfnn.apps.googleusercontent.com";
        public static final String GOOGLE_CLIENT_SECRET = "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";
        // Domain của bạn. Nếu code ở localhost thì để HTTP.
        public static final String GOOGLE_REDIRECT_URI = "http://localhost:8080/Ban_Hoa_Qua_Online/GoogleCallback";
        public static final String GOOGLE_LINK_GET_TOKEN = "https://oauth2.googleapis.com/token";
        public static final String GOOGLE_LINK_GET_USER_INFO = "https://openidconnect.googleapis.com/v1/userinfo";
        public static final String GOOGLE_GRANT_TYPE = "authorization_code";
 
        public static final String EMAIL_SMTP_HOST = "smtp.gmail.com";
        public static final String EMAIL_SMTP_PORT = "587";
        public static final String EMAIL_FROM = "duongminhhoanginwork@gmail.com";
        public static final String EMAIL_PASSWORD = "jkhg przg aohf pwla";
        public static final String SECRET_KEY = "fruitmkt-super-secret-key-2026-secure-sha256";
        public static final String GEMINI_API_KEY = null;
        public static final long ACCESS_TOKEN_EXPIRY_MS   = 15L * 60 * 1000; // 15 phút
        public static final int  REFRESH_TOKEN_EXPIRY_SECS = 7 * 24 * 60 * 60;
        public static final String APP_NAME = "MetaFruit";
        public static final String APP_SUPPORT_EMAIL = EMAIL_FROM;
        public static final String APP_BRAND_COLOR = "#14532d";
        public static final String APP_BASE_URL = "http://localhost:8080/Ban_Hoa_Qua_Online";

        // ------------------------------------------------------------------
        // Email verification
        // ------------------------------------------------------------------
        public static final int EMAIL_VERIFICATION_CODE_LENGTH = 6;
        public static final int EMAIL_VERIFICATION_TTL_MINUTES = 5;
        public static final int EMAIL_VERIFICATION_RESEND_SECONDS = 60;

        // ------------------------------------------------------------------
        // Account status
        // ------------------------------------------------------------------
        public static final String ACCOUNT_STATUS_ACTIVE = "ACTIVE";
        public static final String ACCOUNT_STATUS_INACTIVE = "INACTIVE";
        public static final String ACCOUNT_STATUS_LOCKED = "LOCKED";
        public static final String ACCOUNT_STATUS_SUSPENDED = "SUSPENDED";

        // ------------------------------------------------------------------
        // Phân trang (Pagination)
        // ------------------------------------------------------------------
        /** Số sản phẩm mỗi trang trên trang listing */
        public static final int PAGE_SIZE_PRODUCTS = 20;
        /** Số đơn hàng mỗi trang */
        public static final int PAGE_SIZE_ORDERS = 15;
        /** Số dòng admin table mỗi trang */
        public static final int PAGE_SIZE_ADMIN = 25;
        /** Kích thước trang tối đa cho phép */
        public static final int MAX_PAGE_SIZE = 100;
        /** Kích thước trang mặc định */
        public static final int DEFAULT_PAGE_SIZE = 10;

        // ------------------------------------------------------------------
        // Upload File
        // ------------------------------------------------------------------
        /** Kích thước tối đa 1 file upload ảnh sản phẩm: 5 MB */
        public static final long MAX_UPLOAD_SIZE_BYTES = 5L * 1024 * 1024;
        /** Thư mục upload relative với webapp root — tạo bằng FileUploadUtil */
        public static final String UPLOAD_DIR = "uploads";
        /** Thư mục lưu trữ file upload thực tế bền vững ngoài thư mục build */
        public static final String PERSISTENT_UPLOAD_DIR = System.getProperty("user.home") 
                + java.io.File.separator + "fruitshop_uploads";
        /** Các đuôi file ảnh được phép */
        public static final String[] ALLOWED_IMAGE_EXTS = { "jpg", "jpeg", "png", "webp" };

        /** Kích thước tối đa 1 tài liệu xác minh shop: 25 MB */
        public static final long MAX_SHOP_DOC_SIZE_BYTES = 25L * 1024 * 1024;
        /** Số tài liệu tối đa upload trong 1 lần đăng ký shop */
        public static final int MAX_SHOP_DOC_COUNT = 10;
        /** Các đuôi file tài liệu được phép upload khi đăng ký shop */
        public static final String[] ALLOWED_DOC_EXTS = { "pdf", "jpg", "jpeg", "png", "docx" };
        /** Thư mục con lưu tài liệu xác minh shop, relative với webapp root */
        public static final String UPLOAD_SHOP_DOCS_DIR = "uploads/shop-docs";
        /** Thư mục nháp tạm cho tài liệu xác minh shop */
        public static final String UPLOAD_SHOP_DOCS_DRAFT_DIR = "uploads/shop-docs/_draft";
        /** Thời gian sống tối đa của draft upload trước khi được dọn tự động */
        public static final long SHOP_DOC_DRAFT_TTL_MS = 24L * 60 * 60 * 1000;

        // ------------------------------------------------------------------
        // Logging
        // ------------------------------------------------------------------
        /** Thư mục chứa file log dưới webapp root hoặc working directory. */
        public static final String LOG_DIR = "logs";
        /** File log chính để trace SQL DAO. */
        public static final String LOG_FILE_NAME = "log.txt";

        // ------------------------------------------------------------------
        // Session Keys — dùng thống nhất trong toàn bộ code
        // ------------------------------------------------------------------
        /** Key lưu User object trong session sau khi đăng nhập */
        public static final String SESSION_USER = "currentUser";
        /** Key lưu email chờ xác minh */
        public static final String SESSION_VERIFY_EMAIL = "verifyEmail";
        /** Key lưu email đang trong quá trình forgot password (tách biệt với verify email) */
        public static final String SESSION_FORGOT_EMAIL = "forgotEmail";
        /** Cờ đánh dấu đã verify OTP forgot password thành công — bắt buộc trước khi cho reset */
        public static final String SESSION_FORGOT_VERIFIED = "forgotVerified";
        /** Key lưu flash message sau PRG redirect */
        public static final String SESSION_FLASH_MSG = "flashMsg";
        /** Key lưu loại flash (success / error / warning / info) */
        public static final String SESSION_FLASH_TYPE = "flashType";
        /** Key lưu CSRF token */
        public static final String SESSION_CSRF_TOKEN = "_csrfToken";

        // ------------------------------------------------------------------
        // Role Values — khớp với column role trong bảng users
        // ------------------------------------------------------------------
        public static final String ROLE_CUSTOMER = "CUSTOMER";
        public static final String ROLE_SHOP_OWNER = "SHOP_OWNER";
        public static final String ROLE_DELIVERY = "DELIVERY";
        public static final String ROLE_ADMIN = "ADMIN";

        // ------------------------------------------------------------------
        // Order Status — khớp CHECK constraint trong bảng orders
        // ------------------------------------------------------------------
        public static final String ORDER_PENDING_PAYMENT = "PENDING_PAYMENT";
        public static final String ORDER_APPROVED = "APPROVED";
        public static final String ORDER_CONFIRMED = "CONFIRMED";
        public static final String ORDER_PREPARING = "PREPARING";
        public static final String ORDER_DISPATCHED = "DISPATCHED";
        public static final String ORDER_DELIVERED = "DELIVERED";
        public static final String ORDER_CANCELLED = "CANCELLED";
        public static final String ORDER_PAYMENT_FAILED = "PAYMENT_FAILED";
        public static final String ORDER_EXPIRED = "EXPIRED";

        public static final String ORDER_TYPE_PARENT = "PARENT";
        public static final String ORDER_TYPE_CHILD = "CHILD";

        // ------------------------------------------------------------------
        // Delivery Status
        // ------------------------------------------------------------------
        public static final String DELIVERY_ASSIGNED = "ASSIGNED";
        public static final String DELIVERY_PICKED_UP = "PICKED_UP";
        public static final String DELIVERY_IN_TRANSIT = "IN_TRANSIT";
        public static final String DELIVERY_DELIVERED = "DELIVERED";
        public static final String DELIVERY_FAILED = "FAILED";

        public static final String DELIVERY_TRIP_PLANNED = "PLANNED";
        public static final String DELIVERY_TRIP_ASSIGNED = "ASSIGNED";
        public static final String DELIVERY_TRIP_PICKED_UP = "PICKED_UP";
        public static final String DELIVERY_TRIP_IN_TRANSIT = "IN_TRANSIT";
        public static final String DELIVERY_TRIP_DELIVERED = "DELIVERED";
        public static final String DELIVERY_TRIP_FAILED = "FAILED";
        public static final String DELIVERY_TRIP_CANCELLED = "CANCELLED";

        // ------------------------------------------------------------------
        // Shop Approval Status
        // ------------------------------------------------------------------
        public static final String SHOP_PENDING = "PENDING";
        public static final String SHOP_APPROVED = "APPROVED";
        public static final String SHOP_REJECTED = "REJECTED";
        public static final String SHOP_SUSPENDED = "SUSPENDED";

        // ------------------------------------------------------------------
        // Payment Method
        // ------------------------------------------------------------------
        public static final String PAYMENT_CK = "CK"; // Chuyển khoản
        public static final String PAYMENT_COD = "COD"; // Thanh toán khi nhận

        // ------------------------------------------------------------------
        // Return Request
        // ------------------------------------------------------------------
        public static final String RETURN_REQUESTED = "REQUESTED";
        public static final String RETURN_APPROVED = "APPROVED";
        public static final String RETURN_REJECTED = "REJECTED";
        public static final String RETURN_PROCESSING = "PROCESSING";
        public static final String RETURN_COMPLETED = "COMPLETED";
        public static final String RETURN_CANCELLED = "CANCELLED";

        // ------------------------------------------------------------------
        // Notification Types
        // ------------------------------------------------------------------
        public static final String NOTIF_ORDER_UPDATE = "ORDER_UPDATE";
        public static final String NOTIF_PROMOTION = "PROMOTION";
        public static final String NOTIF_SYSTEM = "SYSTEM";
        public static final String NOTIF_INVENTORY_ALERT = "INVENTORY_ALERT";
        public static final String NOTIF_PAYMENT = "PAYMENT";

        // ------------------------------------------------------------------
        // Inventory Change Types
        // ------------------------------------------------------------------
        public static final String INVENTORY_CHANGE_MANUAL = "MANUAL_ADJUST";
        public static final String INVENTORY_CHANGE_RESERVE = "ORDER_RESERVE";
        public static final String INVENTORY_CHANGE_RELEASE = "ORDER_RELEASE";
        public static final String INVENTORY_CHANGE_CONFIRM = "ORDER_CONFIRM";
        public static final String INVENTORY_CHANGE_RETURN = "RETURN";
        public static final String INVENTORY_CHANGE_EXPIRED = "EXPIRED";
        public static final String INVENTORY_CHANGE_SPOILED = "SPOILED";

        // ------------------------------------------------------------------
        // Security
        // ------------------------------------------------------------------
        /** Số lần đăng nhập sai tối đa trước khi khóa tài khoản */
        public static final int MAX_FAILED_LOGIN = 5;
        /** Thời gian khóa tài khoản (phút) — SEC-01 / UC-02 */
        public static final int LOCK_DURATION_MINUTES = 15;

        // ------------------------------------------------------------------
        // Platform Fee & Settlement (default values — override via system_config DB)
        // ------------------------------------------------------------------
        /** Tỷ lệ phí nền tảng mặc định (%). Admin có thể đổi qua AdminSystemConfigServlet. */
        public static final double PLATFORM_FEE_RATE_DEFAULT = 5.0;      // 5%
        /** Số ngày đóng băng tiền shop sau khi giao hàng thành công mặc định. */
        public static final int    FREEZE_DAYS_DEFAULT        = 15;       // 15 ngày
        /** Số giờ đóng băng mặc định (PAY-03) — dùng khi cần độ phân giải giờ thay vì ngày. */
        public static final int    FREEZE_HOURS_DEFAULT       = 12;
        /** Thời gian giải quyết khi settlement period (ngày). */
        public static final int    SETTLEMENT_CYCLE_DAYS      = 30;

        // ------------------------------------------------------------------
        // Shop Order Acceptance
        // ------------------------------------------------------------------
        /** Shop phải nhận đơn trong bao nhiêu phút. Quá hạn tự huỷ. */
        public static final int    SHOP_ACCEPT_TIMEOUT_MIN    = 30;       // 30 phút

        // ------------------------------------------------------------------
        // Return Request
        // ------------------------------------------------------------------
        /** Khách có tối đa bao nhiêu giờ sau khi DELIVERED để gửi return request. REF-01 */
        public static final int    RETURN_REQUEST_MAX_HOURS   = 24;       // 24 giờ (khớp seed return_request_max_hours)

        // ------------------------------------------------------------------
        // SePay / VietQR (thêm domain deploy ở đây khi lên production)
        // ------------------------------------------------------------------
        public static final String SEPAY_BANK_ID      = "MBBank";
        public static final String SEPAY_ACCOUNT_NO   = "SBSEPAY3NHWA061W5V2";
        public static final String SEPAY_ACCOUNT_NAME = "CONG TY TNHH METAFRUIT";
        public static final String PAYMENT_REF_PREFIX  = "MF";
        /** Thời hạn hiệu lực của mã QR (phút). PAY-02 */
        public static final int    QR_EXPIRE_MINUTES   = 10;
        /**
         * Domain đầy đủ của ứng dụng khi deploy lên server.
         * Dùng cho SePay Webhook URL và link email.
         * Đổi sang domain thật khi deploy: https://yourdomain.com
         */
        public static final String DEPLOY_BASE_URL    = APP_BASE_URL;
        public static final String SEPAY_WEBHOOK_PATH  = "/api/payment/webhook";

        // ------------------------------------------------------------------
        // System Config Keys (dùng với bảng system_config trong DB)
        // ------------------------------------------------------------------
        public static final String CONFIG_PLATFORM_FEE_RATE    = "platform_fee_rate";
        public static final String CONFIG_FREEZE_DAYS          = "settlement_freeze_days";
        public static final String CONFIG_ACCEPT_TIMEOUT_MIN   = "shop_accept_timeout_min";
        public static final String CONFIG_RETURN_MAX_HOURS     = "return_request_max_hours";
        public static final String CONFIG_SEPAY_BANK_ID        = "sepay_bank_id";
        public static final String CONFIG_SEPAY_ACCOUNT_NO     = "sepay_account_no";
        public static final String CONFIG_SEPAY_ACCOUNT_NAME   = "sepay_account_name";
        public static final String CONFIG_GEMINI_API_KEY       = "gemini_api_key";
        public static final String CONFIG_GEMINI_MODEL         = "gemini_model";

        /**
         * Model Gemini mặc định khi Admin chưa cấu hình (system_config key {@code gemini_model})
         * và biến môi trường {@code GEMINI_MODEL} cũng trống.
         * Dùng alias "-latest" để Google tự trỏ sang bản flash hiện hành, tránh lỗi 404
         * "model không khả dụng" khi một model có phiên bản cố định bị ngừng phục vụ.
         */
        public static final String GEMINI_MODEL_DEFAULT        = "gemini-flash-latest";

        private AppConfig() {
                /* Utility class — không khởi tạo */ }

        /**
         * Cấu hình hiện được giữ cố định trong AppConfig nên không cần kiểm tra env.
         */
        public static void validateSecretsForProduction() {
                // No environment variables expected now as they are all inside AppConfig
        }

}
