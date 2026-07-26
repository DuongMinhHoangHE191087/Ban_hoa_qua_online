package servlet.auth;

import config.AppConfig;
import model.entity.auth.User;
import service.auth.AuthService;
import service.auth.AuthService.VerificationRequiredException;
import util.SessionUtil;
import util.TokenUtil;
import util.ShopStatusRedirectUtil;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.sql.SQLException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

/**
 * LoginServlet — Controller cho chức năng: Hiển thị form đăng nhập và xử lý xác thực
 *
 * URL: /auth/login
 * GET : Hiển thị form đăng nhập (tự động điều hướng nếu đã đăng nhập)
 * POST: Xác thực thông tin, cấp phát bộ đôi cookie HttpOnly Access & Refresh Token, và chuyển hướng theo role.
 *
 * @author fruitmkt-team
 */
@WebServlet("/auth/login")
public class LoginServlet extends HttpServlet {

    private final AuthService authService = new AuthService();
    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        
        // Nếu người dùng đã đăng nhập từ trước, tự động chuyển hướng về trang tương ứng theo phân quyền
        HttpSession session = req.getSession(false);
        if (SessionUtil.isLoggedIn(session)) {
            User user = SessionUtil.getCurrentUser(session);
            if (ShopStatusRedirectUtil.redirectToShopStatusIfProfileExists(req, resp, user, session)) {
                return;
            }
            ShopStatusRedirectUtil.redirectToRoleHome(req, resp, user);
            return;
        }
        
        // Forward trực tiếp đến trang JSP đăng nhập an toàn
        if ("success".equals(req.getParameter("logout"))) {
            req.setAttribute("successMsg", "Đăng xuất tài khoản thành công!");
        }
        req.getRequestDispatcher("/WEB-INF/jsp/auth/login.jsp").forward(req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        
        String identifier = req.getParameter("identifier");
        String password = req.getParameter("password");
        String redirectTarget = req.getParameter("redirect");
        
        // Chuẩn hóa identifier (email/SĐT) được xử lý tập trung trong AuthService.login()
        // — servlet chỉ đọc tham số thô, tránh trùng lặp logic normalize (single source of truth).
        
        // 1. Kiểm tra CSRF token thủ công tại Servlet để tăng tính bảo mật
        String sessionCsrf = (String) req.getSession().getAttribute(AppConfig.SESSION_CSRF_TOKEN);
        String reqCsrf = req.getParameter("_csrf");
        if (sessionCsrf == null || !sessionCsrf.equals(reqCsrf)) {
            req.setAttribute("errorMsg", "CSRF token không hợp lệ hoặc phiên làm việc đã hết hạn.");
            req.getRequestDispatcher("/WEB-INF/jsp/auth/login.jsp").forward(req, resp);
            return;
        }

        try {
            // 2. Xác thực credentials từ AuthService
            User user = authService.login(identifier, password);
            
            // 3. Chống tấn công Session Fixation bằng cách hủy session cũ và tạo session mới
            req.getSession().invalidate();
            HttpSession newSession = req.getSession(true);
            newSession.setAttribute(AppConfig.SESSION_CSRF_TOKEN, java.util.UUID.randomUUID().toString());
            SessionUtil.setCurrentUser(newSession, user);
            
            // 4. Tạo bộ đôi Access Token (15 phút) & Refresh Token (7 ngày)
            String accessToken = TokenUtil.generateAccessToken(user.getUserId());
            TokenUtil.addAccessTokenCookie(req, resp, accessToken);
            
            String refreshToken = TokenUtil.generateRefreshToken();
            java.sql.Timestamp expiresAt = new java.sql.Timestamp(System.currentTimeMillis() + (long) TokenUtil.REFRESH_TOKEN_EXPIRY_SECS * 1000);
            
            // Lưu Refresh Token vào Database thông qua AuthService
            authService.saveUserSession(user.getUserId(), refreshToken, expiresAt);
            TokenUtil.addRefreshTokenCookie(req, resp, refreshToken);
            
            // 5. Thiết lập flash message chào mừng thành công
            SessionUtil.flashSuccess(newSession, "Chào mừng quay trở lại, " + user.getFullName() + "!");
            
            // 6. Xử lý chuyển hướng (Redirect)
            // ALLOWLIST: chỉ chấp nhận đường dẫn nội bộ — phải bắt đầu bằng "/" nhưng
            // không phải "//" (protocol-relative) và không chứa "://" (absolute URL).
            if (redirectTarget != null && !redirectTarget.trim().isEmpty()) {
                String cleanTarget = redirectTarget.trim();
                boolean isSafeInternal = cleanTarget.startsWith("/")
                        && !cleanTarget.startsWith("//")
                        && !cleanTarget.contains("://");
                if (isSafeInternal) {
                    resp.sendRedirect(cleanTarget);
                } else {
                    if (ShopStatusRedirectUtil.redirectToShopStatusIfProfileExists(req, resp, user, newSession)) {
                        return;
                    }
                    ShopStatusRedirectUtil.redirectToRoleHome(req, resp, user);
                }
            } else {
                if (ShopStatusRedirectUtil.redirectToShopStatusIfProfileExists(req, resp, user, newSession)) {
                    return;
                }
                ShopStatusRedirectUtil.redirectToRoleHome(req, resp, user);
            }
            
        } catch (VerificationRequiredException e) {
            HttpSession session = req.getSession(true);
            SessionUtil.flashError(session, "Tài khoản chưa được xác minh. Vui lòng nhập mã code để kích hoạt tài khoản.");
            session.setAttribute(AppConfig.SESSION_VERIFY_EMAIL, e.getEmail());
            resp.sendRedirect(req.getContextPath() + "/auth/verify");

        } catch (Exception e) {
            // Đăng nhập thất bại -> Hiển thị lỗi thân thiện
            req.setAttribute("errorMsg", util.ErrorMessageUtil.getUserMessage(e));
            req.getRequestDispatcher("/WEB-INF/jsp/auth/login.jsp").forward(req, resp);
        }
    }
    
}
