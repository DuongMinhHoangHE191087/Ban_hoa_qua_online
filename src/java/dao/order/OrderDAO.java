package dao.order;

import dao.system.BaseDAO;
import model.entity.order.Order;
import model.entity.order.OrderItem;
import util.PaginationHelper;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * OrderDAO — DAO cho entity Order.
 *
 * QUY TẮC:
 *   - Chỉ chứa SQL, không chứa business logic
 *   - Dùng PreparedStatement, KHÔNG nối chuỗi SQL
 *   - Mỗi method ném SQLException để Service xử lý
 *   - Dùng try-with-resources cho Connection + PreparedStatement
 *
 * @author fruitmkt-team
 */
public class OrderDAO extends BaseDAO {

    @FunctionalInterface
    private interface SqlAction<T> {
        T run() throws SQLException;
    }

    private <T> T executeWithTransientRetry(SqlAction<T> action) throws SQLException {
        SQLException last = null;
        for (int attempt = 1; attempt <= 2; attempt++) {
            try {
                return action.run();
            } catch (SQLException e) {
                last = e;
                String sqlState = e.getSQLState();
                boolean transientConnectionError = sqlState != null && sqlState.startsWith("08");
                if (attempt == 1 && transientConnectionError) {
                    continue;
                }
                throw e;
            }
        }
        throw last;
    }

    /**
     * Tìm đơn hàng theo ID.
     */
    public List<Order> findById(int id) throws SQLException {
        List<Order> list = new ArrayList<>();
        String sql = "SELECT * FROM orders WHERE order_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    /**
     * Tìm đơn hàng theo ID và trả về 1 object duy nhất.
     */
    public Order findOneById(int id) throws SQLException {
        try (Connection conn = getConnection()) {
            return findOneById(conn, id);
        }
    }

    /**
     * Tìm đơn hàng theo ID trên connection hiện tại.
     */
    public Order findOneById(Connection conn, int id) throws SQLException {
        String sql = "SELECT * FROM orders WHERE order_id = ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return mapRow(rs);
                }
            }
        }
        return null;
    }

        /**
     * Tìm tất cả đơn hàng (bao gồm cả Parent và Child) của khách hàng.
     */
    public List<Order> findByCustomerId(int customerId) throws SQLException {
        List<Order> list = new ArrayList<>();
        String sql = "SELECT * FROM orders WHERE customer_id = ? ORDER BY order_id DESC";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, customerId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }


    /**
     * Tìm đơn hàng theo ID và trả về 1 object duy nhất.
     */

    /**
     * Tìm đơn hàng theo ID khách hàng có phân trang.
     */
    public List<Order> findByCustomer(int customerId, int page, int pageSize) throws SQLException {
        return findByCustomer(customerId, null, page, pageSize);
    }

    /**
     * Tìm đơn hàng theo ID khách hàng, lọc theo trạng thái có phân trang.
     */
    public List<Order> findByCustomer(int customerId, String status, int page, int pageSize) throws SQLException {
        List<Order> list = new ArrayList<>();

        StringBuilder sql = new StringBuilder("SELECT * FROM orders WHERE customer_id = ? AND parent_order_id IS NULL ");
        List<Object> params = new ArrayList<>();
        params.add(customerId);

        if (status != null && !status.trim().isEmpty()) {
            sql.append("AND status = ? ");
            params.add(status);
        }

        sql.append("ORDER BY order_id DESC").append(PaginationHelper.OFFSET_FETCH_SQL);

        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int paramIndex = 1;
            for (Object param : params) {
                ps.setObject(paramIndex++, param);
            }
            PaginationHelper.bindOffsetFetch(ps, paramIndex, page, pageSize);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }


    /**
     * Tìm đơn hàng thuộc về chủ shop theo trạng thái có phân trang.
     */
    public List<Order> findByOwner(int ownerId, String status, int page, int pageSize) throws SQLException {
        return executeWithTransientRetry(() -> findByOwnerInternal(ownerId, status, page, pageSize));
    }

    private List<Order> findByOwnerInternal(int ownerId, String status, int page, int pageSize) throws SQLException {
        List<Order> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder("SELECT * FROM orders WHERE owner_id = ? ");
        List<Object> params = new ArrayList<>();
        params.add(ownerId);
        if (status != null && !status.trim().isEmpty()) {
            sql.append("AND status = ? ");
            params.add(status);
        }
        sql.append("ORDER BY order_id DESC").append(PaginationHelper.OFFSET_FETCH_SQL);
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int paramIndex = 1;
            for (Object param : params) {
                ps.setObject(paramIndex++, param);
            }
            PaginationHelper.bindOffsetFetch(ps, paramIndex, page, pageSize);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    /** Lấy toàn bộ đơn hàng của shop còn đang mở để phục vụ cascade khi shop bị đình chỉ. */
    public List<Order> findOpenByOwner(int ownerId) throws SQLException {
        List<Order> list = new ArrayList<>();
        String sql = "SELECT * FROM orders WHERE owner_id = ? "
                + "AND status NOT IN ('CANCELLED', 'DELIVERED') "
                + "ORDER BY order_id DESC";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, ownerId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    public int countAll(String status) throws SQLException {
        StringBuilder sql = new StringBuilder("SELECT COUNT(*) FROM orders WHERE parent_order_id IS NULL ");
        List<Object> params = new ArrayList<>();
        if (status != null && !status.trim().isEmpty()) {
            sql.append("AND status = ? ");
            params.add(status);
        }
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) { return rs.getInt(1); }
            }
        }
        return 0;
    }

    /**
     * Lấy toàn bộ danh sách đơn hàng có phân trang, có thể lọc theo trạng thái.
     */
    public List<Order> findAll(String status, int page, int pageSize) throws SQLException {
        List<Order> list = new ArrayList<>();
        int offset = (page - 1) * pageSize;
        StringBuilder sql = new StringBuilder("SELECT * FROM orders WHERE parent_order_id IS NULL ");
        List<Object> params = new ArrayList<>();
        if (status != null && !status.trim().isEmpty()) {
            sql.append("AND status = ? ");
            params.add(status);
        }
        sql.append("ORDER BY order_id DESC OFFSET ? ROWS FETCH NEXT ? ROWS ONLY");
        params.add(offset);
        params.add(pageSize);
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    public int countAll(String status, String paymentMethod, String paymentStatus) throws SQLException {
        StringBuilder sql = new StringBuilder("SELECT COUNT(*) FROM orders o ");
        sql.append("LEFT JOIN payment_transactions pt ON o.order_id = pt.order_id ");
        sql.append("WHERE o.parent_order_id IS NULL ");
        List<Object> params = new ArrayList<>();
        
        if (status != null && !status.trim().isEmpty()) {
            sql.append("AND o.status = ? ");
            params.add(status);
        }
        if (paymentMethod != null && !paymentMethod.trim().isEmpty()) {
            sql.append("AND o.payment_method = ? ");
            params.add(paymentMethod);
        }
        if (paymentStatus != null && !paymentStatus.trim().isEmpty()) {
            sql.append("AND pt.status = ? ");
            params.add(paymentStatus);
        }
        
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) { return rs.getInt(1); }
            }
        }
        return 0;
    }

    public List<Order> findAll(String status, String paymentMethod, String paymentStatus, int page, int pageSize) throws SQLException {
        List<Order> list = new ArrayList<>();
        int offset = (page - 1) * pageSize;
        if (offset < 0) offset = 0;
        
        StringBuilder sql = new StringBuilder("SELECT o.*, pt.status AS payment_status FROM orders o ");
        sql.append("LEFT JOIN payment_transactions pt ON o.order_id = pt.order_id ");
        
        sql.append("WHERE o.parent_order_id IS NULL ");
        List<Object> params = new ArrayList<>();
        
        if (status != null && !status.trim().isEmpty()) {
            sql.append("AND o.status = ? ");
            params.add(status);
        }
        if (paymentMethod != null && !paymentMethod.trim().isEmpty()) {
            sql.append("AND o.payment_method = ? ");
            params.add(paymentMethod);
        }
        if (paymentStatus != null && !paymentStatus.trim().isEmpty()) {
            sql.append("AND pt.status = ? ");
            params.add(paymentStatus);
        }
        
        sql.append("ORDER BY o.order_id DESC OFFSET ? ROWS FETCH NEXT ? ROWS ONLY");
        params.add(offset);
        params.add(pageSize);
        
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    /**
     * Lưu đơn hàng mới trong một giao dịch cho sẵn (bản dùng thực tế của checkout).
     * Bản {@code save(Order)} tự mở connection đã bị loại bỏ vì không nơi nào dùng và
     * thiếu cột recipient_name/recipient_phone/shop_acceptance_deadline.
     */
    public int save(Connection conn, Order order) throws SQLException {
        String sql = "INSERT INTO orders (customer_id, owner_id, parent_order_id, order_type, delivery_address, "
                + "recipient_name, recipient_phone, delivery_time_slot, notes, cancelled_at, cancelled_by, "
                + "cancellation_reason, status, total_amount, delivery_fee, discount_amount, system_discount_amount, "
                + "shop_discount_amount, platform_fee, final_amount, payment_method, refund_status, "
                + "shop_acceptance_deadline, created_at, updated_at) "
                + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, GETDATE(), GETDATE())";
        try (PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, order.getCustomerId());
            if (order.getOwnerIdObject() != null && order.getOwnerIdObject() > 0) {
                ps.setInt(2, order.getOwnerIdObject());
            } else {
                ps.setNull(2, Types.INTEGER);
            }
            if (order.getParentOrderId() != null && order.getParentOrderId() > 0) {
                ps.setInt(3, order.getParentOrderId());
            } else {
                ps.setNull(3, Types.INTEGER);
            }
            ps.setString(4, order.getOrderType() != null ? order.getOrderType() : "CHILD");
            ps.setString(5, order.getDeliveryAddress());
            ps.setString(6, order.getRecipientName());
            ps.setString(7, order.getRecipientPhone());
            ps.setString(8, order.getDeliveryTimeSlot());
            ps.setString(9, order.getNotes());
            if (order.getCancelledAt() != null) {
                ps.setTimestamp(10, Timestamp.valueOf(order.getCancelledAt()));
            } else {
                ps.setNull(10, Types.TIMESTAMP);
            }
            if (order.getCancelledBy() != null) {
                ps.setInt(11, order.getCancelledBy());
            } else {
                ps.setNull(11, Types.INTEGER);
            }
            ps.setString(12, order.getCancellationReason());
            String status = order.getStatus() != null ? order.getStatus() : "PENDING_PAYMENT";
            ps.setString(13, status);
            ps.setBigDecimal(14, order.getTotalAmount() != null ? order.getTotalAmount() : java.math.BigDecimal.ZERO);
            ps.setBigDecimal(15, order.getDeliveryFee() != null ? order.getDeliveryFee() : java.math.BigDecimal.ZERO);
            ps.setBigDecimal(16, order.getDiscountAmount() != null ? order.getDiscountAmount() : java.math.BigDecimal.ZERO);
            ps.setBigDecimal(17, order.getSystemDiscountAmount() != null ? order.getSystemDiscountAmount() : java.math.BigDecimal.ZERO);
            ps.setBigDecimal(18, order.getShopDiscountAmount() != null ? order.getShopDiscountAmount() : java.math.BigDecimal.ZERO);
            ps.setBigDecimal(19, order.getPlatformFee() != null ? order.getPlatformFee() : java.math.BigDecimal.ZERO);
            ps.setBigDecimal(20, order.getFinalAmount() != null ? order.getFinalAmount() : java.math.BigDecimal.ZERO);
            ps.setString(21, order.getPaymentMethod() != null ? order.getPaymentMethod() : "COD");
            ps.setString(22, order.getRefundStatus() != null ? order.getRefundStatus() : "NONE");
            if ("CONFIRMED".equals(status)) {
                ps.setTimestamp(23, Timestamp.valueOf(java.time.LocalDateTime.now().plusMinutes(30)));
            } else {
                ps.setNull(23, Types.TIMESTAMP);
            }
            ps.executeUpdate();
            try (ResultSet rs = ps.getGeneratedKeys()) {
                if (rs.next()) {
                    return rs.getInt(1);
                }
            }
        }
        throw new SQLException("Luu don hang that bai, khong lay duoc ma khoa tu tang.");
    }

    public void updateStatus(int orderId, String status) throws SQLException {
        try (Connection conn = getConnection()) {
            updateStatus(conn, orderId, status);
        }
    }

    public void updateStatus(Connection conn, int orderId, String status) throws SQLException {
        String normalizedStatus = status != null ? status.trim() : null;
        String sql;
        if ("CONFIRMED".equalsIgnoreCase(normalizedStatus)) {
            sql = "UPDATE orders SET status = ?, shop_acceptance_deadline = DATEADD(minute, 30, GETDATE()), updated_at = GETDATE() "
                + "WHERE order_id = ? AND status = 'PENDING_PAYMENT'";
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setString(1, normalizedStatus);
                ps.setInt(2, orderId);
                ps.executeUpdate();
            }
            return;
        }
        if ("APPROVED".equalsIgnoreCase(normalizedStatus)) {
            sql = "UPDATE orders SET status = ?, shop_accepted_at = GETDATE(), shop_acceptance_deadline = NULL, updated_at = GETDATE() "
                + "WHERE order_id = ? AND status = 'CONFIRMED'";
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setString(1, normalizedStatus);
                ps.setInt(2, orderId);
                ps.executeUpdate();
            }
            return;
        }

        sql = "UPDATE orders SET status = ?, updated_at = GETDATE() WHERE order_id = ? AND status <> ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, normalizedStatus);
            ps.setInt(2, orderId);
            ps.setString(3, normalizedStatus);
            ps.executeUpdate();
        }
    }


    public void updateRefundStatus(int orderId, String refundStatus) throws SQLException {
        String sql = "UPDATE orders SET refund_status = ?, updated_at = GETDATE() WHERE order_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, refundStatus);
            ps.setInt(2, orderId);
            ps.executeUpdate();
        }
    }


    /**
     * Hủy đơn hàng.
     */
    public void cancel(int orderId, int cancelledBy, String reason) throws SQLException {
        try (Connection conn = getConnection()) {
            cancel(conn, orderId, cancelledBy, reason);
        }
    }

    public void cancel(Connection conn, int orderId, int cancelledBy, String reason) throws SQLException {
        String sql = "UPDATE orders SET status = 'CANCELLED', cancelled_at = GETDATE(), cancelled_by = ?, cancellation_reason = ?, updated_at = GETDATE() WHERE order_id = ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, cancelledBy);
            ps.setString(2, reason);
            ps.setInt(3, orderId);
            ps.executeUpdate();
        }
    }

    /**
     * Hoan tra lai so luong ton kho cho cac san pham trong don hang.
     */
    public void restoreInventoryStock(int orderId) throws SQLException {
        String sql = "UPDATE pv "
                   + "SET pv.stock_quantity = pv.stock_quantity + oi.quantity "
                   + "FROM product_variants pv "
                   + "JOIN order_items oi ON pv.variant_id = oi.variant_id "
                   + "WHERE oi.order_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, orderId);
            ps.executeUpdate();
        }
    }

    /**
     * Hoan tra lai so luong ton kho cho mot san pham cu the dua tren order_item_id.
     */
    public void restoreItemInventoryStock(int orderItemId, int quantity) throws SQLException {
        String sql = "UPDATE pv "
                   + "SET pv.stock_quantity = pv.stock_quantity + ? "
                   + "FROM product_variants pv "
                   + "JOIN order_items oi ON pv.variant_id = oi.variant_id "
                   + "WHERE oi.order_item_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, quantity);
            ps.setInt(2, orderItemId);
            ps.executeUpdate();
        }
    }

    /**
     * Lay owner_id cua san pham chua variant duoc chi dinh.
     * @param productId ID san pham
     * @return owner_id, hoac -1 neu khong tim thay
     */
    public int getOwnerIdByProductId(int productId) throws SQLException {
        String sql = "SELECT owner_id FROM products WHERE product_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, productId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt("owner_id");
                }
            }
        }
        return -1;
    }

    /** Mo ket noi public - dung khi Service can transaction thu cong. */
    public Connection openConnection() throws SQLException {
        return getConnection();
    }

    public void updatePlatformFee(Connection conn, int orderId, java.math.BigDecimal platformFee) throws SQLException {
        String sql = "UPDATE orders SET platform_fee = ?, updated_at = GETDATE() WHERE order_id = ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setBigDecimal(1, platformFee != null ? platformFee : java.math.BigDecimal.ZERO);
            ps.setInt(2, orderId);
            ps.executeUpdate();
        }
    }

    /**
     * [RBAC-safe] Tìm đơn hàng theo ID CHỈ KHI thuộc về customerId đó.
     */
    public Order findByIdForCustomer(int orderId, int customerId) throws SQLException {
        String sql = "SELECT * FROM orders WHERE order_id = ? AND customer_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, orderId);
            ps.setInt(2, customerId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return mapRow(rs);
            }
        }
        return null;
    }

    /**
     * [RBAC-safe] Tìm đơn hàng theo ID CHỈ KHI thuộc về shop ownerId đó.
     */
    public Order findByIdForOwner(int orderId, int ownerId) throws SQLException {
        String sql = "SELECT * FROM orders WHERE order_id = ? AND owner_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, orderId);
            ps.setInt(2, ownerId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return mapRow(rs);
            }
        }
        return null;
    }

    /** Đếm tổng đơn hàng của customer (phân trang). */
    public int countByCustomer(int customerId) throws SQLException {
        return countByCustomer(customerId, null);
    }

    /** Đếm tổng đơn hàng của customer với status filter (phân trang). */
    public int countByCustomer(int customerId, String status) throws SQLException {
        StringBuilder sql = new StringBuilder("SELECT COUNT(*) FROM orders WHERE customer_id = ? AND parent_order_id IS NULL");
        List<Object> params = new ArrayList<>();
        params.add(customerId);
        
        if (status != null && !status.trim().isEmpty()) {
            sql.append(" AND status = ?");
            params.add(status);
        }
        
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs2 = ps.executeQuery()) {
                if (rs2.next()) return rs2.getInt(1);
            }
        }
        return 0;
    }


    /** Đếm tổng đơn hàng của shop owner (phân trang). */
    public int countByOwner(int ownerId, String status) throws SQLException {
        return executeWithTransientRetry(() -> countByOwnerInternal(ownerId, status));
    }

    private int countByOwnerInternal(int ownerId, String status) throws SQLException {
        StringBuilder sql = new StringBuilder("SELECT COUNT(*) FROM orders WHERE owner_id = ?");
        if (status != null && !status.trim().isEmpty()) sql.append(" AND status = ?");
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            ps.setInt(1, ownerId);
            if (status != null && !status.trim().isEmpty()) ps.setString(2, status);
            try (ResultSet rs2 = ps.executeQuery()) {
                if (rs2.next()) return rs2.getInt(1);
            }
        }
        return 0;
    }

    /** Tính tổng doanh thu của shop owner (chỉ các đơn hàng DELIVERED). */
    public java.math.BigDecimal getRevenueByOwner(int ownerId) throws SQLException {
        String sql = "SELECT SUM(final_amount) FROM orders WHERE owner_id = ? AND status = 'DELIVERED' AND order_type = 'CHILD'";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, ownerId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    java.math.BigDecimal revenue = rs.getBigDecimal(1);
                    return revenue != null ? revenue : java.math.BigDecimal.ZERO;
                }
            }
        }
        return java.math.BigDecimal.ZERO;
    }

    /** Tính tổng doanh thu tạm tính của shop owner (các đơn hàng active chưa DELIVERED/CANCELLED). */
    public java.math.BigDecimal getEstimatedRevenueByOwner(int ownerId) throws SQLException {
        String sql = "SELECT SUM(final_amount) FROM orders WHERE owner_id = ? AND status IN ('PENDING_PAYMENT', 'CONFIRMED', 'APPROVED', 'PREPARING', 'DISPATCHED') AND order_type = 'CHILD'";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, ownerId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    java.math.BigDecimal revenue = rs.getBigDecimal(1);
                    return revenue != null ? revenue : java.math.BigDecimal.ZERO;
                }
            }
        }
        return java.math.BigDecimal.ZERO;
    }


    /** Ánh xạ ResultSet -> Order — gọi trong mọi query SELECT */
    private Order mapRow(ResultSet rs) throws SQLException {
        Order o = new Order();
        o.setOrderId(rs.getInt("order_id"));
        o.setCustomerId(rs.getInt("customer_id"));
        int ownerId = rs.getInt("owner_id");
        o.setOwnerId(rs.wasNull() ? null : ownerId);
        int parentOrderId = rs.getInt("parent_order_id");
        o.setParentOrderId(rs.wasNull() ? null : parentOrderId);
        o.setOrderType(rs.getString("order_type"));
        o.setDeliveryAddress(rs.getString("delivery_address"));
        o.setRecipientName(rs.getString("recipient_name"));
        o.setRecipientPhone(rs.getString("recipient_phone"));
        o.setDeliveryTimeSlot(rs.getString("delivery_time_slot"));
        o.setNotes(rs.getString("notes"));
        
        Timestamp cancelledAtVal = rs.getTimestamp("cancelled_at");
        if (cancelledAtVal != null) {
            o.setCancelledAt(cancelledAtVal.toLocalDateTime());
        }
        
        int cancelledByVal = rs.getInt("cancelled_by");
        o.setCancelledBy(rs.wasNull() ? null : cancelledByVal);
        
        o.setCancellationReason(rs.getString("cancellation_reason"));
        o.setStatus(rs.getString("status"));
        o.setTotalAmount(rs.getBigDecimal("total_amount"));
        o.setDeliveryFee(rs.getBigDecimal("delivery_fee"));
        o.setDiscountAmount(rs.getBigDecimal("discount_amount"));
        o.setSystemDiscountAmount(rs.getBigDecimal("system_discount_amount"));
        o.setShopDiscountAmount(rs.getBigDecimal("shop_discount_amount"));
        o.setPlatformFee(rs.getBigDecimal("platform_fee"));
        o.setFinalAmount(rs.getBigDecimal("final_amount"));
        o.setPaymentMethod(rs.getString("payment_method"));
        try {
            o.setPaymentStatus(rs.getString("payment_status"));
        } catch (SQLException ignored) {
            o.setPaymentStatus(null);
        }
        o.setRefundStatus(rs.getString("refund_status"));
        o.setReceivedStatus(rs.getString("received_status"));

        Timestamp deadlineVal = rs.getTimestamp("shop_acceptance_deadline");
        if (deadlineVal != null) o.setShopAcceptanceDeadline(deadlineVal.toLocalDateTime());

        Timestamp acceptedAtVal = rs.getTimestamp("shop_accepted_at");
        if (acceptedAtVal != null) o.setShopAcceptedAt(acceptedAtVal.toLocalDateTime());

        Timestamp createdAtVal = rs.getTimestamp("created_at");
        if (createdAtVal != null) {
            o.setCreatedAt(createdAtVal.toLocalDateTime());
        }
        
        Timestamp updatedAtVal = rs.getTimestamp("updated_at");
        if (updatedAtVal != null) {
            o.setUpdatedAt(updatedAtVal.toLocalDateTime());
        }
        return o;
    }

    public List<OrderItem> findItemsByOrderId(int orderId) throws SQLException {
        try (Connection conn = getConnection()) {
            return findItemsByOrderId(conn, orderId);
        }
    }

    public List<OrderItem> findItemsByOrderId(Connection conn, int orderId) throws SQLException {
        List<OrderItem> list = new ArrayList<>();
        String sql = "SELECT oi.*, pi.file_path AS image_path, pv.product_id AS product_id "
                   + "FROM order_items oi "
                   + "LEFT JOIN product_variants pv ON pv.variant_id = oi.variant_id "
                   + "LEFT JOIN product_images pi ON pi.product_id = pv.product_id AND pi.is_primary = 1 "
                   + "WHERE oi.order_id = ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, orderId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapOrderItem(rs));
                }
            }
        }
        return list;
    }

    /**
     * Batch load order_items cho nhiều order_id để tránh N+1 khi render danh sách đơn.
     */
    public Map<Integer, List<OrderItem>> findItemsByOrderIds(Collection<Integer> orderIds) throws SQLException {
        Map<Integer, List<OrderItem>> map = new LinkedHashMap<>();
        if (orderIds == null || orderIds.isEmpty()) {
            return map;
        }

        Set<Integer> distinctIds = new LinkedHashSet<>(orderIds);
        StringBuilder placeholders = new StringBuilder();
        int size = distinctIds.size();
        for (int i = 0; i < size; i++) {
            if (i > 0) {
                placeholders.append(",");
            }
            placeholders.append("?");
        }

        String sql = "SELECT oi.*, pi.file_path AS image_path, pv.product_id AS product_id "
                   + "FROM order_items oi "
                   + "LEFT JOIN product_variants pv ON pv.variant_id = oi.variant_id "
                   + "LEFT JOIN product_images pi ON pi.product_id = pv.product_id AND pi.is_primary = 1 "
                   + "WHERE oi.order_id IN (" + placeholders + ") "
                   + "ORDER BY oi.order_id ASC, oi.order_item_id ASC";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            int paramIndex = 1;
            for (Integer orderId : distinctIds) {
                ps.setInt(paramIndex++, orderId);
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    OrderItem item = mapOrderItem(rs);
                    map.computeIfAbsent(item.getOrderId(), key -> new ArrayList<>()).add(item);
                }
            }
        }
        return map;
    }

    private OrderItem mapOrderItem(ResultSet rs) throws SQLException {
        OrderItem item = new OrderItem();
        item.setOrderItemId(rs.getInt("order_item_id"));
        item.setOrderId(rs.getInt("order_id"));
        int vId = rs.getInt("variant_id");
        item.setVariantId(rs.wasNull() ? null : vId);
        item.setProductNameSnapshot(rs.getString("product_name_snapshot"));
        item.setVariantLabelSnapshot(rs.getString("variant_label_snapshot"));
        item.setQuantity(rs.getInt("quantity"));
        item.setUnitPrice(rs.getBigDecimal("unit_price"));
        item.setSubtotal(rs.getBigDecimal("subtotal"));
        item.setPackagingLabelSnapshot(rs.getString("packaging_label_snapshot"));
        item.setPackagingPriceSnapshot(rs.getBigDecimal("packaging_price_snapshot"));
        item.setImagePath(rs.getString("image_path"));
        int pId = rs.getInt("product_id");
        item.setProductId(rs.wasNull() ? null : pId);
        return item;
    }

    public List<Map<String, Object>> getRevenueTrend(Integer ownerId, String startDate, String endDate, Integer categoryId) throws SQLException {
        List<Map<String, Object>> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder();
        List<Object> params = new ArrayList<>();
        
        if (categoryId != null) {
            sql.append(
                "SELECT CAST(o.created_at AS DATE) AS order_date, SUM(oi.subtotal) AS total_revenue " +
                "FROM orders o " +
                "JOIN order_items oi ON o.order_id = oi.order_id " +
                "JOIN product_variants pv ON oi.variant_id = pv.variant_id " +
                "JOIN products p ON pv.product_id = p.product_id " +
                "WHERE o.status IN ('DELIVERED', 'APPROVED', 'CONFIRMED', 'PREPARING', 'DISPATCHED') AND o.order_type = 'CHILD' "
            );
            if (ownerId != null) {
                sql.append("AND o.owner_id = ? ");
                params.add(ownerId);
            }
            if (startDate != null && !startDate.trim().isEmpty()) {
                sql.append("AND CAST(o.created_at AS DATE) >= ? ");
                params.add(java.sql.Date.valueOf(startDate));
            }
            if (endDate != null && !endDate.trim().isEmpty()) {
                sql.append("AND CAST(o.created_at AS DATE) <= ? ");
                params.add(java.sql.Date.valueOf(endDate));
            }
            sql.append("AND p.category_id = ? ");
            params.add(categoryId);
            sql.append("GROUP BY CAST(o.created_at AS DATE) ORDER BY order_date");
        } else {
            sql.append(
                "SELECT CAST(created_at AS DATE) AS order_date, SUM(final_amount) AS total_revenue " +
                "FROM orders " +
                "WHERE status IN ('DELIVERED', 'APPROVED', 'CONFIRMED', 'PREPARING', 'DISPATCHED') AND order_type = 'CHILD' "
            );
            if (ownerId != null) {
                sql.append("AND owner_id = ? ");
                params.add(ownerId);
            }
            if (startDate != null && !startDate.trim().isEmpty()) {
                sql.append("AND CAST(created_at AS DATE) >= ? ");
                params.add(java.sql.Date.valueOf(startDate));
            }
            if (endDate != null && !endDate.trim().isEmpty()) {
                sql.append("AND CAST(created_at AS DATE) <= ? ");
                params.add(java.sql.Date.valueOf(endDate));
            }
            sql.append("GROUP BY CAST(created_at AS DATE) ORDER BY order_date");
        }

        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("date", rs.getDate("order_date").toString());
                    map.put("revenue", rs.getBigDecimal("total_revenue"));
                    list.add(map);
                }
            }
        }
        return list;
    }

    public List<Map<String, Object>> getOrderStatusStats(Integer ownerId, String startDate, String endDate, Integer categoryId) throws SQLException {
        List<Map<String, Object>> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder();
        List<Object> params = new ArrayList<>();
        
        if (categoryId != null) {
            sql.append(
                "SELECT o.status, COUNT(DISTINCT o.order_id) AS order_count " +
                "FROM orders o " +
                "JOIN order_items oi ON o.order_id = oi.order_id " +
                "JOIN product_variants pv ON oi.variant_id = pv.variant_id " +
                "JOIN products p ON pv.product_id = p.product_id " +
                "WHERE o.order_type = 'CHILD' "
            );
            if (ownerId != null) {
                sql.append("AND o.owner_id = ? ");
                params.add(ownerId);
            }
            if (startDate != null && !startDate.trim().isEmpty()) {
                sql.append("AND CAST(o.created_at AS DATE) >= ? ");
                params.add(java.sql.Date.valueOf(startDate));
            }
            if (endDate != null && !endDate.trim().isEmpty()) {
                sql.append("AND CAST(o.created_at AS DATE) <= ? ");
                params.add(java.sql.Date.valueOf(endDate));
            }
            sql.append("AND p.category_id = ? ");
            params.add(categoryId);
            sql.append("GROUP BY o.status");
        } else {
            sql.append(
                "SELECT status, COUNT(*) AS order_count " +
                "FROM orders " +
                "WHERE order_type = 'CHILD' "
            );
            if (ownerId != null) {
                sql.append("AND owner_id = ? ");
                params.add(ownerId);
            }
            if (startDate != null && !startDate.trim().isEmpty()) {
                sql.append("AND CAST(created_at AS DATE) >= ? ");
                params.add(java.sql.Date.valueOf(startDate));
            }
            if (endDate != null && !endDate.trim().isEmpty()) {
                sql.append("AND CAST(created_at AS DATE) <= ? ");
                params.add(java.sql.Date.valueOf(endDate));
            }
            sql.append("GROUP BY status");
        }

        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("status", rs.getString("status"));
                    map.put("count", rs.getInt("order_count"));
                    list.add(map);
                }
            }
        }
        return list;
    }

    public List<Map<String, Object>> getCancellationReasonStats(Integer ownerId, String startDate, String endDate, Integer categoryId) throws SQLException {
        List<Map<String, Object>> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder();
        List<Object> params = new ArrayList<>();
        
        if (categoryId != null) {
            sql.append(
                "SELECT COALESCE(o.cancellation_reason, N'Không có lý do') AS reason, COUNT(DISTINCT o.order_id) AS cancel_count " +
                "FROM orders o " +
                "JOIN order_items oi ON o.order_id = oi.order_id " +
                "JOIN product_variants pv ON oi.variant_id = pv.variant_id " +
                "JOIN products p ON pv.product_id = p.product_id " +
                "WHERE o.status = 'CANCELLED' AND o.order_type = 'CHILD' "
            );
            if (ownerId != null) {
                sql.append("AND o.owner_id = ? ");
                params.add(ownerId);
            }
            if (startDate != null && !startDate.trim().isEmpty()) {
                sql.append("AND CAST(o.created_at AS DATE) >= ? ");
                params.add(java.sql.Date.valueOf(startDate));
            }
            if (endDate != null && !endDate.trim().isEmpty()) {
                sql.append("AND CAST(o.created_at AS DATE) <= ? ");
                params.add(java.sql.Date.valueOf(endDate));
            }
            sql.append("AND p.category_id = ? ");
            params.add(categoryId);
            sql.append("GROUP BY o.cancellation_reason ORDER BY cancel_count DESC");
        } else {
            sql.append(
                "SELECT COALESCE(cancellation_reason, N'Không có lý do') AS reason, COUNT(*) AS cancel_count " +
                "FROM orders " +
                "WHERE status = 'CANCELLED' AND order_type = 'CHILD' "
            );
            if (ownerId != null) {
                sql.append("AND owner_id = ? ");
                params.add(ownerId);
            }
            if (startDate != null && !startDate.trim().isEmpty()) {
                sql.append("AND CAST(created_at AS DATE) >= ? ");
                params.add(java.sql.Date.valueOf(startDate));
            }
            if (endDate != null && !endDate.trim().isEmpty()) {
                sql.append("AND CAST(created_at AS DATE) <= ? ");
                params.add(java.sql.Date.valueOf(endDate));
            }
            sql.append("GROUP BY cancellation_reason ORDER BY cancel_count DESC");
        }

        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("reason", rs.getString("reason"));
                    map.put("count", rs.getInt("cancel_count"));
                    list.add(map);
                }
            }
        }
        return list;
    }

    public List<Map<String, Object>> getFruitUsageReport(Integer ownerId, String startDate, String endDate, Integer categoryId) throws SQLException {
        List<Map<String, Object>> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder(
            "SELECT oi.product_name_snapshot, oi.variant_label_snapshot, " +
            "       SUM(oi.quantity) AS total_quantity, SUM(oi.subtotal) AS total_amount, " +
            "       COUNT(DISTINCT o.order_id) AS order_count "
        );
        
        if (ownerId == null) {
            sql.append(", s.shop_name ");
        }
        
        sql.append(
            "FROM order_items oi " +
            "JOIN orders o ON oi.order_id = o.order_id "
        );
        
        if (ownerId == null) {
            sql.append("LEFT JOIN shop_owner_profiles s ON o.owner_id = s.user_id ");
        }
        
        if (categoryId != null) {
            sql.append("JOIN product_variants pv ON oi.variant_id = pv.variant_id ");
            sql.append("JOIN products p ON pv.product_id = p.product_id ");
        }
        
        sql.append("WHERE o.status IN ('DELIVERED', 'APPROVED', 'CONFIRMED', 'PREPARING', 'DISPATCHED') AND o.order_type = 'CHILD' ");
        
        List<Object> params = new ArrayList<>();
        if (ownerId != null) {
            sql.append("AND o.owner_id = ? ");
            params.add(ownerId);
        }
        if (startDate != null && !startDate.trim().isEmpty()) {
            sql.append("AND CAST(o.created_at AS DATE) >= ? ");
            params.add(java.sql.Date.valueOf(startDate));
        }
        if (endDate != null && !endDate.trim().isEmpty()) {
            sql.append("AND CAST(o.created_at AS DATE) <= ? ");
            params.add(java.sql.Date.valueOf(endDate));
        }
        if (categoryId != null) {
            sql.append("AND p.category_id = ? ");
            params.add(categoryId);
        }
        
        sql.append("GROUP BY oi.product_name_snapshot, oi.variant_label_snapshot ");
        if (ownerId == null) {
            sql.append(", s.shop_name ");
        }
        sql.append("ORDER BY total_quantity DESC");

        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("productName", rs.getString("product_name_snapshot"));
                    map.put("variantLabel", rs.getString("variant_label_snapshot"));
                    map.put("totalQuantity", rs.getInt("total_quantity"));
                    map.put("totalAmount", rs.getBigDecimal("total_amount"));
                    map.put("orderCount", rs.getInt("order_count"));
                    if (ownerId == null) {
                        map.put("shopName", rs.getString("shop_name") != null ? rs.getString("shop_name") : "Hệ thống");
                    }
                    list.add(map);
                }
            }
        }
        return list;
    }

    public List<Order> findChildrenByParentId(int parentOrderId) throws SQLException {
        List<Order> list = new ArrayList<>();
        String sql = "SELECT * FROM orders WHERE parent_order_id = ? ORDER BY order_id ASC";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, parentOrderId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    /**
     * Batch load orders theo danh sách order_id để tránh N+1.
     * Trả về Map<orderId, Order> — các id không tồn tại sẽ không có trong map.
     */
    public Map<Integer, Order> findByIds(Collection<Integer> orderIds) throws SQLException {
        Map<Integer, Order> map = new LinkedHashMap<>();
        if (orderIds == null || orderIds.isEmpty()) {
            return map;
        }

        Set<Integer> distinctIds = new LinkedHashSet<>(orderIds);
        String placeholders = String.join(",", java.util.Collections.nCopies(distinctIds.size(), "?"));
        String sql = "SELECT * FROM orders WHERE order_id IN (" + placeholders + ")";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            int paramIndex = 1;
            for (Integer id : distinctIds) {
                ps.setInt(paramIndex++, id);
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Order o = mapRow(rs);
                    map.put(o.getOrderId(), o);
                }
            }
        }
        return map;
    }

    public void updateReceivedStatus(int orderId, String receivedStatus) throws SQLException {
        String sql = "UPDATE orders SET received_status = ?, updated_at = GETDATE() WHERE order_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, receivedStatus);
            ps.setInt(2, orderId);
            ps.executeUpdate();
        }
    }

    /**
     * SEC-01 — Count FAILED deliveries for a customer in the last {@code days} days.
     * Used by OrderService.isCodEligible() to gate COD payment eligibility.
     */
    public int countRecentFailedDeliveries(int customerId, int days) throws SQLException {
        String sql = "SELECT COUNT(*) FROM deliveries d "
                   + "JOIN orders o ON d.order_id = o.order_id "
                   + "WHERE o.customer_id = ? "
                   + "  AND d.status = 'FAILED' "
                   + "  AND d.updated_at >= DATEADD(day, ?, GETDATE())";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, customerId);
            ps.setInt(2, -days);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return rs.getInt(1);
            }
        }
        return 0;
    }

    /**
     * INV-01 — Find orders in PENDING_PAYMENT whose created_at is older than
     * {@code minutes} minutes. Used by AutoCancelUnpaidListener to release
     * reserved stock and cancel unpaid orders.
     */
    public List<Order> findExpiredPendingPayment(int minutes) throws SQLException {
        String sql = "SELECT * FROM orders "
                   + "WHERE status = 'PENDING_PAYMENT' "
                   + "  AND created_at < DATEADD(minute, ?, GETDATE())";
        List<Order> list = new ArrayList<>();
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, -minutes);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }
    /**
     * Lấy danh sách order_id của tất cả đơn con thuộc đơn cha (trên connection hiện tại).
     */
    public List<Integer> findChildOrderIds(Connection conn, int parentOrderId) throws SQLException {
        List<Integer> ids = new ArrayList<>();
        String sql = "SELECT order_id FROM orders WHERE parent_order_id = ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, parentOrderId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) ids.add(rs.getInt("order_id"));
            }
        }
        return ids;
    }

    /**
     * Bulk update trạng thái tất cả đơn con của đơn cha.
     */
    public void updateStatusByParent(Connection conn, int parentOrderId, String status) throws SQLException {
        String normalizedStatus = status != null ? status.trim() : null;
        String sql;
        if ("CONFIRMED".equalsIgnoreCase(normalizedStatus)) {
            sql = "UPDATE orders SET status = ?, shop_acceptance_deadline = DATEADD(minute, 30, GETDATE()), updated_at = GETDATE() "
                + "WHERE parent_order_id = ? AND status = 'PENDING_PAYMENT'";
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setString(1, normalizedStatus);
                ps.setInt(2, parentOrderId);
                ps.executeUpdate();
            }
            return;
        }
        if ("APPROVED".equalsIgnoreCase(normalizedStatus)) {
            sql = "UPDATE orders SET status = ?, shop_accepted_at = GETDATE(), shop_acceptance_deadline = NULL, updated_at = GETDATE() "
                + "WHERE parent_order_id = ? AND status = 'CONFIRMED'";
            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setString(1, normalizedStatus);
                ps.setInt(2, parentOrderId);
                ps.executeUpdate();
            }
            return;
        }

        sql = "UPDATE orders SET status = ?, updated_at = GETDATE() WHERE parent_order_id = ? AND status <> ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, normalizedStatus);
            ps.setInt(2, parentOrderId);
            ps.setString(3, normalizedStatus);
            ps.executeUpdate();
        }
    }

    /**
     * Đếm số đơn con chưa ở trạng thái DELIVERED hoặc CANCELLED.
     * Dùng để kiểm tra khi nào toàn bộ đơn con đã hoàn thành trước khi update đơn cha.
     */
    public int countNonDeliveredChildOrders(Connection conn, int parentOrderId) throws SQLException {
        String sql = "SELECT COUNT(*) FROM orders WHERE parent_order_id = ? "
                   + "AND status NOT IN ('DELIVERED', 'CANCELLED')";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, parentOrderId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return rs.getInt(1);
            }
        }
        return 0;
    }

    /**
     * Lấy parent_order_id từ một đơn con. Trả về null nếu đơn là đơn cha.
     */
    public Integer getParentOrderIdByChildId(Connection conn, int orderId) throws SQLException {
        String sql = "SELECT parent_order_id FROM orders WHERE order_id = ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, orderId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    int val = rs.getInt("parent_order_id");
                    return rs.wasNull() ? null : val;
                }
            }
        }
        return null;
    }
}
