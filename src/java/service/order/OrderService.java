package service.order;
import service.catalog.InventoryService;
import service.chat.NotificationService;

import config.AppConfig;
import dao.cart.CartDAO;
import dao.order.OrderDAO;
import dao.shop.PaymentDAO;
import dao.auth.UserDAO;
import exception.BusinessException;
import model.dto.checkout.CheckoutDTO;
import model.dto.common.PagedResultDTO;
import model.dto.order.ReorderResultDTO;
import model.entity.cart.Cart;
import model.entity.order.Order;
import model.entity.order.OrderItem;
import model.entity.auth.User;
import model.entity.shop.PaymentTransaction;
import util.LoggerUtil;
import util.PaginationUtil;
import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Objects;
import java.util.logging.Logger;
import service.system.EmailService;

/**
 * OrderService - Tang business logic cho nghiep vu don hang.
 */
public class OrderService {

    private static final Logger log = LoggerUtil.getLogger(OrderService.class);

    private final OrderDAO orderDAO = new OrderDAO();
    private final PaymentDAO paymentDAO = new PaymentDAO();
    private final NotificationService notificationService = new NotificationService();
    private final EmailService emailService = new EmailService();
    private final InventoryService inventoryService = new InventoryService();
    private final DeliveryService deliveryService = new DeliveryService();
    private final CartDAO cartDAO = new CartDAO();
    private final UserDAO userDAO = new UserDAO();

    public Order placeOrder(int customerId, CheckoutDTO dto) throws SQLException {
        throw new UnsupportedOperationException("Not implemented: placeOrder(int customerId, CheckoutDTO dto)");
    }

    public List<Order> getAllOrders(String status, int page, int pageSize) throws SQLException {
        return orderDAO.findAll(status, page, pageSize);
    }

    public List<Order> getAllOrders(String status, String paymentMethod, String paymentStatus, int page, int pageSize)
            throws SQLException {
        return orderDAO.findAll(status, paymentMethod, paymentStatus, page, pageSize);
    }

    public int countAllOrders(String status) throws SQLException {
        return orderDAO.countAll(status);
    }

    public int countAllOrders(String status, String paymentMethod, String paymentStatus) throws SQLException {
        return orderDAO.countAll(status, paymentMethod, paymentStatus);
    }

    public Order getOrderDetail(int orderId) throws SQLException {
        if (orderId <= 0) {
            throw new IllegalArgumentException("Đơn hàng không tồn tại!");
        }
        return orderDAO.findOneById(orderId);
    }

    public PagedResultDTO getOrderHistory(int customerId, int page) throws SQLException {
        throw new UnsupportedOperationException("Not implemented: getOrderHistory(int customerId, int page)");
    }

    public void confirmOrder(int orderId, int ownerId) throws SQLException {
        Order order = getOrderDetail(orderId);
        if (order == null || order.getOwnerId() != ownerId) {
            throw new RuntimeException("Đơn hàng không hợp lệ hoặc bạn không có quyền duyệt!");
        }
        if (!AppConfig.ORDER_CONFIRMED.equals(order.getStatus())) {
            throw new RuntimeException("Chỉ có thể duyệt đơn hàng khi trạng thái là CONFIRMED.");
        }
        orderDAO.updateStatus(orderId, AppConfig.ORDER_APPROVED);
    }

    public void cancelOrder(int orderId, int cancelledBy, String reason) throws SQLException {
        if (reason == null || reason.trim().isEmpty()) {
            throw new IllegalArgumentException("Lý do hủy đơn hàng là bắt buộc.");
        }
        Order order = getOrderDetail(orderId);
        if (order == null) {
            throw new IllegalArgumentException("Đơn hàng không tồn tại!");
        }
        if (AppConfig.ORDER_DELIVERED.equals(order.getStatus()) || AppConfig.ORDER_CANCELLED.equals(order.getStatus())) {
            throw new RuntimeException("Đơn hàng đã giao hoặc đã hủy, không thể hủy thêm!");
        }

        // IDOR fix: unknown caller ID must be rejected before any ownership check
        User user = userDAO.findUserById(cancelledBy);
        if (user == null) {
            throw new BusinessException("UNAUTHORIZED", "Người dùng không tồn tại hoặc không có quyền hủy đơn hàng này!");
        }
        if (AppConfig.ROLE_CUSTOMER.equals(user.getRole())) {
            // ORD-01: customers may only cancel in PENDING_PAYMENT or CONFIRMED
            if (!Objects.equals(order.getCustomerId(), cancelledBy)) {
                throw new BusinessException("FORBIDDEN", "Bạn không có quyền hủy đơn hàng này!");
            }
            if (!AppConfig.ORDER_PENDING_PAYMENT.equals(order.getStatus())
                    && !AppConfig.ORDER_CONFIRMED.equals(order.getStatus())) {
                throw new BusinessException("INVALID_STATUS", "Cửa hàng đã duyệt hoặc đang giao đơn, không thể tự ý hủy!");
            }
        } else if (AppConfig.ROLE_SHOP_OWNER.equals(user.getRole())) {
            if (!Objects.equals(order.getOwnerIdObject(), cancelledBy)) {
                throw new BusinessException("FORBIDDEN", "Đơn hàng này không thuộc cửa hàng của bạn!");
            }
        }
        // ADMIN and other privileged roles may cancel any order without ownership restriction

        cancelOrderAndRestoreStock(order, cancelledBy, reason, false);
    }

    public PagedResultDTO shopOrders(int ownerId, String status, int page) throws SQLException {
        int pageSize = 10;
        List<Order> list = orderDAO.findByOwner(ownerId, status, page, pageSize);
        int total = orderDAO.countByOwner(ownerId, status);
        return PaginationUtil.buildPagedResult(list, page, pageSize, total);
    }

    public void dispatchOrder(int orderId, int ownerId) throws SQLException {
        dispatchOrder(orderId, ownerId, null);
    }

    public void dispatchOrder(int orderId, int ownerId, LocalDateTime estimatedTime) throws SQLException {
        Order order = getOrderDetail(orderId);
        if (order == null || order.getOwnerId() != ownerId) {
            throw new RuntimeException("Đơn hàng không hợp lệ!");
        }
        if (!AppConfig.ORDER_APPROVED.equals(order.getStatus())
                && !AppConfig.ORDER_CONFIRMED.equals(order.getStatus())
                && !"PREPARING".equals(order.getStatus())) {
            throw new RuntimeException("Chỉ có thể giao đơn đang được chuẩn bị hoặc đã duyệt!");
        }
        deliveryService.validateEstimatedTime(estimatedTime);
        try (Connection conn = orderDAO.openConnection()) {
            conn.setAutoCommit(false);
            try {
                orderDAO.updateStatus(conn, orderId, AppConfig.ORDER_DISPATCHED);
                deliveryService.assignShipper(conn, orderId, 0, estimatedTime);
                conn.commit();
            } catch (SQLException | RuntimeException ex) {
                conn.rollback();
                throw ex;
            }
        }

        try {
            User customer = userDAO.findUserById(order.getCustomerId());
            if (customer != null) {
                String customerMsg = "Đơn hàng #" + orderId + " của bạn đang được giao.";
                notificationService.send(customer.getUserId(), AppConfig.NOTIF_ORDER_UPDATE, "Đơn hàng đang giao", customerMsg, "/orders/detail?orderId=" + orderId);
                String orderDetailUrl = AppConfig.APP_BASE_URL + "/orders/detail?orderId=" + orderId;
                emailService.sendOrderNotificationEmail(customer.getEmail(), customer.getFullName(), String.valueOf(orderId), "Đơn hàng đang giao (DISPATCHED)", orderDetailUrl);
            }
        } catch (Exception ex) {
            LoggerUtil.warn(log, "Không gửi được thông báo dispatch cho orderId=" + orderId, ex);
        }
    }

    public void customerConfirmDelivery(int orderId, int customerId) throws SQLException {
        Order order = orderDAO.findByIdForCustomer(orderId, customerId);
        if (order == null) {
            throw new RuntimeException("Đơn hàng không hợp lệ!");
        }
        if (!AppConfig.ORDER_DISPATCHED.equals(order.getStatus())
                && !AppConfig.ORDER_DELIVERED.equals(order.getStatus())) {
            throw new RuntimeException("Chỉ có thể xác nhận nhận hàng đối với đơn đang giao hoặc đã giao!");
        }
        orderDAO.updateStatus(orderId, AppConfig.ORDER_DELIVERED);
        orderDAO.updateReceivedStatus(orderId, "RECEIVED");

        // Ghi log inventory: "Giao hàng thành công" cho từng sản phẩm trong đơn
        try {
            List<OrderItem> items = orderDAO.findItemsByOrderId(orderId);
            for (OrderItem item : items) {
                if (item.getVariantId() != null) {
                    inventoryService.confirm(item.getVariantId(), item.getQuantity(), orderId);
                }
            }
        } catch (Exception ex) {
            LoggerUtil.warn(log, "Không thể ghi log inventory confirm cho orderId=" + orderId, ex);
        }

        try {
            User customer = userDAO.findUserById(customerId);
            if (customer != null) {
                String customerMsg = "Đơn hàng #" + orderId + " đã giao thành công và được bạn xác nhận.";
                notificationService.send(customerId, AppConfig.NOTIF_ORDER_UPDATE, "Giao hàng thành công", customerMsg, "/orders/detail?orderId=" + orderId);
                String orderDetailUrl = AppConfig.APP_BASE_URL + "/orders/detail?orderId=" + orderId;
                emailService.sendOrderNotificationEmail(customer.getEmail(), customer.getFullName(), String.valueOf(orderId), "Giao hàng thành công (DELIVERED)", orderDetailUrl);
            }
        } catch (Exception ex) {
            LoggerUtil.warn(log, "Không gửi được thông báo delivery confirm cho orderId=" + orderId, ex);
        }
    }

    public void reportNotReceived(int orderId, int customerId) throws SQLException {
        Order order = orderDAO.findByIdForCustomer(orderId, customerId);
        if (order == null) {
            throw new SecurityException("Bạn không có quyền thực hiện hành động này.");
        }
        if (!AppConfig.ORDER_DISPATCHED.equals(order.getStatus())
                && !AppConfig.ORDER_DELIVERED.equals(order.getStatus())) {
            throw new IllegalStateException("Chỉ có thể báo chưa nhận hàng với đơn đang giao hoặc đã giao.");
        }
        orderDAO.updateReceivedStatus(orderId, "NOT_RECEIVED");
    }

    public ReorderResultDTO reorder(int orderId, int customerId) throws SQLException {
        Order order = orderDAO.findByIdForCustomer(orderId, customerId);
        if (order == null) {
            throw new SecurityException("Bạn không có quyền thực hiện hành động này.");
        }

        List<OrderItem> items = orderDAO.findItemsByOrderId(orderId);
        List<Cart> carts = cartDAO.findByCustomer(customerId);
        int cartId = carts.isEmpty() ? cartDAO.createForCustomer(customerId) : carts.get(0).getCartId();

        int addedCount = 0;
        int skippedCount = 0;
        for (OrderItem item : items) {
            if (item.getVariantId() == null) {
                skippedCount++;
                continue;
            }
            try {
                cartDAO.addItem(cartId, item.getVariantId(), item.getQuantity());
                addedCount++;
            } catch (Exception ex) {
                skippedCount++;
            }
        }

        ReorderResultDTO result = new ReorderResultDTO();
        result.setAddedCount(addedCount);
        result.setSkippedCount(skippedCount);
        return result;
    }

    public void autoCancelUnacceptedOrders() throws SQLException {
        String sql = "SELECT * FROM orders WHERE status = 'CONFIRMED' AND shop_acceptance_deadline IS NOT NULL AND shop_acceptance_deadline < GETDATE()";
        try (Connection conn = orderDAO.openConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    int orderId = rs.getInt("order_id");
                    int customerId = rs.getInt("customer_id");
                    int ownerId = rs.getInt("owner_id");
                    String paymentMethod = rs.getString("payment_method");

                    boolean cancelled = cancelOrderBySystem(orderId, "Quá 30 phút cửa hàng không nhận đơn. Hệ thống tự động hủy.");

                    if (cancelled && AppConfig.PAYMENT_CK.equals(paymentMethod)) {
                        orderDAO.updateRefundStatus(orderId, "REFUNDED");
                        var txList = paymentDAO.findByOrder(orderId);
                        if (!txList.isEmpty()) {
                            paymentDAO.updateStatus(txList.get(0).getTransactionId(),
                                    "refunded", "SYSTEM_TIMEOUT_REFUND", "Cửa hàng không nhận đơn");
                        }
                    }

                    try {
                        notificationService.send(customerId, "ORDER_UPDATE", "Đơn hàng tự động hủy",
                                "Rất tiếc, cửa hàng đã không nhận chuẩn bị đơn hàng #" + orderId + " của bạn trong vòng 30 phút. "
                                        + (AppConfig.PAYMENT_CK.equals(paymentMethod)
                                        ? "Tiền đã được hoàn trả tự động vào tài khoản của bạn. " : "")
                                        + "Vui lòng đặt lại đơn hàng khác.",
                                "/profile/order-detail?orderId=" + orderId);
                    } catch (Exception e) {
                        LoggerUtil.warn(log, "Failed to notify customer of auto cancellation for orderId=" + orderId, e);
                    }

                    try {
                        notificationService.send(ownerId, "ORDER_UPDATE", "Hủy đơn hàng do quá hạn nhận",
                                "Đơn hàng #" + orderId + " đã bị hệ thống tự động hủy và hoàn tiền vì bạn không bấm nhận đơn trong vòng 30 phút.",
                                "/shop/orders");
                    } catch (Exception e) {
                        LoggerUtil.warn(log, "Failed to notify shop owner of auto cancellation for orderId=" + orderId, e);
                    }
                }
            }
        }
    }

    public BigDecimal getRevenueByOwner(int ownerId) throws SQLException {
        return orderDAO.getRevenueByOwner(ownerId);
    }

    public BigDecimal getEstimatedRevenueByOwner(int ownerId) throws SQLException {
        return orderDAO.getEstimatedRevenueByOwner(ownerId);
    }

    public int getOrderCountByOwner(int ownerId) throws SQLException {
        return orderDAO.countByOwner(ownerId, null);
    }

    public List<Order> getRecentOrdersByOwner(int ownerId, int limit) throws SQLException {
        return orderDAO.findByOwner(ownerId, null, 1, limit);
    }

    public List<OrderItem> getOrderItems(int orderId) throws SQLException {
        return orderDAO.findItemsByOrderId(orderId);
    }

    public int cancelOpenOrdersByOwner(int ownerId, String reason) throws SQLException {
        if (ownerId <= 0) {
            throw new IllegalArgumentException("Owner ID không hợp lệ.");
        }
        int cancelledCount = 0;
        List<Order> orders = orderDAO.findOpenByOwner(ownerId);
        for (Order order : orders) {
            if (isSystemCancelableOrder(order)) {
                if (cancelOrderBySystem(order.getOrderId(), reason)) {
                    cancelledCount++;
                }
            }
        }
        return cancelledCount;
    }

    /**
     * INV-01 — Returns orders in PENDING_PAYMENT whose created_at is older than
     * {@code minutes} minutes. Called by AutoCancelUnpaidListener.
     */
    public List<Order> findExpiredPendingPaymentOrders(int minutes) throws SQLException {
        return orderDAO.findExpiredPendingPayment(minutes);
    }

    /**
     * INV-01 — System-initiated cancel that bypasses ownership checks.
     * Only used by trusted background jobs (AutoCancelUnpaidListener).
     * Marks the order CANCELLED and restores reserved stock through the same path as manual cancel.
     */
    public boolean cancelOrderBySystem(int orderId, String reason) throws SQLException {
        Order order = getOrderDetail(orderId);
        if (order == null) {
            LoggerUtil.warn(log, "cancelOrderBySystem: orderId=%d not found, skipping.", orderId);
            return false;
        }
        if (!isSystemCancelableOrder(order)) {
            return false;
        }
        return cancelOrderAndRestoreStock(order, 1, reason, true);
    }

    private boolean cancelOrderAndRestoreStock(Order currentOrder, int cancelledBy, String reason, boolean skipMissingOrTerminal)
            throws SQLException {
        if (currentOrder == null) {
            if (skipMissingOrTerminal) {
                return false;
            }
            throw new IllegalArgumentException("Đơn hàng không tồn tại!");
        }

        int orderId = currentOrder.getOrderId();
        try (Connection conn = orderDAO.openConnection()) {
            conn.setAutoCommit(false);
            try {
                if (AppConfig.ORDER_CANCELLED.equals(currentOrder.getStatus())
                        || AppConfig.ORDER_DELIVERED.equals(currentOrder.getStatus())) {
                    conn.rollback();
                    if (skipMissingOrTerminal) {
                        return false;
                    }
                    throw new RuntimeException("Đơn hàng đã giao hoặc đã hủy, không thể hủy thêm!");
                }

                orderDAO.cancel(conn, orderId, cancelledBy, reason);
                List<OrderItem> items = orderDAO.findItemsByOrderId(conn, orderId);
                for (OrderItem item : items) {
                    if (item.getVariantId() != null) {
                        inventoryService.restore(conn, item.getVariantId(), item.getQuantity(), orderId, cancelledBy);
                    }
                }
                if (AppConfig.ORDER_PENDING_PAYMENT.equals(currentOrder.getStatus())) {
                    PaymentTransaction paymentTx = paymentDAO.findOneByOrder(conn, orderId);
                    if (paymentTx != null) {
                        paymentDAO.updateStatus(conn, paymentTx.getTransactionId(), "expired", null, null);
                    }
                }
                conn.commit();
                return true;
            } catch (SQLException | RuntimeException ex) {
                conn.rollback();
                throw ex;
            }
        }
    }

    private boolean isSystemCancelableOrder(Order order) {
        if (order == null) {
            return false;
        }
        String status = order.getStatus();
        if (AppConfig.ORDER_CANCELLED.equals(status)
                || AppConfig.ORDER_DELIVERED.equals(status)
                || AppConfig.ORDER_DISPATCHED.equals(status)) {
            return false;
        }
        if (AppConfig.ORDER_PENDING_PAYMENT.equals(status)) {
            return true;
        }
        if (AppConfig.PAYMENT_CK.equalsIgnoreCase(order.getPaymentMethod())) {
            return AppConfig.ORDER_CONFIRMED.equals(status);
        }
        if (!AppConfig.PAYMENT_COD.equalsIgnoreCase(order.getPaymentMethod())) {
            return false;
        }
        return AppConfig.ORDER_CONFIRMED.equals(status)
                || AppConfig.ORDER_APPROVED.equals(status)
                || "PREPARING".equals(status);
    }

    /**
     * SEC-01 — COD eligibility check.
     * Returns false if the customer has more than 3 FAILED deliveries in the last 30 days.
     * A FAILED delivery is recorded when the shipper marks the delivery as FAILED.
     *
     * CONTRACT: exact signature required by downstream callers.
     */
    public boolean isCodEligible(int customerId) throws SQLException {
        int failedCount = orderDAO.countRecentFailedDeliveries(customerId, 30);
        return failedCount <= 3;
    }
}
