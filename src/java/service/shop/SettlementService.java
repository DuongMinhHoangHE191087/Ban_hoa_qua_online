package service.shop;

import config.AppConfig;
import dao.auth.UserDAO;
import dao.shop.SettlementDAO;
import dao.system.SystemConfigDAO;
import model.entity.auth.User;
import model.entity.shop.ShopSettlement;

import java.sql.SQLException;
import java.util.List;
import util.LoggerUtil;
import service.chat.NotificationService;

public class SettlementService {

    private static final java.util.logging.Logger log = java.util.logging.Logger.getLogger(SettlementService.class.getName());

    private final SettlementDAO settlementDAO = new SettlementDAO();
    private final SystemConfigDAO configDAO = new SystemConfigDAO();
    private final UserDAO userDAO = new UserDAO();
    private final NotificationService notificationService = new NotificationService();

    public int runAutoSettlement() throws SQLException {
        synchronized (SettlementService.class) {
            // PAY-03: use hours for freeze window so sub-day release is possible.
            int freezeHours = configDAO.getInt("settlement_freeze_hours", 24);
            // D3: không kết toán trước khi khách hết hạn đổi trả — chờ tối thiểu bằng return window.
            int returnMaxHours = configDAO.getInt("return_request_max_hours", 24);
            int effectiveFreezeHours = Math.max(freezeHours, returnMaxHours);
            return settlementDAO.runAutoSettlementByHours(effectiveFreezeHours);
        }
    }

    public List<ShopSettlement> getAllSettlements(String status, int page, int pageSize) throws SQLException {
        return settlementDAO.findAll(status, page, pageSize);
    }

    public List<ShopSettlement> getAllSettlements(String status, String issueFilter, int page, int pageSize) throws SQLException {
        return settlementDAO.findAll(status, issueFilter, page, pageSize);
    }

    public List<ShopSettlement> getSettlementsByOwner(int ownerId) throws SQLException {
        return settlementDAO.findByOwner(ownerId);
    }

    public int countAllSettlements(String status) throws SQLException {
        return settlementDAO.countAll(status);
    }

    public int countAllSettlements(String status, String issueFilter) throws SQLException {
        return settlementDAO.countAll(status, issueFilter);
    }

    public void confirmSettlement(int settlementId, int ownerId, String confirmNote) throws SQLException {
        ShopSettlement settlement = requireSettlement(settlementId);
        if (settlement.getOwnerId() != ownerId) {
            throw new SecurityException("Bạn không có quyền xác nhận settlement #" + settlementId);
        }
        if (!"PENDING".equalsIgnoreCase(settlement.getStatus())) {
            throw new IllegalStateException("Chỉ có thể xác nhận settlement đang ở trạng thái PENDING.");
        }

        int updated = settlementDAO.confirmByOwner(settlementId, ownerId, confirmNote);
        if (updated == 0) {
            throw new IllegalStateException("Settlement #" + settlementId + " không thể xác nhận vì trạng thái đã thay đổi.");
        }

        notifyAdmins(
                "Shop đã xác nhận settlement #" + settlementId,
                "Shop #" + ownerId + " đã xác nhận settlement #" + settlementId + ". Vui lòng kiểm tra và xử lý giải ngân."
        );
    }

    public void disputeSettlement(int settlementId, int ownerId, String cancelReason) throws SQLException {
        ShopSettlement settlement = requireSettlement(settlementId);
        if (settlement.getOwnerId() != ownerId) {
            throw new SecurityException("Bạn không có quyền hủy settlement #" + settlementId);
        }
        if (!"PENDING".equalsIgnoreCase(settlement.getStatus())) {
            throw new IllegalStateException("Chỉ có thể hủy settlement đang ở trạng thái PENDING.");
        }

        int updated = settlementDAO.disputeByOwner(settlementId, ownerId, cancelReason);
        if (updated == 0) {
            throw new IllegalStateException("Settlement #" + settlementId + " không thể hủy vì trạng thái đã thay đổi.");
        }

        notifyAdmins(
                "Shop báo tranh chấp settlement #" + settlementId,
                "Shop #" + ownerId + " đã báo tranh chấp / hủy settlement #" + settlementId
                        + (cancelReason != null && !cancelReason.trim().isEmpty() ? ". Lý do: " + cancelReason.trim() : ".")
        );
    }

    public void markPaid(int settlementId, int adminId, String paidReference, String paidNote) throws SQLException {
        requireAdminUser(adminId);

        ShopSettlement settlement = requireSettlement(settlementId);
        if (!"CONFIRMED".equalsIgnoreCase(settlement.getStatus())) {
            throw new IllegalStateException("Chỉ có thể thanh toán settlement đã được shop xác nhận.");
        }

        String trimmedReference = paidReference == null ? null : paidReference.trim();
        if (trimmedReference == null || trimmedReference.isEmpty()) {
            throw new IllegalArgumentException("Mã giao dịch chuyển khoản là bắt buộc.");
        }

        int updated = settlementDAO.markPaid(settlementId, adminId, trimmedReference, paidNote);
        if (updated == 0) {
            throw new IllegalStateException("Settlement #" + settlementId + " không thể đánh dấu đã thanh toán vì trạng thái đã thay đổi.");
        }

        notifyOwner(
                settlement.getOwnerId(),
                "Settlement #" + settlementId + " đã được thanh toán",
                "Admin đã xác nhận chuyển khoản settlement #" + settlementId
                        + ". Mã giao dịch: " + trimmedReference
                        + (paidNote != null && !paidNote.trim().isEmpty() ? ". Ghi chú: " + paidNote.trim() : "."),
                "/shop/settlement"
        );
    }

    public void reportPaymentIssue(int settlementId, int ownerId, String issueNote) throws SQLException {
        ShopSettlement settlement = requireSettlement(settlementId);
        if (settlement.getOwnerId() != ownerId) {
            throw new SecurityException("Bạn không có quyền báo lỗi settlement #" + settlementId);
        }
        if (!"PAID".equalsIgnoreCase(settlement.getStatus())) {
            throw new IllegalStateException("Chỉ có thể báo chưa nhận tiền cho settlement đã ở trạng thái PAID.");
        }
        String trimmedIssueNote = issueNote == null ? null : issueNote.trim();
        if (trimmedIssueNote == null || trimmedIssueNote.isEmpty()) {
            throw new IllegalArgumentException("Vui lòng nhập lý do báo chưa nhận tiền.");
        }
        if ("REPORTED".equalsIgnoreCase(settlement.getPaymentIssueStatus())
                || "UNDER_REVIEW".equalsIgnoreCase(settlement.getPaymentIssueStatus())) {
            throw new IllegalStateException("Settlement này đã có báo cáo chưa nhận tiền đang chờ xử lý.");
        }

        int updated = settlementDAO.reportPaymentIssue(settlementId, ownerId, trimmedIssueNote);
        if (updated == 0) {
            throw new IllegalStateException("Settlement #" + settlementId + " không thể báo chưa nhận tiền vì trạng thái đã thay đổi.");
        }

        notifyAdmins(
                "Shop báo chưa nhận tiền settlement #" + settlementId,
                "Shop #" + ownerId + " báo chưa nhận được tiền đối soát cho settlement #" + settlementId
                        + ". Vui lòng kiểm tra sao kê và reference."
                        + " Lý do: " + trimmedIssueNote
        );
    }

    public void reopenPaymentRetry(int settlementId, int adminId, String resolutionNote) throws SQLException {
        requireAdminUser(adminId);

        ShopSettlement settlement = requireSettlement(settlementId);
        if (!"PAID".equalsIgnoreCase(settlement.getStatus())) {
            throw new IllegalStateException("Chỉ có thể mở lại xử lý khi settlement đang ở trạng thái PAID.");
        }
        if (!"REPORTED".equalsIgnoreCase(settlement.getPaymentIssueStatus())
                && !"UNDER_REVIEW".equalsIgnoreCase(settlement.getPaymentIssueStatus())) {
            throw new IllegalStateException("Settlement này chưa có báo cáo chưa nhận tiền để mở lại đối soát.");
        }

        int updated = settlementDAO.reopenForPaymentRetry(settlementId, adminId, resolutionNote);
        if (updated == 0) {
            throw new IllegalStateException("Settlement #" + settlementId + " không thể mở lại để đối soát.");
        }

        notifyOwner(
                settlement.getOwnerId(),
                "Settlement #" + settlementId + " đang được đối soát lại",
                "Admin đã mở lại settlement #" + settlementId + " để kiểm tra thanh toán."
                        + (resolutionNote != null && !resolutionNote.trim().isEmpty() ? " Ghi chú: " + resolutionNote.trim() : ""),
                "/shop/settlement"
        );
    }

    public void resolvePaymentIssue(int settlementId, int adminId, String resolutionNote) throws SQLException {
        requireAdminUser(adminId);

        ShopSettlement settlement = requireSettlement(settlementId);
        if (!"PAID".equalsIgnoreCase(settlement.getStatus())) {
            throw new IllegalStateException("Chỉ có thể chốt xử lý khi settlement đang ở trạng thái PAID.");
        }
        if (!"REPORTED".equalsIgnoreCase(settlement.getPaymentIssueStatus())
                && !"UNDER_REVIEW".equalsIgnoreCase(settlement.getPaymentIssueStatus())) {
            throw new IllegalStateException("Settlement này chưa có báo cáo chưa nhận tiền để chốt xử lý.");
        }

        int updated = settlementDAO.resolvePaymentIssue(settlementId, adminId, resolutionNote);
        if (updated == 0) {
            throw new IllegalStateException("Settlement #" + settlementId + " không thể chốt xử lý.");
        }

        notifyOwner(
                settlement.getOwnerId(),
                "Settlement #" + settlementId + " đã được đối soát",
                "Admin đã xác nhận xử lý xong báo cáo chưa nhận tiền của settlement #" + settlementId
                        + (resolutionNote != null && !resolutionNote.trim().isEmpty() ? ". Ghi chú: " + resolutionNote.trim() : "."),
                "/shop/settlement"
        );
    }

    public void markPaid(int settlementId) throws SQLException {
        markPaid(settlementId, 1, "LEGACY-" + settlementId, null);
    }

    public ShopSettlement getSettlementById(int settlementId) throws SQLException {
        return settlementDAO.findById(settlementId);
    }

    public List<model.entity.shop.ShopSettlementOrder> getOrdersBySettlementId(int settlementId) throws SQLException {
        return settlementDAO.findOrdersBySettlementId(settlementId);
    }

    public int countOpenPaymentIssues() throws SQLException {
        return settlementDAO.countOpenPaymentIssues();
    }

    private ShopSettlement requireSettlement(int settlementId) throws SQLException {
        ShopSettlement settlement = settlementDAO.findById(settlementId);
        if (settlement == null) {
            throw new IllegalArgumentException("Không tìm thấy settlement #" + settlementId);
        }
        return settlement;
    }

    private User requireAdminUser(int adminId) throws SQLException {
        User adminUser = userDAO.findUserById(adminId);
        if (adminUser == null || !AppConfig.ROLE_ADMIN.equals(adminUser.getRole())) {
            throw new SecurityException("Bạn không có quyền thao tác với settlement này.");
        }
        return adminUser;
    }

    private void notifyAdmins(String title, String message) {
        try {
            notificationService.sendBroadcast(title, message, AppConfig.ROLE_ADMIN);
        } catch (SQLException e) {
            LoggerUtil.warn(log, "Không thể gửi thông báo cho admin về settlement", e);
        }
    }

    private void notifyOwner(int ownerId, String title, String message, String actionUrl) {
        try {
            notificationService.send(ownerId, AppConfig.NOTIF_PAYMENT, title, message, actionUrl);
        } catch (SQLException e) {
            LoggerUtil.warn(log, "Không thể gửi thông báo settlement cho shop owner=" + ownerId, e);
        }
    }
}
