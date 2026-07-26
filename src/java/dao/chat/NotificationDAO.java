package dao.chat;

import dao.system.BaseDAO;
import model.entity.chat.Notification;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.List;
import util.PaginationHelper;

/**
 * NotificationDAO — DAO cho entity Notification.
 */
public class NotificationDAO extends BaseDAO {

    public List<Notification> findByUser(int userId, boolean unreadOnly) throws SQLException {
        List<Notification> list = new ArrayList<>();
        String sql = "SELECT * FROM notifications WHERE user_id = ?";
        if (unreadOnly) {
            sql += " AND is_read = 0";
        }
        sql += " ORDER BY created_at DESC";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    public List<Notification> findRecentByUser(int userId, int limit) throws SQLException {
        List<Notification> list = new ArrayList<>();
        if (limit <= 0) {
            return list;
        }

        String sql = "SELECT * FROM notifications "
                + "WHERE user_id = ? "
                + "ORDER BY created_at DESC, notification_id DESC "
                + "OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ps.setInt(2, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    public int countUnreadByUser(int userId) throws SQLException {
        String sql = "SELECT COUNT(*) FROM notifications WHERE user_id = ? AND is_read = 0";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt(1);
                }
            }
        }
        return 0;
    }

    public int save(Notification notif) throws SQLException {
        String sql = "INSERT INTO notifications (user_id, type, title, message, action_url, is_read, created_at) VALUES (?, ?, ?, ?, ?, ?, GETDATE())";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, notif.getUserId());
            ps.setString(2, notif.getType());
            ps.setString(3, notif.getTitle());
            ps.setString(4, notif.getMessage());
            ps.setString(5, notif.getActionUrl());
            ps.setBoolean(6, notif.getIsRead());
            
            int rows = ps.executeUpdate();
            if (rows > 0) {
                try (ResultSet rs = ps.getGeneratedKeys()) {
                    if (rs.next()) {
                        return rs.getInt(1);
                    }
                }
            }
        }
        return 0;
    }

    public boolean hasUnreadChatNotification(int userId, int sessionId) throws SQLException {
        String sql = "SELECT COUNT(*) FROM notifications WHERE user_id = ? AND is_read = 0 AND action_url LIKE ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ps.setString(2, "%sessionId=" + sessionId + "%");
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt(1) > 0;
                }
            }
        }
        return false;
    }

    public void markRead(int notifId) throws SQLException {
        String sql = "UPDATE notifications SET is_read = 1 WHERE notification_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, notifId);
            ps.executeUpdate();
        }
    }

    public int markRead(int notifId, int userId) throws SQLException {
        String sql = "UPDATE notifications SET is_read = 1 WHERE notification_id = ? AND user_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, notifId);
            ps.setInt(2, userId);
            return ps.executeUpdate();
        }
    }

    public List<Notification> findAllSystemNotifications() throws SQLException {
        List<Notification> list = new ArrayList<>();
        String sql = "SELECT * FROM notifications WHERE type = 'SYSTEM' ORDER BY created_at DESC";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    public List<Notification> findAllSystemNotifications(int page, int pageSize) throws SQLException {
        List<Notification> list = new ArrayList<>();
        String sql = "SELECT * FROM notifications WHERE type = 'SYSTEM' ORDER BY created_at DESC, notification_id DESC "
                + PaginationHelper.OFFSET_FETCH_SQL;
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            PaginationHelper.bindOffsetFetch(ps, 1, page, pageSize);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    public int countAllSystemNotifications() throws SQLException {
        String sql = "SELECT COUNT(*) FROM notifications WHERE type = 'SYSTEM'";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            if (rs.next()) {
                return rs.getInt(1);
            }
        }
        return 0;
    }

    public void insertForRole(String title, String message, String role) throws SQLException {
        String sql = "INSERT INTO notifications (user_id, title, message, type, is_read, created_at) " +
                     "SELECT user_id, ?, ?, 'SYSTEM', 0, GETDATE() FROM users WHERE role = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, title);
            ps.setString(2, message);
            ps.setString(3, role);
            ps.executeUpdate();
        }
    }

    public void markAllRead(int userId) throws SQLException {
        String sql = "UPDATE notifications SET is_read = 1 WHERE user_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ps.executeUpdate();
        }
    }

    public void insertForAll(String title, String message) throws SQLException {
        String sql = "INSERT INTO notifications (user_id, title, message, type, is_read, created_at) " +
                     "SELECT user_id, ?, ?, 'SYSTEM', 0, GETDATE() FROM users";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, title);
            ps.setString(2, message);
            ps.executeUpdate();
        }
    }

    private Notification mapRow(ResultSet rs) throws SQLException {
        Notification n = new Notification();
        n.setNotificationId(rs.getInt("notification_id"));
        n.setUserId(rs.getInt("user_id"));
        n.setType(rs.getString("type"));
        n.setTitle(rs.getString("title"));
        n.setMessage(rs.getString("message"));
        
        // Patch for legacy /customer/orders links
        String actionUrl = rs.getString("action_url");
        if ("/customer/orders".equals(actionUrl)) {
            actionUrl = "/profile?tab=orders"; // fallback
            String msg = n.getMessage();
            if (msg != null) {
                java.util.regex.Matcher m = java.util.regex.Pattern.compile("#(\\d+)").matcher(msg);
                if (m.find()) {
                    actionUrl = "/profile/order-detail?orderId=" + m.group(1);
                }
            }
        }
        n.setActionUrl(actionUrl);
        n.setIsRead(rs.getBoolean("is_read"));
        
        Timestamp createdAt = rs.getTimestamp("created_at");
        if (createdAt != null) {
            n.setCreatedAt(createdAt.toLocalDateTime());
        }
        
        
        
        
        
        
        
        
        
        return n;
    }

    public void delete(int notifId) throws SQLException {
        String sql = "DELETE FROM notifications WHERE notification_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, notifId);
            ps.executeUpdate();
        }
    }

    public int delete(int notifId, int userId) throws SQLException {
        String sql = "DELETE FROM notifications WHERE notification_id = ? AND user_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, notifId);
            ps.setInt(2, userId);
            return ps.executeUpdate();
        }
    }

    public Integer findUserIdByNotificationId(int notifId) throws SQLException {
        String sql = "SELECT user_id FROM notifications WHERE notification_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, notifId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt("user_id");
                }
            }
        }
        return null;
    }

    /**
     * Checks if a notification of a specific type containing a keyword in the message
     * has already been sent to the user. Used to prevent duplicate alerts.
     */
    public boolean isNotificationSent(int userId, String type, String messageLike) throws SQLException {
        String sql = "SELECT COUNT(*) FROM notifications WHERE user_id = ? AND type = ? AND message LIKE ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, userId);
            ps.setString(2, type);
            ps.setString(3, messageLike);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt(1) > 0;
                }
            }
        }
        return false;
    }
}
