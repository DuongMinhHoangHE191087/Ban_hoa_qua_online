package service.system;

import config.AppConfig;
import model.entity.order.Order;
import model.entity.order.OrderItem;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * EmailTemplateService — Xây dựng HTML template cho từng loại email gửi đi.
 *
 * SRP: Class này CHỈ build HTML string, không gửi email.
 * Mỗi public method tương ứng 1 loại email nghiệp vụ.
 *
 * @author fruitmkt-team
 */
public class EmailTemplateService {

    // ── Style constants ────────────────────────────────────────────────────
    private static final String EMAIL_STYLE_BASE =
            "font-family:Arial,Helvetica,sans-serif;background:#f5f8f6;margin:0;padding:0;color:#1f2937;";
    private static final String CARD_STYLE =
            "max-width:640px;margin:0 auto;background:#ffffff;border:1px solid #dbe7df;"
            + "border-radius:18px;overflow:hidden;box-shadow:0 18px 48px rgba(20,83,45,0.10);";
    private static final String HEADER_STYLE =
            "padding:28px 28px 20px;background:linear-gradient(135deg,#14532d 0%,#1f6d3b 100%);color:#ffffff;";
    private static final String BODY_STYLE = "padding:28px;line-height:1.7;font-size:15px;";
    private static final String FOOTER_STYLE =
            "padding:20px 28px 28px;border-top:1px solid #e5efe8;background:#fbfdfb;"
            + "color:#607166;font-size:12px;line-height:1.6;";

    // ── Public template builders ───────────────────────────────────────────

    /** Template email xác minh OTP 6 số. */
    public String buildVerificationEmail(String fullName, String verificationCode) {
        Map<String, String> facts = new LinkedHashMap<>();
        facts.put("Mã có hiệu lực", "5 phút");
        facts.put("Gửi lại mã", "Sau 1 phút");
        facts.put("Bảo mật", "Không chia sẻ cho bất kỳ ai");

        String factsHtml = buildFactsTable(facts);
        String mainHtml = buildOtpBox(verificationCode, factsHtml);
        String footerHtml = "Nếu bạn không tạo tài khoản này, chỉ cần bỏ qua email. "
                + "Không ai có thể kích hoạt tài khoản nếu không có mã này."
                + "<br><br>Trân trọng,<br><strong>Đội ngũ " + escapeHtml(AppConfig.APP_NAME) + "</strong>";

        return buildBrandedEmail(
                "Xác minh tài khoản",
                "<p style='margin:0 0 10px 0;'>Xin chào <strong>" + escapeHtml(fullName) + "</strong>,</p>"
                + "<p style='margin:0;'>Cảm ơn bạn đã đăng ký. Để hoàn tất việc tạo tài khoản, "
                + "vui lòng nhập mã xác minh bên dưới.</p>",
                mainHtml,
                "Xem trang xác minh",
                AppConfig.APP_BASE_URL + "/auth/verify",
                footerHtml);
    }

    /** Template email đặt lại mật khẩu. */
    public String buildPasswordResetEmail(String fullName, String resetLink) {
        String mainHtml = "<div style='text-align:center;margin:22px 0;'>"
                + "<a href='" + escapeHtml(resetLink) + "' "
                + "style='display:inline-block;padding:14px 28px;border-radius:14px;"
                + "background:#14532d;color:#fff;font-weight:700;text-decoration:none;font-size:15px;'>"
                + "Đặt lại mật khẩu</a></div>"
                + "<p style='font-size:13px;color:#607166;text-align:center;margin:0;'>"
                + "Liên kết có hiệu lực trong 15 phút.</p>";

        String footerHtml = "Nếu bạn không yêu cầu đặt lại mật khẩu, hãy bỏ qua email này. "
                + "Tài khoản vẫn an toàn.<br><br>Trân trọng,<br><strong>Đội ngũ "
                + escapeHtml(AppConfig.APP_NAME) + "</strong>";

        return buildBrandedEmail(
                "Đặt lại mật khẩu",
                "<p style='margin:0 0 10px 0;'>Xin chào <strong>" + escapeHtml(fullName) + "</strong>,</p>"
                + "<p style='margin:0;'>Chúng tôi nhận được yêu cầu đặt lại mật khẩu cho tài khoản của bạn.</p>",
                mainHtml,
                null, null,
                footerHtml);
    }

    /** Template email thông báo đơn hàng. */
    public String buildOrderNotificationEmail(String fullName, String orderId, String status, String orderDetailUrl) {
        // Load DB data dynamically
        Order order = null;
        List<OrderItem> items = null;
        try {
            int id = Integer.parseInt(orderId);
            if (id > 0) {
                dao.order.OrderDAO orderDAO = new dao.order.OrderDAO();
                order = orderDAO.findOneById(id);
                if (order != null) {
                    items = orderDAO.findItemsByOrderId(id);
                }
            }
        } catch (Exception e) {
            // Keep order and items as null, fallback gracefully
        }

        // Determine status styling
        String badgeColor = "#059669"; // Green
        String badgeBg = "#ecfdf5";
        String statusText = status;

        if (status.toLowerCase().contains("hủy") || status.toLowerCase().contains("cancelled") || status.toLowerCase().contains("failed") || status.toLowerCase().contains("thất bại")) {
            badgeColor = "#dc2626"; // Red
            badgeBg = "#fef2f2";
        } else if (status.toLowerCase().contains("đang giao") || status.toLowerCase().contains("dispatched") || status.toLowerCase().contains("chờ") || status.toLowerCase().contains("pending")) {
            badgeColor = "#d97706"; // Amber
            badgeBg = "#fffbeb";
        }

        StringBuilder mainHtml = new StringBuilder();
        
        // Status & ID Box
        mainHtml.append("<div style='background:#f9fafb; border:1px solid #e5e7eb; border-radius:16px; padding:20px; margin:20px 0;'>")
                .append("<table role='presentation' style='width:100%; border-collapse:collapse;'>")
                .append("<tr>")
                .append("<td style='padding:0;'>")
                .append("<div style='font-size:12px; color:#6b7280; text-transform:uppercase; letter-spacing:1px; margin-bottom:4px;'>Mã đơn hàng</div>")
                .append("<div style='font-size:20px; font-weight:800; color:#111827; letter-spacing:1.5px;'>#").append(escapeHtml(orderId)).append("</div>")
                .append("</td>")
                .append("<td style='padding:0; text-align:right;'>")
                .append("<span style='display:inline-block; padding:8px 16px; border-radius:30px; font-size:13px; font-weight:700; color:").append(badgeColor).append("; background:").append(badgeBg).append("; border:1px solid ").append(badgeColor).append(";'>")
                .append(escapeHtml(statusText))
                .append("</span>")
                .append("</td>")
                .append("</tr>")
                .append("</table>")
                .append("</div>");

        // Order Items Table (Only if loaded successfully)
        if (order != null && items != null && !items.isEmpty()) {
            mainHtml.append("<div style='margin-bottom:24px;'>")
                    .append("<div style='font-size:15px; font-weight:700; color:#1f2937; margin-bottom:12px; border-left:4px solid #14532d; padding-left:10px;'>Chi tiết sản phẩm</div>")
                    .append("<table role='presentation' style='width:100%; border-collapse:collapse; font-size:14px;'>")
                    .append("<thead>")
                    .append("<tr style='border-bottom:2px solid #e5e7eb; color:#4b5563; font-weight:600;'>")
                    .append("<th style='text-align:left; padding:8px 0; font-size:13px;'>Sản phẩm</th>")
                    .append("<th style='text-align:center; padding:8px 8px; font-size:13px; width:60px;'>SL</th>")
                    .append("<th style='text-align:right; padding:8px 0; font-size:13px; width:100px;'>Thành tiền</th>")
                    .append("</tr>")
                    .append("</thead>")
                    .append("<tbody>");

            for (OrderItem item : items) {
                String variantLabel = item.getVariantLabelSnapshot();
                String variantStr = (variantLabel != null && !variantLabel.trim().isEmpty()) ? " (" + variantLabel + ")" : "";
                mainHtml.append("<tr style='border-bottom:1px solid #f3f4f6;'>")
                        .append("<td style='padding:12px 0; vertical-align:middle;'>")
                        .append("<div style='font-weight:600; color:#111827;'>").append(escapeHtml(item.getProductNameSnapshot())).append("</div>")
                        .append("<div style='font-size:12px; color:#6b7280; margin-top:2px;'>Đơn giá: ").append(formatVND(item.getUnitPrice())).append(escapeHtml(variantStr)).append("</div>")
                        .append("</td>")
                        .append("<td style='padding:12px 8px; text-align:center; vertical-align:middle; color:#4b5563; font-weight:600;'>")
                        .append(item.getQuantity())
                        .append("</td>")
                        .append("<td style='padding:12px 0; text-align:right; vertical-align:middle; font-weight:600; color:#111827;'>")
                        .append(formatVND(item.getSubtotal()))
                        .append("</td>")
                        .append("</tr>");
            }
            mainHtml.append("</tbody>")
                    .append("</table>")
                    .append("</div>");

            // Order Financial Calculation Box
            mainHtml.append("<div style='background:#f9fafb; border:1px solid #e5e7eb; border-radius:14px; padding:16px 20px; margin-bottom:24px;'>")
                    .append("<table role='presentation' style='width:100%; border-collapse:collapse; font-size:14px; line-height:1.8;'>")
                    .append("<tr>")
                    .append("<td style='color:#4b5563;'>Tạm tính:</td>")
                    .append("<td style='text-align:right; color:#111827; font-weight:600;'>").append(formatVND(order.getTotalAmount())).append("</td>")
                    .append("</tr>")
                    .append("<tr>")
                    .append("<td style='color:#4b5563;'>Phí vận chuyển:</td>")
                    .append("<td style='text-align:right; color:#111827; font-weight:600;'>+ ").append(formatVND(order.getDeliveryFee())).append("</td>")
                    .append("</tr>");
            
            if (order.getDiscountAmount() != null && order.getDiscountAmount().compareTo(java.math.BigDecimal.ZERO) > 0) {
                mainHtml.append("<tr>")
                        .append("<td style='color:#dc2626;'>Khuyến mãi:</td>")
                        .append("<td style='text-align:right; color:#dc2626; font-weight:600;'>- ").append(formatVND(order.getDiscountAmount())).append("</td>")
                        .append("</tr>");
            }

            mainHtml.append("<tr style='border-top:1px solid #e5e7eb;'>")
                    .append("<td style='padding-top:10px; font-size:16px; font-weight:800; color:#111827;'>Tổng cộng:</td>")
                    .append("<td style='padding-top:10px; text-align:right; font-size:18px; font-weight:800; color:#14532d;'>").append(formatVND(order.getFinalAmount())).append("</td>")
                    .append("</tr>")
                    .append("</table>")
                    .append("</div>");
        } else {
            // Fallback (e.g. if parsed ORD-12345 or no order in DB)
            mainHtml.append("<div style='background:#f0f8f3; border:1px solid #c8e2d0; border-radius:14px; padding:16px 20px; margin:16px 0;'>")
                    .append("<p style='margin:0 0 8px; font-size:13px; color:#607166;'>Mã đơn hàng</p>")
                    .append("<p style='margin:0; font-size:18px; font-weight:800; color:#14532d; letter-spacing:2px;'>")
                    .append(escapeHtml(orderId)).append("</p>")
                    .append("<p style='margin:8px 0 0; font-size:14px; color:#1f2937;'>Trạng thái: <strong>")
                    .append(escapeHtml(status)).append("</strong></p>")
                    .append("</div>");
        }

        // Shipping Information (Only if loaded successfully)
        if (order != null) {
            String paymentMethodLabel = "COD (Thanh toán khi nhận hàng)";
            if ("CK".equalsIgnoreCase(order.getPaymentMethod())) {
                paymentMethodLabel = "Chuyển khoản Ngân hàng (VietQR / SePay)";
            }
            
            mainHtml.append("<div style='background:#ffffff; border:1px solid #e5e7eb; border-radius:16px; padding:20px; margin-bottom:20px;'>")
                    .append("<div style='font-size:15px; font-weight:700; color:#1f2937; margin-bottom:12px; border-left:4px solid #14532d; padding-left:10px;'>Thông tin nhận hàng</div>")
                    .append("<table role='presentation' style='width:100%; border-collapse:collapse; font-size:13px; line-height:1.7;'>")
                    .append("<tr>")
                    .append("<td style='color:#6b7280; width:120px; padding:4px 0;'>Người nhận:</td>")
                    .append("<td style='color:#111827; font-weight:600; padding:4px 0;'>").append(escapeHtml(order.getRecipientName() != null ? order.getRecipientName() : fullName)).append("</td>")
                    .append("</tr>")
                    .append("<tr>")
                    .append("<td style='color:#6b7280; padding:4px 0;'>Số điện thoại:</td>")
                    .append("<td style='color:#111827; font-weight:600; padding:4px 0;'>").append(escapeHtml(order.getRecipientPhone())).append("</td>")
                    .append("</tr>")
                    .append("<tr>")
                    .append("<td style='color:#6b7280; padding:4px 0; vertical-align:top;'>Địa chỉ giao:</td>")
                    .append("<td style='color:#111827; font-weight:600; padding:4px 0;'>").append(escapeHtml(order.getDeliveryAddress())).append("</td>")
                    .append("</tr>");
            
            if (order.getDeliveryTimeSlot() != null && !order.getDeliveryTimeSlot().trim().isEmpty()) {
                mainHtml.append("<tr>")
                        .append("<td style='color:#6b7280; padding:4px 0;'>Thời gian nhận:</td>")
                        .append("<td style='color:#111827; font-weight:600; padding:4px 0;'>").append(escapeHtml(order.getDeliveryTimeSlot())).append("</td>")
                        .append("</tr>");
            }
            
            mainHtml.append("<tr>")
                    .append("<td style='color:#6b7280; padding:4px 0;'>Hình thức thanh toán:</td>")
                    .append("<td style='color:#111827; font-weight:600; padding:4px 0;'>").append(escapeHtml(paymentMethodLabel)).append("</td>")
                    .append("</tr>");
            
            if (order.getNotes() != null && !order.getNotes().trim().isEmpty()) {
                mainHtml.append("<tr>")
                        .append("<td style='color:#6b7280; padding:4px 0; vertical-align:top;'>Ghi chú:</td>")
                        .append("<td style='color:#4b5563; font-style:italic; padding:4px 0;'>\"").append(escapeHtml(order.getNotes())).append("\"</td>")
                        .append("</tr>");
            }
            
            mainHtml.append("</table>")
                    .append("</div>");
        }

        String introMsg = "Xin chào <strong>" + escapeHtml(fullName) + "</strong>, đơn hàng của bạn vừa được cập nhật.";
        if (status.toLowerCase().contains("thanh toán thành công")) {
            introMsg = "Xin chào <strong>" + escapeHtml(fullName) + "</strong>, chúng tôi đã nhận được thanh toán của bạn cho đơn hàng dưới đây.";
        } else if (status.toLowerCase().contains("đặt hàng thành công")) {
            introMsg = "Xin chào <strong>" + escapeHtml(fullName) + "</strong>, chúc mừng bạn đã đặt hàng thành công tại " + escapeHtml(AppConfig.APP_NAME) + ".";
        }

        String footerHtml = "Cảm ơn bạn đã tin tưởng mua sắm tại " + escapeHtml(AppConfig.APP_NAME)
                + ".<br><br>Trân trọng,<br><strong>Đội ngũ " + escapeHtml(AppConfig.APP_NAME) + "</strong>";

        return buildBrandedEmail(
                "Cập nhật đơn hàng",
                introMsg,
                mainHtml.toString(),
                "Xem chi tiết đơn hàng",
                orderDetailUrl,
                footerHtml);
    }

    /**
     * Template email xác nhận đã nhận đơn đăng ký shop.
     * Gửi ngay sau khi người dùng nộp đơn thành công.
     */
    public String buildShopApplicationReceivedEmail(String ownerName, String shopName) {
        String mainHtml = "<div style='background:#f0f8f3;border:1px solid #c8e2d0;border-radius:14px;"
                + "padding:16px 20px;margin:16px 0;'>"
                + "<p style='margin:0 0 8px;font-size:13px;color:#607166;'>Tên cửa hàng đăng ký</p>"
                + "<p style='margin:0;font-size:18px;font-weight:800;color:#14532d;'>"
                + escapeHtml(shopName) + "</p>"
                + "<p style='margin:12px 0 0;font-size:13px;color:#1f2937;'>"
                + "Trạng thái: <strong style='color:#92400e;'>⏳ Đang chờ xét duyệt</strong></p>"
                + "</div>"
                + "<p style='font-size:13px;color:#607166;margin:12px 0 0;'>"
                + "Thời gian xét duyệt thông thường là <strong>1-3 ngày làm việc</strong>. "
                + "Chúng tôi sẽ thông báo kết quả qua email này.</p>";

        String footerHtml = "Nếu bạn không thực hiện đăng ký này, hãy liên hệ bộ phận hỗ trợ."
                + "<br><br>Trân trọng,<br><strong>Đội ngũ " + escapeHtml(AppConfig.APP_NAME) + "</strong>";

        return buildBrandedEmail(
                "Đã nhận đơn đăng ký gian hàng",
                "<p style='margin:0 0 10px 0;'>Xin chào <strong>" + escapeHtml(ownerName) + "</strong>,</p>"
                + "<p style='margin:0;'>Chúng tôi đã nhận được đơn đăng ký mở gian hàng của bạn. "
                + "Đội ngũ kiểm duyệt sẽ xem xét thông tin và tài liệu bạn cung cấp.</p>",
                mainHtml,
                "Xem trạng thái đơn",
                AppConfig.APP_BASE_URL + "/customer/shop-apply",
                footerHtml);
    }

    /**
     * Template email thông báo shop đã được APPROVE.
     * Gửi khi Admin duyệt thành công.
     */
    public String buildShopApprovedEmail(String ownerName, String shopName) {
        String mainHtml = "<div style='background:#f0f8f3;border:2px solid #14532d;border-radius:14px;"
                + "padding:18px 22px;margin:16px 0;text-align:center;'>"
                + "<div style='font-size:36px;margin-bottom:8px;'>🎉</div>"
                + "<p style='margin:0 0 6px;font-size:15px;font-weight:800;color:#14532d;'>"
                + escapeHtml(shopName) + "</p>"
                + "<p style='margin:0;font-size:13px;color:#065f46;font-weight:700;'>"
                + "✅ ĐÃ ĐƯỢC PHÊ DUYỆT</p>"
                + "</div>"
                + "<p style='font-size:13px;color:#1f2937;margin:12px 0;'>"
                + "Bạn có thể <strong>đăng nhập lại</strong> và bắt đầu quản lý gian hàng ngay hôm nay. "
                + "Chào mừng bạn trở thành đối tác chính thức của " + escapeHtml(AppConfig.APP_NAME) + "!</p>";

        String footerHtml = "Cảm ơn bạn đã lựa chọn " + escapeHtml(AppConfig.APP_NAME) + " làm nền tảng kinh doanh."
                + "<br><br>Trân trọng,<br><strong>Đội ngũ " + escapeHtml(AppConfig.APP_NAME) + "</strong>";

        return buildBrandedEmail(
                "🎉 Chúc mừng! Gian hàng đã được duyệt",
                "<p style='margin:0 0 10px 0;'>Xin chào <strong>" + escapeHtml(ownerName) + "</strong>,</p>"
                + "<p style='margin:0;'>Sau khi xem xét, chúng tôi vui mừng thông báo đơn đăng ký "
                + "mở gian hàng của bạn đã được <strong style='color:#14532d;'>PHÊ DUYỆT</strong>.</p>",
                mainHtml,
                "Vào Dashboard bán hàng",
                AppConfig.APP_BASE_URL + "/shop/dashboard",
                footerHtml);
    }

    /**
     * Template email thông báo đơn đăng ký shop bị REJECT.
     * Gửi khi Admin từ chối đơn.
     */
    public String buildShopRejectedEmail(String ownerName, String shopName, String rejectionReason) {
        String mainHtml = "<div style='background:#fff5f5;border:1px solid #fca5a5;border-radius:14px;"
                + "padding:16px 20px;margin:16px 0;'>"
                + "<p style='margin:0 0 8px;font-size:13px;color:#991b1b;font-weight:700;'>Lý do từ chối:</p>"
                + "<p style='margin:0;font-size:14px;color:#1f2937;'>"
                + escapeHtml(rejectionReason) + "</p>"
                + "</div>"
                + "<p style='font-size:13px;color:#607166;margin:12px 0;'>"
                + "Bạn có thể cập nhật thông tin và nộp lại đơn đăng ký. "
                + "Nếu cần hỗ trợ, hãy liên hệ chúng tôi qua email hỗ trợ bên dưới.</p>";

        String footerHtml = "Chúng tôi mong được hỗ trợ bạn trong tương lai."
                + "<br><br>Trân trọng,<br><strong>Đội ngũ " + escapeHtml(AppConfig.APP_NAME) + "</strong>";

        return buildBrandedEmail(
                "Thông báo về đơn đăng ký gian hàng",
                "<p style='margin:0 0 10px 0;'>Xin chào <strong>" + escapeHtml(ownerName) + "</strong>,</p>"
                + "<p style='margin:0;'>Rất tiếc, đơn đăng ký mở gian hàng <strong>"
                + escapeHtml(shopName) + "</strong> của bạn chưa đáp ứng điều kiện phê duyệt lần này.</p>",
                mainHtml,
                "Nộp lại đơn đăng ký",
                AppConfig.APP_BASE_URL + "/customer/shop-apply",
                footerHtml);
    }

    /**
     * Template email chào mừng Delivery Staff khi được Admin tạo tài khoản.
     */
    public String buildDeliveryStaffWelcomeEmail(String fullName, String email, String tempPassword) {
        String mainHtml = "<div style='background:#f0f8f3;border:1px solid #c8e2d0;border-radius:14px;"
                + "padding:16px 20px;margin:16px 0;'>"
                + "<p style='margin:0 0 8px;font-size:13px;color:#607166;font-weight:700;'>Thông tin đăng nhập của bạn:</p>"
                + "<table role='presentation' style='width:100%; border-collapse:collapse;'>"
                + "<tr><td style='padding:4px 0; color:#6b7280; width:100px;'>Email:</td>"
                + "<td style='padding:4px 0; font-weight:700; color:#111827;'>" + escapeHtml(email) + "</td></tr>"
                + "<tr><td style='padding:4px 0; color:#6b7280;'>Mật khẩu:</td>"
                + "<td style='padding:4px 0; font-weight:700; color:#14532d; font-family:monospace; font-size:16px;'>" + escapeHtml(tempPassword) + "</td></tr>"
                + "</table>"
                + "</div>"
                + "<p style='font-size:13px;color:#1f2937;margin:12px 0;'>"
                + "Vui lòng đăng nhập và truy cập trang Hồ sơ để đổi mật khẩu. Đừng chia sẻ thông tin đăng nhập này cho bất kỳ ai.</p>";

        String footerHtml = "Chào mừng bạn gia nhập đội ngũ đối tác giao hàng của chúng tôi."
                + "<br><br>Trân trọng,<br><strong>Đội ngũ " + escapeHtml(AppConfig.APP_NAME) + "</strong>";

        return buildBrandedEmail(
                "Tài khoản Đối tác Giao hàng",
                "<p style='margin:0 0 10px 0;'>Xin chào <strong>" + escapeHtml(fullName) + "</strong>,</p>"
                + "<p style='margin:0;'>Tài khoản đối tác giao hàng của bạn đã được quản trị viên tạo thành công trên hệ thống <strong>" + escapeHtml(AppConfig.APP_NAME) + "</strong>.</p>",
                mainHtml,
                "Đăng nhập ngay",
                AppConfig.APP_BASE_URL + "/auth/login",
                footerHtml);
    }

    // ── Core layout builder (dùng nội bộ) ─────────────────────────────────

    /**
     * Tổng hợp HTML hoàn chỉnh cho 1 email branded.
     * primaryCtaText/Url nullable — bỏ qua nếu null hoặc rỗng.
     */
    public String buildBrandedEmail(
            String headline,
            String introHtml,
            String mainHtml,
            String primaryCtaText,
            String primaryCtaUrl,
            String footerHtml) {

        return "<html><body style='" + EMAIL_STYLE_BASE + "'>"
                + "<div style='padding:32px 16px;'>"
                + "<div style='" + CARD_STYLE + "'>"
                + buildHeader(headline)
                + "<div style='" + BODY_STYLE + "'>"
                + "<div style='font-size:16px;color:#385143;margin-bottom:16px;'>" + introHtml + "</div>"
                + mainHtml
                + buildCta(primaryCtaText, primaryCtaUrl)
                + "</div>"
                + buildFooter(footerHtml)
                + "</div>"
                + "</div>"
                + "</body></html>";
    }

    // ── Private helpers ────────────────────────────────────────────────────

    private String buildHeader(String headline) {
        return "<div style='" + HEADER_STYLE + "'>"
                + "<div style='display:flex;align-items:center;gap:12px;margin-bottom:18px;'>"
                + "<div style='width:44px;height:44px;border-radius:999px;background:rgba(255,255,255,0.18);"
                + "display:flex;align-items:center;justify-content:center;font-size:22px;font-weight:700;'>M</div>"
                + "<div>"
                + "<div style='font-size:13px;letter-spacing:1.2px;text-transform:uppercase;opacity:0.88;'>"
                + escapeHtml(AppConfig.APP_NAME) + "</div>"
                + "<div style='font-size:24px;font-weight:800;margin-top:4px;'>" + escapeHtml(headline) + "</div>"
                + "</div>"
                + "</div>"
                + "<div style='font-size:14px;opacity:0.92;max-width:520px;'>"
                + "Sàn nông sản sạch, hiện đại và an toàn cho người dùng.</div>"
                + "</div>";
    }

    private String buildCta(String text, String url) {
        if (text == null || text.trim().isEmpty() || url == null || url.trim().isEmpty()) {
            return "";
        }
        return "<div style='margin-top:24px;text-align:center;'>"
                + "<a href='" + escapeHtml(url) + "' style='display:inline-block;background:"
                + AppConfig.APP_BRAND_COLOR + ";color:#fff;text-decoration:none;font-weight:700;"
                + "padding:12px 20px;border-radius:12px;'>"
                + escapeHtml(text)
                + "</a></div>";
    }

    private String buildFooter(String footerHtml) {
        return "<div style='" + FOOTER_STYLE + "'>"
                + "<div style='margin-bottom:10px;'>" + footerHtml + "</div>"
                + "<div>Hỗ trợ: <a href='mailto:" + escapeHtml(AppConfig.APP_SUPPORT_EMAIL) + "' "
                + "style='color:" + AppConfig.APP_BRAND_COLOR + ";text-decoration:none;'>"
                + escapeHtml(AppConfig.APP_SUPPORT_EMAIL) + "</a></div>"
                + "</div>";
    }

    private String buildOtpBox(String verificationCode, String factsHtml) {
        return "<div style='text-align:center;margin:22px 0 18px;'>"
                + "<div style='display:inline-block;padding:14px 22px;border-radius:16px;"
                + "background:#eef8f1;border:1px solid #c8e2d0;'>"
                + "<div style='font-size:12px;letter-spacing:1.4px;text-transform:uppercase;"
                + "color:#5e7162;margin-bottom:6px;'>Mã xác minh của bạn</div>"
                + "<div style='font-size:34px;font-weight:800;letter-spacing:8px;color:"
                + AppConfig.APP_BRAND_COLOR + ";line-height:1.2;'>"
                + escapeHtml(verificationCode) + "</div>"
                + "</div></div>"
                + "<div style='background:#fbfdfb;border:1px solid #e2ede5;border-radius:14px;"
                + "padding:16px 18px;'>"
                + factsHtml
                + "</div>";
    }

    private String buildFactsTable(Map<String, String> facts) {
        StringBuilder sb = new StringBuilder(
                "<table role='presentation' style='width:100%;border-collapse:separate;"
                + "border-spacing:0 10px;margin-top:18px;'>");
        for (Map.Entry<String, String> entry : facts.entrySet()) {
            sb.append("<tr>")
              .append("<td style='padding:0;width:38%;font-size:13px;color:#607166;'>")
              .append(escapeHtml(entry.getKey()))
              .append("</td>")
              .append("<td style='padding:0;font-size:13px;color:#1f2937;font-weight:700;'>")
              .append(escapeHtml(entry.getValue()))
              .append("</td>")
              .append("</tr>");
        }
        sb.append("</table>");
        return sb.toString();
    }

    private String formatVND(java.math.BigDecimal amount) {
        if (amount == null) return "0 đ";
        java.text.DecimalFormatSymbols symbols = new java.text.DecimalFormatSymbols();
        symbols.setGroupingSeparator('.');
        java.text.DecimalFormat df = new java.text.DecimalFormat("#,###", symbols);
        return df.format(amount) + " đ";
    }

    public static String escapeHtml(String value) {
        if (value == null) return "";
        return value.replace("&", "&amp;")
                    .replace("<", "&lt;")
                    .replace(">", "&gt;")
                    .replace("\"", "&quot;")
                    .replace("'", "&#39;")
                    .replace("=", "&#61;");
    }
}
