package service.system;

import config.AppConfig;
import dao.system.SystemConfigDAO;
import dao.auth.UserDAO;
import model.entity.auth.User;
import util.LoggerUtil;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Connection;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;
import java.util.logging.Logger;

/**
 * SystemConfigService — Quản lý cấu hình hệ thống (Platform fee, freeze days, etc.)
 */
public class SystemConfigService {

    private static final Logger log = LoggerUtil.getLogger(SystemConfigService.class);

    private final SystemConfigDAO configDAO = new SystemConfigDAO();
    private final UserDAO userDAO = new UserDAO();
    private final EmailService emailService = new EmailService();

    private static final String LEGACY_PLATFORM_FEE_KEY = "platform_fee_rate";
    private static final String LEGACY_FREEZE_DAYS_KEY = "freeze_days";
    private static final String WEBSITE_LOGO_KEY = "WEBSITE_LOGO_URL";

    // Cache toàn bộ config map — tránh truy vấn DB mỗi request (platform fee, timeout, v.v.)
    private static final long CONFIG_CACHE_TTL_MS = 5 * 60 * 1000L; // 5 phút
    private static final Object CONFIG_LOCK = new Object();
    // AtomicReference đảm bảo swap map nguyên tử — không có torn-cache window
    private static final AtomicReference<Map<String, String>> configCacheRef
            = new AtomicReference<>(Collections.emptyMap());
    private static volatile long configCacheExpiry = 0;

    /** Lấy giá trị config theo key, phục vụ từ cache nếu còn hạn. */
    public String getValue(String key) throws SQLException {
        return ensureCache().get(key);
    }

    /** Lấy config dạng double, phục vụ từ cache. */
    public double getDouble(String key, double defaultVal) {
        try {
            String val = ensureCache().get(key);
            if (val == null || val.isBlank()) return defaultVal;
            return Double.parseDouble(val);
        } catch (Exception e) {
            return defaultVal;
        }
    }

    /** Lấy config dạng int, phục vụ từ cache. */
    public int getInt(String key, int defaultVal) {
        try {
            String val = ensureCache().get(key);
            if (val == null || val.isBlank()) return defaultVal;
            return Integer.parseInt(val);
        } catch (Exception e) {
            return defaultVal;
        }
    }

    private Map<String, String> ensureCache() throws SQLException {
        Map<String, String> current = configCacheRef.get();
        if (!current.isEmpty() && System.currentTimeMillis() <= configCacheExpiry) return current;
        synchronized (CONFIG_LOCK) {
            current = configCacheRef.get();
            if (!current.isEmpty() && System.currentTimeMillis() <= configCacheExpiry) return current;
            List<Map<String, Object>> rows = configDAO.findAll();
            Map<String, String> fresh = new HashMap<>(rows.size() * 2);
            for (Map<String, Object> row : rows) {
                Object k = row.get("config_key");
                Object v = row.get("config_value");
                if (k != null) fresh.put(k.toString(), v != null ? v.toString() : "");
            }
            // Swap toàn bộ map nguyên tử — không có khoảng trống rỗng/bán phần
            configCacheRef.set(Collections.unmodifiableMap(fresh));
            configCacheExpiry = System.currentTimeMillis() + CONFIG_CACHE_TTL_MS;
            return configCacheRef.get();
        }
    }

    private static void invalidateConfigCache() {
        synchronized (CONFIG_LOCK) {
            configCacheRef.set(Collections.emptyMap());
            configCacheExpiry = 0;
        }
    }

    public List<Map<String, Object>> findAll() throws SQLException {
        return configDAO.findAll();
    }

    public List<Map<String, Object>> getHistory(String key, int limit) throws SQLException {
        return configDAO.getHistory(key, limit);
    }

    /**
     * Cập nhật cấu hình hệ thống và gửi email thông báo cho shop nếu có tăng phí / thay đổi quan trọng.
     */
    public void updateConfig(String key, String newValue, LocalDateTime effectiveDate, int changedBy, String reason) throws SQLException {
        String normalizedKey = normalizeKey(key);
        String normalizedValue = normalizeValue(normalizedKey, newValue);

        if (effectiveDate == null) {
            effectiveDate = LocalDateTime.now();
        }
        if (effectiveDate.isBefore(LocalDateTime.now().minusMinutes(5))) {
            throw new IllegalArgumentException("Effective date cannot be in the past");
        }
        if (changedBy <= 0) {
            throw new IllegalArgumentException("Người cập nhật không hợp lệ.");
        }
        if (reason == null || reason.trim().isEmpty()) {
            reason = "Cập nhật cấu hình hệ thống";
        }

        try (Connection conn = configDAO.openConnection()) {
            conn.setAutoCommit(false);
            try {
                String oldValue = configDAO.getValue(normalizedKey);
                configDAO.updateConfigWithHistory(conn, normalizedKey, normalizedValue, effectiveDate, changedBy, reason);
                conn.commit();
                invalidateConfigCache(); // Xóa cache ngay sau khi commit thành công

                // Nếu đổi platform_fee_rate hoặc freeze_days, gửi thông báo cho các Shop
                if (isFeeKey(normalizedKey) || isFreezeDaysKey(normalizedKey)) {
                    notifyShopsOfFeeChange(normalizedKey, oldValue, normalizedValue, effectiveDate, reason);
                }
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            } catch (RuntimeException e) {
                conn.rollback();
                throw e;
            }
        }
    }

    private String normalizeKey(String key) {
        if (key == null || key.trim().isEmpty()) {
            throw new IllegalArgumentException("Config key không được để trống.");
        }
        return key.trim();
    }

    private String normalizeValue(String key, String rawValue) {
        String value = rawValue == null ? "" : rawValue.trim();
        if (isFeeKey(key)) {
            return normalizeFeeValue(value);
        }
        if (isFreezeDaysKey(key)) {
            return normalizePositiveIntValue(value, 1, 3650, "Số ngày đóng băng không hợp lệ.");
        }
        if (isAcceptTimeoutKey(key)) {
            return normalizePositiveIntValue(value, 1, 1440, "Thời gian chấp nhận đơn không hợp lệ.");
        }
        if (isReturnHoursKey(key)) {
            return normalizePositiveIntValue(value, 1, 744, "Thời gian gửi yêu cầu đổi trả không hợp lệ.");
        }
        if (isLogoKey(key)) {
            if (value.isEmpty()) {
                return "";
            }
            validateLogoUrl(value);
            return value;
        }
        if (isGeminiKey(key)) {
            return value;
        }
        if (value.isEmpty()) {
            throw new IllegalArgumentException("Giá trị cấu hình không được để trống.");
        }
        return value;
    }

    private String normalizeFeeValue(String value) {
        if (value.isEmpty()) {
            throw new IllegalArgumentException("Tỷ lệ phí nền tảng không được để trống.");
        }
        try {
            BigDecimal rate = new BigDecimal(value);
            if (rate.compareTo(BigDecimal.ZERO) <= 0) {
                throw new IllegalArgumentException("Tỷ lệ phí nền tảng phải lớn hơn 0.");
            }
            if (rate.compareTo(new BigDecimal("100")) > 0) {
                throw new IllegalArgumentException("Tỷ lệ phí nền tảng không được vượt quá 100%.");
            }
            if (rate.compareTo(BigDecimal.ONE) > 0) {
                rate = rate.divide(new BigDecimal("100"), 6, RoundingMode.HALF_UP);
            }
            return rate.stripTrailingZeros().toPlainString();
        } catch (NumberFormatException ex) {
            throw new IllegalArgumentException("Tỷ lệ phí nền tảng không hợp lệ.", ex);
        }
    }

    private String normalizePositiveIntValue(String value, int min, int max, String message) {
        if (value.isEmpty()) {
            throw new IllegalArgumentException(message);
        }
        try {
            int number = Integer.parseInt(value);
            if (number < min || number > max) {
                throw new IllegalArgumentException(message);
            }
            return String.valueOf(number);
        } catch (NumberFormatException ex) {
            throw new IllegalArgumentException(message, ex);
        }
    }

    private void validateLogoUrl(String value) {
        if (value.contains(" ")) {
            throw new IllegalArgumentException("Đường dẫn logo không hợp lệ.");
        }
        if (value.startsWith("/")) {
            return;
        }
        if (value.startsWith("http://") || value.startsWith("https://")) {
            return;
        }
        throw new IllegalArgumentException("Đường dẫn logo phải là URL hợp lệ hoặc đường dẫn tương đối bắt đầu bằng '/'.");
    }

    private boolean isFeeKey(String key) {
        return LEGACY_PLATFORM_FEE_KEY.equalsIgnoreCase(key)
                || AppConfig.CONFIG_PLATFORM_FEE_RATE.equalsIgnoreCase(key);
    }

    private boolean isFreezeDaysKey(String key) {
        return LEGACY_FREEZE_DAYS_KEY.equalsIgnoreCase(key)
                || AppConfig.CONFIG_FREEZE_DAYS.equalsIgnoreCase(key);
    }

    private boolean isAcceptTimeoutKey(String key) {
        return AppConfig.CONFIG_ACCEPT_TIMEOUT_MIN.equalsIgnoreCase(key);
    }

    private boolean isReturnHoursKey(String key) {
        return AppConfig.CONFIG_RETURN_MAX_HOURS.equalsIgnoreCase(key);
    }

    private boolean isLogoKey(String key) {
        return WEBSITE_LOGO_KEY.equalsIgnoreCase(key);
    }

    private boolean isGeminiKey(String key) {
        return AppConfig.CONFIG_GEMINI_API_KEY.equalsIgnoreCase(key)
                || AppConfig.CONFIG_GEMINI_MODEL.equalsIgnoreCase(key);
    }

    private void notifyShopsOfFeeChange(String key, String oldValue, String newValue, LocalDateTime effectiveDate, String reason) {
        try {
            List<User> activeShops = userDAO.findActiveShopOwners();
            String configName = isFeeKey(key) ? "Tỷ lệ phí nền tảng (Platform Fee Rate)" : "Thời gian đóng băng tiền quyết toán (Freeze Days)";
            String unit = isFeeKey(key) ? "%" : " ngày";
            
            // Format values for display
            String oldValStr = oldValue != null ? oldValue : "N/A";
            String newValStr = newValue != null ? newValue : "N/A";
            if (isFeeKey(key)) {
                try {
                    oldValStr = String.valueOf(new BigDecimal(oldValStr).multiply(new BigDecimal("100")).stripTrailingZeros().toPlainString());
                    newValStr = String.valueOf(new BigDecimal(newValStr).multiply(new BigDecimal("100")).stripTrailingZeros().toPlainString());
                } catch (NumberFormatException e) {
                    LoggerUtil.warn(log, "Could not format fee values for display: oldVal=%s newVal=%s", oldValStr, newValStr);
                }
            }

            String dateStr = effectiveDate.format(DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm"));
            String subject = "[Thông báo Quan trọng] Thay đổi chính sách phí gian hàng " + configName;
            
            for (User shop : activeShops) {
                String emailBody = buildFeeChangeEmail(shop.getFullName(), configName, oldValStr, newValStr, unit, dateStr, reason);
                try {
                    emailService.sendHtml(shop.getEmail(), subject, emailBody);
                } catch (Exception e) {
                    LoggerUtil.warn(log, "Failed to send fee change email to shop " + shop.getEmail(), e);
                }
            }
        } catch (Exception e) {
            LoggerUtil.warn(log, "Failed to notify shops of fee change", e);
        }
    }

    private static String escHtml(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#x27;");
    }

    private String buildFeeChangeEmail(String shopName, String configName, String oldVal, String newVal, String unit, String effectiveDate, String reason) {
        return "<div style='font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;'>"
             + "  <h2 style='color: #d32f2f; border-bottom: 2px solid #d32f2f; padding-bottom: 10px;'>Thông Báo Thay Đổi Chính Sách Phí</h2>"
             + "  <p>Kính gửi quý chủ gian hàng <strong>" + escHtml(shopName) + "</strong>,</p>"
             + "  <p>Ban quản trị sàn <strong>FruitMarket</strong> xin thông báo về việc điều chỉnh cấu hình hệ thống liên quan đến phí và quyết toán cụ thể như sau:</p>"
             + "  <table style='width: 100%; border-collapse: collapse; margin: 20px 0;'>"
             + "    <tr style='background-color: #f9f9f9;'>"
             + "      <td style='padding: 10px; border: 1px solid #ddd; font-weight: bold;'>Hạng mục thay đổi</td>"
             + "      <td style='padding: 10px; border: 1px solid #ddd;'>" + escHtml(configName) + "</td>"
             + "    </tr>"
             + "    <tr>"
             + "      <td style='padding: 10px; border: 1px solid #ddd; font-weight: bold;'>Giá trị cũ</td>"
             + "      <td style='padding: 10px; border: 1px solid #ddd; color: #777; text-decoration: line-through;'>" + escHtml(oldVal) + escHtml(unit) + "</td>"
             + "    </tr>"
             + "    <tr style='background-color: #fffde7;'>"
             + "      <td style='padding: 10px; border: 1px solid #ddd; font-weight: bold;'>Giá trị mới áp dụng</td>"
             + "      <td style='padding: 10px; border: 1px solid #ddd; color: #d32f2f; font-weight: bold;'>" + escHtml(newVal) + escHtml(unit) + "</td>"
             + "    </tr>"
             + "    <tr>"
             + "      <td style='padding: 10px; border: 1px solid #ddd; font-weight: bold;'>Thời gian có hiệu lực</td>"
             + "      <td style='padding: 10px; border: 1px solid #ddd; font-weight: bold; color: #388e3c;'>" + escHtml(effectiveDate) + "</td>"
             + "    </tr>"
             + "    <tr style='background-color: #f9f9f9;'>"
             + "      <td style='padding: 10px; border: 1px solid #ddd; font-weight: bold;'>Lý do thay đổi</td>"
             + "      <td style='padding: 10px; border: 1px solid #ddd; font-style: italic;'>" + escHtml(reason) + "</td>"
             + "    </tr>"
             + "  </table>"
             + "  <p style='background-color: #fff3e0; border-left: 4px solid #ff9800; padding: 15px; border-radius: 4px;'>"
             + "    <strong>Lưu ý:</strong> Mọi đơn hàng được tạo trước thời điểm hiệu lực nêu trên sẽ áp dụng mức phí cũ. Các đơn hàng tạo từ thời điểm hiệu lực trở đi sẽ tự động áp dụng mức phí mới."
             + "  </p>"
             + "  <p>Nếu quý chủ gian hàng có bất kỳ thắc mắc nào, vui lòng liên hệ bộ phận hỗ trợ đối tác của FruitMarket để được giải đáp.</p>"
             + "  <p style='margin-top: 30px; border-top: 1px solid #eee; padding-top: 20px; font-size: 0.9em; color: #666;'>"
             + "    Trân trọng,<br/>"
             + "    <strong>Ban Quản Trị FruitMarket</strong>"
             + "  </p>"
             + "</div>";
    }
}
