package servlet.shop.product;

import service.catalog.InventoryService;
import config.AppConfig;
import util.SessionUtil;
import dao.catalog.ProductDAO;
import dao.catalog.ProductVariantDAO;
import model.entity.catalog.Product;
import model.entity.catalog.ProductVariant;
import model.entity.catalog.InventoryLog;
import model.entity.auth.User;
import util.LoggerUtil;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.logging.Logger;

/**
 * InventoryServlet — Controller for Restock Management and inventory logs.
 * URL: /shop/inventory
 */
@WebServlet("/shop/inventory")
public class InventoryServlet extends HttpServlet {

    private static final Logger log = Logger.getLogger(InventoryServlet.class.getName());
    private static final int RESTOCK_HISTORY_LIMIT = 50;

    private final InventoryService inventoryService = new InventoryService();
    private final ProductDAO productDAO = new ProductDAO();
    private final ProductVariantDAO productVariantDAO = new ProductVariantDAO();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        req.setCharacterEncoding("UTF-8");
        resp.setContentType("text/html;charset=UTF-8");

        HttpSession session = req.getSession();
        User currentUser = SessionUtil.getCurrentUser(session);
        if (currentUser == null || !AppConfig.ROLE_SHOP_OWNER.equals(currentUser.getRole())) {
            resp.sendRedirect(req.getContextPath() + "/auth/login");
            return;
        }

        List<Map<String, Object>> variantsWithProduct = new ArrayList<>();
        List<InventoryLog> history = new ArrayList<>();
        String errorMsg = null;
        try {
            // 1. Fetch variants belonging to products of this shop owner in a single joined query (Optimized)
            variantsWithProduct = productVariantDAO.findVariantsWithOwnerDetails(currentUser.getUserId());

            // 2. Fetch past restock history logs
            history = inventoryService.getRestockHistory(currentUser.getUserId(), RESTOCK_HISTORY_LIMIT);

            // 3. Fetch all active batches (no limit)
            List<InventoryLog> activeBatches = inventoryService.getActiveBatches(currentUser.getUserId());
            
            // Group active batches by variant_id
            Map<Integer, List<InventoryLog>> batchesByVariant = new HashMap<>();
            if (activeBatches != null) {
                for (InventoryLog batch : activeBatches) {
                    if (batch.getRemainingQuantity() > 0) {
                        batchesByVariant.computeIfAbsent(batch.getVariantId(), k -> new ArrayList<>()).add(batch);
                    }
                }
            }

            StringBuilder batchesJsonSb = new StringBuilder("{\n");
            boolean firstVariant = true;
            for (Map<String, Object> vMap : variantsWithProduct) {
                int variantId = (Integer) vMap.get("variantId");
                int stockQuantity = (Integer) vMap.get("stockQuantity");
                Integer shelfLifeDays = (Integer) vMap.get("shelfLifeDays");

                List<InventoryLog> vBatches = batchesByVariant.get(variantId);
                List<InventoryLog> filteredBatches = new ArrayList<>();
                if (vBatches != null && !vBatches.isEmpty()) {
                    filteredBatches.addAll(vBatches);
                } else if (stockQuantity > 0) {
                    // Tự động khởi tạo lô ảo từ tồn kho hiện tại của variant nếu chưa có log nhập kho
                    InventoryLog fallbackBatch = new InventoryLog();
                    fallbackBatch.setLogId(0);
                    fallbackBatch.setVariantId(variantId);
                    fallbackBatch.setRemainingQuantity(stockQuantity);
                    if (shelfLifeDays != null && shelfLifeDays > 0) {
                        fallbackBatch.setExpiresAt(LocalDate.now().plusDays(shelfLifeDays));
                    }
                    fallbackBatch.setNote("Lô kho hiện tại");
                    filteredBatches.add(fallbackBatch);
                }
                vMap.put("batches", filteredBatches);

                if (!firstVariant) batchesJsonSb.append(",\n");
                firstVariant = false;
                batchesJsonSb.append('"').append(variantId).append("\": [");
                boolean firstBatch = true;
                for (InventoryLog batch : filteredBatches) {
                    if (!firstBatch) batchesJsonSb.append(',');
                    firstBatch = false;
                    String hsd = batch.getFormattedExpiresAt();
                    if (hsd == null || hsd.isEmpty()) hsd = "Kh\u00f4ng c\u00f3 HSD";
                    hsd = hsd.replace("\\", "\\\\").replace("\"", "\\\"");

                    batchesJsonSb.append('{');
                    batchesJsonSb.append("\"logId\":").append(batch.getLogId()).append(',');
                    batchesJsonSb.append("\"remainingQuantity\":").append(batch.getRemainingQuantity()).append(',');
                    batchesJsonSb.append("\"expiresAt\":\"").append(hsd).append('"');
                    batchesJsonSb.append('}');
                }
                batchesJsonSb.append(']');
            }
            batchesJsonSb.append("\n}");
            req.setAttribute("batchesJson", batchesJsonSb.toString());

        } catch (SQLException e) {
            LoggerUtil.error(log, "Không thể tải danh sách sản phẩm hoặc lịch sử nhập kho", e);
            errorMsg = util.ErrorMessageUtil.MSG_DB_ERROR;
        }

        if (errorMsg != null) {
            req.setAttribute("inventoryError", errorMsg);
        }

        // 4. Retrieve form preservation flash parameters on error
        String flashActionType = (String) session.getAttribute("flash_actionType");
        if (flashActionType != null) {
            req.setAttribute("oldActionType", flashActionType);
            req.setAttribute("oldVariantId", session.getAttribute("flash_variantId"));
            req.setAttribute("oldQuantity", session.getAttribute("flash_quantity"));
            req.setAttribute("oldExpiresAt", session.getAttribute("flash_expiresAt"));
            req.setAttribute("oldNote", session.getAttribute("flash_note"));

            session.removeAttribute("flash_actionType");
            session.removeAttribute("flash_variantId");
            session.removeAttribute("flash_quantity");
            session.removeAttribute("flash_expiresAt");
            session.removeAttribute("flash_note");
        }

        // Set request attributes
        req.setAttribute("variants", variantsWithProduct);
        req.setAttribute("restockLogs", history);

        // Forward to inventory JSP page
        req.getRequestDispatcher("/WEB-INF/jsp/shop/inventory.jsp").forward(req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        req.setCharacterEncoding("UTF-8");

        HttpSession session = req.getSession();
        User currentUser = SessionUtil.getCurrentUser(session);
        if (currentUser == null || !AppConfig.ROLE_SHOP_OWNER.equals(currentUser.getRole())) {
            resp.sendRedirect(req.getContextPath() + "/auth/login");
            return;
        }

        // 1. Read parameters
        String variantIdStr = req.getParameter("variantId");
        String quantityStr = req.getParameter("quantity");
        String note = req.getParameter("note");
        String actionType = req.getParameter("actionType");
        String expiresAtStr = req.getParameter("expiresAt");
        String batchIdStr = req.getParameter("batchId");
        if (actionType == null || actionType.trim().isEmpty()) {
            actionType = "RESTOCK";
        }

        // 2. Validation
        if (variantIdStr == null || variantIdStr.trim().isEmpty() ||
                quantityStr == null || quantityStr.trim().isEmpty()) {
            saveFlashParams(session, actionType, variantIdStr, quantityStr, expiresAtStr, note);
            SessionUtil.flashError(session, "Vui lòng nhập đầy đủ các trường bắt buộc.");
            resp.sendRedirect(req.getContextPath() + "/shop/inventory");
            return;
        }

        int variantId;
        int quantity;
        // changedAt luôn lấy ngày hôm nay
        LocalDate changedAt = LocalDate.now();
        LocalDate expiresAt = null;

        if (expiresAtStr != null && !expiresAtStr.trim().isEmpty()) {
            try {
                expiresAt = LocalDate.parse(expiresAtStr.trim());
                if (!"REDUCE".equals(actionType) && expiresAt.isBefore(LocalDate.now())) {
                    saveFlashParams(session, actionType, variantIdStr, quantityStr, expiresAtStr, note);
                    SessionUtil.flashError(session, "Ngày hết hạn không được là ngày trong quá khứ.");
                    resp.sendRedirect(req.getContextPath() + "/shop/inventory");
                    return;
                }
            } catch (java.time.format.DateTimeParseException e) {
                saveFlashParams(session, actionType, variantIdStr, quantityStr, expiresAtStr, note);
                SessionUtil.flashError(session, "Ngày hết hạn không đúng định dạng yyyy-MM-dd.");
                resp.sendRedirect(req.getContextPath() + "/shop/inventory");
                return;
            }
        }

        try {
            variantId = Integer.parseInt(variantIdStr);
            quantity = Integer.parseInt(quantityStr);
        } catch (NumberFormatException e) {
            saveFlashParams(session, actionType, variantIdStr, quantityStr, expiresAtStr, note);
            SessionUtil.flashError(session, "Mã sản phẩm hoặc số lượng không hợp lệ.");
            resp.sendRedirect(req.getContextPath() + "/shop/inventory");
            return;
        }

        if (quantity <= 0) {
            saveFlashParams(session, actionType, variantIdStr, quantityStr, expiresAtStr, note);
            SessionUtil.flashError(session, "Số lượng phải lớn hơn 0.");
            resp.sendRedirect(req.getContextPath() + "/shop/inventory");
            return;
        }

        try {
            // 3. Security check: Verify that this variant belongs to a product owned by the
            // current Shop Owner
            ProductVariant pv = productVariantDAO.findById(variantId);
            if (pv == null) {
                saveFlashParams(session, actionType, variantIdStr, quantityStr, expiresAtStr, note);
                SessionUtil.flashError(session, "Biến thể sản phẩm không tồn tại.");
                resp.sendRedirect(req.getContextPath() + "/shop/inventory");
                return;
            }

            List<Product> products = productDAO.findById(pv.getProductId());
            if (products.isEmpty() || products.get(0).getOwnerId() != currentUser.getUserId()) {
                saveFlashParams(session, actionType, variantIdStr, quantityStr, expiresAtStr, note);
                SessionUtil.flashError(session, "Bạn không có quyền thay đổi kho cho sản phẩm này.");
                resp.sendRedirect(req.getContextPath() + "/shop/inventory");
                return;
            }

            // 4. Call Service to execute transaction
            if ("REDUCE".equals(actionType)) {
                if (note == null || note.trim().isEmpty()) {
                    saveFlashParams(session, actionType, variantIdStr, quantityStr, expiresAtStr, note);
                    SessionUtil.flashError(session, "Vui lòng nhập lý do giảm kho vào ghi chú.");
                    resp.sendRedirect(req.getContextPath() + "/shop/inventory");
                    return;
                }
                int batchId = 0;
                if (batchIdStr != null && !batchIdStr.trim().isEmpty()) {
                    try {
                        batchId = Integer.parseInt(batchIdStr);
                    } catch (NumberFormatException e) {
                        // ignore
                    }
                }
                inventoryService.manualAdjust(variantId, -quantity, note, currentUser.getUserId(), batchId);
                SessionUtil.flashSuccess(session, "Cập nhật giảm tồn kho thành công!");
            } else {
                inventoryService.restockWithExpiry(variantId, quantity, note, changedAt, expiresAt,
                        currentUser.getUserId());
                SessionUtil.flashSuccess(session, "Nhập kho sản phẩm thành công!");
            }

        } catch (SQLException e) {
            saveFlashParams(session, actionType, variantIdStr, quantityStr, expiresAtStr, note);
            LoggerUtil.error(log, "Lỗi cơ sở dữ liệu khi điều chỉnh kho", e);
            SessionUtil.flashError(session, util.ErrorMessageUtil.MSG_DB_ERROR);
        } catch (IllegalArgumentException e) {
            saveFlashParams(session, actionType, variantIdStr, quantityStr, expiresAtStr, note);
            SessionUtil.flashError(session, util.ErrorMessageUtil.getUserMessage(e));
        } catch (Exception e) {
            saveFlashParams(session, actionType, variantIdStr, quantityStr, expiresAtStr, note);
            LoggerUtil.error(log, "Lỗi không xác định khi điều chỉnh kho", e);
            SessionUtil.flashError(session, "Đã xảy ra lỗi không xác định.");
        }

        // 5. Redirect (PRG Pattern)
        resp.sendRedirect(req.getContextPath() + "/shop/inventory");
    }

    private void saveFlashParams(HttpSession session, String actionType, String variantId, String quantity, String expiresAt, String note) {
        session.setAttribute("flash_actionType", actionType);
        session.setAttribute("flash_variantId", variantId);
        session.setAttribute("flash_quantity", quantity);
        session.setAttribute("flash_expiresAt", expiresAt);
        session.setAttribute("flash_note", note);
    }
}
