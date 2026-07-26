package service.catalog;

import dao.catalog.InventoryDAO;
import dao.catalog.ProductVariantDAO;
import dao.catalog.ProductDAO;
import model.entity.catalog.InventoryLog;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.logging.Logger;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import util.LoggerUtil;

/**
 * InventoryService — Tầng business logic cho nghiệp vụ tương ứng.
 *
 * @author fruitmkt-team
 */
public class InventoryService {

    private static final Logger log = LoggerUtil.getLogger(InventoryService.class);

    private final InventoryDAO inventoryDAO = new InventoryDAO();
    private final ProductVariantDAO productVariantDAO = new ProductVariantDAO();
    private final ProductDAO productDAO = new ProductDAO();

    /**
     * Thực hiện nghiệp vụ nhập kho (Restock) cho một biến thể sản phẩm.
     */
    public void restock(int variantId, int quantity, String note, LocalDate changedAt, int userId) throws SQLException {
        restockWithExpiry(variantId, quantity, note, changedAt, null, userId);
    }

    /**
     * Nhập kho kèm theo ngày hết hạn (Expires At) tùy chọn.
     * Nếu không cung cấp expiresAt và sản phẩm có shelf_life_days, sẽ tự tính:
     *   expiresAt = today + shelf_life_days
     * Validation:
     *   - quantity > 0
     *   - changedAt không được là ngày tương lai
     *   - expiresAt (sau khi tính) không được trước changedAt
     *   - expiresAt không được vượt quá today + shelf_life_days
     */
    public void restockWithExpiry(int variantId, int quantity, String note,
                                   LocalDate changedAt, LocalDate expiresAt, int userId) throws SQLException {
        if (quantity <= 0) {
            throw new IllegalArgumentException("Số lượng nhập kho phải lớn hơn 0.");
        }
        if (changedAt == null) {
            throw new IllegalArgumentException("Ngày nhập kho không được để trống.");
        }
        if (changedAt.isAfter(LocalDate.now())) {
            throw new IllegalArgumentException("Ngày nhập kho không thể là ngày trong tương lai.");
        }

        // Lấy shelf_life_days một lần cho cả auto-calc và validate
        Integer shelfLifeDays = inventoryDAO.getShelfLifeByVariantId(variantId);
        LocalDate maxExpiry = (shelfLifeDays != null && shelfLifeDays > 0)
                ? LocalDate.now().plusDays(shelfLifeDays) : null;

        // Tự động tính expiresAt = today + shelf_life_days nếu người dùng không nhập
        if (expiresAt == null && maxExpiry != null) {
            expiresAt = maxExpiry;
            log.info("[Inventory] Auto-set expiresAt = " + expiresAt + " cho variant " + variantId);
        }

        // Validate expiresAt nếu có (kể cả sau khi auto-calc)
        if (expiresAt != null) {
            if (expiresAt.isBefore(changedAt)) {
                throw new IllegalArgumentException("Ngày hết hạn không thể trước ngày nhập kho.");
            }
            if (expiresAt.isBefore(LocalDate.now())) {
                throw new IllegalArgumentException("Ngày hết hạn không được là ngày trong quá khứ.");
            }
            if (maxExpiry != null && expiresAt.isAfter(maxExpiry)) {
                throw new IllegalArgumentException(
                    "Ngày hết hạn không được vượt quá " + shelfLifeDays
                    + " ngày kể từ hôm nay (tối đa: "
                    + maxExpiry.format(java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy"))
                    + ").");
            }
        }

        try (Connection conn = inventoryDAO.openConnection()) {
            conn.setAutoCommit(false);
            try {
                // 1. Lấy số lượng tồn kho hiện tại (trong transaction)
                int currentStock = productVariantDAO.getStockQuantity(conn, variantId);
                int stockAfter = currentStock + quantity;

                // 2. Ghi nhận lịch sử thay đổi tồn kho kèm hạn dùng
                InventoryLog logEntry = new InventoryLog();
                logEntry.setVariantId(variantId);
                logEntry.setChangedBy(userId);
                logEntry.setChangeType("MANUAL_ADJUST");
                logEntry.setQuantityDelta(quantity);
                logEntry.setQuantityAfter(stockAfter);
                logEntry.setExpiresAt(expiresAt);
                logEntry.setExpired(false);
                logEntry.setRemainingQuantity(quantity); // full qty available in this batch
                logEntry.setNote(note != null && !note.trim().isEmpty() ? note.trim() : "Nhập kho");
                logEntry.setChangedAt(changedAt.atTime(LocalTime.now()));

                inventoryDAO.save(conn, logEntry);

                // 3. Cập nhật tồn kho thực tế
                productVariantDAO.updateStock(conn, variantId, quantity);

                // 4. Cập nhật ngày thu hoạch và trạng thái sản phẩm sang ACTIVE
                int productId = productVariantDAO.getProductId(conn, variantId);
                productDAO.updateHarvestDateAndStatus(conn, productId, changedAt, "ACTIVE");

                conn.commit();
            } catch (SQLException | RuntimeException e) {
                conn.rollback();
                throw e;
            } finally {
                conn.setAutoCommit(true);
            }
        }
    }

    /**
     * Lấy toàn bộ lịch sử biến động kho của Shop Owner.
     */
    public List<InventoryLog> getRestockHistory(int ownerId) throws SQLException {
        if (ownerId <= 0) {
            throw new IllegalArgumentException("Owner ID không hợp lệ.");
        }
        return inventoryDAO.findByOwner(ownerId);
    }

    public List<InventoryLog> getRestockHistory(int ownerId, int limit) throws SQLException {
        if (ownerId <= 0) {
            throw new IllegalArgumentException("Owner ID không hợp lệ.");
        }
        if (limit <= 0) {
            throw new IllegalArgumentException("Limit không hợp lệ.");
        }
        return inventoryDAO.findByOwner(ownerId, limit);
    }

    /**
     * Lấy shelf_life_days của sản phẩm thông qua variant_id — dùng cho Servlet để truyền xuống JSP.
     * Trả về null nếu không cấu hình.
     */
    public Integer getShelfLifeForVariant(int variantId) throws SQLException {
        return inventoryDAO.getShelfLifeByVariantId(variantId);
    }

    /**
     * Lấy danh sách lô hàng nhập kho còn hiệu lực (chưa hết hạn / chưa bị đánh dấu expired).
     * Dùng cho bảng quản lý lô hàng / ngày hết hạn trên trang Tồn kho.
     */
    public List<InventoryLog> getActiveBatches(int ownerId) throws SQLException {
        if (ownerId <= 0) {
            throw new IllegalArgumentException("Owner ID không hợp lệ.");
        }
        return inventoryDAO.findActiveBatchesByOwner(ownerId);
    }

    public List<InventoryLog> getActiveBatches(int ownerId, int limit) throws SQLException {
        if (ownerId <= 0) {
            throw new IllegalArgumentException("Owner ID không hợp lệ.");
        }
        if (limit <= 0) {
            throw new IllegalArgumentException("Limit không hợp lệ.");
        }
        return inventoryDAO.findActiveBatchesByOwner(ownerId, limit);
    }

    public void reserve(Connection conn, int variantId, int qty, int orderId, int userId) throws SQLException {
        if (qty <= 0) return;

        // Trực tiếp cập nhật nguyên tử tồn kho và lấy ra tồn kho mới sau cập nhật
        int stockAfter;
        try {
            stockAfter = productVariantDAO.decrementStockQuantity(conn, variantId, qty);
        } catch (SQLException e) {
            throw new RuntimeException("Không đủ số lượng hàng tồn kho cho sản phẩm.");
        }

        // FIFO deduction from active batches in database
        int qtyNeeded = qty;
        List<InventoryLog> activeBatches = inventoryDAO.findActiveBatchesForVariant(conn, variantId);
        StringBuilder fifoDetails = new StringBuilder(" [FIFO: ");
        boolean first = true;
        for (InventoryLog batch : activeBatches) {
            if (qtyNeeded <= 0) break;
            int batchRemaining = batch.getRemainingQuantity();
            int deduct = Math.min(batchRemaining, qtyNeeded);
            inventoryDAO.updateRemainingQuantity(conn, batch.getLogId(), batchRemaining - deduct);
            qtyNeeded -= deduct;

            if (!first) {
                fifoDetails.append(", ");
            }
            fifoDetails.append("Lô #").append(batch.getLogId()).append(" (-").append(deduct).append(")");
            first = false;
        }
        fifoDetails.append("]");

        String fifoNote = "Giữ hàng cho đơn hàng #" + orderId + (first ? "" : fifoDetails.toString());

        InventoryLog logEntry = new InventoryLog();
        logEntry.setVariantId(variantId);
        logEntry.setChangedBy(userId);
        logEntry.setChangeType("ORDER_RESERVE");
        logEntry.setQuantityDelta(-qty);
        logEntry.setQuantityAfter(stockAfter);
        logEntry.setNote(fifoNote);
        logEntry.setChangedAt(LocalDateTime.now());

        inventoryDAO.save(conn, logEntry);
        checkAndSendLowStockAlert(conn, variantId, stockAfter);
    }

    public void reserve(int variantId, int qty, int orderId) throws SQLException {
        try (Connection conn = inventoryDAO.openConnection()) {
            conn.setAutoCommit(false);
            try {
                reserve(conn, variantId, qty, orderId, 1);
                conn.commit();
            } catch (SQLException | RuntimeException e) {
                conn.rollback();
                throw e;
            } finally {
                conn.setAutoCommit(true);
            }
        }
    }

    public void restore(Connection conn, int variantId, int qty, int orderId, int userId) throws SQLException {
        if (qty <= 0) return;
        int currentStock = productVariantDAO.getStockQuantity(conn, variantId);
        int stockAfter = currentStock + qty;

        // Bóc tách ghi chú để hoàn lại remaining_quantity
        String reserveNote = inventoryDAO.findReserveLogNote(conn, orderId, variantId);
        if (reserveNote != null) {
            Pattern pattern = Pattern.compile("Lô #(\\d+) \\(-(\\d+)\\)");
            Matcher matcher = pattern.matcher(reserveNote);
            while (matcher.find()) {
                int batchLogId = Integer.parseInt(matcher.group(1));
                int deductQty = Integer.parseInt(matcher.group(2));
                inventoryDAO.incrementRemainingQuantity(conn, batchLogId, deductQty);
            }
        }

        InventoryLog logEntry = new InventoryLog();
        logEntry.setVariantId(variantId);
        logEntry.setChangedBy(userId);
        logEntry.setChangeType("ORDER_RELEASE");
        logEntry.setQuantityDelta(qty);
        logEntry.setQuantityAfter(stockAfter);
        logEntry.setNote("Hoàn kho từ đơn hàng #" + orderId);
        logEntry.setChangedAt(LocalDateTime.now());

        inventoryDAO.save(conn, logEntry);
        productVariantDAO.updateStock(conn, variantId, qty);
    }

    public void restore(int variantId, int qty, int orderId) throws SQLException {
        try (Connection conn = inventoryDAO.openConnection()) {
            conn.setAutoCommit(false);
            try {
                restore(conn, variantId, qty, orderId, 1);
                conn.commit();
            } catch (SQLException | RuntimeException e) {
                conn.rollback();
                throw e;
            } finally {
                conn.setAutoCommit(true);
            }
        }
    }

    public void confirm(Connection conn, int variantId, int qty, int orderId, int userId) throws SQLException {
        int currentStock = productVariantDAO.getStockQuantity(conn, variantId);
        InventoryLog logEntry = new InventoryLog();
        logEntry.setVariantId(variantId);
        logEntry.setChangedBy(userId);
        logEntry.setChangeType("ORDER_CONFIRM");
        logEntry.setQuantityDelta(0);  // Kho đã bị trừ từ bước ORDER_RESERVE, đây chỉ đánh dấu audit
        logEntry.setQuantityAfter(currentStock);
        logEntry.setNote("Giao hàng thành công - Đã bán " + qty + " sản phẩm từ đơn hàng #" + orderId);
        logEntry.setChangedAt(LocalDateTime.now());
        inventoryDAO.save(conn, logEntry);
    }

    public void confirm(int variantId, int qty, int orderId) throws SQLException {
        try (Connection conn = inventoryDAO.openConnection()) {
            confirm(conn, variantId, qty, orderId, 1);
        }
    }

    public void manualAdjust(int variantId, int delta, String note, int userId) throws SQLException {
        manualAdjust(variantId, delta, note, userId, 0);
    }

    public void manualAdjust(int variantId, int delta, String note, int userId, int batchId) throws SQLException {
        if (delta == 0) return;
        try (Connection conn = inventoryDAO.openConnection()) {
            conn.setAutoCommit(false);
            try {
                int currentStock = productVariantDAO.getStockQuantity(conn, variantId);
                int stockAfter = currentStock + delta;
                if (stockAfter < 0) {
                    throw new IllegalArgumentException("Số lượng tồn kho sau điều chỉnh không được âm.");
                }

                String finalNote = note != null ? note : "Điều chỉnh kho thủ công";
                if (delta < 0) {
                    int qtyToDeduct = Math.abs(delta);
                    if (batchId > 0) {
                        InventoryLog batch = inventoryDAO.findActiveBatchById(conn, batchId);
                        if (batch == null) {
                            throw new IllegalArgumentException("Lô hàng được chọn (Mã #" + batchId + ") không tồn tại hoặc đã hết hạn.");
                        }
                        if (batch.getRemainingQuantity() < qtyToDeduct) {
                            throw new IllegalArgumentException("Số lượng giảm (" + qtyToDeduct 
                                    + ") vượt quá số lượng tồn còn lại của Lô #" + batchId 
                                    + " (chỉ còn " + batch.getRemainingQuantity() + " sản phẩm).");
                        }
                        int newRem = batch.getRemainingQuantity() - qtyToDeduct;
                        inventoryDAO.updateRemainingQuantity(conn, batchId, newRem);
                        finalNote += " [Trừ lô #" + batchId + "]";
                    } else {
                        if (currentStock < qtyToDeduct) {
                            throw new IllegalArgumentException("Số lượng giảm (" + qtyToDeduct 
                                    + ") vượt quá số lượng tồn kho hiện tại (chỉ còn " + currentStock + " sản phẩm).");
                        }
                        // FIFO deduction across active batches
                        int qtyNeeded = qtyToDeduct;
                        List<InventoryLog> activeBatches = inventoryDAO.findActiveBatchesForVariant(conn, variantId);
                        for (InventoryLog b : activeBatches) {
                            if (qtyNeeded <= 0) break;
                            int bRem = b.getRemainingQuantity();
                            int deduct = Math.min(bRem, qtyNeeded);
                            inventoryDAO.updateRemainingQuantity(conn, b.getLogId(), bRem - deduct);
                            qtyNeeded -= deduct;
                        }
                    }
                }

                InventoryLog logEntry = new InventoryLog();
                logEntry.setVariantId(variantId);
                logEntry.setChangedBy(userId);
                logEntry.setChangeType("MANUAL_ADJUST");
                logEntry.setQuantityDelta(delta);
                logEntry.setQuantityAfter(stockAfter);
                logEntry.setNote(finalNote);
                logEntry.setChangedAt(LocalDateTime.now());

                inventoryDAO.save(conn, logEntry);
                productVariantDAO.updateStock(conn, variantId, delta);
                checkAndSendLowStockAlert(conn, variantId, stockAfter);
                conn.commit();
            } catch (SQLException | RuntimeException e) {
                conn.rollback();
                throw e;
            } finally {
                conn.setAutoCommit(true);
            }
        }
    }

    private void checkAndSendLowStockAlert(Connection conn, int variantId, int stockAfter) {
        try {
            int ownerId = productVariantDAO.getProductOwnerId(conn, variantId);
            int threshold = 5; // default
            String thresholdSql = "SELECT low_stock_threshold FROM shop_owner_profiles WHERE user_id = ?";
            try (PreparedStatement ps = conn.prepareStatement(thresholdSql)) {
                ps.setInt(1, ownerId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        threshold = rs.getInt("low_stock_threshold");
                    }
                }
            }

            if (stockAfter <= threshold) {
                java.util.Map<String, Object> info = productVariantDAO.getVariantAndProductName(conn, variantId);
                String sku = (String) info.get("sku");
                String productName = (String) info.get("name");

                service.chat.NotificationService notificationService = new service.chat.NotificationService();
                String title = "Cảnh báo tồn kho thấp";
                String message = "Sản phẩm \"" + productName + "\" (SKU: " + sku + ") sắp hết hàng. Chỉ còn " + stockAfter + " sản phẩm trong kho.";
                notificationService.send(ownerId, config.AppConfig.NOTIF_INVENTORY_ALERT, title, message, "/shop/products");
            }
        } catch (Exception ex) {
            LoggerUtil.warn(log, "Không thể gửi cảnh báo tồn kho thấp cho variantId=" + variantId, ex);
        }
    }

    /**
     * Nghiệp vụ hao hụt tồn kho do sản phẩm hết hạn (EXPIRED).
     * Sẽ giảm tồn kho và ghi log loại EXPIRED.
     */
    public void adjustStockForExpiry(int variantId, int qty, String note, int userId) throws SQLException {
        if (qty <= 0) {
            throw new IllegalArgumentException("Số lượng hao hụt do hết hạn phải lớn hơn 0.");
        }
        try (Connection conn = inventoryDAO.openConnection()) {
            conn.setAutoCommit(false);
            try {
                int currentStock = productVariantDAO.getStockQuantity(conn, variantId);
                int stockAfter = currentStock - qty;
                if (stockAfter < 0) {
                    throw new IllegalArgumentException("Số lượng hao hụt vượt quá số lượng tồn kho hiện tại.");
                }

                InventoryLog logEntry = new InventoryLog();
                logEntry.setVariantId(variantId);
                logEntry.setChangedBy(userId);
                logEntry.setChangeType(config.AppConfig.INVENTORY_CHANGE_EXPIRED);
                logEntry.setQuantityDelta(-qty);
                logEntry.setQuantityAfter(stockAfter);
                logEntry.setNote(note != null && !note.trim().isEmpty() ? note.trim() : "Hao hụt do hết hạn");
                logEntry.setChangedAt(LocalDateTime.now());

                inventoryDAO.save(conn, logEntry);
                productVariantDAO.updateStock(conn, variantId, -qty);
                checkAndSendLowStockAlert(conn, variantId, stockAfter);
                conn.commit();
            } catch (SQLException | RuntimeException e) {
                conn.rollback();
                throw e;
            } finally {
                conn.setAutoCommit(true);
            }
        }
    }

    /**
     * Nghiệp vụ hao hụt tồn kho do sản phẩm thối/hỏng (SPOILED).
     * Sẽ giảm tồn kho và ghi log loại SPOILED.
     */
    public void adjustStockForSpoilage(int variantId, int qty, String note, int userId) throws SQLException {
        if (qty <= 0) {
            throw new IllegalArgumentException("Số lượng hao hụt do thối hỏng phải lớn hơn 0.");
        }
        try (Connection conn = inventoryDAO.openConnection()) {
            conn.setAutoCommit(false);
            try {
                int currentStock = productVariantDAO.getStockQuantity(conn, variantId);
                int stockAfter = currentStock - qty;
                if (stockAfter < 0) {
                    throw new IllegalArgumentException("Số lượng hao hụt vượt quá số lượng tồn kho hiện tại.");
                }

                InventoryLog logEntry = new InventoryLog();
                logEntry.setVariantId(variantId);
                logEntry.setChangedBy(userId);
                logEntry.setChangeType(config.AppConfig.INVENTORY_CHANGE_SPOILED);
                logEntry.setQuantityDelta(-qty);
                logEntry.setQuantityAfter(stockAfter);
                logEntry.setNote(note != null && !note.trim().isEmpty() ? note.trim() : "Hao hụt do thối hỏng");
                logEntry.setChangedAt(LocalDateTime.now());

                inventoryDAO.save(conn, logEntry);
                productVariantDAO.updateStock(conn, variantId, -qty);
                checkAndSendLowStockAlert(conn, variantId, stockAfter);
                conn.commit();
            } catch (SQLException | RuntimeException e) {
                conn.rollback();
                throw e;
            } finally {
                conn.setAutoCommit(true);
            }
        }
    }

    /**
     * Tự động quét các lô hàng nhập kho đã hết hạn và tiến hành trừ kho,
     * sau đó lưu lịch sử biến động là EXPIRED.
     */
    public int processExpiredBatches() throws SQLException {
        int processedCount = 0;
        try (Connection conn = inventoryDAO.openConnection()) {
            conn.setAutoCommit(false);
            try {
                List<InventoryLog> expiredLogs = inventoryDAO.findExpiredLogs(conn);
                for (InventoryLog logEntry : expiredLogs) {
                    int variantId = logEntry.getVariantId();
                    int batchQty = logEntry.getQuantityDelta(); // Số lượng nhập ban đầu

                    // Lấy số lượng tồn kho hiện tại
                    int currentStock = productVariantDAO.getStockQuantity(conn, variantId);
                    if (currentStock <= 0) {
                        // Kho đã bằng 0, chỉ đánh dấu là đã xử lý
                        inventoryDAO.markLogExpired(conn, logEntry.getLogId());
                        processedCount++;
                        continue;
                    }

                    // Số lượng trừ đi không vượt quá tồn kho thực tế
                    int deductQty = Math.min(currentStock, batchQty);
                    int stockAfter = currentStock - deductQty;

                    // Ghi log biến động kho
                    InventoryLog expiryEntry = new InventoryLog();
                    expiryEntry.setVariantId(variantId);
                    expiryEntry.setChangedBy(logEntry.getChangedBy());
                    expiryEntry.setChangeType(config.AppConfig.INVENTORY_CHANGE_EXPIRED);
                    expiryEntry.setQuantityDelta(-deductQty);
                    expiryEntry.setQuantityAfter(stockAfter);
                    expiryEntry.setNote("Tự động trừ kho: Lô nhập #" + logEntry.getLogId() + " hết hạn ngày " + logEntry.getExpiresAt());
                    expiryEntry.setChangedAt(LocalDateTime.now());

                    inventoryDAO.save(conn, expiryEntry);

                    // Cập nhật số lượng tồn kho của variant
                    productVariantDAO.updateStock(conn, variantId, -deductQty);

                    // Đánh dấu log nhập kho đã xử lý hết hạn
                    inventoryDAO.markLogExpired(conn, logEntry.getLogId());
                    processedCount++;

                    // Gửi cảnh báo nếu tồn kho xuống thấp
                    checkAndSendLowStockAlert(conn, variantId, stockAfter);
                }
                conn.commit();
            } catch (SQLException | RuntimeException e) {
                conn.rollback();
                throw e;
            } finally {
                conn.setAutoCommit(true);
            }
        }
        return processedCount;
    }

    public List<InventoryLog> getLogs(int variantId) throws SQLException {
        if (variantId <= 0) {
            throw new IllegalArgumentException("Variant ID không hợp lệ.");
        }
        return inventoryDAO.findByVariant(variantId);
    }

    /**
     * Tự động quét các lô hàng sắp hết hạn dựa trên cấu hình warning threshold của từng Shop Owner
     * và tiến hành gửi cảnh báo thông báo (INVENTORY_ALERT) nếu chưa gửi.
     */
    public int processNearExpiryAlerts() throws SQLException {
        int alertCount = 0;
        String sql = "SELECT il.log_id, il.variant_id, il.expires_at, p.name AS product_name, p.owner_id, pv.variant_label, "
                   + "       ISNULL(sop.expiry_warning_days, 3) AS expiry_warning_days "
                   + "FROM inventory_logs il "
                   + "JOIN product_variants pv ON il.variant_id = pv.variant_id "
                   + "JOIN products p ON pv.product_id = p.product_id "
                   + "LEFT JOIN shop_owner_profiles sop ON p.owner_id = sop.user_id "
                   + "WHERE il.change_type = 'MANUAL_ADJUST' AND il.quantity_delta > 0 AND il.is_expired = 0 "
                   + "  AND il.expires_at IS NOT NULL AND il.expires_at > CAST(GETDATE() AS DATE) "
                   + "  AND il.expires_at <= DATEADD(day, ISNULL(sop.expiry_warning_days, 3), CAST(GETDATE() AS DATE))";

        dao.chat.NotificationDAO notificationDAO = new dao.chat.NotificationDAO();
        service.chat.NotificationService notificationService = new service.chat.NotificationService();

        try (Connection conn = inventoryDAO.openConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {
                int logId = rs.getInt("log_id");
                int ownerId = rs.getInt("owner_id");
                java.sql.Date expiresAt = rs.getDate("expires_at");
                String productName = rs.getString("product_name");
                String variantLabel = rs.getString("variant_label");

                String title = "Cảnh báo lô hàng sắp hết hạn";
                String message = "Lô hàng #" + logId + " của sản phẩm \"" + productName + "\" (Phân loại: " + variantLabel + ") sắp hết hạn vào ngày " + expiresAt + ". Vui lòng kiểm tra tồn kho.";

                // Check if already notified to avoid spamming the seller daily
                if (!notificationDAO.isNotificationSent(ownerId, config.AppConfig.NOTIF_INVENTORY_ALERT, "%Lô hàng #" + logId + "%")) {
                    notificationService.send(ownerId, config.AppConfig.NOTIF_INVENTORY_ALERT, title, message, "/shop/inventory");
                    alertCount++;
                }
            }
        }
        return alertCount;
    }
}
