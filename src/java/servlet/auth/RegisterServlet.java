package servlet.auth;

import config.AppConfig;
import dao.catalog.CategoryDAO;
import dao.auth.UserDAO;
import model.entity.catalog.Category;
import model.entity.auth.User;
import util.FileUploadUtil;
import util.ShopDocDraftUtil;
import util.SessionUtil;
import util.ShopStatusRedirectUtil;
import service.auth.AuthService;
import service.shop.ShopService;

import util.LoggerUtil;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Logger;

/**
 * RegisterServlet — Controller cho chức năng: Hiển thị form đăng ký
 *
 * URL: /auth/register
 * GET : Hiển thị form đăng ký (load categories từ DB)
 * POST: Tạo tài khoản mới, xử lý upload tài liệu (tối đa 10 file, mỗi file ≤ 25MB)
 *
 * QUY TẮC SERVLET:
 * 1. Không viết SQL ở đây — gọi Service
 * 2. Sau POST thành công dùng PRG pattern (sendRedirect)
 * 3. Lưu flash message vào session trước redirect
 * 4. Forward đến /WEB-INF/jsp/auth/... (không để truy cập trực tiếp)
 * 5. Kiểm tra quyền bằng SessionUtil trước khi xử lý
 *
 * @author fruitmkt-team
 */
@WebServlet("/auth/register")
@MultipartConfig(
    maxFileSize    = 26_214_400L,   // 25MB mỗi file
    maxRequestSize = 264_241_152L,  // ~252MB tổng (10 file × 25MB + overhead)
    fileSizeThreshold = 1_048_576   // 1MB: dưới ngưỡng này giữ trong RAM
)
public class RegisterServlet extends HttpServlet {

    private static final Logger log = Logger.getLogger(RegisterServlet.class.getName());

    private final AuthService authService = new AuthService();
    private final CategoryDAO categoryDAO = new CategoryDAO();
    private final ShopService shopService = new ShopService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        HttpSession session = req.getSession(false);
        User currentUser = SessionUtil.getCurrentUser(session);
        if (currentUser != null) {
            try {
                if (shopService.getShopByUserId(currentUser.getUserId()) != null) {
                    ShopStatusRedirectUtil.redirectToShopStatusIfProfileExists(req, resp, currentUser, session);
                    return;
                }
            } catch (SQLException e) {
                getServletContext().log("RegisterServlet GET: Không kiểm tra được trạng thái shop profile", e);
            }
            if ("ADMIN".equals(currentUser.getRole()) || "DELIVERY".equals(currentUser.getRole())) {
                ShopStatusRedirectUtil.redirectToRoleHome(req, resp, currentUser);
                return;
            }
            req.setAttribute("prefilledUser", currentUser);
        }

        // Load danh mục active từ DB để render checkbox động
        try {
            List<Category> categories = categoryDAO.findAllActive();
            req.setAttribute("categories", categories);
        } catch (SQLException e) {
            getServletContext().log("RegisterServlet GET: Không tải được categories", e);
            req.setAttribute("categories", new ArrayList<>());
        }
        req.getRequestDispatcher("/WEB-INF/jsp/auth/register.jsp").forward(req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        req.setCharacterEncoding("UTF-8");

        String sessionCsrf = (String) req.getSession().getAttribute(AppConfig.SESSION_CSRF_TOKEN);
        String reqCsrf = req.getParameter("_csrf");
        if (sessionCsrf == null || !sessionCsrf.equals(reqCsrf)) {
            forwardWithError(req, resp, "CSRF token không hợp lệ hoặc phiên làm việc đã hết hạn.");
            return;
        }

        HttpSession session = req.getSession(false);
        User currentUser = SessionUtil.getCurrentUser(session);
        if (currentUser != null) {
            handleUserUpgrade(req, resp, currentUser);
            return;
        }

        handleNewRegistration(req, resp);
    }

    private void handleNewRegistration(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        HttpSession session = req.getSession();
        User newUser = null;
        List<String> promotedDocPaths = new ArrayList<>();

        try {
            String role = req.getParameter("accountType");
            String fullName = sanitizeInput(req.getParameter("fullName"));
            String email = sanitizeInput(req.getParameter("email"));
            String phone = sanitizeInput(req.getParameter("phone"));
            String password = req.getParameter("password");
            String confirmPassword = req.getParameter("confirmPassword");
            String storeName = sanitizeInput(req.getParameter("storeName"));
            String address = sanitizeInput(req.getParameter("address"));
            String businessEmail = sanitizeInput(req.getParameter("businessEmail"));

            fullName = util.ValidationUtil.requireNotBlank(fullName, "Họ và tên");
            email = util.ValidationUtil.requireValidEmail(email, "Email");
            phone = util.ValidationUtil.requireValidPhone(phone, "Số điện thoại");
            password = util.ValidationUtil.requireValidPassword(password, "Mật khẩu");
            confirmPassword = util.ValidationUtil.requireNotBlank(confirmPassword, "Mật khẩu xác nhận");

            if (!password.equals(confirmPassword)) {
                throw new Exception("Mật khẩu xác nhận không khớp!");
            }

            if (role == null || (!role.equals("CUSTOMER") && !role.equals("SHOP_OWNER"))) {
                role = "CUSTOMER";
            }

            if (req.getParameter("terms") == null) {
                throw new Exception("Bạn phải đồng ý với điều khoản sử dụng trước khi tiếp tục.");
            }

            String preferredCategoriesJson = null;
            if ("SHOP_OWNER".equals(role)) {
                storeName = util.ValidationUtil.requireValidShopName(storeName, "Tên cửa hàng");
                address = util.ValidationUtil.requireValidAddress(address, "Địa chỉ kinh doanh");
                businessEmail = util.ValidationUtil.requireValidEmail(businessEmail, "Email liên hệ kinh doanh");
                preferredCategoriesJson = buildCategoryJson(req.getParameterValues("categoryIds"));
                if (preferredCategoriesJson == null) {
                    throw new Exception("Vui lòng chọn ít nhất một danh mục sản phẩm.");
                }

                List<String> draftPaths = collectVerificationDraftDocs(req, session);
                String draftDocPathsJson = ShopDocDraftUtil.toJsonArray(draftPaths);

                User user = buildUserFromForm(fullName, email, password, phone, role);
                newUser = authService.register(user, storeName, address, preferredCategoriesJson, draftDocPathsJson);
                promotedDocPaths = ShopDocDraftUtil.promoteDraftDocs(session, ShopDocDraftUtil.REGISTER_SCOPE, newUser.getUserId());
                String finalDocPathsJson = ShopDocDraftUtil.toJsonArray(promotedDocPaths);
                shopService.finalizeRegisteredShopProfile(newUser.getUserId(), storeName, address,
                        preferredCategoriesJson, businessEmail, finalDocPathsJson);
                ShopDocDraftUtil.clearDraftDocs(session, ShopDocDraftUtil.REGISTER_SCOPE);
            } else {
                User user = buildUserFromForm(fullName, email, password, phone, role);
                newUser = authService.register(user);
            }

            SessionUtil.flashSuccess(session, "Đăng ký thành công! Vui lòng kiểm tra email để xác minh trong 5 phút.");
            session.setAttribute(AppConfig.SESSION_VERIFY_EMAIL, newUser.getEmail());
            resp.sendRedirect(req.getContextPath() + "/auth/verify");

        } catch (Exception e) {
            rollbackRegisterFailure(newUser, promotedDocPaths);
            HttpSession errorSession = req.getSession(false);
            if (errorSession != null) {
                errorSession.removeAttribute(AppConfig.SESSION_VERIFY_EMAIL);
            }
            getServletContext().log("RegisterServlet error: " + util.ErrorMessageUtil.getSafeLogMessage(e), e);
            forwardWithError(req, resp, util.ErrorMessageUtil.getUserMessage(e));
        }
    }

    private void handleUserUpgrade(HttpServletRequest req, HttpServletResponse resp, User currentUser)
            throws ServletException, IOException {
        HttpSession session = req.getSession(false);
        List<String> promotedDocPaths = new ArrayList<>();

        try {
            String storeName = sanitizeInput(req.getParameter("storeName"));
            String address = sanitizeInput(req.getParameter("address"));
            String businessEmail = sanitizeInput(req.getParameter("businessEmail"));
            String phone = sanitizeInput(req.getParameter("phone"));
            String agreeTerms = req.getParameter("terms");

            storeName = util.ValidationUtil.requireValidShopName(storeName, "Tên cửa hàng");
            address = util.ValidationUtil.requireValidAddress(address, "Địa chỉ kinh doanh");
            businessEmail = util.ValidationUtil.requireValidEmail(businessEmail, "Email liên hệ kinh doanh");
            String preferredCategoriesJson = buildCategoryJson(req.getParameterValues("categoryIds"));
            if (preferredCategoriesJson == null) {
                throw new Exception("Vui lòng chọn ít nhất một danh mục sản phẩm.");
            }

            if (agreeTerms == null) {
                throw new Exception("Bạn phải đồng ý với điều khoản sử dụng trước khi gửi đơn.");
            }

            if (currentUser.getPhone() == null || currentUser.getPhone().trim().isEmpty()) {
                phone = util.ValidationUtil.requireValidPhone(phone, "Số điện thoại");
            } else if (phone != null && !phone.trim().isEmpty()) {
                phone = util.ValidationUtil.requireValidPhone(phone, "Số điện thoại");
                if (phone.equals(currentUser.getPhone().trim())) {
                    phone = null;
                }
            } else {
                phone = null;
            }

            if (shopService.getShopByUserId(currentUser.getUserId()) != null) {
                throw new Exception("Tài khoản của bạn đã đăng ký hoặc nộp đơn mở cửa hàng rồi.");
            }

            collectVerificationDraftDocs(req, session);

            promotedDocPaths = ShopDocDraftUtil.promoteDraftDocs(session, ShopDocDraftUtil.REGISTER_SCOPE, currentUser.getUserId());
            String docPathsJson = ShopDocDraftUtil.toJsonArray(promotedDocPaths);

            model.entity.shop.ShopProfile profile = new model.entity.shop.ShopProfile();
            profile.setUserId(currentUser.getUserId());
            profile.setShopName(storeName);
            profile.setShopDescription("Chào mừng tới cửa hàng của chúng tôi!");
            profile.setApprovalStatus(AppConfig.SHOP_PENDING);
            profile.setDeliveryAddress(address);
            profile.setRating(java.math.BigDecimal.ZERO);
            profile.setPreferredCategories(preferredCategoriesJson);
            profile.setDocPaths(docPathsJson);
            profile.setBusinessEmail(businessEmail);

            shopService.submitShopApplication(profile, phone);
            if (phone != null) {
                currentUser.setPhone(phone);
                session.setAttribute(AppConfig.SESSION_USER, currentUser);
            }

            ShopDocDraftUtil.clearDraftDocs(session, ShopDocDraftUtil.REGISTER_SCOPE);
            if (ShopStatusRedirectUtil.redirectToShopStatusIfProfileExists(req, resp, currentUser, session)) {
                return;
            }
            ShopStatusRedirectUtil.redirectToRoleHome(req, resp, currentUser);

        } catch (Exception e) {
            rollbackPromotedDocs(promotedDocPaths);
            getServletContext().log("RegisterServlet upgrade error: " + util.ErrorMessageUtil.getSafeLogMessage(e), e);
            forwardWithError(req, resp, util.ErrorMessageUtil.getUserMessage(e));
        }
    }

    private void rollbackRegisterFailure(User createdUser, List<String> promotedDocPaths) {
        rollbackPromotedDocs(promotedDocPaths);
        if (createdUser == null) {
            return;
        }
        try {
            new dao.shop.ShopProfileDAO().deleteByUserId(createdUser.getUserId());
        } catch (Exception ex) {
            getServletContext().log("Rollback shop profile failed: " + util.ErrorMessageUtil.getSafeLogMessage(ex), ex);
        }
        try {
            new UserDAO().deleteUser(createdUser.getUserId());
        } catch (Exception ex) {
            getServletContext().log("Rollback user failed: " + util.ErrorMessageUtil.getSafeLogMessage(ex), ex);
        }
    }

    private void rollbackPromotedDocs(List<String> promotedDocPaths) {
        if (promotedDocPaths == null || promotedDocPaths.isEmpty()) {
            return;
        }
        for (String path : promotedDocPaths) {
            FileUploadUtil.delete(path);
        }
    }

    /** Tạo User entity từ dữ liệu form đăng ký (dùng chung cho nhánh CUSTOMER & SHOP_OWNER). */
    private User buildUserFromForm(String fullName, String email, String password, String phone, String role) {
        User user = new User();
        user.setFullName(fullName);
        user.setEmail(email);
        user.setPasswordHash(password);
        user.setPhone(phone);
        user.setRole(role);
        return user;
    }

    /**
     * Nhận file tài liệu xác minh shop từ request, lưu vào draft theo session và trả về danh sách
     * đường dẫn draft. Ném lỗi nếu chưa có tài liệu nào. Dùng chung cho đăng ký mới & nâng cấp shop.
     */
    private List<String> collectVerificationDraftDocs(HttpServletRequest req, HttpSession session) throws Exception {
        List<String> uploadedDraftPaths = ShopDocDraftUtil.uploadDraftDocs(
                req, "businessDocs", ShopDocDraftUtil.REGISTER_SCOPE);
        if (!uploadedDraftPaths.isEmpty()) {
            ShopDocDraftUtil.replaceDraftDocs(session, ShopDocDraftUtil.REGISTER_SCOPE, uploadedDraftPaths);
        }
        List<String> draftPaths = ShopDocDraftUtil.getDraftPaths(session, ShopDocDraftUtil.REGISTER_SCOPE);
        if (draftPaths.isEmpty()) {
            throw new Exception("Vui lòng tải lên ít nhất một tài liệu xác minh.");
        }
        return draftPaths;
    }

    private String buildCategoryJson(String[] catIds) {
        if (catIds == null || catIds.length == 0) {
            return null;
        }
        StringBuilder sb = new StringBuilder("[");
        boolean first = true;
        for (String id : catIds) {
            try {
                int catId = Integer.parseInt(id);
                if (!first) {
                    sb.append(",");
                }
                sb.append(catId);
                first = false;
            } catch (NumberFormatException e) {
                LoggerUtil.warn(log, "ID danh mục không hợp lệ: " + id, e);
            }
        }
        if (first) {
            return null;
        }
        sb.append("]");
        return sb.toString();
    }

    /** XSS Sanitizer helper to strip HTML tags from user inputs */
    private String sanitizeInput(String input) {
        if (input == null) return null;
        // Strip out HTML tags to defend against XSS Injection attacks
        return input.replaceAll("<[^>]*>", "").trim();
    }

    /** Forward về form với thông báo lỗi và load lại categories */
    private void forwardWithError(HttpServletRequest req, HttpServletResponse resp, String errorMsg)
            throws ServletException, IOException {
        try {
            req.setAttribute("categories", categoryDAO.findAllActive());
        } catch (SQLException ex) {
            req.setAttribute("categories", new ArrayList<>());
        }
        HttpSession session = req.getSession(false);
        User currentUser = SessionUtil.getCurrentUser(session);
        if (currentUser != null) {
            req.setAttribute("prefilledUser", currentUser);
        }
        ShopDocDraftUtil.exposeDraftDocs(session, req, ShopDocDraftUtil.REGISTER_SCOPE, "registerDraftDocPaths");
        req.setAttribute("errorMsg", errorMsg);
        req.getRequestDispatcher("/WEB-INF/jsp/auth/register.jsp").forward(req, resp);
    }
}
