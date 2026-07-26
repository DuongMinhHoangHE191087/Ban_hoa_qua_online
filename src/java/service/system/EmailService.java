package service.system;

import config.AppConfig;

import javax.mail.Authenticator;
import javax.mail.Message;
import javax.mail.MessagingException;
import javax.mail.PasswordAuthentication;
import javax.mail.Session;
import javax.mail.Transport;
import javax.mail.internet.InternetAddress;
import javax.mail.internet.MimeMessage;
import java.sql.SQLException;
import java.util.Date;
import java.util.Properties;

/**
 * EmailService — Gửi email qua SMTP. CHỈ lo transport, không build HTML.
 *
 * SRP: Class này CHỈ gửi email. Mọi HTML template được delegate sang EmailTemplateService.
 * Caller build nội dung HTML trước rồi gọi sendHtml() hoặc các method tiện ích.
 *
 * @author fruitmkt-team
 */
public class EmailService {

    private static final java.util.concurrent.ExecutorService emailExecutor = 
        java.util.concurrent.Executors.newFixedThreadPool(4, r -> {
            Thread t = new Thread(r, "app-email-executor");
            t.setDaemon(true);
            return t;
        });

    private final EmailTemplateService templateService = new EmailTemplateService();

    // ── Convenience methods (nghiệp vụ cụ thể) ────────────────────────────

    /**
     * Gửi email xác minh OTP sau khi đăng ký.
     */
    public boolean sendVerificationCodeEmail(String toEmail, String fullName, String verificationCode)
            throws SQLException {
        if (toEmail == null || toEmail.trim().isEmpty()) {
            throw new IllegalArgumentException("Email không được để trống.");
        }
        if (fullName == null || fullName.trim().isEmpty()) {
            throw new IllegalArgumentException("Họ tên không được để trống.");
        }
        if (verificationCode == null || verificationCode.trim().isEmpty()) {
            throw new IllegalArgumentException("Mã xác minh không được để trống.");
        }
        String subject = "[" + AppConfig.APP_NAME + "] Mã xác minh tài khoản của bạn";
        String html = templateService.buildVerificationEmail(fullName, verificationCode);
        return sendHtml(toEmail, subject, html);
    }

    /**
     * Gửi email đặt lại mật khẩu.
     */
    public boolean sendPasswordResetEmail(String toEmail, String fullName, String resetLink)
            throws SQLException {
        if (toEmail == null || toEmail.trim().isEmpty()) {
            throw new IllegalArgumentException("Email không được để trống.");
        }
        if (fullName == null || fullName.trim().isEmpty()) {
            throw new IllegalArgumentException("Họ tên không được để trống.");
        }
        if (resetLink == null || resetLink.trim().isEmpty()) {
            throw new IllegalArgumentException("Link không được để trống.");
        }
        String subject = "[" + AppConfig.APP_NAME + "] Yêu cầu đặt lại mật khẩu";
        String html = templateService.buildPasswordResetEmail(fullName, resetLink);
        return sendHtml(toEmail, subject, html);
    }

    /**
     * Gửi email thông báo cập nhật đơn hàng.
     */
    public boolean sendOrderNotificationEmail(String toEmail, String fullName,
                                               String orderId, String status, String orderDetailUrl)
            throws SQLException {
        if (toEmail == null || toEmail.trim().isEmpty()) {
            throw new IllegalArgumentException("Email không được để trống.");
        }
        if (fullName == null || fullName.trim().isEmpty()) {
            throw new IllegalArgumentException("Họ tên không được để trống.");
        }
        if (orderId == null || orderId.trim().isEmpty()) {
            throw new IllegalArgumentException("Mã đơn hàng không được để trống.");
        }
        if (status == null || status.trim().isEmpty()) {
            throw new IllegalArgumentException("Trạng thái không được để trống.");
        }
        if (orderDetailUrl == null || orderDetailUrl.trim().isEmpty()) {
            throw new IllegalArgumentException("Link chi tiết không được để trống.");
        }
        String subject = "[" + AppConfig.APP_NAME + "] Đơn hàng " + orderId + " - " + status;
        String html = templateService.buildOrderNotificationEmail(fullName, orderId, status, orderDetailUrl);
        return sendHtml(toEmail, subject, html);
    }

    /**
     * Gửi email xác nhận đã nhận đơn đăng ký mở shop.
     */
    public boolean sendShopApplicationReceivedEmail(String toEmail, String ownerName, String shopName)
            throws SQLException {
        if (toEmail == null || toEmail.trim().isEmpty()) {
            throw new IllegalArgumentException("Email không được để trống.");
        }
        if (ownerName == null || ownerName.trim().isEmpty()) {
            throw new IllegalArgumentException("Tên chủ shop không được để trống.");
        }
        if (shopName == null || shopName.trim().isEmpty()) {
            throw new IllegalArgumentException("Tên shop không được để trống.");
        }
        String subject = "[" + AppConfig.APP_NAME + "] Đã nhận đơn đăng ký mở gian hàng " + shopName;
        String html = templateService.buildShopApplicationReceivedEmail(ownerName, shopName);
        return sendHtml(toEmail, subject, html);
    }

    /**
     * Gửi email thông báo đơn đăng ký mở shop đã được duyệt.
     */
    public boolean sendShopApprovedEmail(String toEmail, String ownerName, String shopName)
            throws SQLException {
        if (toEmail == null || toEmail.trim().isEmpty()) {
            throw new IllegalArgumentException("Email không được để trống.");
        }
        if (ownerName == null || ownerName.trim().isEmpty()) {
            throw new IllegalArgumentException("Tên chủ shop không được để trống.");
        }
        if (shopName == null || shopName.trim().isEmpty()) {
            throw new IllegalArgumentException("Tên shop không được để trống.");
        }
        String subject = "[" + AppConfig.APP_NAME + "] Chúc mừng! Gian hàng " + shopName + " đã được duyệt";
        String html = templateService.buildShopApprovedEmail(ownerName, shopName);
        return sendHtml(toEmail, subject, html);
    }

    /**
     * Gửi email thông báo đơn đăng ký mở shop bị từ chối.
     */
    public boolean sendShopRejectedEmail(String toEmail, String ownerName, String shopName, String reason)
            throws SQLException {
        if (toEmail == null || toEmail.trim().isEmpty()) {
            throw new IllegalArgumentException("Email không được để trống.");
        }
        if (ownerName == null || ownerName.trim().isEmpty()) {
            throw new IllegalArgumentException("Tên chủ shop không được để trống.");
        }
        if (shopName == null || shopName.trim().isEmpty()) {
            throw new IllegalArgumentException("Tên shop không được để trống.");
        }
        if (reason == null || reason.trim().isEmpty()) {
            throw new IllegalArgumentException("Lý do không được để trống.");
        }
        String subject = "[" + AppConfig.APP_NAME + "] Thông báo về đơn đăng ký mở gian hàng " + shopName;
        String html = templateService.buildShopRejectedEmail(ownerName, shopName, reason);
        return sendHtml(toEmail, subject, html);
    }

    /**
     * Gửi email chào mừng và cấp mật khẩu tạm cho Delivery Staff.
     */
    public boolean sendDeliveryStaffWelcomeEmail(String toEmail, String fullName, String tempPassword)
            throws SQLException {
        if (toEmail == null || toEmail.trim().isEmpty()) {
            throw new IllegalArgumentException("Email không được để trống.");
        }
        if (fullName == null || fullName.trim().isEmpty()) {
            throw new IllegalArgumentException("Họ tên không được để trống.");
        }
        if (tempPassword == null || tempPassword.trim().isEmpty()) {
            throw new IllegalArgumentException("Mật khẩu tạm không được để trống.");
        }
        String subject = "[" + AppConfig.APP_NAME + "] Thông tin tài khoản Đối tác Giao hàng";
        String html = templateService.buildDeliveryStaffWelcomeEmail(fullName, toEmail, tempPassword);
        return sendHtml(toEmail, subject, html);
    }

    // ── Core transport ────────────────────────────────────────────────────

    /**
     * Gửi email HTML thuần — low-level, dùng khi cần tùy biến hoàn toàn.
     */
    public boolean sendHtml(String toEmail, String subject, String htmlBody) throws SQLException {
        if (toEmail == null || toEmail.trim().isEmpty()) {
            throw new IllegalArgumentException("Email nhận không được để trống.");
        }
        if (subject == null || subject.trim().isEmpty()) {
            throw new IllegalArgumentException("Tiêu đề không được để trống.");
        }
        if (htmlBody == null || htmlBody.trim().isEmpty()) {
            throw new IllegalArgumentException("Nội dung không được để trống.");
        }

        emailExecutor.submit(() -> {
            try {
                Session session = buildSession();
                MimeMessage message = buildMessage(session, toEmail, subject, htmlBody);
                try (Transport transport = session.getTransport("smtp")) {
                    transport.connect(AppConfig.EMAIL_SMTP_HOST, AppConfig.EMAIL_FROM, AppConfig.EMAIL_PASSWORD);
                    transport.sendMessage(message, message.getAllRecipients());
                }
            } catch (Exception e) {
                java.util.logging.Logger.getLogger(EmailService.class.getName())
                        .log(java.util.logging.Level.SEVERE, "Lỗi gửi email bất đồng bộ tới " + toEmail, e);
            }
        });

        return true;
    }

    // ── Private helpers ────────────────────────────────────────────────────



    private Session buildSession() {
        Properties props = new Properties();
        props.setProperty("mail.smtp.auth", "true");
        props.setProperty("mail.smtp.starttls.enable", "true");
        props.setProperty("mail.smtp.starttls.required", "true");
        props.setProperty("mail.smtp.host", AppConfig.EMAIL_SMTP_HOST);
        props.setProperty("mail.smtp.port", AppConfig.EMAIL_SMTP_PORT);
        props.setProperty("mail.smtp.ssl.trust", AppConfig.EMAIL_SMTP_HOST);
        props.setProperty("mail.smtp.ssl.protocols", "TLSv1.2");
        props.setProperty("mail.smtp.connectiontimeout", "10000");
        props.setProperty("mail.smtp.timeout", "10000");
        props.setProperty("mail.smtp.writetimeout", "10000");

        String from = AppConfig.EMAIL_FROM;
        String pass = AppConfig.EMAIL_PASSWORD;
        return Session.getInstance(props, new Authenticator() {
            @Override
            protected PasswordAuthentication getPasswordAuthentication() {
                return new PasswordAuthentication(from, pass);
            }
        });
    }

    private MimeMessage buildMessage(Session session, String toEmail, String subject, String htmlBody)
            throws MessagingException {
        MimeMessage msg = new MimeMessage(session);
        msg.setFrom(new InternetAddress(AppConfig.EMAIL_FROM));
        msg.setRecipients(Message.RecipientType.TO, InternetAddress.parse(toEmail, false));
        msg.setSubject(subject, "UTF-8");
        msg.setSentDate(new Date());
        msg.setContent(htmlBody, "text/html; charset=UTF-8");
        msg.saveChanges();
        return msg;
    }
}
