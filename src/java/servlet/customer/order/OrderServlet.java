package servlet.customer.order;

import dao.order.OrderDAO;
import model.dto.order.OrderDetailViewDTO;
import model.dto.order.OrderListViewDTO;
import model.dto.order.ReorderResultDTO;
import model.entity.order.Order;
import model.entity.order.OrderItem;
import model.entity.auth.User;
import service.order.OrderService;
import service.order.OrderViewService;
import util.ActorAccessPolicy;
import util.SessionUtil;
import util.LoggerUtil;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.logging.Logger;
import util.ErrorMessageUtil;

/**
 * Controller cho lich su don hang, chi tiet va invoice.
 */
@WebServlet({"/orders", "/orders/detail", "/customer/orders"})
public class OrderServlet extends HttpServlet {

    private static final Logger log = Logger.getLogger(OrderServlet.class.getName());

    private final OrderService orderService = new OrderService();
    private final OrderViewService orderViewService = new OrderViewService();
    private final OrderDAO orderDAO = new OrderDAO();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        User user = SessionUtil.getCurrentUser(req.getSession());
        if (!ActorAccessPolicy.canAccessOrderArea(user)) {
            resp.sendRedirect(req.getContextPath() + "/auth/login");
            return;
        }

        req.setCharacterEncoding("UTF-8");
        resp.setContentType("text/html;charset=UTF-8");

        String action = req.getParameter("action");
        String servletPath = req.getServletPath();
        if ("detail".equals(action) || "/orders/detail".equals(servletPath)) {
            handleDetailView(req, resp, user);
            return;
        }
        if ("invoice".equals(action)) {
            handleInvoiceView(req, resp, user);
            return;
        }

        if (ActorAccessPolicy.isCustomer(user)) {
            resp.sendRedirect(req.getContextPath() + "/profile?tab=orders");
            return;
        }

        String status = req.getParameter("status");
        int page = parsePage(req.getParameter("page"));
        try {
            OrderListViewDTO view = orderViewService.getOrderListView(user, status, page);
            req.setAttribute("orders", view.getOrders());
            req.setAttribute("deliveryMap", view.getDeliveryMap());
            req.setAttribute("paymentTxMap", view.getPaymentTransactionMap());
            req.setAttribute("currentPage", view.getCurrentPage());
            req.setAttribute("totalPages", view.getTotalPages());
            req.setAttribute("selectedStatus", view.getSelectedStatus());
            req.getRequestDispatcher("/WEB-INF/jsp/customer/orders.jsp").forward(req, resp);
        } catch (Exception e) {
            throw new ServletException(e);
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        User user = SessionUtil.getCurrentUser(req.getSession());
        if (!ActorAccessPolicy.canAccessOrderArea(user)) {
            resp.sendError(HttpServletResponse.SC_FORBIDDEN);
            return;
        }

        int orderId;
        try {
            orderId = Integer.parseInt(req.getParameter("orderId"));
        } catch (Exception e) {
            resp.sendRedirect(req.getContextPath() + "/orders");
            return;
        }

        String action = req.getParameter("action");
        try {
            if ("confirmDelivery".equals(action)) {
                orderService.customerConfirmDelivery(orderId, user.getUserId());
                SessionUtil.setFlashMessage(req.getSession(),
                        "Cảm ơn bạn đã xác nhận nhận hàng thành công!", "success");
            } else if ("reportNotReceived".equals(action)) {
                orderService.reportNotReceived(orderId, user.getUserId());
                SessionUtil.setFlashMessage(req.getSession(),
                        "Bạn đã báo cáo chưa nhận được hàng. Ban quản trị sẽ tiến hành xác minh đơn hàng.",
                        "warning");
            } else if ("cancel".equals(action)) {
                orderService.cancelOrder(orderId, user.getUserId(), req.getParameter("reason"));
                SessionUtil.setFlashMessage(req.getSession(), "Bạn đã hủy đơn hàng thành công!", "success");
            } else if ("reorder".equals(action)) {
                ReorderResultDTO result = orderService.reorder(orderId, user.getUserId());
                if (result.getSkippedCount() > 0) {
                    SessionUtil.setFlashMessage(req.getSession(),
                            "Đã thêm " + result.getAddedCount() + " sản phẩm vào giỏ hàng. "
                                    + result.getSkippedCount() + " sản phẩm không còn khả dụng đã bị bỏ qua.",
                            "warning");
                } else {
                    SessionUtil.setFlashMessage(req.getSession(),
                            "Đã thêm " + result.getAddedCount() + " sản phẩm vào giỏ hàng thành công!",
                            "success");
                }
                resp.sendRedirect(req.getContextPath() + "/cart");
                return;
            }
        } catch (SecurityException e) {
            resp.sendError(HttpServletResponse.SC_FORBIDDEN, ErrorMessageUtil.getUserMessage(e));
            return;
        } catch (Exception e) {
            SessionUtil.setFlashMessage(req.getSession(),
                    ErrorMessageUtil.logAndGetUserMessage(log, "OrderServlet#doPost", e), "error");
        }

        if (ActorAccessPolicy.isCustomer(user)) {
            resp.sendRedirect(req.getContextPath() + "/profile/order-detail?orderId=" + orderId);
        } else {
            resp.sendRedirect(req.getContextPath() + "/orders");
        }
    }

    private void handleDetailView(HttpServletRequest req, HttpServletResponse resp, User user)
            throws IOException, ServletException {
        Integer orderId = parseOrderId(req.getParameter("orderId"));
        if (orderId == null) {
            resp.sendRedirect(req.getContextPath() + "/orders");
            return;
        }
        try {
            OrderDetailViewDTO view = orderViewService.getOrderDetailView(user, orderId);
            if (view != null && view.getOrder() != null) {
                Order order = view.getOrder();
                req.setAttribute("order", order);
                req.setAttribute("orderItems", view.getOrderItems());
                req.setAttribute("paymentTx", view.getPaymentTransaction());
                req.setAttribute("delivery", view.getDelivery());

                // If this is a PARENT order, load children
                if ("PARENT".equals(order.getOrderType())) {
                    List<Order> childOrders = orderDAO.findChildrenByParentId(orderId);
                    req.setAttribute("childOrders", childOrders);

                    List<Integer> childOrderIds = new ArrayList<>();
                    List<Integer> ownerIds = new ArrayList<>();
                    for (Order child : childOrders) {
                        childOrderIds.add(child.getOrderId());
                        ownerIds.add(child.getOwnerId());
                    }
                    Map<Integer, List<OrderItem>> childOrderItemsMap = new HashMap<>();
                    try {
                        childOrderItemsMap = orderViewService.getOrderItemsMap(childOrderIds);
                    } catch (Exception e) {
                        LoggerUtil.warn(log, "Không thể tải items của đơn con theo batch", e);
                        for (Order child : childOrders) {
                            childOrderItemsMap.put(child.getOrderId(), new ArrayList<>());
                        }
                    }

                    Map<Integer, String> ownerNames = new HashMap<>();
                    try {
                        ownerNames = orderViewService.getShopNamesMap(ownerIds);
                    } catch (Exception e) {
                        LoggerUtil.warn(log, "Không thể tải tên shop cho đơn con theo batch", e);
                    }
                    Map<Integer, String> shopNamesMap = new HashMap<>();
                    for (Order child : childOrders) {
                        shopNamesMap.put(child.getOrderId(), ownerNames.getOrDefault(child.getOwnerId(), "Cửa hàng"));
                    }
                    req.setAttribute("childOrderItemsMap", childOrderItemsMap);
                    req.setAttribute("shopNamesMap", shopNamesMap);
                } else {
                    // For single shop order, load its shop name
                    Map<Integer, String> ownerNames;
                    try {
                        ownerNames = orderViewService.getShopNamesMap(List.of(order.getOwnerId()));
                    } catch (Exception e) {
                        LoggerUtil.warn(log, "Không thể tải tên shop cho đơn #" + orderId, e);
                        ownerNames = new HashMap<>();
                    }
                    String shopName = ownerNames.getOrDefault(order.getOwnerId(), "Cửa hàng");
                    req.setAttribute("shopName", shopName);
                }

                req.getRequestDispatcher("/WEB-INF/jsp/customer/order-detail.jsp").forward(req, resp);
                return;
            }
        } catch (Exception e) {
            LoggerUtil.error(log, "Lỗi khi tải chi tiết đơn hàng", e);
        }
        resp.sendRedirect(req.getContextPath() + "/orders");
    }

    private void handleInvoiceView(HttpServletRequest req, HttpServletResponse resp, User user)
            throws IOException, ServletException {
        Integer orderId = parseOrderId(req.getParameter("orderId"));
        if (orderId == null) {
            resp.sendRedirect(req.getContextPath() + "/orders");
            return;
        }
        try {
            OrderDetailViewDTO view = orderViewService.getInvoiceView(user, orderId);
            if (view != null && view.getOrder() != null) {
                req.setAttribute("order", view.getOrder());
                req.setAttribute("orderItems", view.getOrderItems());
                req.getRequestDispatcher("/WEB-INF/jsp/customer/invoice.jsp").forward(req, resp);
                return;
            }
            SessionUtil.setFlashMessage(req.getSession(),
                    "Hoa don dien tu chi kha dung khi don hang da giao thanh cong.", "warning");
        } catch (Exception e) {
            LoggerUtil.error(log, "Lỗi khi tải hóa đơn đơn hàng", e);
        }
        resp.sendRedirect(req.getContextPath() + "/orders");
    }

    private int parsePage(String pageStr) {
        if (pageStr == null || pageStr.trim().isEmpty()) {
            return 1;
        }
        try {
            return Integer.parseInt(pageStr);
        } catch (NumberFormatException e) {
            return 1;
        }
    }

    private Integer parseOrderId(String orderIdStr) {
        if (orderIdStr == null || orderIdStr.trim().isEmpty()) {
            return null;
        }
        try {
            return Integer.parseInt(orderIdStr);
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
