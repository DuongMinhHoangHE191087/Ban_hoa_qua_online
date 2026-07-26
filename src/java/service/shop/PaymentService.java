package service.shop;

import config.AppConfig;
import dao.order.OrderDAO;
import dao.shop.PaymentDAO;
import dao.auth.UserDAO;
import com.fasterxml.jackson.databind.JsonNode;
import model.dto.checkout.CheckoutPaymentSummaryDTO;
import model.entity.order.Order;
import model.entity.shop.PaymentTransaction;
import model.entity.auth.User;
import util.JsonUtil;
import util.LoggerUtil;
import service.chat.NotificationService;
import service.system.EmailService;
import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.logging.Logger;
import java.security.SecureRandom;

/**
 * PaymentService — Business logic cho thanh toán.
 *
 * Luồng chính:
 *   1. CK: initPayment() → tạo payment_transactions
 *   2. Customer bấm "Tôi đã thanh toán" → confirmManualPayment()
 *   3. Admin xác nhận → adminApprovePayment()
 *   4. SePay webhook (tự động, idempotent) → processWebhook()
 *
 * @author fruitmkt-team
 */
public class PaymentService {

    private static final Logger log = LoggerUtil.getLogger(PaymentService.class);
    private static final SecureRandom secureRandom = new SecureRandom();

    private final PaymentDAO paymentDAO = new PaymentDAO();
    private final OrderDAO   orderDAO   = new OrderDAO();
    private final UserDAO    userDAO    = new UserDAO();
    private final NotificationService notificationService = new NotificationService();
    private final EmailService emailService = new EmailService();

    private static final int QR_EXPIRE_MIN = AppConfig.QR_EXPIRE_MINUTES;

    /**
     * Khởi tạo bản ghi payment_transaction cho đơn CK.
     * Gọi ngay sau khi INSERT orders thành công.
     */
    public PaymentTransaction initPayment(int orderId, String method) throws SQLException {
        return initPayment(orderId, method, null);
    }

    public PaymentTransaction initPayment(int orderId, String method, String ipAddress) throws SQLException {
        try (Connection conn = paymentDAO.openConnection()) {
            return initPayment(conn, orderId, method, ipAddress);
        }
    }

    public PaymentTransaction initPayment(Connection conn, int orderId, String method, String ipAddress) throws SQLException {
        if (orderId <= 0) {
            throw new IllegalArgumentException("không tìm thấy đơn hàng #" + orderId);
        }
        Order order = orderDAO.findOneById(conn, orderId);
        if (order == null) throw new IllegalArgumentException("không tìm thấy đơn hàng #" + orderId);

        String reference = buildSepayReference(orderId);
        LocalDateTime expiresAt = LocalDateTime.now().plusMinutes(QR_EXPIRE_MIN);

        int txId = paymentDAO.initTransaction(
            conn, orderId, method, order.getFinalAmount(),
            reference, ipAddress, expiresAt
        );

        PaymentTransaction tx = new PaymentTransaction();
        tx.setTransactionId(txId);
        tx.setOrderId(orderId);
        tx.setPaymentMethod(method);
        tx.setAmount(order.getFinalAmount());
        tx.setSepayReference(reference);
        tx.setStatus("pending");
        tx.setExpiresAt(expiresAt);
        return tx;
    }

    /**
     * Lấy thông tin payment transaction của đơn hàng.
     */
    public PaymentTransaction getPaymentByOrder(int orderId) throws SQLException {
        return paymentDAO.findOneByOrder(orderId);
    }

    public CheckoutPaymentSummaryDTO getCustomerPaymentSummary(int orderId, int customerId) throws SQLException {
        Order requestedOrder = orderDAO.findByIdForCustomer(orderId, customerId);
        if (requestedOrder == null) {
            return null;
        }

        Order rootOrder = requestedOrder;
        if (requestedOrder.getParentOrderId() != null && requestedOrder.getParentOrderId() > 0) {
            Order candidateRoot = orderDAO.findByIdForCustomer(requestedOrder.getParentOrderId(), customerId);
            if (candidateRoot != null) {
                rootOrder = candidateRoot;
            }
        }

        List<Order> childOrders = AppConfig.ORDER_TYPE_PARENT.equals(rootOrder.getOrderType())
                ? orderDAO.findChildrenByParentId(rootOrder.getOrderId())
                : java.util.List.of(rootOrder);
        PaymentTransaction paymentTx = getPaymentByOrder(rootOrder.getOrderId());
        return buildPaymentSummary(requestedOrder, rootOrder, childOrders, paymentTx);
    }

    public Map<Integer, PaymentTransaction> getPaymentMapByOrderIds(Collection<Integer> orderIds) throws SQLException {
        return paymentDAO.findByOrderIds(orderIds);
    }

    /**
     * Danh sách payment toàn sàn cho dashboard admin.
     */
    public List<Map<String, Object>> getAdminPayments(String status, String paymentMethod,
                                                      String keyword, int page, int pageSize) throws SQLException {
        return paymentDAO.findAdminPayments(status, paymentMethod, keyword, page, pageSize);
    }

    /**
     * Đếm payment toàn sàn theo bộ lọc dashboard admin.
     */
    public int countAdminPayments(String status, String paymentMethod, String keyword) throws SQLException {
        return paymentDAO.countAdminPayments(status, paymentMethod, keyword);
    }

    /**
     * Khách bấm "Tôi đã thanh toán" — chuyển status → processing.
     * Thông báo admin cần xác minh thủ công.
     * @return false nếu QR đã hết hạn
     */
    public boolean confirmManualPayment(int orderId, int customerId) throws SQLException {
        CheckoutPaymentSummaryDTO summary = getCustomerPaymentSummary(orderId, customerId);
        if (summary == null) {
            throw new SecurityException("Không có quyền truy cập đơn hàng #" + orderId);
        }
        Order order = orderDAO.findByIdForCustomer(summary.getOrderId(), customerId);
        if (order == null) {
            throw new IllegalArgumentException("không tìm thấy đơn hàng #" + summary.getOrderId());
        }
        PaymentTransaction tx = getPaymentByOrder(summary.getOrderId());
        if (tx == null) {
            throw new IllegalStateException("Không tìm thấy bản ghi thanh toán cho đơn #" + summary.getOrderId());
        }

        if (!summary.getPendingPayment()) {
            throw new IllegalStateException("Đơn hàng không ở trạng thái chờ thanh toán.");
        }
        String currentTxStatus = tx.getStatus();
        if (currentTxStatus != null
                && !"pending".equalsIgnoreCase(currentTxStatus)
                && !"processing".equalsIgnoreCase(currentTxStatus)) {
            throw new IllegalStateException("Giao dịch thanh toán không còn ở trạng thái có thể xác nhận.");
        }
        // Kiểm tra QR còn hạn không
        if (tx.getExpiresAt() != null && LocalDateTime.now().isAfter(tx.getExpiresAt())) {
            return false; // QR hết hạn
        }
        if (!"processing".equalsIgnoreCase(currentTxStatus)) {
            paymentDAO.updateStatus(tx.getTransactionId(), "processing");
        }
        // Thông báo admin (NotificationService sẽ được mở rộng sau)
        LoggerUtil.info(log, "Customer #%d báo đã CK cho đơn #%d. Cần admin xác nhận.", customerId, orderId);
        return true;
    }

    /**
     * Admin xác nhận đã nhận tiền — chuyển payment → completed, order → CONFIRMED.
     */
    public void adminApprovePayment(int orderId, int adminId) throws SQLException {
        if (orderId <= 0) {
            throw new IllegalArgumentException("không tìm thấy đơn hàng #" + orderId);
        }
        User adminUser = userDAO.findUserById(adminId);
        if (adminUser == null || !AppConfig.ROLE_ADMIN.equals(adminUser.getRole())) {
            throw new SecurityException("Bạn không có quyền thực hiện phê duyệt thanh toán này.");
        }

        try (Connection conn = paymentDAO.openConnection()) {
            conn.setAutoCommit(false);
            try {
                Order order = orderDAO.findOneById(conn, orderId);
                if (order == null) throw new IllegalArgumentException("không tìm thấy đơn hàng #" + orderId);

                if (!AppConfig.ORDER_PENDING_PAYMENT.equals(order.getStatus())) {
                    throw new IllegalStateException("Đơn hàng không ở trạng thái chờ thanh toán.");
                }

                PaymentTransaction tx = paymentDAO.findOneByOrder(conn, orderId);
                if (tx == null) throw new IllegalStateException("Không tìm thấy bản ghi thanh toán.");

                finalizePaymentTree(conn, order, tx, "ADMIN_MANUAL_" + adminId, null);
                conn.commit();
                LoggerUtil.info(log, "Admin #%d xác nhận thanh toán đơn #%d%s.",
                        adminId, orderId,
                        AppConfig.ORDER_TYPE_PARENT.equals(order.getOrderType()) ? " và cascade đơn con" : "");
                notifyPaymentSuccessAsync(orderId, order.getCustomerId(),
                        "Đơn hàng #" + orderId + " đã được xác nhận thanh toán thành công bởi quản trị viên.");
                notifyOrdersReadyForFulfillmentAsync(order.getOrderId());
                return;
            } catch (SQLException | RuntimeException ex) {
                conn.rollback();
                throw ex;
            } finally {
                conn.setAutoCommit(true);
            }
        }
    }

    /**
     * Reconcile các payment đã completed nhưng tree đơn vẫn còn lệch (ví dụ child order chưa được cascade CONFIRMED).
     *
     * @return số payment tree đã được kiểm tra và đồng bộ lại thành công
     */
    public int reconcileCompletedPayments() throws SQLException {
        List<Integer> candidateOrderIds = paymentDAO.findCompletedOrderIdsForReconciliation();
        if (candidateOrderIds.isEmpty()) {
            return 0;
        }

        int repairedCount = 0;
        for (Integer candidateOrderId : candidateOrderIds) {
            if (candidateOrderId == null || candidateOrderId <= 0) {
                continue;
            }

            try (Connection conn = paymentDAO.openConnection()) {
                conn.setAutoCommit(false);
                try {
                    Order order = orderDAO.findOneById(conn, candidateOrderId);
                    if (order == null) {
                        LoggerUtil.warn(log, "[Reconcile] Không tìm thấy orderId=%d dù payment đã completed.", candidateOrderId);
                        conn.rollback();
                        continue;
                    }

                    PaymentTransaction tx = paymentDAO.findOneByOrder(conn, candidateOrderId);
                    if (tx == null) {
                        LoggerUtil.warn(log, "[Reconcile] Không tìm thấy payment transaction cho orderId=%d.", candidateOrderId);
                        conn.rollback();
                        continue;
                    }

                    boolean freshCompletion = AppConfig.ORDER_PENDING_PAYMENT.equals(order.getStatus());
                    finalizePaymentTree(conn, order, tx, tx.getSepayTransactionId(), tx.getProviderResponse());
                    conn.commit();
                    repairedCount++;
                    LoggerUtil.info(log, "[Reconcile] Đồng bộ payment tree thành công cho orderId=%d.", candidateOrderId);

                    if (freshCompletion) {
                        notifyPaymentSuccessAsync(order.getOrderId(), order.getCustomerId(),
                                "Đơn hàng #" + order.getOrderId() + " đã được xác nhận thanh toán thành công sau đối soát tự động.");
                        notifyOrdersReadyForFulfillmentAsync(order.getOrderId());
                    }
                } catch (SQLException | RuntimeException ex) {
                    conn.rollback();
                    LoggerUtil.error(log, "[Reconcile] Lỗi khi đồng bộ payment tree cho orderId=" + candidateOrderId, ex);
                } finally {
                    conn.setAutoCommit(true);
                }
            }
        }
        return repairedCount;
    }

    /**
     * Làm mới QR (gia hạn thêm 15 phút).
     * Chỉ cho phép nếu đơn vẫn ở PENDING_PAYMENT và QR thực sự đã hết hạn.
     */
    public PaymentTransaction renewQr(int orderId, int customerId) throws SQLException {
        Order order = orderDAO.findByIdForCustomer(orderId, customerId);
        if (order == null) throw new SecurityException("Không có quyền truy cập đơn hàng #" + orderId);
        if (!AppConfig.ORDER_PENDING_PAYMENT.equals(order.getStatus())) {
            throw new IllegalStateException("Không thể làm mới QR cho đơn không ở trạng thái chờ thanh toán.");
        }
        PaymentTransaction tx = getPaymentByOrder(orderId);
        if (tx == null) {
            // Chưa có → tạo mới
            return initPayment(orderId, "SEPAY");
        }
        if (tx.getExpiresAt() != null && LocalDateTime.now().isBefore(tx.getExpiresAt())) {
            return tx;
        }
        String newReference = buildSepayReference(orderId);
        LocalDateTime newExpiry = LocalDateTime.now().plusMinutes(QR_EXPIRE_MIN);
        String updateSql = "UPDATE payment_transactions SET sepay_reference = ?, expires_at = ?, status = 'pending', "
                         + "sepay_transaction_id = NULL, provider_response = NULL, error_code = NULL, error_message = NULL, completed_at = NULL "
                         + "WHERE transaction_id = ?";
        try (Connection conn = paymentDAO.openConnection();
             PreparedStatement ps = conn.prepareStatement(updateSql)) {
            ps.setString(1, newReference);
            ps.setTimestamp(2, Timestamp.valueOf(newExpiry));
            ps.setInt(3, tx.getTransactionId());
            ps.executeUpdate();
        }
        tx.setSepayReference(newReference);
        tx.setExpiresAt(newExpiry);
        tx.setStatus("pending");
        return tx;
    }

    /**
     * Xử lý SePay Webhook — implement đầy đủ cho production.
     *
     * Payload SePay (relevant fields):
     *   id            → sepay_transaction_id
     *   code          → sepay_reference (VD: "MF101")
     *   transferAmount → số tiền thực nhận
     *   transferType  → "in" = tiền vào, "out" = tiền ra
     *
     * @param jsonPayload raw JSON body từ SePay
     */
    @com.fasterxml.jackson.annotation.JsonIgnoreProperties(ignoreUnknown = true)
    public static final class SepayWebhookPayload {
        public JsonNode id;
        public JsonNode code;
        public JsonNode transferType;
        public JsonNode transferAmount;
        public JsonNode subAccount;
        public JsonNode accountNumber;
        public JsonNode referenceCode;
    }

    public static final class WebhookProcessingResult {
        private final String outcome;
        private final boolean duplicate;
        private final boolean notifyCustomer;
        private final int orderId;
        private final int customerId;
        private final String sepayTxId;

        private WebhookProcessingResult(String outcome, boolean duplicate, boolean notifyCustomer, int orderId,
                                        int customerId, String sepayTxId) {
            this.outcome = outcome;
            this.duplicate = duplicate;
            this.notifyCustomer = notifyCustomer;
            this.orderId = orderId;
            this.customerId = customerId;
            this.sepayTxId = sepayTxId;
        }

        static WebhookProcessingResult duplicate() {
            return new WebhookProcessingResult("duplicate", true, false, -1, -1, null);
        }

        static WebhookProcessingResult handled(int orderId, int customerId, String sepayTxId) {
            return new WebhookProcessingResult("processed", false, true, orderId, customerId, sepayTxId);
        }

        static WebhookProcessingResult skipped(String outcome) {
            return new WebhookProcessingResult(outcome, false, false, -1, -1, null);
        }

        static WebhookProcessingResult invalidPayload() {
            return skipped("invalid_payload");
        }

        public String getOutcome() {
            return outcome;
        }

        public boolean isDuplicate() {
            return duplicate;
        }

        public boolean shouldNotifyCustomer() {
            return notifyCustomer;
        }

        public int getOrderId() {
            return orderId;
        }

        public int getCustomerId() {
            return customerId;
        }

        public String getSepayTxId() {
            return sepayTxId;
        }

        public java.util.Map<String, Object> toResponseMap() {
            java.util.Map<String, Object> payload = new java.util.LinkedHashMap<>();
            payload.put("outcome", outcome);
            payload.put("duplicate", duplicate);
            payload.put("notifyCustomer", notifyCustomer);
            if (orderId > 0) {
                payload.put("orderId", orderId);
            }
            if (customerId > 0) {
                payload.put("customerId", customerId);
            }
            if (sepayTxId != null) {
                payload.put("sepayTxId", sepayTxId);
            }
            return payload;
        }
    }

    public WebhookProcessingResult processWebhook(String jsonPayload) throws SQLException {
        SepayWebhookPayload payload;
        try {
            payload = JsonUtil.fromJson(jsonPayload, SepayWebhookPayload.class);
        } catch (Exception e) {
            LoggerUtil.warn(log, "[Webhook] Payload JSON không hợp lệ (len="
                    + (jsonPayload == null ? 0 : jsonPayload.length()) + ")", e);
            return WebhookProcessingResult.invalidPayload();
        }

        String sepayTxId = normalizeNodeText(payload != null ? payload.id : null);
        if (sepayTxId == null && payload != null) {
            sepayTxId = normalizeNodeText(payload.referenceCode);
        }
        String code = normalizeNodeText(payload != null ? payload.code : null);
        String transferType = normalizeNodeText(payload != null ? payload.transferType : null);
        String amountStr = normalizeNodeText(payload != null ? payload.transferAmount : null);
        String subAccount = normalizeNodeText(payload != null ? payload.subAccount : null);
        String accountNumber = normalizeNodeText(payload != null ? payload.accountNumber : null);

        if (sepayTxId == null || code == null) {
            LoggerUtil.warn(log, "[Webhook] Payload thiếu trường bắt buộc: sepayTxId (id/referenceCode) hoặc code. len="
                    + (jsonPayload == null ? 0 : jsonPayload.length()));
            return WebhookProcessingResult.invalidPayload();
        }

        WebhookProcessingResult result = null;
        int maxRetries = 3;
        int retryDelayMs = 100;
        for (int attempt = 1; attempt <= maxRetries; attempt++) {
            try (Connection conn = paymentDAO.openConnection()) {
                conn.setAutoCommit(false);
                try {
                    result = processWebhook(conn, jsonPayload, sepayTxId, code, transferType, amountStr, subAccount, accountNumber);
                    if (result.isDuplicate()) {
                        conn.rollback();
                        return result;
                    }
                    conn.commit();
                    break; // Success! Exit retry loop.
                } catch (SQLException e) {
                    conn.rollback();
                    if (e.getErrorCode() == 1205 && attempt < maxRetries) {
                        LoggerUtil.warn(log, "[Webhook] Deadlock detected (attempt " + attempt + "/" + maxRetries + "). Retrying in " + retryDelayMs + "ms...", e);
                        try { Thread.sleep(retryDelayMs); } catch (InterruptedException ie) { Thread.currentThread().interrupt(); }
                        retryDelayMs *= 2; // Exponential backoff
                        continue;
                    }
                    throw e;
                }
            }
        }

        if (result.shouldNotifyCustomer()) {
            notifyPaymentSuccessAsync(result.orderId, result.customerId,
                    "Đơn hàng #" + result.orderId + " đã được xác nhận thanh toán thành công qua chuyển khoản tự động.");
            notifyOrdersReadyForFulfillmentAsync(result.orderId);
        }
        return result;
    }

    private WebhookProcessingResult processWebhook(Connection conn, String jsonPayload, String sepayTxId,
                                                   String code, String transferType, String amountStr, String subAccount, String accountNumber) throws SQLException {
        if (!paymentDAO.insertDedup(conn, sepayTxId, code, "processing")) {
            LoggerUtil.info(log, "[Webhook] Duplicate sepay_tx_id=%s — bỏ qua.", sepayTxId);
            return WebhookProcessingResult.duplicate();
        }

        if (!"in".equalsIgnoreCase(transferType)) {
            paymentDAO.updateDedupResult(conn, sepayTxId, "skipped_not_in");
            return WebhookProcessingResult.skipped("skipped_not_in");
        }

        // Kiểm tra số tài khoản thụ hưởng nếu có gửi lên (sử dụng trong production)
        if (subAccount != null || accountNumber != null) {
            dao.system.SystemConfigDAO systemConfigDAO = new dao.system.SystemConfigDAO();
            String expectedAccountNo = null;
            try {
                expectedAccountNo = systemConfigDAO.getValue(AppConfig.CONFIG_SEPAY_ACCOUNT_NO);
            } catch (Exception e) {
                // Bỏ qua lỗi truy vấn DB, sử dụng mặc định
            }
            if (expectedAccountNo == null || expectedAccountNo.trim().isEmpty()) {
                expectedAccountNo = AppConfig.SEPAY_ACCOUNT_NO;
            }
            boolean matchSub = subAccount != null && subAccount.equalsIgnoreCase(expectedAccountNo);
            boolean matchMain = accountNumber != null && accountNumber.equalsIgnoreCase(expectedAccountNo);
            if (!matchSub && !matchMain) {
                LoggerUtil.warn(log, "[Webhook] Số tài khoản nhận tiền không khớp: subAccount=%s, accountNumber=%s, config=%s. Bỏ qua.",
                    subAccount, accountNumber, expectedAccountNo);
                paymentDAO.updateDedupResult(conn, sepayTxId, "skipped_wrong_account");
                return WebhookProcessingResult.skipped("skipped_wrong_account");
            }
        }

        PaymentTransaction tx = paymentDAO.findByReference(conn, code);
        if (tx == null) {
            LoggerUtil.warn(log, "[Webhook] Không tìm thấy payment_transaction với reference=%s", code);
            paymentDAO.updateDedupResult(conn, sepayTxId, "not_found");
            return WebhookProcessingResult.skipped("not_found");
        }

        String txStatus = tx.getStatus();
        if (!"pending".equalsIgnoreCase(txStatus) && !"processing".equalsIgnoreCase(txStatus)) {
            LoggerUtil.warn(log, "[Webhook] transactionId=%d không ở trạng thái xử lý hợp lệ (hiện tại: %s) — bỏ qua.",
                    tx.getTransactionId(), txStatus);
            paymentDAO.updateDedupResult(conn, sepayTxId, "skipped_wrong_status");
            return WebhookProcessingResult.skipped("skipped_wrong_status");
        }

        Order order = orderDAO.findOneById(conn, tx.getOrderId());
        if (order == null || !AppConfig.ORDER_PENDING_PAYMENT.equals(order.getStatus())) {
            String currentStatus = order != null ? order.getStatus() : "null";
            LoggerUtil.warn(log, "[Webhook] orderId=%d không ở trạng thái PENDING_PAYMENT (hiện tại: %s) — bỏ qua.",
                tx.getOrderId(), currentStatus);
            paymentDAO.updateDedupResult(conn, sepayTxId, "skipped_wrong_status");
            return WebhookProcessingResult.skipped("skipped_wrong_status");
        }

        BigDecimal received;
        try {
            received = amountStr != null ? new BigDecimal(amountStr) : BigDecimal.ZERO;
        } catch (NumberFormatException nfe) {
            LoggerUtil.warn(log, "[Webhook] Số tiền không hợp lệ: %s", amountStr);
            paymentDAO.updateDedupResult(conn, sepayTxId, "invalid_payload");
            return WebhookProcessingResult.invalidPayload();
        }

        BigDecimal expected = tx.getAmount() != null ? tx.getAmount() : BigDecimal.ZERO;
        if (received.compareTo(expected) != 0) {
            paymentDAO.updateDedupResult(conn, sepayTxId, "amount_mismatch");
            LoggerUtil.warn(log, "[Webhook] Số tiền không khớp: expected=%s received=%s orderId=%d",
                expected, received, tx.getOrderId());
            return WebhookProcessingResult.skipped("amount_mismatch");
        }

        finalizePaymentTree(conn, order, tx, sepayTxId, jsonPayload);

        paymentDAO.updateDedupResult(conn, sepayTxId, "processed");
        LoggerUtil.info(log, "[Webhook] outcome=processed orderId=%d sepayTxId=%s%s",
                tx.getOrderId(), sepayTxId,
                AppConfig.ORDER_TYPE_PARENT.equals(order.getOrderType()) ? " parentCascade=true" : "");
        return WebhookProcessingResult.handled(order.getOrderId(), order.getCustomerId(), sepayTxId);
    }

    private void finalizePaymentTree(Connection conn, Order order, PaymentTransaction tx,
                                     String sepayTransactionId, String providerResponse) throws SQLException {
        paymentDAO.updateStatus(conn, tx.getTransactionId(), "completed", sepayTransactionId, providerResponse);
        orderDAO.updateStatus(conn, order.getOrderId(), AppConfig.ORDER_CONFIRMED);

        if (AppConfig.ORDER_TYPE_PARENT.equals(order.getOrderType())) {
            orderDAO.updateStatusByParent(conn, order.getOrderId(), AppConfig.ORDER_CONFIRMED);
            LoggerUtil.info(log, "[Payment] Cascade CONFIRMED cho tất cả đơn con của parentOrderId=%d", order.getOrderId());
        }
    }

    private static final java.util.concurrent.ExecutorService notifierExecutor = 
        java.util.concurrent.Executors.newCachedThreadPool(r -> {
            Thread t = new Thread(r, "sepay-webhook-notifier");
            t.setDaemon(true);
            return t;
        });

    private void notifyPaymentSuccessAsync(int orderId, int customerId, String customerMessage) {
        try {
            notifierExecutor.submit(() -> {
                try {
                    LoggerUtil.info(log, "[Payment] [Async] Gửi thông báo khách hàng cho orderId=%d", orderId);
                    User customer = userDAO.findUserById(customerId);
                    if (customer != null) {
                        notificationService.send(customer.getUserId(), AppConfig.NOTIF_PAYMENT, "Thanh toán thành công", customerMessage, "/orders/detail?orderId=" + orderId);
                        String orderDetailUrl = AppConfig.APP_BASE_URL + "/orders/detail?orderId=" + orderId;
                        emailService.sendOrderNotificationEmail(customer.getEmail(), customer.getFullName(), String.valueOf(orderId), "Xác nhận thanh toán thành công", orderDetailUrl);
                    }
                } catch (Exception ex) {
                    LoggerUtil.warn(log, "Không gửi được thông báo thanh toán cho orderId=" + orderId, ex);
                }
            });
        } catch (RuntimeException ex) {
            LoggerUtil.warn(log, "Không thể xếp hàng thông báo thanh toán cho orderId=" + orderId, ex);
        }
    }

    private CheckoutPaymentSummaryDTO buildPaymentSummary(Order requestedOrder,
                                                          Order rootOrder,
                                                          List<Order> childOrders,
                                                          PaymentTransaction paymentTx) {
        CheckoutPaymentSummaryDTO summary = new CheckoutPaymentSummaryDTO();
        summary.setRequestedOrderId(requestedOrder.getOrderId());
        summary.setOrderId(rootOrder.getOrderId());
        summary.setOrderType(rootOrder.getOrderType());
        summary.setPaymentMethod(rootOrder.getPaymentMethod());
        BigDecimal finalAmount = rootOrder.getFinalAmount() != null ? rootOrder.getFinalAmount() : BigDecimal.ZERO;
        boolean paymentRequired = AppConfig.PAYMENT_CK.equals(rootOrder.getPaymentMethod())
                && finalAmount.compareTo(BigDecimal.ZERO) > 0;
        summary.setFinalAmount(finalAmount);
        summary.setPaymentRequired(paymentRequired);
        summary.setCancelled(AppConfig.ORDER_CANCELLED.equals(rootOrder.getStatus()));

        String paymentStatus = paymentTx != null ? paymentTx.getStatus() : null;
        summary.setPaymentStatus(paymentStatus);
        if (paymentTx != null) {
            summary.setReference(paymentTx.getSepayReference());
        }

        String effectiveOrderStatus = rootOrder.getStatus();
        boolean paid = !paymentRequired || "completed".equalsIgnoreCase(paymentStatus);
        if (!paymentRequired && AppConfig.ORDER_PENDING_PAYMENT.equals(effectiveOrderStatus)) {
            effectiveOrderStatus = AppConfig.ORDER_CONFIRMED;
        }
        if (AppConfig.ORDER_PENDING_PAYMENT.equals(effectiveOrderStatus) && paid) {
            effectiveOrderStatus = AppConfig.ORDER_CONFIRMED;
        }
        summary.setOrderStatus(effectiveOrderStatus);
        summary.setPaid(paid);
        summary.setPendingPayment(paymentRequired
                && AppConfig.ORDER_PENDING_PAYMENT.equals(rootOrder.getStatus())
                && !paid
                && !summary.getCancelled());
        summary.setCanConfirmPayment(summary.getPendingPayment()
                && paymentTx != null
                && ("pending".equalsIgnoreCase(paymentStatus) || "processing".equalsIgnoreCase(paymentStatus)));

        List<Integer> childOrderIds = new java.util.ArrayList<>();
        if (childOrders != null) {
            for (Order childOrder : childOrders) {
                if (childOrder != null && childOrder.getOrderId() != rootOrder.getOrderId()) {
                    childOrderIds.add(childOrder.getOrderId());
                }
            }
        }
        summary.setChildOrderIds(childOrderIds);
        return summary;
    }

    private void notifyOrdersReadyForFulfillmentAsync(int orderId) {
        try {
            notifierExecutor.submit(() -> {
                try {
                    Order rootOrder = orderDAO.findOneById(orderId);
                    if (rootOrder == null) {
                        return;
                    }
                    if (AppConfig.ORDER_TYPE_PARENT.equals(rootOrder.getOrderType())) {
                        for (Order childOrder : orderDAO.findChildrenByParentId(rootOrder.getOrderId())) {
                            notifyShopOrderReady(childOrder);
                        }
                    } else {
                        notifyShopOrderReady(rootOrder);
                    }
                } catch (Exception ex) {
                    LoggerUtil.warn(log, "Không gửi được thông báo shop sau xác nhận thanh toán cho orderId=" + orderId, ex);
                }
            });
        } catch (RuntimeException ex) {
            LoggerUtil.warn(log, "Không thể xếp hàng thông báo shop cho orderId=" + orderId, ex);
        }
    }

    private void notifyShopOrderReady(Order order) throws SQLException {
        if (order == null || order.getOwnerId() <= 0) {
            return;
        }
        String shopMsg = "Đơn hàng #" + order.getOrderId() + " đã thanh toán thành công và sẵn sàng để shop chuẩn bị.";
        notificationService.send(order.getOwnerId(), AppConfig.NOTIF_ORDER_UPDATE,
                "Có đơn hàng mới cần chuẩn bị", shopMsg, "/shop/orders");
        User shopOwner = userDAO.findUserById(order.getOwnerId());
        if (shopOwner != null) {
            emailService.sendOrderNotificationEmail(
                    shopOwner.getEmail(),
                    shopOwner.getFullName(),
                    String.valueOf(order.getOrderId()),
                    "Có đơn hàng mới cần chuẩn bị",
                    AppConfig.APP_BASE_URL + "/shop/orders");
        }
    }

    private String normalizeNodeText(JsonNode node) {
        if (node == null || node.isNull()) {
            return null;
        }
        String value = node.asText();
        if (value == null) {
            return null;
        }
        value = value.trim();
        return value.isEmpty() ? null : value;
    }

    /** Tạo reference SePay theo format MF + mã đơn hàng + 4 chữ số ngẫu nhiên. */
    public static String buildSepayReference(int orderId) {
        int suffix = secureRandom.nextInt(10000);
        return String.format("%s%03d%04d", AppConfig.PAYMENT_REF_PREFIX, orderId, suffix);
    }

    /** Mở kết nối dùng cho renewQr (package-private để test). */
    Connection openConnection() throws SQLException {
        return orderDAO.openConnection();
    }
}
