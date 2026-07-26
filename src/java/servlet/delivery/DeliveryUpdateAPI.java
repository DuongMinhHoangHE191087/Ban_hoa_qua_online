package servlet.delivery;

import com.fasterxml.jackson.databind.ObjectMapper;
import model.entity.auth.User;
import model.response.ApiResponse;
import service.order.DeliveryService;
import util.JsonUtil;
import util.LoggerUtil;
import util.SessionUtil;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.logging.Logger;

@WebServlet("/delivery/api/update")
public class DeliveryUpdateAPI extends HttpServlet {

    private static final Logger log = Logger.getLogger(DeliveryUpdateAPI.class.getName());

    private final DeliveryService deliveryService = new DeliveryService();
    private final ObjectMapper mapper = new ObjectMapper();

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        resp.setContentType("application/json;charset=UTF-8");
        resp.setCharacterEncoding("UTF-8");

        try {
            User currentUser = SessionUtil.getCurrentUser(req.getSession(false));
            if (currentUser == null || !"DELIVERY".equals(currentUser.getRole())) {
                resp.setStatus(HttpServletResponse.SC_FORBIDDEN);
                JsonUtil.writeJson(resp, ApiResponse.fail(HttpServletResponse.SC_FORBIDDEN, "Truy cập bị từ chối"));
                return;
            }

            Map<String, String> data = mapper.readValue(req.getInputStream(), Map.class);
            int deliveryId = Integer.parseInt(data.get("deliveryId"));
            String action = data.get("action"); // "CLAIM", "STATUS" or "ESTIMATE"

            if ("CLAIM".equals(action)) {
                deliveryService.claimDelivery(currentUser.getUserId(), deliveryId);
            } else if ("STATUS".equals(action)) {
                String status = data.get("status");
                String reason = data.get("failureReason");
                String proofUrl = data.get("proofImageUrl");
                if ("DELIVERED".equals(status)) {
                    deliveryService.markAsDelivered(currentUser.getUserId(), deliveryId, proofUrl);
                } else {
                    deliveryService.updateStatusAndProof(currentUser.getUserId(), deliveryId, status, reason, proofUrl);
                }
            } else if ("ESTIMATE".equals(action)) {
                String estTimeStr = data.get("estimatedTime");
                if (estTimeStr != null && !estTimeStr.isEmpty()) {
                    LocalDateTime est = LocalDateTime.parse(estTimeStr);
                    deliveryService.updateEstimatedTime(currentUser.getUserId(), deliveryId, est);
                }
            }

            resp.setStatus(HttpServletResponse.SC_OK);
            JsonUtil.writeJson(resp, ApiResponse.ok(Map.of()));
        } catch (IllegalArgumentException e) {
            resp.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            JsonUtil.writeJson(resp, ApiResponse.fail(HttpServletResponse.SC_BAD_REQUEST,
                    e.getMessage() != null ? e.getMessage() : "Dữ liệu cập nhật giao hàng không hợp lệ."));
        } catch (Exception e) {
            LoggerUtil.error(log, "Lỗi máy chủ khi cập nhật trạng thái giao hàng", e);
            util.ServletUtil.sendJsonInternalServerError(
                    req,
                    resp,
                    log,
                    "DeliveryUpdateAPI#doPost",
                    "Lỗi máy chủ",
                    e);
        }
    }
}
