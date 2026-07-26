package servlet.customer.cart;

import config.AppConfig;
import dao.order.OrderDAO;
import dao.system.SystemConfigDAO;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import model.dto.checkout.CheckoutPaymentSummaryDTO;
import model.dto.checkout.CheckoutRequestDTO;
import model.dto.checkout.CheckoutResultDTO;
import model.dto.checkout.CheckoutViewData;
import model.entity.auth.User;
import model.entity.order.Order;
import model.entity.shop.PaymentTransaction;
import model.response.ApiResponse;
import service.cart.CheckoutService;
import service.shop.PaymentService;
import util.ActorAccessPolicy;
import util.ErrorMessageUtil;
import util.JsonUtil;
import util.LoggerUtil;
import util.SessionUtil;

import java.io.IOException;
import java.math.RoundingMode;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.logging.Logger;

/**
 * Controller cho checkout.
 */
@WebServlet("/checkout")
public class CheckoutServlet extends HttpServlet {

    private static final Logger log = Logger.getLogger(CheckoutServlet.class.getName());

    private static final String DEFAULT_BANK_ID = AppConfig.SEPAY_BANK_ID;
    private static final String DEFAULT_ACCOUNT_NO = AppConfig.SEPAY_ACCOUNT_NO;
    private static final String DEFAULT_ACCOUNT_NAME = AppConfig.SEPAY_ACCOUNT_NAME;
    private static final int QR_EXPIRE_MIN = AppConfig.QR_EXPIRE_MINUTES;

    private final CheckoutService checkoutService = new CheckoutService();
    private final PaymentService paymentService = new PaymentService();
    private final OrderDAO orderDAO = new OrderDAO();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        req.setCharacterEncoding("UTF-8");
        resp.setContentType("text/html;charset=UTF-8");

        HttpSession session = req.getSession();
        User user = SessionUtil.getCurrentUser(session);
        if (user == null) {
            SessionUtil.flashError(session, "Bạn cần đăng nhập để tiếp tục thanh toán. Hệ thống sẽ đưa bạn trở lại checkout sau khi đăng nhập.");
            String redirectUrl = req.getRequestURI();
            if (req.getQueryString() != null && !req.getQueryString().trim().isEmpty()) {
                redirectUrl += "?" + req.getQueryString();
            }
            resp.sendRedirect(req.getContextPath() + "/auth/login?redirect=" + URLEncoder.encode(redirectUrl, StandardCharsets.UTF_8));
            return;
        }
        if (!ActorAccessPolicy.canAccessCustomerArea(user)) {
            resp.sendError(HttpServletResponse.SC_FORBIDDEN, "Ban khong co quyen thuc hien thanh toan.");
            return;
        }

        String action = req.getParameter("action");
        if ("success".equals(action)) {
            handleSuccessView(req, resp, user);
            return;
        }
        if ("payment".equals(action)) {
            handlePaymentView(req, resp, user);
            return;
        }
        if ("status".equals(action)) {
            handleStatusView(req, resp, user);
            return;
        }

        try {
            CheckoutViewData viewData = checkoutService.buildCheckoutView(
                    user,
                    parseSelectionIds(req.getParameter("cartItemIds")));
            req.setAttribute("userAddresses", viewData.getUserAddresses());
            req.setAttribute("cartSummary", viewData.getCartSummary());
            req.setAttribute("userAddress", user.getUserAddress());
            req.setAttribute("shopCount", viewData.getShopCount());
            req.setAttribute("directSaleAmount", viewData.getDirectSaleAmount());
            req.setAttribute("checkoutQuote", viewData.getQuote());
            req.setAttribute("shopSummaries", viewData.getShopSummaries());
            if (viewData.getShopOwnerId() != null) {
                req.setAttribute("shopOwnerId", viewData.getShopOwnerId());
            }
            req.getRequestDispatcher("/WEB-INF/jsp/customer/checkout.jsp").forward(req, resp);
        } catch (Exception e) {
            String userMsg = ErrorMessageUtil.logAndGetUserMessage(log, "Failed to build checkout view", e);
            SessionUtil.flashError(session, userMsg);
            resp.sendRedirect(req.getContextPath() + "/cart");
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        req.setCharacterEncoding("UTF-8");

        HttpSession session = req.getSession();
        User user = SessionUtil.getCurrentUser(session);
        if (user == null) {
            resp.sendRedirect(req.getContextPath() + "/auth/login");
            return;
        }
        if (!ActorAccessPolicy.canAccessCustomerArea(user)) {
            resp.sendError(HttpServletResponse.SC_FORBIDDEN, "Ban khong co quyen thuc hien thanh toan.");
            return;
        }
        if (!isValidCsrf(session, req.getParameter("_csrf"))) {
            SessionUtil.flashError(session, "Yêu cầu không hợp lệ (CSRF). Vui lòng thử lại.");
            resp.sendRedirect(req.getContextPath() + "/cart");
            return;
        }

        String action = req.getParameter("action");
        if ("confirmPayment".equals(action)) {
            handleConfirmPayment(req, resp, session, user);
            return;
        }

        CheckoutRequestDTO checkoutRequest = buildCheckoutRequest(req);
        try {
            CheckoutResultDTO result = checkoutService.placeOrder(user, checkoutRequest, req.getRemoteAddr());
            SessionUtil.setCurrentUser(session, user);
            session.setAttribute("_purgedCartItemIds", result.getPurgedCartItemIds());
            SessionUtil.flashSuccess(session, result.getSuccessMessage());
            if (result.isPaymentRequired()) {
                resp.sendRedirect(req.getContextPath() + "/checkout?action=payment&orderId=" + result.getOrderId());
            } else {
                resp.sendRedirect(req.getContextPath() + "/checkout?action=success&orderId=" + result.getOrderId());
            }
        } catch (SecurityException e) {
            ErrorMessageUtil.logException(log, "Security violation in placeOrder", e);
            resp.sendError(HttpServletResponse.SC_FORBIDDEN);
        } catch (Exception e) {
            String userMsg = ErrorMessageUtil.logAndGetUserMessage(log,
                    "Failed to place order for customer=" + user.getUserId(), e);
            SessionUtil.flashError(session, userMsg);
            if (!checkoutRequest.getCartItemIds().isEmpty()) {
                resp.sendRedirect(req.getContextPath() + buildCheckoutRedirect(checkoutRequest.getCartItemIds()));
            } else {
                resp.sendRedirect(req.getContextPath() + buildLegacyCheckoutRedirect(checkoutRequest.getVariantIds()));
            }
        }
    }

    private void handleSuccessView(HttpServletRequest req, HttpServletResponse resp, User user)
            throws IOException, ServletException {
        Order order = findCustomerOrder(req.getParameter("orderId"), user.getUserId());
        PaymentTransaction paymentTx = null;
        if (order != null) {
            try {
                CheckoutPaymentSummaryDTO summary = paymentService.getCustomerPaymentSummary(order.getOrderId(), user.getUserId());
                if (summary != null) {
                    paymentTx = paymentService.getPaymentByOrder(summary.getOrderId());
                }
            } catch (Exception e) {
                LoggerUtil.warn(log, "Không thể tải thông tin giao dịch thanh toán cho đơn hàng", e);
            }
        }
        req.setAttribute("order", order);
        if (paymentTx != null) {
            req.setAttribute("paymentTx", paymentTx);
        }
        req.getRequestDispatcher("/WEB-INF/jsp/customer/order-success.jsp").forward(req, resp);
    }

    private void handlePaymentView(HttpServletRequest req, HttpServletResponse resp, User user)
            throws IOException, ServletException {
        int requestedOrderId = parseOrderId(req.getParameter("orderId"));
        if (requestedOrderId <= 0) {
            resp.sendRedirect(req.getContextPath() + "/home");
            return;
        }

        CheckoutPaymentSummaryDTO summary;
        try {
            summary = paymentService.getCustomerPaymentSummary(requestedOrderId, user.getUserId());
        } catch (SQLException e) {
            throw new ServletException("Không thể tải payment summary", e);
        }
        if (summary == null) {
            resp.sendRedirect(req.getContextPath() + "/home");
            return;
        }
        if (!summary.getPaymentRequired()) {
            resp.sendRedirect(req.getContextPath() + "/checkout?action=success&orderId=" + summary.getOrderId());
            return;
        }

        Order order = findCustomerOrder(String.valueOf(summary.getOrderId()), user.getUserId());
        if (order == null) {
            resp.sendRedirect(req.getContextPath() + "/home");
            return;
        }
        if (summary.getCancelled()) {
            resp.sendRedirect(req.getContextPath() + "/profile/order-detail?orderId=" + summary.getOrderId());
            return;
        }
        if (!summary.getPendingPayment()) {
            resp.sendRedirect(req.getContextPath() + "/checkout?action=success&orderId=" + summary.getOrderId());
            return;
        }

        PaymentTransaction paymentTx = null;
        try {
            paymentTx = paymentService.getPaymentByOrder(summary.getOrderId());
            if (paymentTx == null || isQrExpired(paymentTx)) {
                paymentTx = paymentService.renewQr(summary.getOrderId(), user.getUserId());
            }
        } catch (Exception e) {
            LoggerUtil.warn(log, "Không thể tải thông tin giao dịch thanh toán cho đơn hàng", e);
        }

        String amountFormatted = summary.getFinalAmount().setScale(0, RoundingMode.HALF_UP).toString();
        String reference = paymentTx != null && paymentTx.getSepayReference() != null
                ? paymentTx.getSepayReference()
                : (summary.getReference() != null ? summary.getReference() : PaymentService.buildSepayReference(summary.getOrderId()));

        SystemConfigDAO systemConfigDAO = new SystemConfigDAO();
        String bankId = null;
        String accountNo = null;
        String accountName = null;
        try {
            bankId = systemConfigDAO.getValue(AppConfig.CONFIG_SEPAY_BANK_ID);
            accountNo = systemConfigDAO.getValue(AppConfig.CONFIG_SEPAY_ACCOUNT_NO);
            accountName = systemConfigDAO.getValue(AppConfig.CONFIG_SEPAY_ACCOUNT_NAME);
        } catch (Exception e) {
            LoggerUtil.warn(log, "Không thể tải cấu hình SePay từ DB, sử dụng mặc định", e);
        }

        if (bankId == null || bankId.trim().isEmpty()) {
            bankId = DEFAULT_BANK_ID;
        }
        if (accountNo == null || accountNo.trim().isEmpty()) {
            accountNo = DEFAULT_ACCOUNT_NO;
        }
        if (accountName == null || accountName.trim().isEmpty()) {
            accountName = DEFAULT_ACCOUNT_NAME;
        }

        req.setAttribute("order", order);
        req.setAttribute("paymentSummary", summary);
        req.setAttribute("qrUrl", buildQrUrl(bankId, accountNo, reference, amountFormatted));
        req.setAttribute("bankId", bankId);
        req.setAttribute("accountNo", accountNo);
        req.setAttribute("accountName", accountName);
        req.setAttribute("reference", reference);
        req.setAttribute("description", reference);
        req.setAttribute("amountFormatted", amountFormatted);
        req.setAttribute("qrExpireMin", QR_EXPIRE_MIN);
        if (paymentTx != null) {
            req.setAttribute("paymentTx", paymentTx);
        }
        req.getRequestDispatcher("/WEB-INF/jsp/customer/order-payment.jsp").forward(req, resp);
    }

    private void handleStatusView(HttpServletRequest req, HttpServletResponse resp, User user) throws IOException {
        resp.setContentType("application/json;charset=UTF-8");
        resp.setCharacterEncoding("UTF-8");

        int requestedOrderId = parseOrderId(req.getParameter("orderId"));
        if (requestedOrderId <= 0) {
            JsonUtil.writeJson(resp, ApiResponse.error("Đơn hàng không hợp lệ."));
            return;
        }

        try {
            CheckoutPaymentSummaryDTO summary = paymentService.getCustomerPaymentSummary(requestedOrderId, user.getUserId());
            Map<String, Object> responseData = new java.util.LinkedHashMap<>();
            if (summary == null) {
                responseData.put("status", "UNKNOWN");
            } else {
                responseData.put("status", summary.getOrderStatus());
                responseData.put("paymentStatus", summary.getPaymentStatus());
                responseData.put("pendingPayment", summary.getPendingPayment());
                responseData.put("paid", summary.getPaid());
                responseData.put("rootOrderId", summary.getOrderId());
            }
            JsonUtil.writeJson(resp, ApiResponse.ok(responseData));
        } catch (Exception e) {
            LoggerUtil.warn(log, "Không thể tải trạng thái thanh toán cho đơn hàng", e);
            JsonUtil.writeJson(resp, ApiResponse.error("Không thể tải trạng thái thanh toán."));
        }
    }

    private void handleConfirmPayment(HttpServletRequest req, HttpServletResponse resp, HttpSession session, User user)
            throws IOException {
        String orderId = req.getParameter("orderId");
        int requestedOrderId = parseOrderId(orderId);
        try {
            CheckoutPaymentSummaryDTO summary = paymentService.getCustomerPaymentSummary(requestedOrderId, user.getUserId());
            if (summary == null) {
                resp.sendError(HttpServletResponse.SC_FORBIDDEN);
                return;
            }
            boolean ok = paymentService.confirmManualPayment(summary.getOrderId(), user.getUserId());
            if (ok) {
                SessionUtil.flashSuccess(session,
                        "Chúng tôi đã nhận thông báo thanh toán. Admin sẽ xác minh và duyệt trong 1-24 giờ làm việc.");
                resp.sendRedirect(req.getContextPath() + "/checkout?action=success&orderId=" + summary.getOrderId());
                return;
            } else {
                SessionUtil.flashError(session, "Mã QR đã hết hạn. Vui lòng làm mới mã QR và thanh toán lại.");
            }
        } catch (SecurityException e) {
            ErrorMessageUtil.logException(log, "Security violation in confirmPayment", e);
            resp.sendError(HttpServletResponse.SC_FORBIDDEN);
            return;
        } catch (Exception e) {
            String userMsg = ErrorMessageUtil.logAndGetUserMessage(log,
                    "Failed to confirm payment for orderId=" + orderId, e);
            SessionUtil.flashError(session, userMsg);
        }
        resp.sendRedirect(req.getContextPath() + "/checkout?action=payment&orderId=" + requestedOrderId);
    }

    private CheckoutRequestDTO buildCheckoutRequest(HttpServletRequest req) {
        CheckoutRequestDTO request = new CheckoutRequestDTO();
        request.setFullName(req.getParameter("fullName"));
        request.setPhone(req.getParameter("phone"));
        request.setDeliveryAddress(req.getParameter("deliveryAddress"));
        request.setDeliveryTimeSlot(req.getParameter("deliveryTimeSlot"));
        request.setNotes(req.getParameter("notes"));

        String paymentMethod = req.getParameter("paymentMethod");
        if (paymentMethod == null || paymentMethod.trim().isEmpty()) {
            paymentMethod = AppConfig.PAYMENT_COD;
        }
        request.setPaymentMethod(paymentMethod.trim());
        request.setShopCouponCodes(parseCouponCodes(req.getParameterValues("shopCouponCodes"), req.getParameter("shopCouponCode")));
        request.setSystemCouponCodes(parseCouponCodes(req.getParameterValues("systemCouponCodes"), req.getParameter("systemCouponCode")));
        request.setShopCouponCode(req.getParameter("shopCouponCode"));
        request.setSystemCouponCode(req.getParameter("systemCouponCode"));
        request.setCartItemIds(parseIdList(req.getParameter("cartItemIds")));
        request.setVariantIds(parseIdList(req.getParameter("variantIds")));
        request.setSaveAddressToBook("true".equals(req.getParameter("saveAddressToBook")));
        return request;
    }

    private List<String> parseCouponCodes(String[] values, String fallbackCsv) {
        List<String> codes = new ArrayList<>();
        if (values != null && values.length > 0) {
            for (String value : values) {
                appendCouponCodes(codes, value);
            }
            return codes;
        }
        appendCouponCodes(codes, fallbackCsv);
        return codes;
    }

    private void appendCouponCodes(List<String> codes, String raw) {
        if (raw == null || raw.trim().isEmpty()) {
            return;
        }
        for (String part : raw.split(",")) {
            String normalized = part != null ? part.trim().toUpperCase() : null;
            if (normalized != null && !normalized.isEmpty() && !codes.contains(normalized)) {
                codes.add(normalized);
            }
        }
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

    private boolean isQrExpired(PaymentTransaction paymentTx) {
        return paymentTx != null
                && (paymentTx.getExpiresAt() == null
                || LocalDateTime.now().isAfter(paymentTx.getExpiresAt()));
    }

    private boolean isValidCsrf(HttpSession session, String csrfParam) {
        String csrfSession = (String) session.getAttribute(AppConfig.SESSION_CSRF_TOKEN);
        if (csrfSession == null || csrfParam == null) {
            return false;
        }
        return MessageDigest.isEqual(
                csrfSession.getBytes(java.nio.charset.StandardCharsets.UTF_8),
                csrfParam.getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }

    private String buildCheckoutRedirect(List<Integer> cartItemIds) {
        if (cartItemIds == null || cartItemIds.isEmpty()) {
            return "/cart";
        }
        StringBuilder builder = new StringBuilder("/checkout?cartItemIds=");
        for (int i = 0; i < cartItemIds.size(); i++) {
            builder.append(cartItemIds.get(i));
            if (i < cartItemIds.size() - 1) {
                builder.append(",");
            }
        }
        return builder.toString();
    }

    private String buildLegacyCheckoutRedirect(List<Integer> variantIds) {
        if (variantIds == null || variantIds.isEmpty()) {
            return "/cart";
        }
        StringBuilder builder = new StringBuilder("/checkout?variantIds=");
        for (int i = 0; i < variantIds.size(); i++) {
            builder.append(variantIds.get(i));
            if (i < variantIds.size() - 1) {
                builder.append(",");
            }
        }
        return builder.toString();
    }

    private Order findCustomerOrder(String orderIdParam, int customerId) {
        int orderId = parseOrderId(orderIdParam);
        if (orderId <= 0) {
            return null;
        }
        try {
            return orderDAO.findByIdForCustomer(orderId, customerId);
        } catch (SQLException e) {
            return null;
        }
    }

    private int parseOrderId(String orderIdParam) {
        if (orderIdParam == null || orderIdParam.trim().isEmpty()) {
            return -1;
        }
        try {
            return Integer.parseInt(orderIdParam.trim());
        } catch (NumberFormatException e) {
            return -1;
        }
    }

    private String buildQrUrl(String bankId, String accountNo, String reference, String amount)
            throws java.io.UnsupportedEncodingException {
        return "https://qr.sepay.vn/img?bank=" + java.net.URLEncoder.encode(bankId, "UTF-8")
                + "&acc=" + java.net.URLEncoder.encode(accountNo, "UTF-8")
                + "&amount=" + java.net.URLEncoder.encode(amount, "UTF-8")
                + "&des=" + java.net.URLEncoder.encode(reference, "UTF-8")
                + "&template=compact";
    }
}
