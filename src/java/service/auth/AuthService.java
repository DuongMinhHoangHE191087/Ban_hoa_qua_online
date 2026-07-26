package service.auth;

import exception.BusinessException;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.security.SecureRandom;
import java.util.UUID;

import config.AppConfig;
import dao.cart.CartDAO;
import dao.auth.UserDAO;
import dao.auth.UserSessionDAO;
import model.entity.auth.User;
import service.system.EmailService;
import util.HashUtil;
import util.ValidationUtil;
/**
 * AuthService — Tầng business logic cho nghiệp vụ tương ứng.
 *
 * QUY TẮC:
 *   - Chỉ gọi DAO, không viết SQL ở đây
 *   - Chứa tất cả validation và business rule
 *   - Ném RuntimeException hoặc custom exception cho Servlet xử lý
 *   - Không tương tác trực tiếp với HttpRequest/Response
 *
 * @author fruitmkt-team
 */
public class AuthService {
    private final UserDAO userDAO = new UserDAO();
    private final UserSessionDAO userSessionDAO = new UserSessionDAO();
    private final EmailService emailService = new EmailService();
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    public static class VerificationRequiredException extends Exception {
        private final String email;

        public VerificationRequiredException(String email, String message) {
            super(message);
            this.email = email;
        }

        public String getEmail() {
            return email;
        }
    }

    /**
     * Đăng ký tài khoản khách hàng (không có thông tin shop)
     */
    public User register(model.entity.auth.User user) throws SQLException, Exception {
        return register(user, null, null, null, null);
    }

    /**
     * Đăng ký tài khoản (có thông tin shop cơ bản, không có danh mục/doc)
     */
    public User register(model.entity.auth.User user, String shopName, String shopAddress) throws SQLException, Exception {
        return register(user, shopName, shopAddress, null, null);
    }

    /**
     * Đăng ký tài khoản đầy đủ — hỗ trợ cả CUSTOMER và SHOP_OWNER.
     * @param preferredCategoriesJson JSON array category_id dự kiến KD: "[1,3,5]" hoặc null
     * @param docPathsJson            JSON array đường dẫn file tài liệu hoặc null
     */
    public User register(model.entity.auth.User user, String shopName, String shopAddress,
                         String preferredCategoriesJson, String docPathsJson) throws SQLException, Exception {
        if (user == null) {
            throw new IllegalArgumentException("Thông tin tài khoản không được để trống.");
        }
        // Validate input bằng ValidationUtil
        user.setFullName(ValidationUtil.requireNotBlank(user.getFullName(), "Họ và tên"));
        user.setEmail(ValidationUtil.requireValidEmail(user.getEmail(), "Email"));
        user.setPasswordHash(ValidationUtil.requireValidPassword(user.getPasswordHash(), "Mật khẩu"));
        user.setPhone(ValidationUtil.requireValidPhone(user.getPhone(), "Số điện thoại"));

        User existingUser = userDAO.findByEmail(user.getEmail());
        if (existingUser != null) {
            throw new Exception("Địa chỉ email đã được đăng ký bởi tài khoản khác, vui lòng đăng nhập!");
        }

        User existingPhoneUser = userDAO.findByPhone(user.getPhone());
        if (existingPhoneUser != null) {
            throw new Exception("Số điện thoại đã được đăng ký bởi tài khoản khác, vui lòng đăng nhập!");
        }

        // Băm mật khẩu để bảo mật trước khi đưa xuống DAO
        String requestedRole = user.getRole();
        boolean shopOwnerRegistration = AppConfig.ROLE_SHOP_OWNER.equals(requestedRole);
        user.setRole(AppConfig.ROLE_CUSTOMER);

        String hashedPass = HashUtil.hashPassword(user.getPasswordHash());

        // Hàm save hoặc insert của DAO
        int insertedId = userDAO.saveNewCustomer(user.getFullName(), user.getEmail(), hashedPass, user.getPhone(), user.getRole(), AppConfig.ACCOUNT_STATUS_INACTIVE, false);
        if (insertedId > 0) {
            try {
                User createdUser = userDAO.findByEmail(user.getEmail());
                if (createdUser == null) {
                    throw new Exception("Không thể tải lại thông tin tài khoản vừa tạo.");
                }

                issueVerificationCode(createdUser);

                CartDAO cartDAO = new CartDAO();
                cartDAO.createForCustomer(insertedId);

                return createdUser;
            } catch (Exception ex) {
                try {
                    if (shopOwnerRegistration) {
                        new dao.shop.ShopProfileDAO().deleteByUserId(insertedId);
                    }
                    userDAO.deleteUser(insertedId);
                } catch (SQLException sqle) {
                    // Bỏ qua lỗi xóa phụ để ném ra lỗi chính ban đầu
                }
                throw ex;
            }
        }
        throw new Exception("Lỗi hệ thống khi tạo tài khoản.");
    }

    /**
     * Tạo tài khoản Delivery Staff bởi Admin.
     * Tự động sinh mật khẩu tạm và gửi qua email.
     */
    public User createDeliveryStaff(String fullName, String email, String phone) throws Exception {
        // Validate input
        fullName = ValidationUtil.requireNotBlank(fullName, "Họ và tên");
        email = ValidationUtil.requireValidEmail(email, "Email");
        phone = ValidationUtil.requireValidPhone(phone, "Số điện thoại");

        // Check trùng lặp
        if (userDAO.findByEmail(email) != null) {
            throw new Exception("Địa chỉ email đã tồn tại trong hệ thống.");
        }
        if (userDAO.findByPhone(phone) != null) {
            throw new Exception("Số điện thoại đã tồn tại trong hệ thống.");
        }

        // Sinh mật khẩu tạm (8 ký tự)
        String tempPassword = UUID.randomUUID().toString().substring(0, 8);
        String hashedPass = HashUtil.hashPassword(tempPassword);

        // Lưu user với role DELIVERY, trạng thái ACTIVE, đã xác minh email
        int insertedId = userDAO.saveNewCustomer(fullName, email, hashedPass, phone, AppConfig.ROLE_DELIVERY, AppConfig.ACCOUNT_STATUS_ACTIVE, true);
        if (insertedId > 0) {
            User createdUser = userDAO.findByEmail(email);
            if (createdUser != null) {
                // Gửi email chứa mật khẩu tạm
                emailService.sendDeliveryStaffWelcomeEmail(email, fullName, tempPassword);
                return createdUser;
            }
        }
        throw new Exception("Lỗi hệ thống khi tạo tài khoản giao hàng.");
    }

    /**
     * TODO: Implement — xem SRS / use case tương ứng
     */
    public model.entity.auth.User login(String identifier, String password) throws SQLException, Exception {
        if (!ValidationUtil.notBlank(identifier)) {
            throw new BusinessException("AUTH_IDENTIFIER_REQUIRED", "Email hoặc số điện thoại không được để trống.");
        }

        String cleanIdentifier = identifier.trim();
        if (cleanIdentifier.matches("^(0|\\+84|84)\\d+$") || cleanIdentifier.matches("^\\d+$")) {
            cleanIdentifier = ValidationUtil.normalizePhone(cleanIdentifier);
        }

        User user = userDAO.findByLoginIdentifier(cleanIdentifier);
        if (user == null) {
            // Generic message — không tiết lộ sự tồn tại của tài khoản (anti-enumeration, SEC-03)
            throw new BusinessException("AUTH_INVALID_CREDENTIALS", "Email hoặc mật khẩu không chính xác.");
        }

        // 1. Kiểm tra tài khoản có bị khóa hay không
        if (user.getLockedUntil() != null && LocalDateTime.now().isBefore(user.getLockedUntil())) {
            DateTimeFormatter dtf = DateTimeFormatter.ofPattern("HH:mm:ss dd/MM/yyyy");
            throw new BusinessException("AUTH_ACCOUNT_LOCKED", "Tài khoản đang bị khóa tạm thời do nhập sai mật khẩu quá nhiều lần. Vui lòng thử lại sau: "
                + user.getLockedUntil().format(dtf));
        }

        // 2. Kiểm tra đối chiếu hash
        if (!HashUtil.verify(password, user.getPasswordHash())) {
            // Tăng số lần nhập sai
            userDAO.incrementFailedLogin(user.getUserId());
            int newFailedCount = user.getFailedLoginCount() + 1;
            
            if (newFailedCount >= AppConfig.MAX_FAILED_LOGIN) {
                LocalDateTime lockTime = LocalDateTime.now().plusMinutes(AppConfig.LOCK_DURATION_MINUTES);
                userDAO.lockAccount(user.getUserId(), lockTime);
                DateTimeFormatter dtf2 = DateTimeFormatter.ofPattern("HH:mm:ss dd/MM/yyyy");
                throw new BusinessException("AUTH_ACCOUNT_LOCKED", "Tài khoản đã bị khóa tạm thời. Vui lòng thử lại sau: " + lockTime.format(dtf2));
            }
            // Generic message — không tiết lộ số lần còn lại (anti-enumeration, SEC-03)
            throw new BusinessException("AUTH_INVALID_CREDENTIALS", "Email hoặc mật khẩu không chính xác.");
        }

        if (!AppConfig.ACCOUNT_STATUS_ACTIVE.equals(user.getStatus())) {
            if (AppConfig.ACCOUNT_STATUS_INACTIVE.equals(user.getStatus())) {
                throw new VerificationRequiredException(user.getEmail(), "Tài khoản chưa được xác minh. Vui lòng nhập mã code để kích hoạt tài khoản.");
            }
            if (AppConfig.ACCOUNT_STATUS_SUSPENDED.equals(user.getStatus())) {
                throw new BusinessException("AUTH_ACCOUNT_SUSPENDED", "Tài khoản đã bị đình chỉ bởi Quản trị viên. Vui lòng liên hệ bộ phận hỗ trợ.");
            }
            if (AppConfig.ACCOUNT_STATUS_LOCKED.equals(user.getStatus())) {
                throw new BusinessException("AUTH_ACCOUNT_LOCKED", "Tài khoản đang bị khóa tạm thời do hệ thống. Vui lòng thử lại sau khi hệ thống mở khóa.");
            }
            throw new BusinessException("AUTH_ACCOUNT_UNAVAILABLE", "Tài khoản không thể đăng nhập ở trạng thái hiện tại.");
        }

        if (!user.isEmailVerified()) {
            throw new VerificationRequiredException(user.getEmail(), "Tài khoản chưa được xác minh. Vui lòng nhập mã code để kích hoạt tài khoản.");
        }

        // 3. Đăng nhập thành công: reset số lần sai
        if (user.getFailedLoginCount() > 0 || user.getLockedUntil() != null) {
            userDAO.resetFailedLogin(user.getUserId());
        }
        return user;
    }

    /**
     * Logout — xóa session và refresh token của user
     */
    public void logout(int userId) throws SQLException {
        if (userId <= 0) {
            throw new IllegalArgumentException("User ID không hợp lệ.");
        }
        // Xóa tất cả refresh token của user (logged out từ mọi thiết bị)
        // Thực hiện: gọi UserSessionDAO.deleteByUserId(userId) nếu tồn tại
        // Hiện tại, session được quản lý bởi servlet container, nên chỉ cần invalidate session
        // trong LogoutServlet. Method này có thể mở rộng sau nếu dùng refresh token DB.
    }

    /**
     * Xử lý đăng nhập thất bại — hiện tại logic được xử lý trực tiếp trong login()
     */
    public void handleFailedLogin(String email) throws SQLException {
        if (!ValidationUtil.notBlank(email)) {
            throw new IllegalArgumentException("Email không được để trống.");
        }
        User user = userDAO.findByEmail(email);
        if (user == null) {
            return;  // User không tồn tại, skip
        }
        userDAO.incrementFailedLogin(user.getUserId());
        int newFailedCount = user.getFailedLoginCount() + 1;
        if (newFailedCount >= AppConfig.MAX_FAILED_LOGIN) {
            LocalDateTime lockTime = LocalDateTime.now().plusMinutes(AppConfig.LOCK_DURATION_MINUTES);
            userDAO.lockAccount(user.getUserId(), lockTime);
        }
    }

    /**
     * TODO: Implement — xem SRS / use case tương ứng
     */
    /**
     * Đặt lại mật khẩu sau khi đã xác minh OTP forgot-password thành công.
     */
    public void resetPassword(String email, String newPassword) throws Exception {
        if (!ValidationUtil.notBlank(email) || !ValidationUtil.isValidEmail(email)) {
            throw new Exception("Email không hợp lệ.");
        }
        if (!ValidationUtil.isValidPassword(newPassword)) {
            throw new Exception("Mật khẩu mới phải từ 8 đến 64 ký tự.");
        }

        User user = userDAO.findByEmail(email);
        if (user == null) {
            throw new Exception("Không tìm thấy tài khoản.");
        }

        String newHash = HashUtil.hashPassword(newPassword);
        userDAO.updatePassword(user.getUserId(), newHash);
        userDAO.clearForgotPasswordCode(user.getUserId());
    }

    /**
     * Đổi mật khẩu cho user đã đăng nhập — yêu cầu xác nhận mật khẩu cũ.
     *
     * @param userId          ID user đang đăng nhập (lấy từ session)
     * @param currentPassword Mật khẩu hiện tại để xác nhận
     * @param newPassword     Mật khẩu mới
     */
    public void changePassword(int userId, String currentPassword, String newPassword) throws Exception {
        if (userId <= 0) {
            throw new IllegalArgumentException("User ID không hợp lệ.");
        }
        if (currentPassword == null || currentPassword.trim().isEmpty()) {
            throw new IllegalArgumentException("Mật khẩu hiện tại không được để trống.");
        }
        if (newPassword == null || newPassword.trim().isEmpty()) {
            throw new IllegalArgumentException("Mật khẩu mới không được để trống.");
        }
        if (!ValidationUtil.isValidPassword(newPassword)) {
            throw new Exception("Mật khẩu mới phải từ 8 đến 64 ký tự.");
        }

        User user = userDAO.findUserById(userId);
        if (user == null) {
            throw new Exception("Không tìm thấy tài khoản.");
        }

        // Tài khoản Google OAuth không có mật khẩu thật — không cho đổi theo cách này
        if (user.getPasswordHash() == null) {
            throw new Exception("Tài khoản liên kết Google không hỗ trợ tính năng này.");
        }

        if (!HashUtil.verify(currentPassword, user.getPasswordHash())) {
            throw new Exception("Mật khẩu hiện tại không chính xác.");
        }

        if (HashUtil.verify(newPassword, user.getPasswordHash())) {
            throw new Exception("Mật khẩu mới không được trùng với mật khẩu hiện tại.");
        }

        String newHash = HashUtil.hashPassword(newPassword);
        userDAO.updatePassword(userId, newHash);
    }

    /**
     * Gửi OTP đặt lại mật khẩu đến email.
     * Nếu email chưa đăng kí: silently skip (không lộ thông tin user existence).
     *
     * @return true nếu đã gửi mail, false nếu email không tồn tại (caller hiển thị cùng UI)
     */
    public boolean sendForgotPasswordCode(String email) throws Exception {
        if (!ValidationUtil.notBlank(email) || !ValidationUtil.isValidEmail(email)) {
            throw new Exception("Email không hợp lệ.");
        }

        User user = userDAO.findByEmail(email);
        if (user == null) {
            // Anti-enumeration: không báo lỗi — trả false để servlet biết nhưng không lộ ra UI
            return false;
        }

        // Kiểm tra cooldown giống resend email verify
        if (user.getEmailVerificationResendAt() != null
                && LocalDateTime.now().isBefore(user.getEmailVerificationResendAt())) {
            throw new Exception("Vui lòng chờ 1 phút rồi mới gửi lại mã.");
        }

        issueVerificationCode(user);
        return true;
    }

    /**
     * Xác minh OTP forgot-password — GIỐNG verifyEmailCode nhưng KHÔNG activate tài khoản.
     * Chỉ trả về user để servlet có thể set session cờ.
     */
    public User verifyForgotCode(String email, String code) throws Exception {
        if (!ValidationUtil.notBlank(email) || !ValidationUtil.isValidEmail(email)) {
            throw new Exception("Email không hợp lệ.");
        }
        if (!ValidationUtil.notBlank(code)) {
            throw new Exception("Mã xác minh không được để trống.");
        }

        User user = userDAO.findByEmail(email);
        if (user == null) {
            throw new Exception("Không tìm thấy tài khoản.");
        }

        if (user.getEmailVerificationExpiresAt() == null
                || LocalDateTime.now().isAfter(user.getEmailVerificationExpiresAt())) {
            throw new Exception("Mã xác minh đã hết hạn. Vui lòng gửi lại mã mới.");
        }

        if (!HashUtil.verify(code.trim(), user.getEmailVerificationCodeHash())) {
            throw new Exception("Mã xác minh không đúng.");
        }

        // Không activate — chỉ xác nhận OTP hợp lệ
        return user;
    }

    /**
     * Kiểm tra xem email đã được đăng ký chưa
     */
    public boolean isEmailTaken(String email) throws SQLException {
        if (!ValidationUtil.notBlank(email)) {
            throw new IllegalArgumentException("Email không được để trống.");
        }
        if (!ValidationUtil.isValidEmail(email)) {
            throw new IllegalArgumentException("Email không hợp lệ.");
        }
        User user = userDAO.findByEmail(email.trim());
        return user != null;
    }
    public User processGoogleLogin(String email, String fullName) throws Exception {
        return processGoogleLogin(email, fullName, "assets/images/default-avatar.svg");
    }

    public User processGoogleLogin(String email, String fullName, String pictureUrl) throws Exception {
        if (email == null || email.trim().isEmpty()) {
            throw new IllegalArgumentException("Email không được để trống.");
        }
        if (fullName == null || fullName.trim().isEmpty()) {
            throw new IllegalArgumentException("Họ và tên không được để trống.");
        }
        User existingUser = userDAO.findByEmail(email);
        if (existingUser != null) {
            // UC-21: Chặn privilege-escalation — tài khoản ADMIN/SHOP_OWNER phải đăng nhập bằng mật khẩu
            String role = existingUser.getRole();
            if (AppConfig.ROLE_ADMIN.equals(role) || AppConfig.ROLE_SHOP_OWNER.equals(role)) {
                throw new Exception("Vui lòng đăng nhập bằng mật khẩu của bạn.");
            }
            
            String status = existingUser.getStatus();
            if (AppConfig.ACCOUNT_STATUS_SUSPENDED.equals(status)) {
                throw new Exception("Tài khoản đã bị đình chỉ bởi Quản trị viên. Vui lòng liên hệ bộ phận hỗ trợ.");
            }
            if (AppConfig.ACCOUNT_STATUS_LOCKED.equals(status)) {
                throw new Exception("Tài khoản đang bị khóa tạm thời do hệ thống. Vui lòng thử lại sau khi hệ thống mở khóa.");
            }

            // Chặn đăng nhập nếu tài khoản đang bị khóa tạm thời
            if (existingUser.getLockedUntil() != null && LocalDateTime.now().isBefore(existingUser.getLockedUntil())) {
                DateTimeFormatter dtf = DateTimeFormatter.ofPattern("HH:mm:ss dd/MM/yyyy");
                throw new Exception("Tài khoản đang bị khóa tạm thời. Vui lòng thử lại sau: " + existingUser.getLockedUntil().format(dtf));
            }

            if (AppConfig.ACCOUNT_STATUS_INACTIVE.equals(status) || !existingUser.isEmailVerified()) {
                userDAO.activateVerifiedEmail(existingUser.getUserId());
                existingUser = userDAO.findByEmail(email);
            }
            // Sync/update Google avatar if current avatar is null, default or if Google avatar was updated
            if (pictureUrl != null && !pictureUrl.trim().isEmpty()) {
                String currentAvatar = existingUser.getAvatarUrl();
                if (currentAvatar == null || currentAvatar.trim().isEmpty()
                        || currentAvatar.equals("assets/images/default-avatar.svg")
                        || currentAvatar.startsWith("https://lh3.googleusercontent.com")
                        || currentAvatar.startsWith("https://openidconnect.googleapis.com")
                        || currentAvatar.startsWith("https://www.googleapis.com")) {
                    userDAO.updateAvatar(existingUser.getUserId(), pictureUrl);
                    existingUser.setAvatarUrl(pictureUrl);
                }
            }
            return existingUser; 
        } else {
            // Sinh mật khẩu random an toàn vì Oauth không cung cấp pass
            String randomPass = UUID.randomUUID().toString();
            String hashedPass = HashUtil.hashPassword(randomPass);

            // Insert role mặc định CUSTOMER qua DAO
            int newId = userDAO.saveNewCustomer(fullName, email, hashedPass, null, "CUSTOMER", AppConfig.ACCOUNT_STATUS_ACTIVE, true, pictureUrl);
            
            // Tự động khởi tạo giỏ hàng cho tài khoản Google mới
            CartDAO cartDAO = new CartDAO();
            cartDAO.createForCustomer(newId);

            return userDAO.findByEmail(email);
        }
    }

    public User verifyEmailCode(String email, String code) throws Exception {
        if (!ValidationUtil.notBlank(email) || !ValidationUtil.isValidEmail(email)) {
            throw new Exception("Email không hợp lệ.");
        }
        if (!ValidationUtil.notBlank(code)) {
            throw new Exception("Mã xác minh không được để trống.");
        }

        User user = userDAO.findByEmail(email);
        if (user == null) {
            throw new Exception("Không tìm thấy tài khoản cần xác minh.");
        }
        if (AppConfig.ACCOUNT_STATUS_SUSPENDED.equals(user.getStatus())) {
            throw new Exception("Tài khoản đã bị đình chỉ bởi Quản trị viên. Không thể xác minh email.");
        }
        if (AppConfig.ACCOUNT_STATUS_LOCKED.equals(user.getStatus())) {
            throw new Exception("Tài khoản đang bị khóa tạm thời. Không thể xác minh email lúc này.");
        }
        if (user.getLockedUntil() != null && LocalDateTime.now().isBefore(user.getLockedUntil())) {
            DateTimeFormatter dtf = DateTimeFormatter.ofPattern("HH:mm:ss dd/MM/yyyy");
            throw new Exception("Tài khoản đang bị khóa tạm thời. Vui lòng thử lại sau: " + user.getLockedUntil().format(dtf));
        }
        if (AppConfig.ACCOUNT_STATUS_ACTIVE.equals(user.getStatus()) && user.isEmailVerified()) {
            return user;
        }

        if (user.getEmailVerificationExpiresAt() == null || LocalDateTime.now().isAfter(user.getEmailVerificationExpiresAt())) {
            throw new Exception("Mã xác minh đã hết hạn. Vui lòng gửi lại mã mới.");
        }

        if (!HashUtil.verify(code.trim(), user.getEmailVerificationCodeHash())) {
            throw new Exception("Mã xác minh không đúng.");
        }

        userDAO.activateVerifiedEmail(user.getUserId());
        return userDAO.findByEmail(email);
    }

    public User resendVerificationCode(String email) throws Exception {
        if (!ValidationUtil.notBlank(email) || !ValidationUtil.isValidEmail(email)) {
            throw new Exception("Email không hợp lệ.");
        }

        User user = userDAO.findByEmail(email);
        if (user == null) {
            throw new Exception("Không tìm thấy tài khoản cần xác minh.");
        }
        if (AppConfig.ACCOUNT_STATUS_SUSPENDED.equals(user.getStatus())) {
            throw new Exception("Tài khoản đã bị đình chỉ bởi Quản trị viên. Không thể gửi lại mã xác minh.");
        }
        if (AppConfig.ACCOUNT_STATUS_LOCKED.equals(user.getStatus())) {
            throw new Exception("Tài khoản đang bị khóa tạm thời. Không thể gửi lại mã xác minh lúc này.");
        }
        if (user.getLockedUntil() != null && LocalDateTime.now().isBefore(user.getLockedUntil())) {
            DateTimeFormatter dtf = DateTimeFormatter.ofPattern("HH:mm:ss dd/MM/yyyy");
            throw new Exception("Tài khoản đang bị khóa tạm thời. Vui lòng thử lại sau: " + user.getLockedUntil().format(dtf));
        }
        if (AppConfig.ACCOUNT_STATUS_ACTIVE.equals(user.getStatus()) && user.isEmailVerified()) {
            throw new Exception("Tài khoản này đã được xác minh.");
        }
        if (user.getEmailVerificationResendAt() != null && LocalDateTime.now().isBefore(user.getEmailVerificationResendAt())) {
            throw new Exception("Vui lòng chờ 1 phút rồi mới gửi lại mã.");
        }

        issueVerificationCode(user);
        return userDAO.findByEmail(email);
    }

    private void issueVerificationCode(User user) throws Exception {
        String verificationCode = generateVerificationCode();
        String codeHash = HashUtil.hashPassword(verificationCode);
        LocalDateTime now = LocalDateTime.now();
        Timestamp expiresAt = Timestamp.valueOf(now.plusMinutes(AppConfig.EMAIL_VERIFICATION_TTL_MINUTES));
        Timestamp resendAt = Timestamp.valueOf(now.plusSeconds(AppConfig.EMAIL_VERIFICATION_RESEND_SECONDS));

        userDAO.saveEmailVerificationCode(user.getUserId(), codeHash, expiresAt, resendAt);
        boolean sent = emailService.sendVerificationCodeEmail(user.getEmail(), user.getFullName(), verificationCode);
        if (!sent) {
            throw new Exception("Không thể gửi email xác minh. Vui lòng thử lại sau.");
        }
    }

    private String generateVerificationCode() {
        int bound = (int) Math.pow(10, AppConfig.EMAIL_VERIFICATION_CODE_LENGTH);
        int min = bound / 10;
        int code = min + SECURE_RANDOM.nextInt(bound - min);
        return String.format("%0" + AppConfig.EMAIL_VERIFICATION_CODE_LENGTH + "d", code);
    }

    public void saveUserSession(int userId, String token, Timestamp expiresAt) throws SQLException {
        userSessionDAO.saveUserSession(userId, token, expiresAt);
    }

    public void deleteUserSession(String token) throws SQLException {
        userSessionDAO.deleteUserSession(token);
    }
}
