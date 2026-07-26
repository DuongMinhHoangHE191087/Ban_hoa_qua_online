package service.order;

import config.AppConfig;
import dao.order.DeliveryDAO;
import dao.order.DeliveryTripDAO;
import dao.order.OrderDAO;
import dao.shop.PaymentDAO;
import exception.BusinessException;
import model.entity.order.Delivery;
import model.entity.order.Order;
import model.entity.auth.User;
import dao.auth.UserDAO;
import service.chat.NotificationService;
import service.system.EmailService;
import service.catalog.InventoryService;
import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import java.util.logging.Logger;
import util.LoggerUtil;

/**
 * DeliveryService — Tầng business logic cho nghiệp vụ tương ứng.
 *
 * QUY TẮC:
 *   - Chỉ gọi DAO, không viết SQL ở đây
 *   - Chứa tất cả validation và business rule
 *   - Ném RuntimeException hoặc custom exception cho Servlet xử lý
 *   - Không tương tác trực tiếp với HttpRequest/Response
 *
 * @author fruitmkt-team
 */
public class DeliveryService {

    private static final Logger log = LoggerUtil.getLogger(DeliveryService.class);

    // DLV-04 — allowed forward transitions for the delivery state-machine.
    // Any state may transition to FAILED (shipper reports delivery failure).
    // Reversals and illegal jumps are rejected with a BusinessException.
    private enum DeliveryStatus { ASSIGNED, PICKED_UP, IN_TRANSIT, DELIVERED, FAILED }

    private static final Map<DeliveryStatus, Set<DeliveryStatus>> ALLOWED_TRANSITIONS;
    static {
        ALLOWED_TRANSITIONS = new EnumMap<>(DeliveryStatus.class);
        ALLOWED_TRANSITIONS.put(DeliveryStatus.ASSIGNED,   EnumSet.of(DeliveryStatus.PICKED_UP, DeliveryStatus.FAILED));
        ALLOWED_TRANSITIONS.put(DeliveryStatus.PICKED_UP,  EnumSet.of(DeliveryStatus.IN_TRANSIT, DeliveryStatus.FAILED));
        ALLOWED_TRANSITIONS.put(DeliveryStatus.IN_TRANSIT, EnumSet.of(DeliveryStatus.DELIVERED, DeliveryStatus.FAILED));
        ALLOWED_TRANSITIONS.put(DeliveryStatus.DELIVERED,  EnumSet.noneOf(DeliveryStatus.class));
        ALLOWED_TRANSITIONS.put(DeliveryStatus.FAILED,     EnumSet.noneOf(DeliveryStatus.class));
    }

    private final DeliveryDAO deliveryDAO = new DeliveryDAO();
    private final DeliveryTripDAO deliveryTripDAO = new DeliveryTripDAO();
    private final OrderDAO orderDAO = new OrderDAO();
    private final PaymentDAO paymentDAO = new PaymentDAO();
    private final UserDAO userDAO = new UserDAO();
    private final NotificationService notificationService = new NotificationService();
    private final EmailService emailService = new EmailService();

    public List<Delivery> getDeliveriesForStaff(int staffId) throws SQLException {
        return deliveryDAO.findByStaffId(staffId);
    }

    public void validateEstimatedTime(LocalDateTime estimatedTime) {
        if (estimatedTime == null) {
            return;
        }
        LocalDateTime minAllowed = LocalDateTime.now().withSecond(0).withNano(0);
        if (estimatedTime.isBefore(minAllowed)) {
            throw new IllegalArgumentException("Thời gian giao hàng dự kiến không được ở quá khứ.");
        }
    }

    public boolean updateStatusAndProof(int staffId, int deliveryId, String status, String failureReason, String proofImageUrl) throws SQLException {
        Delivery del = deliveryDAO.findById(deliveryId);
        if (del == null) {
            throw new IllegalArgumentException("Không tìm thấy thông tin giao hàng.");
        }
        if (del.getStaffId() == null || !del.getStaffId().equals(staffId)) {
            throw new IllegalArgumentException("Bạn không có quyền cập nhật trạng thái đơn giao hàng này.");
        }

        if (status == null || status.trim().isEmpty()) {
            throw new IllegalArgumentException("Trạng thái là bắt buộc.");
        }

        // DLV-04 — enforce sequential delivery state-machine
        DeliveryStatus current;
        DeliveryStatus next;
        try {
            current = DeliveryStatus.valueOf(del.getStatus());
            next    = DeliveryStatus.valueOf(status);
        } catch (IllegalArgumentException e) {
            throw new BusinessException("INVALID_STATUS",
                    "Trạng thái giao hàng không hợp lệ: " + status);
        }
        Set<DeliveryStatus> allowed = ALLOWED_TRANSITIONS.getOrDefault(current, EnumSet.noneOf(DeliveryStatus.class));
        if (!allowed.contains(next)) {
            throw new BusinessException("INVALID_TRANSITION",
                    String.format("Không thể chuyển trạng thái từ %s sang %s.", current, next));
        }

        // Proof / reason validation for terminal states
        if (next == DeliveryStatus.DELIVERED && (proofImageUrl == null || proofImageUrl.trim().isEmpty())) {
            throw new IllegalArgumentException("Vui lòng cung cấp ảnh bằng chứng giao hàng!");
        }
        if (next == DeliveryStatus.FAILED && (failureReason == null || failureReason.trim().isEmpty())) {
            throw new IllegalArgumentException("Vui lòng nhập lý do giao hàng thất bại!");
        }

        try (Connection conn = orderDAO.openConnection()) {
            conn.setAutoCommit(false);
            try {
                // 1. Update delivery status
                deliveryDAO.updateStatusAndProof(conn, deliveryId, status, failureReason, proofImageUrl);

                if (next == DeliveryStatus.FAILED) {
                    Order order = orderDAO.findOneById(conn, del.getOrderId());
                    if (order != null) {
                        // 2. Cancel order
                        String cancelReason = "Giao hàng thất bại: " + failureReason;
                        orderDAO.cancel(conn, order.getOrderId(), staffId, cancelReason);

                        // 3. Restock inventory
                        List<model.entity.order.OrderItem> items = orderDAO.findItemsByOrderId(conn, order.getOrderId());
                        InventoryService inventoryService = new InventoryService();
                        for (model.entity.order.OrderItem item : items) {
                            if (item.getVariantId() != null) {
                                inventoryService.restore(conn, item.getVariantId(), item.getQuantity(), order.getOrderId(), staffId);
                            }
                        }

                        conn.commit();

                        // 4. Send notifications
                        try {
                            User customer = userDAO.findUserById(order.getCustomerId());
                            if (customer != null) {
                                String customerMsg = "Đơn hàng #" + order.getOrderId() + " giao hàng thất bại. Lý do: " + failureReason;
                                notificationService.send(customer.getUserId(), AppConfig.NOTIF_ORDER_UPDATE, "Giao hàng thất bại", customerMsg, "/orders/detail?orderId=" + order.getOrderId());
                            }
                        } catch (Exception ex) {
                            LoggerUtil.warn(log, "Failed to send failure notification to customer for orderId=" + order.getOrderId(), ex);
                        }

                        try {
                            if (order.getOwnerIdObject() != null) {
                                String ownerMsg = "Đơn hàng #" + order.getOrderId() + " giao hàng thất bại và đã được hoàn lại kho. Lý do: " + failureReason;
                                notificationService.send(order.getOwnerIdObject(), AppConfig.NOTIF_ORDER_UPDATE, "Giao hàng thất bại", ownerMsg, "/shop/orders");
                            }
                        } catch (Exception ex) {
                            LoggerUtil.warn(log, "Failed to send failure notification to owner for orderId=" + order.getOrderId(), ex);
                        }
                    } else {
                        conn.commit();
                    }
                } else {
                    conn.commit();
                }
            } catch (SQLException | RuntimeException ex) {
                conn.rollback();
                throw ex;
            } finally {
                conn.setAutoCommit(true);
            }
        }
        return true;
    }

    public void updateEstimatedTime(int staffId, int deliveryId, LocalDateTime estimatedTime) throws SQLException {
        Delivery del = deliveryDAO.findById(deliveryId);
        if (del == null) {
            throw new IllegalArgumentException("Không tìm thấy thông tin giao hàng.");
        }
        // B1 Fix: use Objects.equals() to avoid Integer auto-unbox NPE
        if (del.getStaffId() == null || !del.getStaffId().equals(staffId)) {
            throw new IllegalArgumentException("Bạn không có quyền cập nhật thời gian dự kiến cho đơn giao hàng này.");
        }
        if ("DELIVERED".equals(del.getStatus()) || "FAILED".equals(del.getStatus())) {
            throw new IllegalArgumentException("Không thể cập nhật thời gian dự kiến cho đơn hàng đã hoàn tất hoặc thất bại.");
        }
        validateEstimatedTime(estimatedTime);
        deliveryDAO.updateEstimatedTime(deliveryId, estimatedTime);
    }

    public void assignShipper(int orderId, int staffId, LocalDateTime estimatedTime) throws SQLException {
        validateEstimatedTime(estimatedTime);
        List<Order> orders = orderDAO.findById(orderId);
        Order order = orders.isEmpty() ? null : orders.get(0);
        if (order == null) {
            throw new IllegalArgumentException("Không tìm thấy đơn hàng để tạo chuyến giao.");
        }
        int parentOrderId = order.getParentOrderId() != null ? order.getParentOrderId() : order.getOrderId();
        String tripStatus = staffId > 0 ? AppConfig.DELIVERY_TRIP_ASSIGNED : AppConfig.DELIVERY_TRIP_PLANNED;
        try (Connection conn = orderDAO.openConnection()) {
            conn.setAutoCommit(false);
            try {
                int tripId = deliveryTripDAO.save(conn, parentOrderId, staffId > 0 ? staffId : null,
                        tripStatus, null, estimatedTime);
                deliveryDAO.assignShipper(conn, orderId, tripId, 1, staffId, estimatedTime);
                // Cập nhật trạng thái đơn sang DISPATCHED sau khi chỉ định shipper thành công
                orderDAO.updateStatus(conn, orderId, AppConfig.ORDER_DISPATCHED);
                conn.commit();
            } catch (SQLException | RuntimeException ex) {
                conn.rollback();
                throw ex;
            }
        }
    }

    public void assignShipper(Connection conn, int orderId, int staffId, LocalDateTime estimatedTime) throws SQLException {
        validateEstimatedTime(estimatedTime);
        // CRITICAL FIX: Do NOT call orderDAO.findById() here — it opens a NEW connection
        // which deadlocks against the active transaction held by `conn`.
        // Instead, derive parentOrderId directly using the same connection.
        int parentOrderId = getParentOrderId(conn, orderId);
        String tripStatus = staffId > 0 ? AppConfig.DELIVERY_TRIP_ASSIGNED : AppConfig.DELIVERY_TRIP_PLANNED;
        int tripId = deliveryTripDAO.save(conn, parentOrderId, staffId > 0 ? staffId : null,
                tripStatus, null, estimatedTime);
        deliveryDAO.assignShipper(conn, orderId, tripId, 1, staffId, estimatedTime);
    }

    /**
     * Lấy parent_order_id của một đơn hàng dùng Connection đã có sẵn (tránh deadlock).
     * Nếu không có parent thì trả về chính orderId.
     */
    private int getParentOrderId(Connection conn, int orderId) throws SQLException {
        String sql = "SELECT ISNULL(parent_order_id, order_id) AS parent_id FROM orders WHERE order_id = ?";
        try (java.sql.PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, orderId);
            try (java.sql.ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return rs.getInt("parent_id");
            }
        }
        return orderId; // fallback
    }


    public Delivery getDeliveryByOrderId(int orderId) throws SQLException {
        return deliveryDAO.findByOrderId(orderId);
    }

    /**
     * Delivery staff xác nhận giao hàng thành công.
     * Cập nhật cả bảng deliveries và orders (DISPATCHED -> DELIVERED).
     * COD: Ghi nhận payment_transaction completed.
     * Cascade: Nếu toàn bộ đơn con của đơn cha đã DELIVERED thì update đơn cha.
     */
    public void markAsDelivered(int staffId, int deliveryId, String proofImageUrl) throws SQLException {
        Delivery del = deliveryDAO.findById(deliveryId);
        if (del == null) {
            throw new IllegalArgumentException("Không tìm thấy thông tin giao hàng.");
        }
        if (del.getStaffId() == null || !del.getStaffId().equals(staffId)) {
            throw new IllegalArgumentException("Bạn không có quyền xác nhận đơn giao hàng này.");
        }
        if (proofImageUrl == null || proofImageUrl.trim().isEmpty()) {
            throw new IllegalArgumentException("Vui lòng cung cấp ảnh bằng chứng giao hàng!");
        }

        try (Connection conn = orderDAO.openConnection()) {
            conn.setAutoCommit(false);
            try {
                // 1. Update deliveries table
                deliveryDAO.updateStatusAndProof(conn, deliveryId, "DELIVERED", null, proofImageUrl);

                // 2. Update child order -> DELIVERED
                orderDAO.updateStatus(conn, del.getOrderId(), "DELIVERED");

                // 3. Load order to know payment method and parent
                Order order = orderDAO.findOneById(conn, del.getOrderId());

                if (order != null) {
                    // 4. COD — tạo payment_transaction completed khi shipper thu tiền mặt
                    if ("COD".equalsIgnoreCase(order.getPaymentMethod())) {
                        BigDecimal amount = order.getFinalAmount();
                        String note = "Shipper xác nhận thu tiền COD đơn #" + order.getOrderId();
                        paymentDAO.initCodTransaction(conn, order.getOrderId(), amount, note);
                        LoggerUtil.info(log, "[COD] Ghi nhận payment_transaction completed cho orderId=%d amount=%s",
                                order.getOrderId(), amount);
                    }

                    // 5. Cascade: nếu đây là đơn CHILD, kiểm tra xem tất cả đơn anh em đã DELIVERED chưa
                    Integer parentOrderId = orderDAO.getParentOrderIdByChildId(conn, order.getOrderId());
                    if (parentOrderId != null) {
                        int remaining = orderDAO.countNonDeliveredChildOrders(conn, parentOrderId);
                        if (remaining == 0) {
                            // Tất cả đơn con đã giao thành công -> update đơn cha
                            orderDAO.updateStatus(conn, parentOrderId, "DELIVERED");
                            LoggerUtil.info(log, "[Delivery] Cascade DELIVERED lên đơn cha parentOrderId=%d", parentOrderId);
                        }
                    }
                }

                conn.commit();

                // 6. Gửi thông báo async (ngoài transaction)
                if (order != null) {
                    final Order finalOrder = order;
                    try {
                        User customer = userDAO.findUserById(finalOrder.getCustomerId());
                        if (customer != null) {
                            String customerMsg = "Đơn hàng #" + finalOrder.getOrderId() + " đã giao hàng thành công bởi người vận chuyển. Vui lòng xác nhận nhận hàng.";
                            notificationService.send(customer.getUserId(), AppConfig.NOTIF_ORDER_UPDATE, "Giao hàng thành công", customerMsg, "/orders/detail?orderId=" + finalOrder.getOrderId());
                            String orderDetailUrl = AppConfig.APP_BASE_URL + "/orders/detail?orderId=" + finalOrder.getOrderId();
                            emailService.sendOrderNotificationEmail(customer.getEmail(), customer.getFullName(), String.valueOf(finalOrder.getOrderId()), "Giao hàng thành công", orderDetailUrl);
                        }
                    } catch (Exception ex) {
                        LoggerUtil.warn(log, "Không gửi được thông báo giao hàng thành công cho orderId=" + finalOrder.getOrderId(), ex);
                    }
                }

            } catch (SQLException | RuntimeException ex) {
                conn.rollback();
                throw ex;
            } finally {
                conn.setAutoCommit(true);
            }
        }
    }

    /**
     * Lấy danh sách đơn giao hàng gộp gồm: đơn đã nhận của staff + đơn chưa được gán.
     */
    public List<Delivery> getDashboardDeliveries(int staffId) throws SQLException {
        List<Delivery> assigned = deliveryDAO.findByStaffId(staffId);
        List<Delivery> unassigned = deliveryDAO.findUnassigned();
        
        List<Delivery> merged = new ArrayList<>(unassigned);
        merged.addAll(assigned);
        
        // Sắp xếp theo created_at giảm dần (tin mới nhất lên đầu)
        merged.sort((d1, d2) -> {
            LocalDateTime t1 = d1.getCreatedAt();
            LocalDateTime t2 = d2.getCreatedAt();
            if (t1 == null && t2 == null) return 0;
            if (t1 == null) return 1;
            if (t2 == null) return -1;
            return t2.compareTo(t1);
        });
        return merged;
    }

    /**
     * Shipper tự nhận đơn hàng chưa có người giao.
     */
    public void claimDelivery(int staffId, int deliveryId) throws SQLException {
        Delivery del = deliveryDAO.findById(deliveryId);
        if (del == null) {
            throw new IllegalArgumentException("Không tìm thấy thông tin giao hàng.");
        }
        if (del.getStaffId() != null) {
            throw new IllegalArgumentException("Đơn hàng này đã được tài xế khác nhận trước đó!");
        }
        if (!"ASSIGNED".equals(del.getStatus())) {
            throw new IllegalArgumentException("Trạng thái đơn hàng không khả dụng để nhận.");
        }

        try (Connection conn = orderDAO.openConnection()) {
            conn.setAutoCommit(false);
            try {
                boolean claimed = deliveryDAO.claimDelivery(conn, deliveryId, staffId);
                if (!claimed) {
                    throw new IllegalArgumentException("Đơn hàng này đã được tài xế khác nhận trước đó!");
                }
                if (del.getDeliveryTripId() != null) {
                    deliveryTripDAO.assignShipper(conn, del.getDeliveryTripId(), staffId);
                }
                conn.commit();
            } catch (SQLException | RuntimeException ex) {
                conn.rollback();
                throw ex;
            } finally {
                conn.setAutoCommit(true);
            }
        }
    }
}
