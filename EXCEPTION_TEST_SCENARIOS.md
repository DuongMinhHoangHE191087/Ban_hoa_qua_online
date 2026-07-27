# Exception & Error Scenarios Test Coverage Analysis
## Ban_Hoa_Qua_Online Project

**Date:** 2026-06-15  
**Target Coverage:** 80%+ for all exception scenarios  
**Focus:** AuthService, CartService, CheckoutService, OrderService, PaymentService, DeliveryService

---

## 1. AuthService

### 1.1 Input Validation Errors

| Scenario | Exception Type | Test Case |
|----------|---|---|
| register: null user | IllegalArgumentException | register(null) → throws "Thông tin tài khoản không được để trống" |
| register: blank fullName | IllegalArgumentException | register(user with empty fullName) → throws validation error |
| register: invalid email format | IllegalArgumentException | register(user with "invalid-email") → throws "Email không hợp lệ" |
| register: weak password (<8 chars) | IllegalArgumentException | register(user with "short1") → throws "phải từ 8 đến 64 ký tự" |
| register: invalid phone format | IllegalArgumentException | register(user with "123") → throws "Số điện thoại không hợp lệ" |
| login: null identifier | Exception | login(null, pass) → throws "Email hoặc số điện thoại không được để trống" |
| login: blank password | Exception | login("user@test.com", "") → throws "không được để trống" |
| resetPassword: invalid email | Exception | resetPassword("bad-email", newPass) → throws "Email không hợp lệ" |
| resetPassword: weak new password | Exception | resetPassword("user@test.com", "short") → throws "8 đến 64 ký tự" |
| changePassword: invalid userId | IllegalArgumentException | changePassword(-1, oldPass, newPass) → throws "User ID không hợp lệ" |
| changePassword: null currentPassword | IllegalArgumentException | changePassword(userId, null, newPass) → throws "không được để trống" |
| changePassword: null newPassword | IllegalArgumentException | changePassword(userId, oldPass, null) → throws "không được để trống" |
| verifyEmailCode: invalid email | Exception | verifyEmailCode("bad-email", code) → throws "Email không hợp lệ" |
| verifyEmailCode: null code | Exception | verifyEmailCode("user@test.com", null) → throws "không được để trống" |
| sendForgotPasswordCode: invalid email | Exception | sendForgotPasswordCode("bad-email") → throws "Email không hợp lệ" |
| processGoogleLogin: null email | IllegalArgumentException | processGoogleLogin(null, name) → throws "Email không được để trống" |
| processGoogleLogin: null fullName | IllegalArgumentException | processGoogleLogin(email, null) → throws "Họ và tên không được để trống" |

### 1.2 Business Logic Violations (Duplicate/Conflict)

| Scenario | Exception Type | Test Case |
|----------|---|---|
| register: duplicate email | Exception | register(user) twice with same email → throws "Địa chỉ email đã được đăng ký" |
| register: duplicate phone | Exception | register(user1) with phone, then register(user2) with same phone → throws "Số điện thoại đã được đăng ký" |
| login: account locked | Exception | failed login 5+ times → throws "Tài khoản đang bị khóa tạm thời" |
| login: account not verified | VerificationRequiredException | login with unverified account → throws "Tài khoản chưa được xác minh" |
| login: incorrect password | Exception | login(user@test.com, wrongPass) → throws "Mật khẩu không chính xác" + remaining attempts |
| login: inactive account | Exception | login with INACTIVE status → throws "Tài khoản chưa được xác minh" |
| verifyEmailCode: expired code | Exception | verifyEmailCode with expired_at < now → throws "Mã xác minh đã hết hạn" |
| verifyEmailCode: wrong code | Exception | verifyEmailCode with incorrect hash → throws "Mã xác minh không chính xác" |
| verifyEmailCode: already verified | (no error, returns verified user) | verifyEmailCode for already-active account |
| resendVerificationCode: already verified | Exception | resendVerificationCode for active user → throws "Tài khoản này đã được xác minh" |
| resendVerificationCode: cooldown violated | Exception | resend twice within 1 minute → throws "Vui lòng chờ 1 phút" |
| changePassword: current password wrong | Exception | changePassword with incorrect currentPassword → throws "không chính xác" |
| changePassword: new password same as current | Exception | changePassword(newPass = oldPass) → throws "không được trùng" |
| changePassword: OAuth account (no password) | Exception | changePassword on Google OAuth user → throws "Tài khoản liên kết Google không hỗ trợ" |
| verifyForgotCode: code expired | Exception | verifyForgotCode with expired_at < now → throws "Mã xác minh đã hết hạn" |
| verifyForgotCode: wrong code | Exception | verifyForgotCode with incorrect hash → throws "Mã xác minh không chính xác" |
| login: user not found | Exception | login(nonexistent@test.com) → throws "Tài khoản hoặc mật khẩu không chính xác" |

### 1.3 Database Errors

| Scenario | Exception Type | Test Case |
|----------|---|---|
| register: DB connection failure | SQLException | userDAO.saveNewCustomer() fails → throws SQLException |
| register: concurrent duplicate insert | SQLException | Two threads insert same email simultaneously → one throws constraint violation |
| login: DB query fails | SQLException | userDAO.findByLoginIdentifier() throws SQLException |
| register: rollback on email send failure | Exception | issueVerificationCode() email fails → DAO.deleteUser() is called, then throws |
| changePassword: update fails | SQLException | userDAO.updatePassword() throws SQLException |

### 1.4 External Service Failures

| Scenario | Exception Type | Test Case |
|----------|---|---|
| register: email service down | Exception | emailService.sendVerificationCodeEmail() returns false → throws "Không thể gửi email xác minh" |
| issueVerificationCode: email send fails | Exception | emailService.sendVerificationCodeEmail() throws → propagates as "Không thể gửi email xác minh" |
| sendForgotPasswordCode: email send fails | Exception | emailService throws on forgot password email |
| processGoogleLogin: cart creation fails | SQLException | cartDAO.createForCustomer() throws |

### 1.5 State Transition Errors

| Scenario | Exception Type | Test Case |
|----------|---|---|
| register: insert returns 0 | Exception | userDAO.saveNewCustomer() returns 0 → throws "Lỗi hệ thống khi tạo tài khoản" |
| register: findByEmail returns null after insert | Exception | findByEmail(email) is null after insert → throws "Không thể tải lại thông tin" |
| verifyEmailCode: already active, no error | (OK) | verifyEmailCode on already-verified account → returns user (no exception) |

### 1.6 Resource Not Found

| Scenario | Exception Type | Test Case |
|----------|---|---|
| login: user not in DB | Exception | userDAO.findByLoginIdentifier() returns null → throws "Tài khoản hoặc mật khẩu không chính xác" |
| resetPassword: email not found | Exception | userDAO.findByEmail() returns null → throws "Không tìm thấy tài khoản" |
| changePassword: user not found | Exception | userDAO.findUserById() returns null → throws "Không tìm thấy tài khoản" |
| verifyEmailCode: user not found | Exception | userDAO.findByEmail() returns null → throws "Không tìm thấy tài khoản cần xác minh" |
| resendVerificationCode: user not found | Exception | userDAO.findByEmail() returns null → throws "Không tìm thấy tài khoản cần xác minh" |
| processGoogleLogin: non-existent user (OK) | (OK) | processGoogleLogin for new user → creates and returns |
| sendForgotPasswordCode: email not found (OK) | (no error) | sendForgotPasswordCode(nonexistent@test.com) → returns false (anti-enumeration) |

---

## 2. CartService

### 2.1 Input Validation Errors

| Scenario | Exception Type | Test Case |
|----------|---|---|
| addToCart: qty <= 0 | IllegalArgumentException | addToCart(customerId, variantId, 0) → throws "Số lượng thêm vào giỏ hàng phải lớn hơn 0" |
| addToCart: qty < 0 | IllegalArgumentException | addToCart(customerId, variantId, -5) → throws "Số lượng... phải lớn hơn 0" |
| updateQuantity: qty <= 0 | IllegalArgumentException | updateQuantity(customerId, itemId, 0) → throws "Số lượng sản phẩm phải lớn hơn 0" |
| updateQuantity: qty < 0 | IllegalArgumentException | updateQuantity(customerId, itemId, -1) → throws "Số lượng sản phẩm phải lớn hơn 0" |
| syncGuestCart: null or empty JSON | (OK) | syncGuestCart(customerId, null) → returns without error |
| syncGuestCart: malformed JSON | (handled) | syncGuestCart(customerId, "{bad json}") → logs warning, continues |
| syncOnUnload: null cartJson | (OK) | syncOnUnload(customerId, null) → returns |

### 2.2 Business Logic Violations (Stock/Inventory)

| Scenario | Exception Type | Test Case |
|----------|---|---|
| addToCart: product inactive | IllegalArgumentException | addToCart with inactive variant → throws "Sản phẩm... đã ngừng kinh doanh" |
| addToCart: product not found | IllegalArgumentException | addToCart with nonexistent variantId → throws "Sản phẩm hoặc biến thể này không tồn tại" |
| addToCart: exceeds stock (new item) | IllegalArgumentException | addToCart when qty > stock → throws "Số lượng yêu cầu... vượt quá số lượng còn lại" |
| addToCart: merge with existing, exceeds stock | IllegalArgumentException | item exists with qty=5, add qty=10, stock=12 → throws with total (15) |
| updateQuantity: exceeds stock | IllegalArgumentException | updateQuantity to qty > stock → throws "Số lượng yêu cầu... vượt quá số lượng" |
| updateQuantity: product inactive | IllegalArgumentException | updateQuantity for inactive variant → throws "Biến thể sản phẩm này không còn tồn tại" |
| changeVariant: new variant inactive | IllegalArgumentException | changeVariant to inactive variant → throws "Biến thể mới không tồn tại hoặc đã ngừng kinh doanh" |
| changeVariant: new variant out of stock | IllegalArgumentException | changeVariant to variant with stock=0 → throws "Rất tiếc! Biến thể mới này hiện đã hết hàng" |
| changeVariant: merge exceeds stock | (capped) | changeVariant merges and qty > stock → qty capped to stock |
| checkCartStockBeforeCheckout: product became inactive | (error in list) | Product marked inactive between add and checkout → error returned in list |
| checkCartStockBeforeCheckout: insufficient stock | (error in list) | Stock reduced below cart qty → error returned in list |
| checkCartStockBeforeCheckout: product out of stock | (error in list) | Stock = 0 → specific "hết hàng" error |

### 2.3 Authorization/IDOR Errors

| Scenario | Exception Type | Test Case |
|----------|---|---|
| updateQuantity: wrong customer | IllegalArgumentException | updateQuantity for item not in customer's cart → throws "Sản phẩm không thuộc giỏ hàng của bạn" |
| removeItem: wrong customer | IllegalArgumentException | removeItem for item not in customer's cart → throws "Sản phẩm không thuộc giỏ hàng của bạn" |
| changeVariant: wrong customer | IllegalArgumentException | changeVariant for item not in customer's cart → throws "Sản phẩm không thuộc giỏ hàng của bạn" |

### 2.4 Database Errors

| Scenario | Exception Type | Test Case |
|----------|---|---|
| getCart: findByCustomer fails | SQLException | cartDAO.findByCustomer() throws SQLException |
| addToCart: createForCustomer fails | SQLException | cartDAO.createForCustomer() throws |
| addToCart: addItem fails | SQLException | cartDAO.addItem() throws |
| updateQuantity: updateItemQuantity fails | SQLException | cartDAO.updateItemQuantity() throws |
| removeItem: findItemById fails | SQLException | cartDAO.findItemById() throws |
| changeVariant: updateItemVariant fails | SQLException | cartDAO.updateItemVariant() throws |
| syncGuestCart: addToCart for guest item fails (handled) | (no error) | syncGuestCart continues on individual item failure, logs warning |
| syncOnUnload: replaceCartItems fails | (handled) | syncOnUnload logs warning on DB failure |
| checkCartStockBeforeCheckout: findItems fails | SQLException | cartDAO.findItems() throws |

### 2.5 Resource Not Found

| Scenario | Exception Type | Test Case |
|----------|---|---|
| updateQuantity: cart item not found | IllegalArgumentException | updateQuantity(cartItemId) where item is null → throws "Không tìm thấy sản phẩm này" |
| removeItem: cart item not found | (OK) | removeItem(cartItemId) where item is null → returns silently |
| changeVariant: cart item not found | IllegalArgumentException | changeVariant(cartItemId) where item is null → throws "Không tìm thấy sản phẩm này" |

### 2.6 State Consistency

| Scenario | Exception Type | Test Case |
|----------|---|---|
| syncOnUnload: exceeds 100 items limit | (capped) | syncOnUnload with >100 items → limited to 100 for DoS prevention |
| syncOnUnload: invalid stock check | (capped) | Item with stock=0 → item added with qty=0 (filtered or capped) |

---

## 3. CheckoutService

### 3.1 Input Validation Errors

| Scenario | Exception Type | Test Case |
|----------|---|---|
| validateRequest: non-customer role | SecurityException | placeOrder by SHOP_OWNER → throws "Bạn không có quyền thực hiện thanh toán" |
| validateRequest: name < 3 chars | IllegalArgumentException | fullName = "AB" → throws "phải từ 3 ký tự trở lên" |
| validateRequest: name null | IllegalArgumentException | fullName = null → throws "phải từ 3 ký tự trở lên" |
| validateRequest: invalid phone | IllegalArgumentException | phone = "123" (not matching PHONE_REGEX) → throws "không hợp lệ" |
| validateRequest: phone null | IllegalArgumentException | phone = null → throws "không hợp lệ" |
| validateRequest: address < 5 chars | IllegalArgumentException | address = "1234" → throws "phải từ 5 ký tự trở lên" |
| validateRequest: address null | IllegalArgumentException | address = null → throws "phải từ 5 ký tự trở lên" |
| validateRequest: empty delivery time slot | IllegalArgumentException | deliveryTimeSlot = "" → throws "Vui lòng chọn khung giờ giao hàng" |
| validateRequest: null time slot | IllegalArgumentException | deliveryTimeSlot = null → throws "Vui lòng chọn khung giờ giao hàng" |
| validateRequest: no variants selected | IllegalArgumentException | variantIds = null or empty → throws "Vui lòng chọn ít nhất một sản phẩm" |
| validateRequest: invalid payment method | IllegalArgumentException | paymentMethod not in {COD, CK} → throws "Phương thức thanh toán không hợp lệ" |

### 3.2 Business Logic Violations (Stock/Inventory)

| Scenario | Exception Type | Test Case |
|----------|---|---|
| validateStock: item qty <= 0 | IllegalStateException | Cart item with qty=0 → throws "So luong san pham... khong hop le" |
| validateStock: product inactive | IllegalStateException | Product marked inactive → throws "da ngung kinh doanh" |
| validateStock: product not found | IllegalStateException | ProductVariant missing from variantMap → throws "da ngung kinh doanh" |
| validateStock: insufficient stock | IllegalStateException | item qty > variant.stock → throws "chi con X san pham" |
| validateStock: multiple errors | IllegalStateException | Multiple stock issues → throws all concatenated errors |
| placeOrder: empty checkout items | IllegalStateException | filterCheckoutItems returns empty with failWhenEmpty=true → throws "Không tìm thấy sản phẩm nào" |
| placeOrder: no variants match | IllegalArgumentException | No requested variantIds in cart → throws "Không tìm thấy sản phẩm nào" |

### 3.3 Promotion/Coupon Errors

| Scenario | Exception Type | Test Case |
|----------|---|---|
| placeSingleShopOrder: invalid shop coupon | IllegalArgumentException | promoteService.validateShopCoupon() returns null → throws "Mã giảm giá... không hợp lệ, đã hết hạn" |
| placeSingleShopOrder: invalid system coupon | IllegalArgumentException | promoteService.validateSystemCoupon() returns null → throws "Mã giảm giá của sàn... không hợp lệ" |
| placeMultiShopOrder: invalid shop coupon for any owner | IllegalArgumentException | No owner accepts shop coupon → throws "Mã voucher shop không hợp lệ" |
| placeMultiShopOrder: invalid system coupon | IllegalArgumentException | promoteService.validateSystemCoupon() returns null → throws "Mã voucher sàn không hợp lệ" |

### 3.4 Authorization/Business Rule Violations

| Scenario | Exception Type | Test Case |
|----------|---|---|
| buildCheckoutView: empty cart | IllegalStateException | cart.items.isEmpty() → throws "Giỏ hàng của bạn đang trống" |
| placeSingleShopOrder: customer is owner | IllegalArgumentException | user.getUserId() == ownerId → throws "Bạn không thể mua hàng từ cửa hàng của chính mình" |
| placeMultiShopOrder: customer is owner | IllegalArgumentException | Any ownerId == user.getUserId() → throws "Bạn không thể mua hàng từ cửa hàng của chính mình" |

### 3.5 Database Errors

| Scenario | Exception Type | Test Case |
|----------|---|---|
| placeOrder: lock timeout | IllegalStateException | UserLockManager.tryLock() times out → throws "Yeu cau dat hang cua ban dang duoc he thong xu ly" |
| placeOrder: loadVariantMap fails | SQLException | productVariantDAO.findById() throws |
| placeOrder: groupItemsByOwnerId fails | SQLException | orderDAO.getOwnerIdByProductId() throws |
| placeSingleShopOrder: saveOrder fails | SQLException | orderDAO.save() throws (within transaction, rolled back) |
| placeSingleShopOrder: saveBatch fails | SQLException | orderItemDAO.saveBatch() throws (within transaction, rolled back) |
| placeSingleShopOrder: reserveInventory fails | SQLException | inventoryService.reserve() throws (within transaction, rolled back) |
| placeMultiShopOrder: parent order save fails | SQLException | orderDAO.save() throws (rolled back) |
| placeMultiShopOrder: child order save fails | SQLException | orderDAO.save() for child fails (rolled back) |
| placeMultiShopOrder: multiple items fail | SQLException | Cart operations fail mid-transaction |

### 3.6 State Transition Errors

| Scenario | Exception Type | Test Case |
|----------|---|---|
| placeOrder: resolveSingleShopOwnerId returns -1 | IllegalStateException | No items match → throws "Không thể xác định shop" |
| placeOrder: getOwnerIdByProductId returns <=0 | IllegalStateException | Product owner lookup fails → throws "Không tìm thấy owner_id" |
| placeMultiShopOrder: multi-shop but one invalid | IllegalStateException | Some products have no valid owner |

### 3.7 Resource Not Found

| Scenario | Exception Type | Test Case |
|----------|---|---|
| loadVariantMap: variant not in DB | (silent, skipped) | ProductVariant with variantId not found → entry is skipped in map |
| validateStock: variant null in map | IllegalStateException | Variant became unavailable |
| filterCheckoutItems: all variantIds invalid | IllegalArgumentException | None of requested variantIds in cart |

### 3.8 Concurrent Access Issues

| Scenario | Exception Type | Test Case |
|----------|---|---|
| placeOrder: concurrent stock depletion | IllegalStateException | Stock validation passes, but another thread reserves stock before insert → may pass or fail in DB constraint check |
| placeOrder: concurrent order creation | (transaction isolation) | Same user places 2 orders simultaneously → lock prevents race, queues requests |

---

## 4. OrderService

### 4.1 Authorization/Permission Errors

| Scenario | Exception Type | Test Case |
|----------|---|---|
| confirmOrder: order not found | RuntimeException | order = null → throws "Đơn hàng không hợp lệ hoặc bạn không có quyền" |
| confirmOrder: wrong owner | RuntimeException | order.ownerId != ownerId → throws "Đơn hàng không hợp lệ hoặc bạn không có quyền" |
| confirmOrder: wrong status | RuntimeException | order.status != CONFIRMED → throws "Chỉ có thể duyệt đơn hàng khi trạng thái là CONFIRMED" |
| cancelOrder: order not found | IllegalArgumentException | order = null → throws "Đơn hàng không tồn tại" |
| cancelOrder: already delivered | RuntimeException | order.status = DELIVERED → throws "Đơn hàng đã giao hoặc đã hủy" |
| cancelOrder: already cancelled | RuntimeException | order.status = CANCELLED → throws "Đơn hàng đã giao hoặc đã hủy" |
| cancelOrder: customer wrong order | RuntimeException | Customer tries to cancel order not theirs → throws "Bạn không có quyền hủy" |
| cancelOrder: customer post-approval | RuntimeException | Customer tries to cancel after shop approved → throws "Cửa hàng đã duyệt hoặc đang giao" |
| cancelOrder: shop wrong order | RuntimeException | Shop tries to cancel order not theirs → throws "Đơn hàng này không thuộc cửa hàng của bạn" |
| dispatchOrder: order not found | RuntimeException | order = null → throws "Đơn hàng không hợp lệ" |
| dispatchOrder: wrong owner | RuntimeException | order.ownerId != ownerId → throws "Đơn hàng không hợp lệ" |
| dispatchOrder: wrong status | RuntimeException | order.status not in {APPROVED, CONFIRMED, PREPARING} → throws "Chỉ có thể giao đơn..." |
| customerConfirmDelivery: order not found (for customer) | RuntimeException | orderDAO.findByIdForCustomer() returns null → throws "Đơn hàng không hợp lệ" |
| customerConfirmDelivery: wrong status | RuntimeException | order.status not in {DISPATCHED, DELIVERED} → throws "Chỉ có thể xác nhận" |
| reportNotReceived: order not found | SecurityException | orderDAO.findByIdForCustomer() returns null → throws "Bạn không có quyền thực hiện hành động này" |
| reportNotReceived: wrong status | IllegalStateException | order.status not in {DISPATCHED, DELIVERED} → throws "Chỉ có thể báo chưa nhận hàng" |
| reorder: order not found | SecurityException | orderDAO.findByIdForCustomer() returns null → throws "Bạn không có quyền thực hiện hành động này" |

### 4.2 Database Errors

| Scenario | Exception Type | Test Case |
|----------|---|---|
| getOrderDetail: query fails | SQLException | orderDAO.findOneById() throws |
| cancelOrder: update status fails | SQLException | orderDAO.cancel() throws |
| cancelOrder: findItems fails | SQLException | orderDAO.findItemsByOrderId() throws |
| dispatchOrder: update status fails | SQLException | orderDAO.updateStatus() throws |
| customerConfirmDelivery: update status fails | SQLException | orderDAO.updateStatus() throws |
| reorder: findByCustomer fails | SQLException | cartDAO.findByCustomer() throws |
| reorder: addItem fails (per item) | (handled) | cartDAO.addItem() fails → caught, skippedCount++ |

### 4.3 External Service Failures

| Scenario | Exception Type | Test Case |
|----------|---|---|
| dispatchOrder: notification fails | (logged) | notificationService.send() throws → logged as warning, order still updated |
| dispatchOrder: email fails | (logged) | emailService.sendOrderNotificationEmail() throws → logged, order still updated |
| customerConfirmDelivery: inventoryService.confirm fails | (logged) | inventoryService.confirm() throws → logged, state still updated |
| autoCancelUnacceptedOrders: notification fails | (logged) | notificationService fails for auto-cancel |

### 4.4 State Consistency Issues

| Scenario | Exception Type | Test Case |
|----------|---|---|
| cancelOrder: release inventory fails (per item) | (partial) | inventoryService.release() fails for some items → rolls back on exception |
| reorder: addItem for variant fails | (handled) | Individual addToCart fails → item skipped, addedCount/skippedCount updated |
| reorder: null variantId in order items | (skipped) | OrderItem.variantId = null → skipped, skippedCount++ |

### 4.5 Resource Not Found

| Scenario | Exception Type | Test Case |
|----------|---|---|
| confirmOrder: order null | RuntimeException | order = null |
| cancelOrder: order null | IllegalArgumentException | order = null |
| dispatchOrder: order null | RuntimeException | order = null |
| customerConfirmDelivery: order null | RuntimeException | findByIdForCustomer returns null |
| reorder: order null | SecurityException | findByIdForCustomer returns null |

---

## 5. PaymentService

### 5.1 Input Validation Errors

| Scenario | Exception Type | Test Case |
|----------|---|---|
| initPayment: orderId invalid | IllegalArgumentException | initPayment for nonexistent order → throws "Không tìm thấy đơn hàng" |
| confirmManualPayment: QR expired | (returns false) | confirmManualPayment when tx.expiresAt < now → returns false |

### 5.2 Authorization/Permission Errors

| Scenario | Exception Type | Test Case |
|----------|---|---|
| confirmManualPayment: order not customer's | SecurityException | orderDAO.findByIdForCustomer() returns null → throws "Không có quyền truy cập đơn hàng" |
| adminApprovePayment: not admin | SecurityException | userDAO.findUserById(adminId).getRole() != ADMIN → throws "Bạn không có quyền" |

### 5.3 Business Logic Violations (State)

| Scenario | Exception Type | Test Case |
|----------|---|---|
| confirmManualPayment: order not pending payment | IllegalStateException | order.status != PENDING_PAYMENT → throws "Đơn hàng không ở trạng thái chờ thanh toán" |
| confirmManualPayment: no payment transaction | IllegalStateException | getPaymentByOrder() returns null → throws "Không tìm thấy bản ghi thanh toán" |
| adminApprovePayment: order not pending payment | IllegalStateException | order.status != PENDING_PAYMENT → throws "Đơn hàng không ở trạng thái chờ thanh toán" |
| renewQr: order not pending payment | IllegalStateException | order.status != PENDING_PAYMENT → throws "Không thể làm mới QR" |
| processWebhook: invalid transferType | (skipped) | transferType != "in" → insertDedup("skipped_not_in"), returns |
| processWebhook: amount mismatch | (failed) | received < expected → updateStatus("failed"), insertDedup("amount_mismatch") |

### 5.4 Resource Not Found

| Scenario | Exception Type | Test Case |
|----------|---|---|
| initPayment: order null | IllegalArgumentException | orderDAO.findOneById() returns null → throws "Không tìm thấy đơn hàng" |
| getPaymentByOrder: no transaction | (returns null) | paymentDAO.findOneByOrder() returns null |
| adminApprovePayment: order null | IllegalArgumentException | orderDAO.findOneById() returns null → throws "Không tìm thấy đơn hàng" |
| adminApprovePayment: payment null | IllegalStateException | getPaymentByOrder() returns null → throws "Không tìm thấy bản ghi thanh toán" |
| renewQr: order null | SecurityException | orderDAO.findByIdForCustomer() returns null → throws "Không có quyền" |
| renewQr: payment null (OK) | (creates new) | getPaymentByOrder() returns null → calls initPayment() |
| processWebhook: payment not found | (not_found) | paymentDAO.findByReference(code) returns null → insertDedup("not_found") |

### 5.5 Database Errors

| Scenario | Exception Type | Test Case |
|----------|---|---|
| initPayment: paymentDAO.initTransaction fails | SQLException | paymentDAO.initTransaction() throws |
| confirmManualPayment: updateStatus fails | SQLException | paymentDAO.updateStatus() throws |
| adminApprovePayment: updateStatus fails | SQLException | paymentDAO.updateStatus() throws |
| adminApprovePayment: orderDAO.updateStatus fails | SQLException | orderDAO.updateStatus() throws |
| renewQr: PreparedStatement fails | SQLException | ps.executeUpdate() throws |
| processWebhook: updateStatus fails | SQLException | paymentDAO.updateStatus() throws |
| processWebhook: orderDAO.updateStatus fails | SQLException | orderDAO.updateStatus() throws |

### 5.6 External Service Failures

| Scenario | Exception Type | Test Case |
|----------|---|---|
| adminApprovePayment: notification fails | (logged) | notificationService.send() throws → logged, order state still updated |
| adminApprovePayment: email fails | (logged) | emailService.sendOrderNotificationEmail() throws → logged |
| processWebhook: notification fails | (logged) | notificationService.send() throws → logged, payment state already updated |
| processWebhook: email fails | (logged) | emailService throws → logged |

### 5.7 Webhook Processing Edge Cases

| Scenario | Exception Type | Test Case |
|----------|---|---|
| processWebhook: null payload | (skipped) | jsonPayload = null → warns, skips |
| processWebhook: missing id field | (skipped) | extractJsonString("id") returns null → warns, returns |
| processWebhook: missing code field | (skipped) | extractJsonString("code") returns null → warns, returns |
| processWebhook: duplicate sepay_tx_id | (dedup) | paymentDAO.isDuplicate() returns true → logs, returns |
| processWebhook: malformed amount | (skipped) | amountStr unparseable as BigDecimal → insertDedup("invalid_amount") |

---

## 6. DeliveryService

### 6.1 Input Validation Errors

| Scenario | Exception Type | Test Case |
|----------|---|---|
| updateStatusAndProof: null status | IllegalArgumentException | status = null → throws "Trạng thái là bắt buộc" |
| updateStatusAndProof: empty status | IllegalArgumentException | status = "" → throws "Trạng thái là bắt buộc" |
| updateStatusAndProof: DELIVERED without proof | IllegalArgumentException | status="DELIVERED" & proofImageUrl=null → throws "Vui lòng cung cấp ảnh bằng chứng" |
| updateStatusAndProof: FAILED without reason | IllegalArgumentException | status="FAILED" & failureReason=null → throws "Vui lòng nhập lý do" |
| markAsDelivered: null proof | IllegalArgumentException | proofImageUrl = null → throws "Vui lòng cung cấp ảnh bằng chứng" |
| markAsDelivered: empty proof | IllegalArgumentException | proofImageUrl = "" → throws "Vui lòng cung cấp ảnh bằng chứng" |
| updateEstimatedTime: after delivery | IllegalArgumentException | delivery.status = DELIVERED → throws "Không thể cập nhật thời gian" |
| updateEstimatedTime: after failure | IllegalArgumentException | delivery.status = FAILED → throws "Không thể cập nhật thời gian" |

### 6.2 Authorization/Permission Errors

| Scenario | Exception Type | Test Case |
|----------|---|---|
| updateStatusAndProof: wrong staff | IllegalArgumentException | del.staffId != staffId → throws "Bạn không có quyền cập nhật" |
| updateStatusAndProof: null staffId on delivery | IllegalArgumentException | del.staffId = null → throws "Bạn không có quyền" (Objects.equals fix) |
| updateEstimatedTime: wrong staff | IllegalArgumentException | del.staffId != staffId → throws "Bạn không có quyền cập nhật" |
| updateEstimatedTime: null staffId on delivery | IllegalArgumentException | del.staffId = null → throws "Bạn không có quyền" |
| markAsDelivered: wrong staff | IllegalArgumentException | del.staffId != staffId → throws "Bạn không có quyền xác nhận" |
| claimDelivery: already assigned | IllegalArgumentException | del.staffId != null → throws "Đơn giao hàng này đã được shipper khác" |

### 6.3 Resource Not Found

| Scenario | Exception Type | Test Case |
|----------|---|---|
| updateStatusAndProof: delivery null | IllegalArgumentException | deliveryDAO.findById() returns null → throws "Không tìm thấy thông tin giao hàng" |
| updateEstimatedTime: delivery null | IllegalArgumentException | deliveryDAO.findById() returns null → throws "Không tìm thấy thông tin giao hàng" |
| markAsDelivered: delivery null | IllegalArgumentException | deliveryDAO.findById() returns null → throws "Không tìm thấy thông tin giao hàng" |
| claimDelivery: delivery null | IllegalArgumentException | deliveryDAO.findById() returns null → throws "Không tìm thấy thông tin giao hàng" |
| assignShipper: order null | IllegalArgumentException | orderDAO.findById() returns empty → throws "Không tìm thấy đơn hàng" |

### 6.4 Database Errors

| Scenario | Exception Type | Test Case |
|----------|---|---|
| updateStatusAndProof: update fails | SQLException | deliveryDAO.updateStatusAndProof() throws |
| updateEstimatedTime: update fails | SQLException | deliveryDAO.updateEstimatedTime() throws |
| getDeliveryByOrderId: query fails | SQLException | deliveryDAO.findByOrderId() throws |
| assignShipper: tripDAO.save fails | SQLException | deliveryTripDAO.save() throws (within transaction, rolled back) |
| assignShipper: assignShipper fails | SQLException | deliveryDAO.assignShipper() throws (rolled back) |
| markAsDelivered: deliveryDAO update fails | SQLException | deliveryDAO.updateStatusAndProof() throws |
| markAsDelivered: orderDAO update fails | SQLException | orderDAO.updateStatus() throws |
| getDashboardDeliveries: query fails | SQLException | deliveryDAO.findByStaffId() throws or findUnassigned() throws |
| claimDelivery: claimDelivery fails | SQLException | deliveryDAO.claimDelivery() throws or returns false |

### 6.5 State Transition Issues

| Scenario | Exception Type | Test Case |
|----------|---|---|
| assignShipper: trip creation fails in transaction | SQLException | deliveryTripDAO.save() throws → transaction rolled back |
| claimDelivery: concurrent claim race | (returns false) | Another shipper claims between check and update → claimDelivery returns false |

### 6.6 External Service Failures

| Scenario | Exception Type | Test Case |
|----------|---|---|
| markAsDelivered: notification fails | (logged) | notificationService.send() throws → logged, delivery state still updated |
| markAsDelivered: email fails | (logged) | emailService.sendOrderNotificationEmail() throws → logged |

---

## Summary Statistics

### By Service:

| Service | Total Scenarios | Authorization | Input Validation | Business Logic | DB Errors | External Service | Resource Not Found |
|---------|-----------------|---|---|---|---|---|---|
| AuthService | 49 | 0 | 14 | 19 | 5 | 4 | 7 |
| CartService | 44 | 3 | 7 | 14 | 9 | 0 | 3 |
| CheckoutService | 38 | 3 | 11 | 9 | 10 | 0 | 5 |
| OrderService | 22 | 12 | 0 | 4 | 9 | 4 | 5 |
| PaymentService | 29 | 2 | 2 | 9 | 8 | 4 | 8 |
| DeliveryService | 24 | 6 | 7 | 3 | 8 | 2 | 5 |

**Total Exception Scenarios to Test: 206**

### By Category:

- **Authorization/Permission Errors:** 26 scenarios
- **Input Validation Errors:** 41 scenarios
- **Business Logic Violations:** 58 scenarios
- **Database Errors:** 51 scenarios
- **External Service Failures:** 14 scenarios
- **Resource Not Found:** 33 scenarios
- **Concurrent Access/State Issues:** 5 scenarios
- **Webhook/Special Processing:** 8 scenarios

### Priority Testing Order:

1. **CRITICAL (must test first):**
   - All Authorization/Permission errors (26)
   - All Database constraint/connection errors (51)
   - Business logic violations affecting data integrity (stock, payments, orders)

2. **HIGH (essential for feature completeness):**
   - Input validation for all user-facing operations (41)
   - External service failures + recovery (14)
   - State transition errors (13)

3. **MEDIUM (improves robustness):**
   - Resource not found scenarios (33)
   - Concurrent access issues (5)
   - Edge cases in webhook processing (8)

---

## Test Implementation Guidelines

### For Each Scenario:

1. **Unit Test** - Mock all dependencies, test isolated business logic
2. **Integration Test** - Real database (Testcontainers), verify transactional boundaries
3. **End-to-End Test** - Full request→response flow if applicable

### Assertion Points:

- Exception type and message accuracy
- Transaction rollback verification (no partial state)
- Notification queue updates
- Audit log entries
- State consistency in related tables

### Parameterized Test Approach:

Group similar scenarios (e.g., "input validation for 5 fields") into parameterized tests to maximize coverage efficiency.

