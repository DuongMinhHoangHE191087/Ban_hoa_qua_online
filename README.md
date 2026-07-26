# 📁 MetaFruit — Nền Tảng Thương Mại Điện Tử Hoa Quả Trực Tuyến Đa Cửa Hàng

[![Tech Stack](https://img.shields.io/badge/Tech%20Stack-Java%2017%2F25%20%7C%20Tomcat%2010.1%20%7C%20SQL%20Server%202022-orange.svg?style=for-the-badge)](file:///README.md)
[![Jakarta EE](https://img.shields.io/badge/Jakarta%20EE-10%20(Servlet%206.0%2C%20JSP%203.1)-blue.svg?style=for-the-badge)](file:///README.md)
[![Security](https://img.shields.io/badge/Security-BCrypt%20%7C%20CSRF%20%7C%20RBAC%20%7C%20XSS%20%7C%20PRG-green.svg?style=for-the-badge)](file:///README.md)
[![Architecture](https://img.shields.io/badge/Architecture-MVC%20Layered%20(Servlet--Service--DAO)-purple.svg?style=for-the-badge)](file:///README.md)

Chào mừng bạn đến với **MetaFruit** — Hệ thống thương mại điện tử hoa quả trực tuyến đa cửa hàng (Multi-Vendor Online Fruit Marketplace) chuẩn doanh nghiệp. Ứng dụng được xây dựng theo kiến trúc MVC phân lớp sâu (Layered Servlet - Service - DAO), phục vụ 5 đối tượng người dùng chuyên biệt, tích hợp hệ thống thanh toán tự động VietQR (SePay Webhook), kết toán ví tự động và cơ chế bảo mật đa tầng.

---

## 🗺️ MỤC LỤC TÀI LIỆU
1. [🏗️ Kiến Trúc Hệ Thống & Luồng Request](#-kiến-trúc-hệ-thống--luồng-request)
2. [🛡️ Các Giải Pháp Bảo Mật & Tiêu Chuẩn Lập Trình Chống Lỗ Hổng](#%EF%B8%8F-các-giải-pháp-bảo-mật--tiêu-chuẩn-lập-trình-chống-lỗ-hổng)
3. [👥 5 Vai Trò Hệ Thống & Phân Quyền Truy Cập (RBAC Scope)](#-5-vai-trò-hệ-thống--phân-quuyền-truy-cập-rbac-scope)
4. [✨ Chi Tiết Tất Cả Chức Năng Nổi Bật & Quy Trình Hoạt Động Nghiệp Vụ](#-chi-tiết-tất-cả-chức-năng-nổi-bật--quy-trình-hoạt-động-nghiệp-vụ)
5. [⚙️ Hướng Dẫn Cài Đặt & Cấu Hình Khởi Chạy](#%EF%B8%8F-hướng-dẫn-cài-đặt--cấu-hình-khởi-chạy)

---

## 🏗️ KIẾN TRÚC HỆ THỐNG & LUỒNG REQUEST

MetaFruit tuân thủ chặt chẽ mô hình **MVC (Model-View-Controller)** với kiến trúc 4 lớp độc lập:

```text
                                [ Trình Duyệt Client / Browser ]
                                               │
                                               ▼ (HTTP Requests)
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│ 🛡️ FILTER CHAIN BẢO MẬT & ĐIỀU PHỐI (Servlet Filters)                                       │
│  ├─ EncodingFilter: Thiết lập UTF-8 Toàn hệ thống                                           │
│  ├─ SecurityAuthFilter: Kiểm tra Session, Authenticated Identity & Phân quyền RBAC         │
│  └─ CsrfFilter: Độc quyền chặn tấn công CSRF trên mọi HTTP POST Request                     │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
                                               │
                                               ▼ (Validated & Authorized Request)
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│ 🎮 CONTROLLER LAYER (Jakarta Servlet 6.0 Engine)                                           │
│  ├─ Tiếp nhận Parameter, Validate DTO đầu vào                                              │
│  ├─ Điều phối luồng nghiệp vụ                                                              │
│  └─ Áp dụng mô hình PRG (Post-Redirect-Get) triệt tiêu F5 Submit trùng lặp đơn hàng       │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
                                               │
                                               ▼ (Business Service Delegation)
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│ ⚙️ SERVICE LAYER (Business Logic Core)                                                     │
│  ├─ Tính toán giá sản phẩm, biến thể trọng lượng & mã giảm giá Coupon                       │
│  ├─ Kiểm tra tồn kho thời gian thực & điều phối Database Transaction                        │
│  ├─ Tích hợp bên thứ ba: Google OAuth 2.0, SePay VietQR Webhook, Jakarta Mail Sender        │
│  └─ Chạy Daily Batch Job kết toán tiền ví Chủ shop tự động                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
                                               │
                                               ▼ (Persistence Interface)
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│ 🗄️ DAO LAYER (Data Access Object - SQL Server JDBC)                                          │
│  ├─ Nơi duy nhất chứa câu lệnh Parameterized SQL                                           │
│  ├─ Quản lý kết nối an toàn qua JNDI DataSource / Connection Pool                           │
│  └─ Thực thi qua PreparedStatement và try-with-resources (Zero Connection Leak)             │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
                                               │
                                               ▼ (Query / Mutation)
                               [ Microsoft SQL Server 2022 Database ]
```

### Chi Tiết Nhiệm Vụ Các Lớp:
*   **View (JSP 3.1 / JSTL 3.0 / Tailwind CSS)**: Đặt toàn bộ trong `web/WEB-INF/jsp` để chặn truy cập trực tiếp từ URL. Sử dụng Custom Taglib tự định nghĩa (`ft:currency`, `ft:stars`, `ft:orderStatus`, `ft:pagination`, `ft:allow`) giúp triệt tiêu 100% mã Java scriptlets (`<% %>`).
*   **Controller (Jakarta Servlet 6.0)**: Đóng vai trò Router & Orchestrator. Chuyển hướng theo chuẩn PRG, lưu thông báo tạm thời qua Flash Session (`SessionUtil.flashSuccess`).
*   **Service Layer**: Xử lý 100% logic nghiệp vụ. Đảm bảo tính nguyên tố (Atomicity) của giao dịch thông qua cơ chế Transaction Rollback.
*   **DAO Layer**: Chứa duy nhất SQL chuẩn. Bảo đảm 100% các truy vấn đều dùng tham số biến động (`?`) chống Injection.

---

## 🛡️ CÁC GIẢI PHÁP BẢO MẬT & TIÊU CHUẨN LẬP TRÌNH CHỐNG LỖ HỔNG

Hệ thống được thiết kế với cơ chế bảo mật đa lớp (Defense-in-Depth) chống lại toàn bộ danh mục OWASP Top 10:

### 1. Mã Hóa Mật Khẩu An Toàn (BCrypt Password Hashing)
*   Sử dụng thuật toán `BCrypt` với Salt ngẫu nhiên 10 rounds thông qua `HashUtil.hash()`.
*   Tuyệt đối không lưu Plaintext Password. Mọi thao tác xác thực đăng nhập kiểm tra qua `HashUtil.verify()`.

### 2. Phòng Chống SQL Injection (100% Parameterized Queries)
*   Tất cả các truy vấn CSDL trong DAO Layer bắt buộc sử dụng `PreparedStatement`.
*   Truyền tham số qua bộ khóa định danh `pstmt.setString(1, param)` hoặc `pstmt.setInt(2, val)`. Tuyệt đối cấm nối chuỗi SQL.

### 3. Phân Quyền Theo Vai Trò (Role-Based Access Control - RBAC)
*   Hệ thống định danh 5 Roles với các mã ID cố định trong `AppConfig`:
    - `ROLE_GUEST`: Khách vãng lai.
    - `ROLE_CUSTOMER` (ID = 2): Khách hàng cá nhân.
    - `ROLE_SHOP_OWNER` (ID = 3): Chủ gian hàng.
    - `ROLE_DELIVERY` (ID = 4): Nhân viên giao hàng.
    - `ROLE_ADMIN` (ID = 5): Quản trị viên sàn.
*   Bộ lọc `RoleFilter` kiểm tra URL pattern đối chiếu với Session Role của người dùng. Truy cập trái phép lập tức bị đẩy về trang Access Denied (HTTP 403).

### 4. Chống Tấn Công Giả Mạo Yêu Cầu (CSRF Guard)
*   Tự động sinh chuỗi `CSRF_TOKEN` ngẫu nhiên lưu trong Session khi người dùng truy cập Form.
*   Bộ lọc `CsrfFilter` chặn tất cả các yêu cầu `POST`, `PUT`, `DELETE` thiếu Token hoặc Token không khớp.

### 5. Chống Kịch Bản Mạng Độc Hại (XSS Sanitization & HTML Output Encoding)
*   Mọi dữ liệu người dùng nhập (Tên, địa chỉ, đánh giá) đều qua bộ lọc `ValidationUtil.sanitizeInput()`.
*   Mã JSP render dữ liệu qua thẻ JSTL `<c:out value="${data}"/>` tự động Escape các ký tự đặc biệt (`<`, `>`, `&`, `"`).

### 6. Bảo Vệ Luồng Giao Dịch & Chống F5 Đặt Trùng (PRG Pattern & Transaction Rollback)
*   Tất cả Servlet xử lý Form POST sau khi ghi nhận thành công sẽ trả về HTTP 302 Redirect (PRG). Người dùng F5 trang chỉ tải lại yêu cầu GET, không làm trùng lặp đơn hàng.
*   Các thao tác ảnh hưởng nhiều bảng (Tạo đơn hàng multi-shop, trừ kho, trừ mã giảm giá) được bọc trong 1 `Connection` duy nhất với `setAutoCommit(false)` và `rollback()` khi gặp ngoại lệ.

---

## 👥 5 VAI TRÒ HỆ THỐNG & PHÂN QUYỀN TRUY CẬP (RBAC SCOPE)

Nền tảng MetaFruit phục vụ 5 nhóm đối tượng tương tác với quyền hạn độc lập:

| Vai Trò | Phạm Vi Quyền Hạn (Scope) | Trang Quyền Hạn |
| :--- | :--- | :--- |
| **Guest (Khách vãng lai)** | Xem trang chủ, tìm kiếm/lọc hoa quả, xem chi tiết, giỏ hàng `localStorage`, Đặt hàng nhanh (Guest Checkout), Đăng ký/Đăng nhập. | `/home`, `/product-detail`, `/cart`, `/checkout`, `/login`, `/register` |
| **Customer (Khách mua hàng)** | Đồng bộ giỏ hàng CSDL, quản lý sổ địa chỉ, xem lịch sử đơn hàng, theo dõi lộ trình real-time, đánh giá 1-5 sao, gửi yêu cầu Đổi Trả/Hoàn Tiền, đăng ký mở Shop. | `/customer/*` |
| **Shop Owner (Chủ gian hàng)** | Quản lý thông tin Shop, thêm/sửa/xóa hoa quả, quản lý biến thể trọng lượng & tồn kho, duyệt/từ chối đơn hàng, tạo Coupon khuyến mãi, xem báo cáo biểu đồ doanh thu. | `/shop/*` |
| **Delivery Staff (Shipper)** | Dashboard danh sách đơn hàng đóng gói trong khu vực, nhận đơn giao, cập nhật lộ trình (Đang giao, Đã giao thành công, Giao thất bại), chốt tiền COD. | `/delivery/*` |
| **Admin (Quản trị viên sàn)** | Xem thống kê tổng quan toàn sàn, duyệt/khóa hồ sơ Shop đăng ký mới, kiểm duyệt sản phẩm/bình luận vi phạm, giám sát dòng tiền VietQR, chốt ví đối soát tài chính. | `/admin/*` |

---

## ✨ CHI TIẾT TẤT CẢ CHỨC NĂNG NỔI BẬT & QUY TRÌNH HOẠT ĐỘNG NGHIỆP VỤ

### 1. Phân Hệ Xác Thực & Quản Lý Tài Khoản (Authentication & Account Flow)
*   **Đăng Ký Tài Khoản (Registration)**:
    - Người dùng nhập Email, Mật khẩu, Họ tên, Số điện thoại.
    - `ValidationUtil` kiểm tra định dạng email và độ mạnh mật khẩu (tối thiểu 8 ký tự, gồm chữ cái và số).
    - `UserDAO` kiểm tra trùng lặp Email/SĐT -> Băm mật khẩu bằng `BCrypt` -> Lưu trạng thái `UNVERIFIED`.
    - `EmailService` tự động gửi Email chứa OTP/Link xác thực -> Người dùng xác nhận thành công nâng trạng thái thành `ACTIVE`.
*   **Đăng Nhập (Login & Google OAuth 2.0)**:
    - Đăng nhập truyền thống: Kiểm tra Email -> Xác thực mật khẩu qua `HashUtil.verify()` -> Lưu `User` Entity vào Session.
    - Đăng nhập Google 1-Touch: Khách bấm "Đăng nhập với Google" -> Google trả về Code -> `GoogleAuthService` đổi lấy Access Token & User Profile -> Tự động sinh tài khoản nếu chưa tồn tại -> Đăng nhập tức thì.
*   **Quên Mật Khẩu (Forgot & Reset Password)**:
    - Nhập Email -> Sinh Token ngẫu nhiên có thời hạn 15 phút lưu CSDL -> Gửi Link đổi mật khẩu qua Email -> Người dùng nhấp link và cập nhật mật khẩu mới.

### 2. Quy Trình Đăng Ký Gian Hàng & Duyệt Shop (Merchant Onboarding)
*   **Đăng Ký Mở Gian Hàng (Shop Application)**:
    - Customer truy cập `/customer/shop-apply` -> Nhập Tên Shop, Giấy phép kinh doanh, Số tài khoản ngân hàng, Tỉnh/Thành phố kinh doanh và Ảnh đại diện Shop.
    - Hệ thống ghi nhận hồ sơ ở trạng thái `PENDING_APPROVAL`.
*   **Quy Trình Xét Duyệt Của Admin (Admin Merchant Moderation)**:
    - Admin vào `/admin/shops` xem danh sách Shop chờ duyệt.
    - Nhấn **Đồng Ý Duyệt**: Hệ thống chuyển Role người dùng từ `Customer` sang `Shop Owner`, khởi tạo Ví doanh thu (`ShopSettlement`) và gửi Email chúc mừng.
    - Nhấn **Từ Chối**: Nhập lý do từ chối -> Gửi Email thông báo cho người dùng điều chỉnh hồ sơ.

### 3. Quy Trình Thêm, Sửa & Quản Lý Tồn Kho Sản Phẩm (Inventory & Variant Management)
*   **Thêm Sản Phẩm Mới (Create Product)**:
    - Chủ Shop vào `/shop/product/create` -> Tải ảnh hoa quả (`FileUploadUtil`), chọn danh mục (Táo, Cam, Nho, Xoài...), nhập mô tả.
    - Cấu hình **Biến thể trọng lượng** (Variants): Mỗi biến thể bao gồm Nhãn (ví dụ: Hộp 500g, Khay 1kg, Thùng 5kg), Giá bán, Giá khuyến mãi và Số lượng kho ban đầu.
    - Lưu dữ liệu đồng thời vào 2 bảng `Products` và `ProductVariants` trong 1 Transaction.
*   **Chỉnh Sửa Sản Phẩm (Edit Product)**:
    - Chủ Shop thay đổi thông tin, giá bán, hoặc tải thêm ảnh con. Hệ thống cập nhật thời gian `updated_at`.
*   **Quản Lý Tồn Kho Thời Gian Thực & Cảnh Báo Kho (Inventory Control)**:
    - Cảnh báo In-App: Hệ thống hiển thị huy hiệu đỏ cảnh báo khi tồn kho biến thể rơi xuống `< 5`.
    - Khi Khách đặt hàng: Tồn kho biến thể tự động trừ tức thì theo số lượng mua (`stock = stock - quantity`).
    - Khi Đơn hàng bị Hủy (bởi Khách hoặc Chủ shop): Hệ thống tự động hoàn trả số lượng kho lại như cũ (`stock = stock + quantity`).

### 4. Quy Trình Mua Hàng & Thanh Toán Trực Tuyến (Checkout & VietQR Webhook)
*   **Quản Lý Giỏ Hàng Động (Dynamic Cart)**:
    - Khách vãng lai thao tác giỏ hàng trên trình duyệt bằng `localStorage`.
    - Khi đăng nhập thành công: `CartService` tự động hợp nhất (Merge) giỏ hàng từ `localStorage` vào Database SQL Server.
*   **Đặt Hàng Không Cần Tài Khoản (Guest Checkout)**:
    - Khách nhập Tên, SĐT, Địa chỉ nhận hàng -> Hệ thống tự động tạo một tài khoản ngẫu nhiên, tạo đơn hàng và gửi Email chứa thông tin truy cập cho khách.
*   **Thanh Toán VietQR Tự Động (SePay Integration)**:
    - Khi Khách chọn "Thanh toán VietQR": Server tạo đơn hàng trạng thái `PENDING_PAYMENT` và hiển thị mã QR động chứa Số tài khoản, Ngân hàng, Số tiền chính xác và Nội dung chuyển khoản (Ví dụ: `MF10024`).
    - Khách quét mã chuyển tiền trên App Ngân hàng -> Ngân hàng gửi IPN Webhook về URL `/api/sepay-webhook`.
    - `SepayWebhookServlet` xác thực IPN Secret Key -> Khớp mã đơn hàng và số tiền -> Chuyển trạng thái đơn hàng thành `PAID` và gửi Email hóa đơn trong vòng **3 giây**.

### 5. Giao Hàng & Kết Toán Ví Doanh Thu Tự Động (Delivery & Settlement)
*   **Giao Vận Cho Shipper (Delivery Processing)**:
    - Sau khi Chủ shop đóng gói và nhấn "Duyệt Đơn" -> Đơn hàng chuyển sang trạng thái `READY_FOR_PICKUP`.
    - Shipper truy cập `/delivery/dashboard` thấy danh sách đơn trong khu vực -> Bấm "Nhận Giao" -> Cập nhật trạng thái `SHIPPING` -> Cập nhật `DELIVERED` (kèm thu tiền COD nếu có).
*   **Tự Động Kết Toán Doanh Thu Cho Chủ Shop (Daily Settlement Batch Job)**:
    - Lớp `SettlementScheduler` khởi chạy tự động lúc `00:00` hàng ngày.
    - Quét tất cả các đơn hàng có trạng thái `DELIVERED` đã qua **7 ngày** (hết thời hạn đổi trả).
    - Tính toán tiền hàng trừ đi phí sàn -> Tự động chuyển doanh thu net vào Ví của Chủ shop (`ShopSettlement`) và cập nhật trạng thái đơn thành `SETTLED`.

---

## ⚙️ HƯỚNG DẪN CÀI ĐẶT & CẤU HÌNH KHỞI CHẠY

### 1. Yêu Cầu Môi Trường Kỹ Thuật
*   **Java Development Kit (JDK)**: JDK 17 trở lên (Hỗ trợ JDK 25 tốt nhất).
*   **Web Application Server**: Apache Tomcat 10.1.x (Hỗ trợ Jakarta EE 10 / Servlet API 6.0).
*   **Database Management System**: Microsoft SQL Server 2019 / 2022.
*   **Build Engine**: Apache Ant (Đã tích hợp sẵn trong NetBeans).

### 2. Các Bước Khởi Chạy Dự Án Chi Tiết
1. **Khởi Tạo CSDL SQL Server**:
   - Mở SQL Server Management Studio (SSMS).
   - Chạy tệp script `database/Setup_OnlineFruitShopping.sql` để tạo CSDL `OnlineFruitShopping`, bảng biểu và dữ liệu mẫu initial data.
2. **Cấu Hình Kết Nối Cơ Sở Dữ Liệu**:
   - Mở tệp `src/java/config/DBConfig.java`.
   - Cập nhật thông số `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` và `DB_PASSWORD` phù hợp với máy cục bộ của bạn.
3. **Biên Dịch & Khởi Chạy Web App**:
   - Mở dự án `Ban_Hoa_Qua_Online` bằng IDE NetBeans 21+.
   - Nhấp chuột phải vào dự án -> Chọn **Clean and Build**.
   - Nhấp chuột phải -> Chọn **Run** (IDE sẽ tự động Deploy lên Tomcat 10 và mở trình duyệt).
   - Truy cập ứng dụng tại đường dẫn mặc định: `http://localhost:8080/Ban_Hoa_Qua_Online`.

---
*MetaFruit — Nền Tảng Thương Mại Điện Tử Hoa Quả Trực Tuyến An Toàn, Tiện Lợi và Hiện Đại.*
