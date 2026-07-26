package dao.catalog;

import dao.system.BaseDAO;
import model.entity.catalog.InventoryLog;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;

/**
 * InventoryDAO — DAO cho entity InventoryLog.
 *
 * QUY TẮC:
 * - Chỉ chứa SQL, không chứa business logic
 * - Dùng PreparedStatement, KHÔNG nối chuỗi SQL
 * - Mỗi method ném SQLException để Service xử lý
 * - Dùng try-with-resources cho Connection + PreparedStatement
 *
 * @author fruitmkt-team
 */
public class InventoryDAO extends BaseDAO {

    /**
     * Exposes connection for starting standard JDBC transactions in Service.
     */
    public Connection openConnection() throws SQLException {
        return getConnection();
    }

    /**
     * Saves an inventory log entry using an active transactional connection.
     */
    public int save(Connection conn, InventoryLog log) throws SQLException {
        String sql = "INSERT INTO inventory_logs (variant_id, changed_by, change_type, quantity_delta, quantity_after, note, expires_at, is_expired, changed_at, remaining_quantity) "
                + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        try (PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, log.getVariantId());
            ps.setInt(2, log.getChangedBy());
            ps.setString(3, log.getChangeType());
            ps.setInt(4, log.getQuantityDelta());
            ps.setInt(5, log.getQuantityAfter());
            if (log.getNote() != null) {
                ps.setString(6, log.getNote());
            } else {
                ps.setNull(6, Types.NVARCHAR);
            }
            if (log.getExpiresAt() != null) {
                ps.setDate(7, java.sql.Date.valueOf(log.getExpiresAt()));
            } else {
                ps.setNull(7, Types.DATE);
            }
            ps.setBoolean(8, log.isExpired());
            if (log.getChangedAt() != null) {
                ps.setTimestamp(9, Timestamp.valueOf(log.getChangedAt()));
            } else {
                ps.setTimestamp(9, new Timestamp(System.currentTimeMillis()));
            }
            ps.setInt(10, log.getRemainingQuantity());

            ps.executeUpdate();
            try (ResultSet rs = ps.getGeneratedKeys()) {
                if (rs.next()) {
                    return rs.getInt(1);
                }
            }
        }
        throw new SQLException("Lưu lịch sử thay đổi kho thất bại, không lấy được mã tự tăng.");
    }

    /**
     * Saves an inventory log entry using a fresh connection.
     */
    public int save(InventoryLog log) throws SQLException {
        try (Connection conn = getConnection()) {
            return save(conn, log);
        }
    }

    /**
     * Retrieves all inventory history logs for products owned by a specific Shop
     * Owner.
     */
    public List<InventoryLog> findByOwner(int ownerId) throws SQLException {
        List<InventoryLog> list = new ArrayList<>();
        String sql = "SELECT il.*, p.name AS product_name, pv.variant_label, u.full_name AS changed_by_name "
                + "FROM inventory_logs il "
                + "JOIN product_variants pv ON il.variant_id = pv.variant_id "
                + "JOIN products p ON pv.product_id = p.product_id "
                + "JOIN users u ON il.changed_by = u.user_id "
                + "WHERE p.owner_id = ? "
                + "ORDER BY il.changed_at DESC";

        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, ownerId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRowWithDetails(rs));
                }
            }
        }
        return list;
    }

    public List<InventoryLog> findByOwner(int ownerId, int limit) throws SQLException {
        List<InventoryLog> list = new ArrayList<>();
        if (limit <= 0) {
            return list;
        }
        String sql = "SELECT il.*, p.name AS product_name, pv.variant_label, u.full_name AS changed_by_name "
                + "FROM inventory_logs il "
                + "JOIN product_variants pv ON il.variant_id = pv.variant_id "
                + "JOIN products p ON pv.product_id = p.product_id "
                + "JOIN users u ON il.changed_by = u.user_id "
                + "WHERE p.owner_id = ? "
                + "ORDER BY il.changed_at DESC "
                + "OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY";

        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, ownerId);
            ps.setInt(2, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRowWithDetails(rs));
                }
            }
        }
        return list;
    }

    /**
     * Retrieves all inventory history logs for a specific Product Variant.
     */
    public List<InventoryLog> findByVariant(int variantId) throws SQLException {
        List<InventoryLog> list = new ArrayList<>();
        String sql = "SELECT il.*, p.name AS product_name, pv.variant_label, u.full_name AS changed_by_name "
                + "FROM inventory_logs il "
                + "JOIN product_variants pv ON il.variant_id = pv.variant_id "
                + "JOIN products p ON pv.product_id = p.product_id "
                + "JOIN users u ON il.changed_by = u.user_id "
                + "WHERE il.variant_id = ? "
                + "ORDER BY il.changed_at DESC";

        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, variantId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRowWithDetails(rs));
                }
            }
        }
        return list;
    }

    /** Ánh xạ ResultSet -> InventoryLog */
    private InventoryLog mapRow(ResultSet rs) throws SQLException {
        InventoryLog log = new InventoryLog();
        log.setLogId(rs.getInt("log_id"));
        log.setVariantId(rs.getInt("variant_id"));
        log.setChangedBy(rs.getInt("changed_by"));
        log.setChangeType(rs.getString("change_type"));
        log.setQuantityDelta(rs.getInt("quantity_delta"));
        log.setQuantityAfter(rs.getInt("quantity_after"));
        log.setNote(rs.getString("note"));

        java.sql.Date expDate = rs.getDate("expires_at");
        if (expDate != null) {
            log.setExpiresAt(expDate.toLocalDate());
        }
        log.setExpired(rs.getBoolean("is_expired"));

        int rem = rs.getInt("remaining_quantity");
        if (!rs.wasNull()) {
            log.setRemainingQuantity(rem);
        } else {
            log.setRemainingQuantity(log.getQuantityDelta());
        }

        Timestamp ts = rs.getTimestamp("changed_at");
        if (ts != null) {
            log.setChangedAt(ts.toLocalDateTime());
        }

        return log;
    }

    /** Ánh xạ ResultSet -> InventoryLog kèm thông tin chi tiết liên kết */
    private InventoryLog mapRowWithDetails(ResultSet rs) throws SQLException {
        InventoryLog log = mapRow(rs);
        log.setProductName(rs.getString("product_name"));
        log.setVariantLabel(rs.getString("variant_label"));
        log.setChangedByName(rs.getString("changed_by_name"));
        return log;
    }

    /**
     * Tìm tất cả các dòng giao dịch nhập kho (MANUAL_ADJUST và delta > 0) có ngày
     * hết hạn đã qua
     * nhưng chưa được xử lý hết hạn (is_expired = 0).
     */
    public List<InventoryLog> findExpiredLogs(Connection conn) throws SQLException {
        List<InventoryLog> list = new ArrayList<>();
        String sql = "SELECT * FROM inventory_logs WHERE change_type = 'MANUAL_ADJUST' AND quantity_delta > 0 "
                + "AND expires_at IS NOT NULL AND expires_at <= CAST(GETDATE() AS DATE) AND is_expired = 0";
        try (PreparedStatement ps = conn.prepareStatement(sql);
                ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                list.add(mapRow(rs));
            }
        }
        return list;
    }

    /**
     * Lấy danh sách lô hàng nhập kho còn hiệu lực (MANUAL_ADJUST, delta > 0, is_expired = 0)
     * kèm thông tin sản phẩm, phân loại và ngày hết hạn — dùng cho bảng Tồn kho của Shop Owner.
     * Chỉ hiển thị lô chưa qua ngày hết hạn (expires_at >= TODAY hoặc expires_at IS NULL).
     */
    public List<InventoryLog> findActiveBatchesByOwner(int ownerId) throws SQLException {
        List<InventoryLog> list = new ArrayList<>();
        String sql = "SELECT il.log_id, il.variant_id, il.change_type, il.quantity_delta, il.quantity_after, il.remaining_quantity, "
                + "       il.expires_at, il.is_expired, il.changed_at, il.note, il.changed_by, "
                + "       p.name AS product_name, pv.variant_label, u.full_name AS changed_by_name "
                + "FROM inventory_logs il "
                + "JOIN product_variants pv ON il.variant_id = pv.variant_id "
                + "JOIN products p ON pv.product_id = p.product_id "
                + "JOIN users u ON il.changed_by = u.user_id "
                + "WHERE p.owner_id = ? "
                + "  AND il.change_type = 'MANUAL_ADJUST' "
                + "  AND il.quantity_delta > 0 "
                + "  AND il.is_expired = 0 "
                + "  AND ISNULL(il.remaining_quantity, il.quantity_delta) > 0 "
                + "  AND (il.expires_at IS NULL OR il.expires_at >= CAST(GETDATE() AS DATE)) "
                + "ORDER BY il.expires_at ASC, il.changed_at DESC";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, ownerId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRowWithDetails(rs));
                }
            }
        }
        return list;
    }

    public List<InventoryLog> findActiveBatchesByOwner(int ownerId, int limit) throws SQLException {
        List<InventoryLog> list = new ArrayList<>();
        if (limit <= 0) {
            return list;
        }
        String sql = "SELECT il.log_id, il.variant_id, il.change_type, il.quantity_delta, il.quantity_after, il.remaining_quantity, "
                + "       il.expires_at, il.is_expired, il.changed_at, il.note, il.changed_by, "
                + "       p.name AS product_name, pv.variant_label, u.full_name AS changed_by_name "
                + "FROM inventory_logs il "
                + "JOIN product_variants pv ON il.variant_id = pv.variant_id "
                + "JOIN products p ON pv.product_id = p.product_id "
                + "JOIN users u ON il.changed_by = u.user_id "
                + "WHERE p.owner_id = ? "
                + "  AND il.change_type = 'MANUAL_ADJUST' "
                + "  AND il.quantity_delta > 0 "
                + "  AND il.is_expired = 0 "
                + "  AND ISNULL(il.remaining_quantity, il.quantity_delta) > 0 "
                + "  AND (il.expires_at IS NULL OR il.expires_at >= CAST(GETDATE() AS DATE)) "
                + "ORDER BY il.expires_at ASC, il.changed_at DESC "
                + "OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, ownerId);
            ps.setInt(2, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRowWithDetails(rs));
                }
            }
        }
        return list;
    }

    /**
     * Lấy shelf_life_days của sản phẩm thông qua variant_id.
     * Trả về null nếu sản phẩm không cấu hình shelf_life_days.
     */
    public Integer getShelfLifeByVariantId(int variantId) throws SQLException {
        String sql = "SELECT p.shelf_life_days "
                + "FROM product_variants pv "
                + "JOIN products p ON pv.product_id = p.product_id "
                + "WHERE pv.variant_id = ?";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, variantId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    int val = rs.getInt("shelf_life_days");
                    return rs.wasNull() ? null : val;
                }
            }
        }
        return null;
    }

    /**
     * Tìm lô nhập kho FIFO — lô có ngày hết hạn SỚM NHẤT (hoặc ngày nhập sớm nhất nếu không có HH)
     * cho một variant cụ thể. Dùng để ghi audit trail khi bán hàng (ORDER_RESERVE).
     */
    public InventoryLog findOldestActiveBatchForVariant(Connection conn, int variantId) throws SQLException {
        String sql = "SELECT TOP 1 * FROM inventory_logs "
                + "WHERE variant_id = ? AND change_type = 'MANUAL_ADJUST' AND quantity_delta > 0 "
                + "AND is_expired = 0 AND ISNULL(remaining_quantity, quantity_delta) > 0 "
                + "AND (expires_at IS NULL OR expires_at >= CAST(GETDATE() AS DATE)) "
                + "ORDER BY "
                + "  CASE WHEN expires_at IS NULL THEN 1 ELSE 0 END ASC, " // lô có HH lên trước
                + "  expires_at ASC, "                                       // HH sớm nhất
                + "  changed_at ASC";                                        // nhập sớm nhất nếu bằng nhau
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, variantId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return mapRow(rs);
                }
            }
        }
        return null;
    }

    /**
     * Lấy danh sách các lô hàng đang hoạt động của một variant theo thứ tự FIFO (expires_at ASC, changed_at ASC).
     */
    public List<InventoryLog> findActiveBatchesForVariant(Connection conn, int variantId) throws SQLException {
        List<InventoryLog> list = new ArrayList<>();
        String sql = "SELECT * FROM inventory_logs "
                + "WHERE variant_id = ? AND change_type = 'MANUAL_ADJUST' AND quantity_delta > 0 "
                + "AND is_expired = 0 AND ISNULL(remaining_quantity, quantity_delta) > 0 "
                + "AND (expires_at IS NULL OR expires_at >= CAST(GETDATE() AS DATE)) "
                + "ORDER BY "
                + "  CASE WHEN expires_at IS NULL THEN 1 ELSE 0 END ASC, " // lô có HH lên trước
                + "  expires_at ASC, "                                       // HH sớm nhất
                + "  changed_at ASC";                                        // nhập sớm nhất nếu bằng nhau
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, variantId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    /**
     * Cập nhật số lượng còn lại của lô hàng trong transaction.
     */
    public void updateRemainingQuantity(Connection conn, int logId, int newRemainingQuantity) throws SQLException {
        String sql = "UPDATE inventory_logs SET remaining_quantity = ? WHERE log_id = ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, newRemainingQuantity);
            ps.setInt(2, logId);
            ps.executeUpdate();
        }
    }

    /**
     * Tìm một lô hàng hoạt động cụ thể theo ID.
     */
    public InventoryLog findActiveBatchById(Connection conn, int logId) throws SQLException {
        String sql = "SELECT * FROM inventory_logs WHERE log_id = ? AND change_type = 'MANUAL_ADJUST' AND quantity_delta > 0 AND is_expired = 0";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, logId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return mapRow(rs);
                }
            }
        }
        return null;
    }

    /**
     * Đánh dấu log nhập kho đã được xử lý hết hạn.
     */
    public void markLogExpired(Connection conn, int logId) throws SQLException {
        String sql = "UPDATE inventory_logs SET is_expired = 1, remaining_quantity = 0 WHERE log_id = ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, logId);
            ps.executeUpdate();
        }
    }

    /**
     * Lấy chuỗi note của ORDER_RESERVE
     */
    public String findReserveLogNote(Connection conn, int orderId, int variantId) throws SQLException {
        String sql = "SELECT TOP 1 note FROM inventory_logs WHERE change_type = 'ORDER_RESERVE' AND variant_id = ? AND note LIKE ? ORDER BY log_id DESC";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, variantId);
            ps.setString(2, "Giữ hàng cho đơn hàng #" + orderId + "%");
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getString("note");
                }
            }
        }
        return null;
    }

    /**
     * Cộng lại số lượng vào remaining_quantity của một lô.
     */
    public void incrementRemainingQuantity(Connection conn, int logId, int incrementQty) throws SQLException {
        String sql = "UPDATE inventory_logs SET remaining_quantity = ISNULL(remaining_quantity, 0) + ? WHERE log_id = ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, incrementQty);
            ps.setInt(2, logId);
            ps.executeUpdate();
        }
    }
}
