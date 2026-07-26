package dao.order;

import dao.system.BaseDAO;
import model.entity.order.DeliveryTrip;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.sql.Types;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

public class DeliveryTripDAO extends BaseDAO {

    public int save(Connection conn, int parentOrderId, Integer shipperId,
                    String status, LocalDateTime estimatedStartTime,
                    LocalDateTime estimatedEndTime) throws SQLException {
        String sql = "INSERT INTO delivery_trips (parent_order_id, shipper_id, status, estimated_start_time, estimated_end_time, created_at, updated_at) "
                   + "VALUES (?, ?, ?, ?, ?, GETDATE(), GETDATE())";
        try (PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, parentOrderId);
            if (shipperId != null && shipperId > 0) {
                ps.setInt(2, shipperId);
            } else {
                ps.setNull(2, Types.INTEGER);
            }
            ps.setString(3, status != null ? status : "PLANNED");
            ps.setTimestamp(4, estimatedStartTime != null ? Timestamp.valueOf(estimatedStartTime) : null);
            ps.setTimestamp(5, estimatedEndTime != null ? Timestamp.valueOf(estimatedEndTime) : null);
            ps.executeUpdate();
            try (ResultSet rs = ps.getGeneratedKeys()) {
                if (rs.next()) {
                    return rs.getInt(1);
                }
            }
        }
        throw new SQLException("Khong tao duoc delivery trip.");
    }

    public DeliveryTrip findById(int tripId) throws SQLException {
        String sql = "SELECT * FROM delivery_trips WHERE trip_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tripId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return mapRow(rs);
                }
            }
        }
        return null;
    }

    public List<DeliveryTrip> findByParentOrderId(int parentOrderId) throws SQLException {
        List<DeliveryTrip> list = new ArrayList<>();
        String sql = "SELECT * FROM delivery_trips WHERE parent_order_id = ? ORDER BY trip_id";
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

    public void assignShipper(int tripId, int shipperId) throws SQLException {
        try (Connection conn = getConnection()) {
            assignShipper(conn, tripId, shipperId);
        }
    }

    public void assignShipper(Connection conn, int tripId, int shipperId) throws SQLException {
        String sql = "UPDATE delivery_trips SET shipper_id = ?, status = 'ASSIGNED', updated_at = GETDATE() WHERE trip_id = ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, shipperId);
            ps.setInt(2, tripId);
            ps.executeUpdate();
        }
    }

    public void updateStatus(int tripId, String status) throws SQLException {
        String sql = "UPDATE delivery_trips SET status = ?, updated_at = GETDATE() WHERE trip_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, status);
            ps.setInt(2, tripId);
            ps.executeUpdate();
        }
    }

    private DeliveryTrip mapRow(ResultSet rs) throws SQLException {
        DeliveryTrip trip = new DeliveryTrip();
        trip.setTripId(rs.getInt("trip_id"));
        trip.setParentOrderId(rs.getInt("parent_order_id"));
        int shipperId = rs.getInt("shipper_id");
        trip.setShipperId(rs.wasNull() ? null : shipperId);
        trip.setStatus(rs.getString("status"));

        Timestamp estimatedStart = rs.getTimestamp("estimated_start_time");
        if (estimatedStart != null) {
            trip.setEstimatedStartTime(estimatedStart.toLocalDateTime());
        }
        Timestamp estimatedEnd = rs.getTimestamp("estimated_end_time");
        if (estimatedEnd != null) {
            trip.setEstimatedEndTime(estimatedEnd.toLocalDateTime());
        }
        Timestamp createdAt = rs.getTimestamp("created_at");
        if (createdAt != null) {
            trip.setCreatedAt(createdAt.toLocalDateTime());
        }
        Timestamp updatedAt = rs.getTimestamp("updated_at");
        if (updatedAt != null) {
            trip.setUpdatedAt(updatedAt.toLocalDateTime());
        }
        return trip;
    }
}
