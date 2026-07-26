package dao.order;

import dao.system.BaseDAO;
import model.entity.order.Delivery;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * DeliveryDAO — DAO cho entity Delivery.
 *
 * QUY TẮC:
 *   - Chỉ chứa SQL, không chứa business logic
 *   - Dùng PreparedStatement, KHÔNG nối chuỗi SQL
 *   - Mỗi method ném SQLException để Service xử lý
 *   - Dùng try-with-resources cho Connection + PreparedStatement
 *
 * @author fruitmkt-team
 */
public class DeliveryDAO extends BaseDAO {

    public Delivery findById(int deliveryId) throws SQLException {
        String sql = "SELECT * FROM deliveries WHERE delivery_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, deliveryId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return mapRow(rs);
            }
        }
        return null;
    }

    public List<Delivery> findByStaffId(int staffId) throws SQLException {
        List<Delivery> list = new ArrayList<>();
        String sql = "SELECT * FROM deliveries WHERE staff_id = ? ORDER BY created_at DESC";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, staffId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    public void updateStatusAndProof(int deliveryId, String status, String failureReason, String proofImageUrl) throws SQLException {
        try (Connection conn = getConnection()) {
            updateStatusAndProof(conn, deliveryId, status, failureReason, proofImageUrl);
        }
    }

    public void updateStatusAndProof(Connection conn, int deliveryId, String status, String failureReason, String proofImageUrl) throws SQLException {
        // B3 Fix: added space before WHERE to prevent SQL syntax error
        String sql = "UPDATE deliveries SET status = ?, failure_reason = ?, proof_image_url = ?, updated_at = GETDATE() ";
        if ("PICKED_UP".equals(status)) {
            sql += ", picked_up_at = GETDATE() ";
        } else if ("DELIVERED".equals(status)) {
            sql += ", delivered_at = GETDATE() ";
        }
        sql += " WHERE delivery_id = ?";

        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, status);
            ps.setString(2, failureReason);
            ps.setString(3, proofImageUrl);
            ps.setInt(4, deliveryId);
            ps.executeUpdate();
        }
    }

    public void updateEstimatedTime(int deliveryId, java.time.LocalDateTime estimatedTime) throws SQLException {
        String sql = "UPDATE deliveries SET estimated_delivery_time = ?, updated_at = GETDATE() WHERE delivery_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setTimestamp(1, estimatedTime != null ? Timestamp.valueOf(estimatedTime) : null);
            ps.setInt(2, deliveryId);
            ps.executeUpdate();
        }
    }

    public void assignShipper(int orderId, int staffId, java.time.LocalDateTime estimatedTime) throws SQLException {
        String sql = "INSERT INTO deliveries (order_id, staff_id, status, estimated_delivery_time, created_at, updated_at) "
                   + "VALUES (?, ?, 'ASSIGNED', ?, GETDATE(), GETDATE())";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, orderId);
            if (staffId > 0) {
                ps.setInt(2, staffId);
            } else {
                ps.setNull(2, Types.INTEGER); // Chờ phân công
            }
            ps.setTimestamp(3, estimatedTime != null ? Timestamp.valueOf(estimatedTime) : null);
            ps.executeUpdate();
        }
    }

    public void assignShipper(int orderId, Integer deliveryTripId, Integer tripStopSeq,
                              int staffId, java.time.LocalDateTime estimatedTime) throws SQLException {
        try (Connection conn = getConnection()) {
            assignShipper(conn, orderId, deliveryTripId, tripStopSeq, staffId, estimatedTime);
        }
    }

    public void assignShipper(Connection conn, int orderId, Integer deliveryTripId, Integer tripStopSeq,
                              int staffId, java.time.LocalDateTime estimatedTime) throws SQLException {
        String updateSql = "UPDATE deliveries SET delivery_trip_id = ?, trip_stop_seq = ?, staff_id = ?, status = 'ASSIGNED', estimated_delivery_time = ?, updated_at = GETDATE() "
                         + "WHERE order_id = ?";
        try (PreparedStatement ps = conn.prepareStatement(updateSql)) {
            if (deliveryTripId != null && deliveryTripId > 0) {
                ps.setInt(1, deliveryTripId);
            } else {
                ps.setNull(1, Types.INTEGER);
            }
            if (tripStopSeq != null) {
                ps.setInt(2, tripStopSeq);
            } else {
                ps.setNull(2, Types.INTEGER);
            }
            if (staffId > 0) {
                ps.setInt(3, staffId);
            } else {
                ps.setNull(3, Types.INTEGER);
            }
            ps.setTimestamp(4, estimatedTime != null ? Timestamp.valueOf(estimatedTime) : null);
            ps.setInt(5, orderId);
            if (ps.executeUpdate() > 0) {
                return;
            }
        }

        String insertSql = "INSERT INTO deliveries (order_id, delivery_trip_id, trip_stop_seq, staff_id, status, estimated_delivery_time, created_at, updated_at) "
                         + "VALUES (?, ?, ?, ?, 'ASSIGNED', ?, GETDATE(), GETDATE())";
        try (PreparedStatement ps = conn.prepareStatement(insertSql)) {
            ps.setInt(1, orderId);
            if (deliveryTripId != null && deliveryTripId > 0) {
                ps.setInt(2, deliveryTripId);
            } else {
                ps.setNull(2, Types.INTEGER);
            }
            if (tripStopSeq != null) {
                ps.setInt(3, tripStopSeq);
            } else {
                ps.setNull(3, Types.INTEGER);
            }
            if (staffId > 0) {
                ps.setInt(4, staffId);
            } else {
                ps.setNull(4, Types.INTEGER);
            }
            ps.setTimestamp(5, estimatedTime != null ? Timestamp.valueOf(estimatedTime) : null);
            ps.executeUpdate();
        }
    }

    public boolean claimDelivery(int deliveryId, int staffId) throws SQLException {
        try (Connection conn = getConnection()) {
            return claimDelivery(conn, deliveryId, staffId);
        }
    }

    public boolean claimDelivery(Connection conn, int deliveryId, int staffId) throws SQLException {
        String sql = "UPDATE deliveries SET staff_id = ?, updated_at = GETDATE() WHERE delivery_id = ? AND staff_id IS NULL AND status = 'ASSIGNED'";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, staffId);
            ps.setInt(2, deliveryId);
            return ps.executeUpdate() > 0;
        }
    }

    public Delivery findByOrderId(int orderId) throws SQLException {
        String sql = "SELECT TOP 1 * FROM deliveries WHERE order_id = ? ORDER BY created_at DESC";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, orderId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return mapRow(rs);
                }
            }
        }
        return null;
    }

    public Map<Integer, Delivery> findByOrderIds(Collection<Integer> orderIds) throws SQLException {
        Map<Integer, Delivery> map = new LinkedHashMap<>();
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

        String sql = "SELECT * FROM deliveries WHERE order_id IN (" + placeholders + ") "
                   + "ORDER BY order_id ASC, created_at DESC, delivery_id DESC";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            int paramIndex = 1;
            for (Integer orderId : distinctIds) {
                ps.setInt(paramIndex++, orderId);
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Delivery delivery = mapRow(rs);
                    map.putIfAbsent(delivery.getOrderId(), delivery);
                }
            }
        }
        return map;
    }

    /**
     * Lấy tất cả deliveries (dùng cho admin/report).
     */
    public List<Delivery> findAll() throws SQLException {
        List<Delivery> list = new ArrayList<>();
        String sql = "SELECT * FROM deliveries ORDER BY created_at DESC";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                list.add(mapRow(rs));
            }
        }
        return list;
    }

    /**
     * Lấy deliveries chưa được gán staff (staff_id IS NULL).
     */
    public List<Delivery> findUnassigned() throws SQLException {
        List<Delivery> list = new ArrayList<>();
        String sql = "SELECT * FROM deliveries WHERE staff_id IS NULL AND status = 'ASSIGNED' ORDER BY created_at ASC";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                list.add(mapRow(rs));
            }
        }
        return list;
    }

    private Delivery mapRow(ResultSet rs) throws SQLException {
        Delivery d = new Delivery();
        d.setDeliveryId(rs.getInt("delivery_id"));
        d.setOrderId(rs.getInt("order_id"));
        int deliveryTripId = rs.getInt("delivery_trip_id");
        d.setDeliveryTripId(rs.wasNull() ? null : deliveryTripId);
        int tripStopSeq = rs.getInt("trip_stop_seq");
        d.setTripStopSeq(rs.wasNull() ? null : tripStopSeq);
        d.setStaffId(rs.getObject("staff_id") != null ? rs.getInt("staff_id") : null);
        d.setStatus(rs.getString("status"));
        
        Timestamp pickedUpAt = rs.getTimestamp("picked_up_at");
        if (pickedUpAt != null) d.setPickedUpAt(pickedUpAt.toLocalDateTime());
        
        Timestamp deliveredAt = rs.getTimestamp("delivered_at");
        if (deliveredAt != null) d.setDeliveredAt(deliveredAt.toLocalDateTime());
        
        d.setFailureReason(rs.getString("failure_reason"));
        d.setProofImageUrl(rs.getString("proof_image_url"));
        
        Timestamp estTime = rs.getTimestamp("estimated_delivery_time");
        if (estTime != null) d.setEstimatedDeliveryTime(estTime.toLocalDateTime());
        
        Timestamp createdAt = rs.getTimestamp("created_at");
        if (createdAt != null) d.setCreatedAt(createdAt.toLocalDateTime());
        
        Timestamp updatedAt = rs.getTimestamp("updated_at");
        if (updatedAt != null) d.setUpdatedAt(updatedAt.toLocalDateTime());
        
        return d;
    }

}

