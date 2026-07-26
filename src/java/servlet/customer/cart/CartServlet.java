package servlet.customer.cart;

import config.AppConfig;
import exception.BusinessException;
import model.dto.product.CartSummaryDTO;
import model.entity.auth.User;
import model.response.ApiResponse;
import service.cart.CartService;
import util.JsonUtil;
import util.SessionUtil;

import util.LoggerUtil;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.logging.Logger;

/**
 * CartServlet — Controller cho chức năng: Giỏ hàng
 *
 * URL: /cart
 * GET : Giỏ hàng: hiển thị items và tổng tiền
 * POST: Thêm/sửa/xóa item, sync guest cart, check stock
 *
 * @author fruitmkt-team
 */
@WebServlet("/cart")
public class CartServlet extends HttpServlet {

    private static final Logger log = Logger.getLogger(CartServlet.class.getName());

    private final CartService cartService = new CartService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        
        req.setCharacterEncoding("UTF-8");
        resp.setContentType("text/html;charset=UTF-8");

        HttpSession session = req.getSession();
        User user = SessionUtil.getCurrentUser(session);

        String format = req.getParameter("format");
        boolean isJson = "json".equals(format) || "XMLHttpRequest".equals(req.getHeader("X-Requested-With"));

        try {
            if (user != null) {
                // Đã đăng nhập -> lấy dữ liệu giỏ hàng từ database
                CartSummaryDTO cartSummary = cartService.getCart(user.getUserId());

                if (isJson) {
                    JsonUtil.writeJson(resp, ApiResponse.ok(Map.of("cartSummary", cartSummary, "isLoggedIn", true)));
                } else {
                    req.setAttribute("cartSummary", cartSummary);
                    req.getRequestDispatcher("/WEB-INF/jsp/customer/cart.jsp").forward(req, resp);
                }
            } else {
                // Khách vãng lai -> Dữ liệu giỏ hàng sẽ được Client-side JS tự render từ Local Storage
                if (isJson) {
                    JsonUtil.writeJson(resp, ApiResponse.ok(Map.of("isLoggedIn", false)));
                } else {
                    req.setAttribute("cartSummary", null);
                    req.getRequestDispatcher("/WEB-INF/jsp/customer/cart.jsp").forward(req, resp);
                }
            }
        } catch (SQLException e) {
            LoggerUtil.error(log, "Lỗi kết nối cơ sở dữ liệu khi tải giỏ hàng", e);
            if (isJson) {
                JsonUtil.writeJson(resp, ApiResponse.error("Lỗi kết nối cơ sở dữ liệu."));
            } else {
                SessionUtil.flashError(session, "Không thể tải giỏ hàng của bạn lúc này. Vui lòng thử lại sau.");
                resp.sendRedirect(req.getContextPath() + "/home");
            }
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        
        req.setCharacterEncoding("UTF-8");
        resp.setContentType("application/json;charset=UTF-8");

        HttpSession session = req.getSession();
        User user = SessionUtil.getCurrentUser(session);
        String action = req.getParameter("action");

        if (action == null) {
            resp.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            JsonUtil.writeJson(resp, ApiResponse.error("Yêu cầu không hợp lệ. Thiếu action."));
            return;
        }

        try {
            switch (action) {
                case "add": {
                    // Thêm sản phẩm vào giỏ
                    if (user == null) {
                        JsonUtil.writeJson(resp, ApiResponse.ok(Map.of("message", "Đã thêm vào giỏ hàng cục bộ.")));
                        return;
                    }

                    int variantId = Integer.parseInt(req.getParameter("variantId"));
                    int quantity = Integer.parseInt(req.getParameter("quantity"));
                    String packagingIdStr = req.getParameter("packagingId");
                    Integer packagingId = (packagingIdStr != null && !packagingIdStr.trim().isEmpty())
                        ? Integer.parseInt(packagingIdStr.trim())
                        : null;

                    cartService.addToCart(user.getUserId(), variantId, quantity, packagingId);
                    CartSummaryDTO updatedSummary = cartService.getCart(user.getUserId());
                    JsonUtil.writeJson(resp, ApiResponse.ok(Map.of("message", "Đã thêm vào giỏ hàng thành công.", "cartSummary", updatedSummary)));
                    break;
                }
                case "update": {
                    // Cập nhật số lượng
                    if (user == null) {
                        JsonUtil.writeJson(resp, ApiResponse.ok(Map.of("message", "Đã cập nhật giỏ hàng cục bộ.")));
                        return;
                    }

                    int cartItemId = Integer.parseInt(req.getParameter("cartItemId"));
                    int quantity = Integer.parseInt(req.getParameter("quantity"));

                    cartService.updateQuantity(user.getUserId(), cartItemId, quantity);
                    CartSummaryDTO updatedSummary = cartService.getCart(user.getUserId());
                    JsonUtil.writeJson(resp, ApiResponse.ok(Map.of("message", "Cập nhật thành công.", "cartSummary", updatedSummary)));
                    break;
                }
                case "remove": {
                    // Xóa sản phẩm
                    if (user == null) {
                        JsonUtil.writeJson(resp, ApiResponse.ok(Map.of("message", "Đã xóa khỏi giỏ hàng cục bộ.")));
                        return;
                    }

                    int cartItemId = Integer.parseInt(req.getParameter("cartItemId"));

                    cartService.removeItem(user.getUserId(), cartItemId);
                    CartSummaryDTO updatedSummary = cartService.getCart(user.getUserId());
                    JsonUtil.writeJson(resp, ApiResponse.ok(Map.of("message", "Đã xóa sản phẩm khỏi giỏ hàng.", "cartSummary", updatedSummary)));
                    break;
                }
                case "changeVariant": {
                    if (user == null) {
                        JsonUtil.writeJson(resp, ApiResponse.ok(Map.of("message", "Đã cập nhật biến thể giỏ hàng cục bộ.")));
                        return;
                    }

                    int cartItemId = Integer.parseInt(req.getParameter("cartItemId"));
                    int newVariantId = Integer.parseInt(req.getParameter("newVariantId"));

                    cartService.changeVariant(user.getUserId(), cartItemId, newVariantId);
                    CartSummaryDTO updatedSummary = cartService.getCart(user.getUserId());
                    JsonUtil.writeJson(resp, ApiResponse.ok(Map.of("message", "Đã cập nhật biến thể thành công.", "cartSummary", updatedSummary)));
                    break;
                }
                case "sync": {
                    // Đồng bộ gộp giỏ hàng guest khi đăng nhập
                    if (user == null) {
                        JsonUtil.writeJson(resp, ApiResponse.error("Chưa đăng nhập."));
                        return;
                    }

                    String guestCartJson = req.getParameter("guestCart");
                    if (guestCartJson != null && !guestCartJson.trim().isEmpty()) {
                        cartService.syncGuestCart(user.getUserId(), guestCartJson);
                    }

                    CartSummaryDTO updatedSummary = cartService.getCart(user.getUserId());
                    JsonUtil.writeJson(resp, ApiResponse.ok(Map.of("message", "Đồng bộ thành công.", "cartSummary", updatedSummary)));
                    break;
                }
                case "syncOnUnload": {
                    // Nhận Beacon API đồng bộ ghi đè khi tắt tab
                    if (user == null) {
                        JsonUtil.writeJson(resp, ApiResponse.error("Chưa đăng nhập."));
                        return;
                    }

                    String bodyJson = readRequestBody(req);
                    Map<String, Object> parsedBody = JsonUtil.fromJson(bodyJson, Map.class);
                    if (parsedBody != null && parsedBody.containsKey("items")) {
                        String itemsJson = JsonUtil.toJson(parsedBody.get("items"));
                        cartService.syncOnUnload(user.getUserId(), itemsJson);
                    }

                    JsonUtil.writeJson(resp, ApiResponse.ok(null));
                    break;
                }
                case "checkStock": {
                    // Kiểm tra tồn kho trước khi thanh toán
                    if (user == null) {
                        JsonUtil.writeJson(resp, ApiResponse.error("Bạn vui lòng đăng nhập để tiến hành thanh toán."));
                        return;
                    }

                    List<Integer> cartItemIds = parseSelectionIds(req.getParameter("cartItemIds"));
                    List<String> errors = !cartItemIds.isEmpty()
                            ? cartService.checkCartStockBeforeCheckoutByCartItemIds(user.getUserId(), cartItemIds)
                            : cartService.checkCartStockBeforeCheckout(user.getUserId(), parseVariantIds(req.getParameter("variantIds")));
                    if (errors.isEmpty()) {
                        JsonUtil.writeJson(resp, ApiResponse.ok(null));
                    } else {
                        resp.setStatus(HttpServletResponse.SC_CONFLICT);
                        JsonUtil.writeJson(resp, ApiResponse.fail(
                                HttpServletResponse.SC_CONFLICT,
                                "Một số sản phẩm trong giỏ không còn đủ tồn kho. Vui lòng kiểm tra lại.",
                                buildStockErrorMeta(errors)));
                    }
                    break;
                }
                default:
                    resp.setStatus(HttpServletResponse.SC_BAD_REQUEST);
                    JsonUtil.writeJson(resp, ApiResponse.error("Hành động không được hỗ trợ."));
                    break;
            }
        } catch (BusinessException e) {
            resp.setStatus(422);
            JsonUtil.writeJson(resp, ApiResponse.fail(422,
                    "Dữ liệu giỏ hàng không hợp lệ.",
                    buildValidationErrorMeta(e.getErrorCode())));
        } catch (IllegalArgumentException e) {
            resp.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            JsonUtil.writeJson(resp, ApiResponse.fail(HttpServletResponse.SC_BAD_REQUEST,
                    "Dữ liệu giỏ hàng không hợp lệ."));
        } catch (Exception e) {
            LoggerUtil.error(log, "Lỗi hệ thống khi xử lý giỏ hàng", e);
            resp.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            JsonUtil.writeJson(resp, ApiResponse.error("Lỗi hệ thống khi xử lý giỏ hàng."));
        }
    }

    private Map<String, Object> buildValidationErrorMeta(String errorCode) {
        Map<String, Object> meta = new HashMap<>();
        if (isMissingCartItemErrorCode(errorCode)) {
            meta.put("errorCode", "cart_item_not_found");
        } else if (isOutOfSeasonErrorCode(errorCode)) {
            meta.put("errorCode", "out_of_season");
        } else if (isStockRelatedErrorCode(errorCode)) {
            meta.put("errorCode", "out_of_stock");
        }
        return meta.isEmpty() ? null : meta;
    }

    private boolean isMissingCartItemErrorCode(String errorCode) {
        if (errorCode == null) {
            return false;
        }
        return "cart_item_not_found".equals(errorCode)
                || "cart_item_not_owned".equals(errorCode);
    }

    private boolean isOutOfSeasonErrorCode(String errorCode) {
        if (errorCode == null) {
            return false;
        }
        return "out_of_season".equals(errorCode);
    }

    private boolean isStockRelatedErrorCode(String errorCode) {
        if (errorCode == null) {
            return false;
        }
        return "out_of_stock".equals(errorCode);
    }

    private Map<String, Object> buildStockErrorMeta(List<String> errors) {
        Map<String, Object> meta = new HashMap<>();
        meta.put("errorCode", resolveStockErrorCode(errors));
        meta.put("errors", errors);
        return meta;
    }

    private String resolveStockErrorCode(List<String> errors) {
        if (errors == null) {
            return "out_of_stock";
        }
        for (String message : errors) {
            if (isOutOfSeasonMessage(message)) {
                return "out_of_season";
            }
        }
        return "out_of_stock";
    }

    private boolean isOutOfSeasonMessage(String message) {
        if (message == null) {
            return false;
        }
        return message.contains("hết mùa")
                || message.contains("ngoài mùa")
                || message.contains("vụ mới")
                || message.contains("không còn khả dụng");
    }

    private List<Integer> parseVariantIds(String variantIdsParam) {
        List<Integer> variantIds = new ArrayList<>();
        if (variantIdsParam == null || variantIdsParam.trim().isEmpty()) {
            return variantIds;
        }
        for (String part : variantIdsParam.split(",")) {
            try {
                variantIds.add(Integer.parseInt(part.trim()));
            } catch (NumberFormatException e) {
                LoggerUtil.warn(log, "ID biến thể không hợp lệ: " + part, e);
            }
        }
        return variantIds;
    }

    private List<Integer> parseSelectionIds(String cartItemIdsParam) {
        return parseIdList(cartItemIdsParam);
    }

    private List<Integer> parseIdList(String idsParam) {
        List<Integer> ids = new ArrayList<>();
        if (idsParam == null || idsParam.trim().isEmpty()) {
            return ids;
        }
        for (String part : idsParam.split(",")) {
            try {
                int parsed = Integer.parseInt(part.trim());
                if (parsed > 0) {
                    ids.add(parsed);
                }
            } catch (NumberFormatException e) {
                LoggerUtil.warn(log, "ID không hợp lệ: " + part, e);
            }
        }
        return ids;
    }

    private String readRequestBody(HttpServletRequest req) throws IOException {
        StringBuilder sb = new StringBuilder();
        String line;
        try (java.io.BufferedReader reader = req.getReader()) {
            while ((line = reader.readLine()) != null) {
                sb.append(line);
            }
        }
        return sb.toString();
    }
}
