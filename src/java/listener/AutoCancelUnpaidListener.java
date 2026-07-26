package listener;

import model.entity.order.Order;
import service.order.OrderService;
import util.LoggerUtil;
import jakarta.servlet.ServletContextEvent;
import jakarta.servlet.ServletContextListener;
import jakarta.servlet.annotation.WebListener;
import java.sql.SQLException;
import java.util.List;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.logging.Logger;

/**
 * AutoCancelUnpaidListener — Background job that runs every 2 minutes to:
 *
 * (a) INV-01: Cancel orders stuck in PENDING_PAYMENT for more than 15 minutes
 *     and restore their reserved stock back via OrderService.
 * (b) SHOP_ACCEPT_TIMEOUT: Cancel CONFIRMED orders whose shop_acceptance_deadline
 *     has passed (delegates to OrderService.autoCancelUnacceptedOrders).
 *
 * Registered via @WebListener — do NOT add to web.xml.
 */
@WebListener
public class AutoCancelUnpaidListener implements ServletContextListener {

    private static final Logger log = Logger.getLogger(AutoCancelUnpaidListener.class.getName());

    /** Orders unpaid for longer than this many minutes are auto-cancelled. */
    private static final int UNPAID_EXPIRY_MINUTES = 15;

    /** Interval between job runs (minutes). */
    private static final int SCHEDULE_INTERVAL_MINUTES = 2;

    private ScheduledExecutorService scheduler;

    // Lazily instantiated so the context is fully started before DAO connections open.
    private final OrderService orderService = new OrderService();

    @Override
    public void contextInitialized(ServletContextEvent sce) {
        LoggerUtil.info(log, "[AutoCancelUnpaidListener] Starting scheduled job (interval: "
                + SCHEDULE_INTERVAL_MINUTES + " min, expiry: " + UNPAID_EXPIRY_MINUTES + " min).");
        scheduler = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "AutoCancelUnpaid-Thread");
            t.setDaemon(true);
            return t;
        });

        scheduler.scheduleWithFixedDelay(
                this::runJob,
                SCHEDULE_INTERVAL_MINUTES,
                SCHEDULE_INTERVAL_MINUTES,
                TimeUnit.MINUTES);
    }

    @Override
    public void contextDestroyed(ServletContextEvent sce) {
        LoggerUtil.info(log, "[AutoCancelUnpaidListener] Shutting down scheduler.");
        if (scheduler != null) {
            scheduler.shutdownNow();
            try {
                if (!scheduler.awaitTermination(5, TimeUnit.SECONDS)) {
                    LoggerUtil.warn(log, "[AutoCancelUnpaidListener] Scheduler did not terminate within 5 seconds.");
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }

    private void runJob() {
        try {
            cancelExpiredUnpaidOrders();
        } catch (Exception e) {
            LoggerUtil.error(log, "[AutoCancelUnpaidListener] Error in cancelExpiredUnpaidOrders", e);
        }

        try {
            orderService.autoCancelUnacceptedOrders();
        } catch (Exception e) {
            LoggerUtil.error(log, "[AutoCancelUnpaidListener] Error in autoCancelUnacceptedOrders", e);
        }
    }

    /**
     * INV-01 — Queries PENDING_PAYMENT orders older than {@value #UNPAID_EXPIRY_MINUTES} minutes,
     * cancels each one and restores reserved stock via OrderService.
     */
    private void cancelExpiredUnpaidOrders() throws SQLException {
        List<Order> expired = orderService.findExpiredPendingPaymentOrders(UNPAID_EXPIRY_MINUTES);
        if (expired.isEmpty()) {
            return;
        }
        LoggerUtil.info(log, "[AutoCancelUnpaidListener] Found " + expired.size()
                + " expired PENDING_PAYMENT order(s) to auto-cancel.");

        for (Order order : expired) {
            int orderId = order.getOrderId();
            try {
                // Cancel order (system user id = 1); skip ownership check path via ADMIN role
                orderService.cancelOrderBySystem(orderId,
                        "Đơn hàng chưa thanh toán sau " + UNPAID_EXPIRY_MINUTES + " phút. Hệ thống tự động hủy.");
                LoggerUtil.info(log, "[AutoCancelUnpaidListener] Auto-cancelled expired unpaid orderId=" + orderId);
            } catch (Exception e) {
                LoggerUtil.error(log, "[AutoCancelUnpaidListener] Failed to auto-cancel orderId=" + orderId, e);
            }
        }
    }
}
