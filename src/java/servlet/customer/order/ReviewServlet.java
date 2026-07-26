package servlet.customer.order;

import dao.order.OrderDAO;
import dao.order.ReviewDAO;
import model.entity.order.Order;
import model.entity.order.OrderItem;
import model.entity.order.Review;
import model.entity.auth.User;
import service.order.OrderService;
import service.order.ReviewService;
import util.ActorAccessPolicy;
import util.FileUploadUtil;
import util.SessionUtil;
import util.ErrorMessageUtil;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import util.LoggerUtil;
import jakarta.servlet.http.HttpSession;
import jakarta.servlet.http.Part;
import java.io.IOException;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Logger;

/**
 * ReviewServlet - Controller cho chức năng đánh giá sản phẩm.
 *
 * URL: /reviews
 * GET : Form viết review hoặc form chỉnh sửa review
 * POST: Lưu / cập nhật / xóa review
 *
 * @author fruitmkt-team
 */
@WebServlet("/reviews")
@MultipartConfig(
    fileSizeThreshold = 1024 * 1024 * 2,
    maxFileSize = 1024 * 1024 * 10,
    maxRequestSize = 1024 * 1024 * 50
)
public class ReviewServlet extends HttpServlet {

    private static final Logger log = Logger.getLogger(ReviewServlet.class.getName());

    private final ReviewService reviewService = new ReviewService();
    private final OrderService orderService = new OrderService();
    private final OrderDAO orderDAO = new OrderDAO();
    private final ReviewDAO reviewDAO = new ReviewDAO();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        req.setCharacterEncoding("UTF-8");
        resp.setContentType("text/html;charset=UTF-8");

        HttpSession session = req.getSession();
        User user = SessionUtil.getCurrentUser(session);
        if (!ActorAccessPolicy.canAccessCustomerArea(user)) {
            SessionUtil.setFlashMessage(session, "Vui lòng đăng nhập để đánh giá sản phẩm.", "danger");
            resp.sendRedirect(req.getContextPath() + "/auth/login");
            return;
        }

        String action = req.getParameter("action");
        if ("edit".equalsIgnoreCase(action)) {
            showEditForm(req, resp, session, user);
            return;
        }

        showCreateForm(req, resp, session, user);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        req.setCharacterEncoding("UTF-8");

        HttpSession session = req.getSession();
        User user = SessionUtil.getCurrentUser(session);
        if (!ActorAccessPolicy.canAccessCustomerArea(user)) {
            resp.sendError(HttpServletResponse.SC_FORBIDDEN);
            return;
        }

        String csrfParam = req.getParameter("_csrf");
        String csrfSession = (String) session.getAttribute("_csrfToken");
        if (csrfSession != null && !csrfSession.equals(csrfParam)) {
            SessionUtil.flashError(session, "Yêu cầu không hợp lệ (CSRF). Vui lòng thử lại.");
            resp.sendRedirect(req.getContextPath() + "/orders");
            return;
        }

        String action = req.getParameter("action");
        String orderIdStr = req.getParameter("orderId");
        String orderItemIdStr = req.getParameter("orderItemId");

        if (orderIdStr == null || orderItemIdStr == null) {
            SessionUtil.flashError(session, "Thiếu mã đơn hàng hoặc chi tiết đơn hàng.");
            resp.sendRedirect(req.getContextPath() + "/orders");
            return;
        }

        int orderId;
        int orderItemId;
        try {
            orderId = Integer.parseInt(orderIdStr);
            orderItemId = Integer.parseInt(orderItemIdStr);
        } catch (NumberFormatException e) {
            SessionUtil.flashError(session, "Mã đơn hàng không hợp lệ.");
            resp.sendRedirect(req.getContextPath() + "/orders");
            return;
        }

        try {
            Order order = orderDAO.findByIdForCustomer(orderId, user.getUserId());
            if (order == null || !"DELIVERED".equals(order.getStatus())) {
                SessionUtil.flashError(session, "Đơn hàng không hợp lệ để đánh giá.");
                resp.sendRedirect(req.getContextPath() + "/orders");
                return;
            }

            boolean belongsToOrder = false;
            for (OrderItem item : orderService.getOrderItems(orderId)) {
                if (item.getOrderItemId() == orderItemId) {
                    belongsToOrder = true;
                    break;
                }
            }
            if (!belongsToOrder) {
                SessionUtil.flashError(session, "Chi tiết đơn hàng không hợp lệ.");
                resp.sendRedirect(req.getContextPath() + "/orders");
                return;
            }

            if ("delete".equalsIgnoreCase(action)) {
                Review existing = reviewDAO.findByOrderItemId(orderItemId);
                if (existing == null || existing.getCustomerId() != user.getUserId()) {
                    SessionUtil.flashError(session, "Không tìm thấy đánh giá hợp lệ để xóa.");
                    resp.sendRedirect(req.getContextPath() + "/orders?action=detail&orderId=" + orderId);
                    return;
                }

                reviewService.deleteReview(existing.getReviewId());
                SessionUtil.flashSuccess(session, "Đã xóa đánh giá sản phẩm.");
                resp.sendRedirect(req.getContextPath() + "/orders?action=detail&orderId=" + orderId);
                return;
            }

            String ratingStr = req.getParameter("rating");
            if (ratingStr == null) {
                SessionUtil.flashError(session, "Vui lòng nhập đầy đủ thông tin đánh giá.");
                resp.sendRedirect(req.getContextPath() + "/orders?action=detail&orderId=" + orderId);
                return;
            }

            int rating = Integer.parseInt(ratingStr);
            String reviewText = req.getParameter("reviewText");
            String reviewImageUrl = resolveReviewImageUrl(req);

            Review review = new Review();
            review.setOrderItemId(orderItemId);
            review.setCustomerId(user.getUserId());
            review.setRating(rating);
            review.setReviewText(reviewText != null ? reviewText.trim() : "");
            review.setReviewImageUrl(reviewImageUrl);

            if ("edit".equalsIgnoreCase(action)) {
                Review existing = reviewDAO.findByOrderItemId(orderItemId);
                if (existing == null || existing.getCustomerId() != user.getUserId()) {
                    SessionUtil.flashError(session, "Không tìm thấy đánh giá hợp lệ để cập nhật.");
                    resp.sendRedirect(req.getContextPath() + "/orders?action=detail&orderId=" + orderId);
                    return;
                }
                review.setReviewId(existing.getReviewId());
                review.setIsHidden(existing.getIsHidden());
                reviewService.updateReview(review);
                SessionUtil.flashSuccess(session, "Đã cập nhật đánh giá sản phẩm.");
            } else {
                reviewService.submitReview(review);
                SessionUtil.flashSuccess(session, "Cảm ơn bạn đã gửi đánh giá sản phẩm!");
            }
        } catch (IllegalArgumentException e) {
            SessionUtil.flashError(session, ErrorMessageUtil.getUserMessage(e));
        } catch (Exception e) {
            String userMsg = ErrorMessageUtil.logAndGetUserMessage(log, "Failed to submit review for orderId=" + orderId, e);
            SessionUtil.flashError(session, userMsg);
        }

        resp.sendRedirect(req.getContextPath() + "/orders?action=detail&orderId=" + orderId);
    }

    private void showCreateForm(HttpServletRequest req, HttpServletResponse resp, HttpSession session, User user)
            throws ServletException, IOException {
        String orderIdStr = req.getParameter("orderId");
        if (orderIdStr == null || orderIdStr.trim().isEmpty()) {
            SessionUtil.flashError(session, "Mã đơn hàng không hợp lệ.");
            resp.sendRedirect(req.getContextPath() + "/orders");
            return;
        }

        try {
            int orderId = Integer.parseInt(orderIdStr);
            Order order = orderDAO.findByIdForCustomer(orderId, user.getUserId());
            if (order == null) {
                SessionUtil.flashError(session, "Không tìm thấy đơn hàng.");
                resp.sendRedirect(req.getContextPath() + "/orders");
                return;
            }

            if (!"DELIVERED".equals(order.getStatus())) {
                SessionUtil.flashError(session, "Chỉ có đơn hàng đã giao thành công mới có thể đánh giá sản phẩm.");
                resp.sendRedirect(req.getContextPath() + "/orders?action=detail&orderId=" + orderId);
                return;
            }

            List<OrderItem> items = orderService.getOrderItems(orderId);
            List<OrderItem> unreviewedItems = new ArrayList<>();
            List<OrderItem> reviewedItems = new ArrayList<>();
            for (OrderItem item : items) {
                if (reviewService.canReview(user.getUserId(), item.getOrderItemId())) {
                    unreviewedItems.add(item);
                } else {
                    reviewedItems.add(item);
                }
            }

            req.setAttribute("order", order);
            req.setAttribute("unreviewedItems", unreviewedItems);
            req.setAttribute("reviewedItems", reviewedItems);
            req.getRequestDispatcher("/WEB-INF/jsp/customer/review.jsp").forward(req, resp);
        } catch (Exception e) {
            String userMsg = ErrorMessageUtil.logAndGetUserMessage(log, "Failed to show review form for orderId=" + orderIdStr, e);
            SessionUtil.flashError(session, userMsg);
            resp.sendRedirect(req.getContextPath() + "/orders");
        }
    }

    private void showEditForm(HttpServletRequest req, HttpServletResponse resp, HttpSession session, User user)
            throws ServletException, IOException {
        String orderIdStr = req.getParameter("orderId");
        String orderItemIdStr = req.getParameter("orderItemId");
        if (orderIdStr == null || orderItemIdStr == null) {
            SessionUtil.flashError(session, "Thiếu thông tin đánh giá cần chỉnh sửa.");
            resp.sendRedirect(req.getContextPath() + "/profile?tab=orders");
            return;
        }

        try {
            int orderId = Integer.parseInt(orderIdStr);
            int orderItemId = Integer.parseInt(orderItemIdStr);

            Order order = orderDAO.findByIdForCustomer(orderId, user.getUserId());
            if (order == null || !"DELIVERED".equals(order.getStatus())) {
                SessionUtil.flashError(session, "Đơn hàng không hợp lệ để chỉnh sửa đánh giá.");
                resp.sendRedirect(req.getContextPath() + "/profile?tab=orders");
                return;
            }

            boolean belongsToOrder = false;
            for (OrderItem item : orderService.getOrderItems(orderId)) {
                if (item.getOrderItemId() == orderItemId) {
                    belongsToOrder = true;
                    break;
                }
            }
            if (!belongsToOrder) {
                SessionUtil.flashError(session, "Chi tiết đơn hàng không hợp lệ để chỉnh sửa.");
                resp.sendRedirect(req.getContextPath() + "/profile?tab=orders");
                return;
            }

            Review review = reviewDAO.findByOrderItemId(orderItemId);
            if (review == null || review.getCustomerId() != user.getUserId()) {
                SessionUtil.flashError(session, "Không tìm thấy đánh giá để chỉnh sửa.");
                resp.sendRedirect(req.getContextPath() + "/profile?tab=orders");
                return;
            }

            req.setAttribute("order", order);
            req.setAttribute("orderItemId", orderItemId);
            req.setAttribute("review", review);
            req.setAttribute("action", "edit");
            req.getRequestDispatcher("/WEB-INF/jsp/customer/review-submit.jsp").forward(req, resp);
        } catch (Exception e) {
            LoggerUtil.error(log, "Lỗi khi hiển thị form sửa đánh giá", e);
            SessionUtil.flashError(session, ErrorMessageUtil.logAndGetUserMessage(log, "Failed to show review edit form", e));
            resp.sendRedirect(req.getContextPath() + "/profile?tab=orders");
        }
    }

    private String resolveReviewImageUrl(HttpServletRequest req) throws Exception {
        String contentType = req.getContentType();
        if (contentType != null && contentType.toLowerCase().startsWith("multipart/")) {
            Part reviewImagePart = req.getPart("reviewImage");
            if (reviewImagePart != null && reviewImagePart.getSize() > 0) {
                String uploadDir = getServletContext().getRealPath("");
                return FileUploadUtil.save(reviewImagePart, uploadDir);
            }
        }

        String reviewImageUrl = req.getParameter("reviewImageUrl");
        return reviewImageUrl != null && !reviewImageUrl.trim().isEmpty() ? reviewImageUrl.trim() : null;
    }
}
