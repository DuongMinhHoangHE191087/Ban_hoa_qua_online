package servlet.admin.user;

import config.AppConfig;
import model.entity.auth.User;
import model.response.ApiResponse;
import service.auth.AuthService;
import util.JsonUtil;
import util.LoggerUtil;
import util.SessionUtil;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.util.logging.Logger;

@WebServlet("/admin/users/create-delivery")
public class AdminCreateDeliveryAPI extends HttpServlet {

    private static final Logger log = Logger.getLogger(AdminCreateDeliveryAPI.class.getName());

    private final AuthService authService = new AuthService();

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        response.setContentType("application/json;charset=UTF-8");
        response.setCharacterEncoding("UTF-8");

        // Kiểm tra quyền ADMIN
        if (!SessionUtil.hasRole(request.getSession(false), AppConfig.ROLE_ADMIN)) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            JsonUtil.writeJson(response, ApiResponse.fail(HttpServletResponse.SC_FORBIDDEN, "Không có quyền thực hiện thao tác này."));
            return;
        }

        try {
            String fullName = request.getParameter("fullName");
            String email = request.getParameter("email");
            String phone = request.getParameter("phone");

            if (fullName == null || fullName.trim().isEmpty() ||
                email == null || email.trim().isEmpty() ||
                phone == null || phone.trim().isEmpty()) {
                response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
                JsonUtil.writeJson(response, ApiResponse.fail(HttpServletResponse.SC_BAD_REQUEST, "Vui lòng điền đầy đủ họ tên, email và số điện thoại."));
                return;
            }

            User newDeliveryStaff = authService.createDeliveryStaff(fullName.trim(), email.trim(), phone.trim());

            if (newDeliveryStaff != null) {
                response.setStatus(HttpServletResponse.SC_OK);
                JsonUtil.writeJson(response, ApiResponse.ok("Tạo tài khoản giao hàng thành công. Mật khẩu đã được gửi qua email."));
            } else {
                response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
                JsonUtil.writeJson(response, ApiResponse.fail(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "Lỗi khi tạo tài khoản."));
            }
        } catch (IllegalArgumentException e) {
            response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            JsonUtil.writeJson(response, ApiResponse.fail(HttpServletResponse.SC_BAD_REQUEST, e.getMessage()));
        } catch (Exception e) {
            if (e.getMessage() != null && (e.getMessage().contains("tồn tại") || e.getMessage().contains("hợp lệ") || e.getMessage().contains("trống"))) {
                response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
                JsonUtil.writeJson(response, ApiResponse.fail(HttpServletResponse.SC_BAD_REQUEST, e.getMessage()));
            } else {
                util.ServletUtil.sendJsonInternalServerError(
                        request,
                        response,
                        log,
                        "AdminCreateDeliveryAPI#doPost",
                        "Lỗi hệ thống khi tạo tài khoản giao hàng.",
                        e);
            }
        }
    }
}
