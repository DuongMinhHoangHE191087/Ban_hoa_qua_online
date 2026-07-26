package service.catalog;

import config.AppConfig;
import dao.catalog.ProductDAO;
import model.dto.common.PagedResultDTO;
import model.entity.catalog.Product;

import java.math.BigDecimal;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;

/**
 * ProductService — Business logic cho Product.
 *
 * SRP: Validate input, áp dụng business rule, delegate xuống DAO.
 * Không viết SQL, không tương tác HttpRequest/Response.
 *
 * @author fruitmkt-team
 */
public class ProductService {

    private final ProductDAO productDAO = new ProductDAO();

    /**
     * Lấy danh sách sản phẩm có filter + phân trang.
     *
     * @param page       Trang hiện tại (1-based). Nếu <= 0 sẽ được reset về 1.
     * @param keyword    Từ khóa tìm kiếm (nullable).
     * @param categoryId ID danh mục (nullable = tất cả danh mục).
     * @param minPrice   Giá tối thiểu (nullable).
     * @param maxPrice   Giá tối đa (nullable).
     */
    public PagedResultDTO getProductList(int page, String keyword, Integer categoryId,
                                          BigDecimal minPrice, BigDecimal maxPrice) throws SQLException {
        productDAO.autoDeactivateExpiredProducts();
        if (page < 1) page = 1;

        int pageSize = AppConfig.PAGE_SIZE_PRODUCTS;
        int total = productDAO.countSearch(keyword, categoryId, minPrice, maxPrice);
        int totalPages = Math.max(1, (int) Math.ceil((double) total / pageSize));
        if (page > totalPages) page = totalPages;

        List<Product> items = productDAO.search(keyword, categoryId, minPrice, maxPrice, page, pageSize);
        return new PagedResultDTO(items, page, totalPages, total, pageSize);
    }

    /**
     * Tìm sản phẩm theo ID (không làm tăng view count).
     *
     * @param productId ID sản phẩm
     * @return đối tượng Product hoặc null nếu không tìm thấy
     * @throws SQLException nếu xảy ra lỗi cơ sở dữ liệu
     */
    public Product getProductById(int productId) throws SQLException {
        if (productId <= 0) {
            throw new IllegalArgumentException("productId không hợp lệ.");
        }
        productDAO.autoDeactivateExpiredProducts();
        return productDAO.findOneById(productId);
    }

    /**
     * Lấy nhiều sản phẩm theo danh sách ID.
     *
     * @param productIds danh sách ID sản phẩm
     * @return map theo productId
     * @throws SQLException nếu xảy ra lỗi cơ sở dữ liệu
     */
    public Map<Integer, Product> getProductsByIds(List<Integer> productIds) throws SQLException {
        return productDAO.findByIds(productIds);
    }

    /**
     * Lấy chi tiết sản phẩm theo ID.
     * Giữ tên method tương thích với servlet đang gọi trực tiếp.
     *
     * @param productId ID sản phẩm
     * @return Product hoặc null nếu không tìm thấy
     * @throws SQLException nếu xảy ra lỗi cơ sở dữ liệu
     */
    public Product getProductDetail(int productId) throws SQLException {
        return getProductById(productId);
    }

    /**
     * Lấy danh sách sản phẩm của một shop owner.
     *
     * @param ownerId ID chủ shop
     * @return danh sách sản phẩm theo owner
     * @throws SQLException nếu xảy ra lỗi cơ sở dữ liệu
     */
    public List<Product> getProductsByOwner(int ownerId) throws SQLException {
        if (ownerId <= 0) {
            throw new IllegalArgumentException("ownerId không hợp lệ.");
        }
        productDAO.autoDeactivateExpiredProducts();
        return productDAO.findByOwner(ownerId);
    }

    public PagedResultDTO getProductsByOwner(int ownerId, int page, int pageSize, String keyword, Integer categoryId, String approvalStatus, String sellStatus, String stockStatus) throws SQLException {
        if (ownerId <= 0) {
            throw new IllegalArgumentException("ownerId không hợp lệ.");
        }
        productDAO.autoDeactivateExpiredProducts();
        int validatedPage = util.PaginationUtil.validatePage(page);
        int validatedPageSize = util.PaginationUtil.validatePageSize(pageSize);
        List<Product> items = productDAO.findByOwner(ownerId, validatedPage, validatedPageSize, keyword, categoryId, approvalStatus, sellStatus, stockStatus);
        int total = productDAO.countByOwner(ownerId, keyword, categoryId, approvalStatus, sellStatus, stockStatus);
        return util.PaginationUtil.buildPagedResult(items, validatedPage, validatedPageSize, total);
    }

    /**
     * Lấy một số sản phẩm gần nhất của shop owner để render dashboard nhanh hơn.
     */
    public List<Product> getRecentProductsByOwner(int ownerId, int limit) throws SQLException {
        if (ownerId <= 0) {
            throw new IllegalArgumentException("ownerId không hợp lệ.");
        }
        if (limit <= 0) {
            throw new IllegalArgumentException("limit không hợp lệ.");
        }
        return productDAO.findRecentByOwner(ownerId, limit);
    }



    /**
     * Tạo sản phẩm mới — chỉ dành cho SHOP_OWNER.
     *
     * @throws IllegalArgumentException nếu dữ liệu không hợp lệ.
     */
    public int createProduct(Product product) throws SQLException {
        validateProduct(product);
        product.setStatus("ACTIVE");
        return productDAO.save(product);
    }

    /**
     * Cập nhật sản phẩm — chỉ chủ sở hữu mới được phép.
     *
     * @throws IllegalArgumentException nếu dữ liệu không hợp lệ.
     */
    public void updateProduct(Product product) throws SQLException {
        validateProduct(product);
        productDAO.update(product);
    }

    /**
     * Bật/tắt trạng thái sản phẩm.
     *
     * @param status Phải là "ACTIVE" hoặc "INACTIVE".
     */
    public void toggleStatus(int productId, String status) throws SQLException {
        if (!"ACTIVE".equals(status) && !"INACTIVE".equals(status)) {
            throw new IllegalArgumentException("Trạng thái không hợp lệ: " + status);
        }
        productDAO.updateStatus(productId, status);
    }

    public int getLowStockCountByOwner(int ownerId, int threshold) throws SQLException {
        if (ownerId <= 0) {
            throw new IllegalArgumentException("ownerId không hợp lệ.");
        }
        return productDAO.getLowStockCountByOwner(ownerId, threshold);
    }

    public List<Map<String, Object>> getLowStockVariantsByOwner(int ownerId, int threshold) throws SQLException {
        if (ownerId <= 0) {
            throw new IllegalArgumentException("ownerId không hợp lệ.");
        }
        return productDAO.getLowStockVariantsByOwner(ownerId, threshold);
    }

    /**
     * Lấy danh sách sản phẩm ở trạng thái chờ duyệt (PENDING).
     *
     * @return danh sách sản phẩm chờ duyệt
     * @throws SQLException nếu xảy ra lỗi cơ sở dữ liệu
     */
    public List<Product> getPendingProducts() throws SQLException {
        return productDAO.findPendingProducts();
    }

    /**
     * Lấy danh sách toàn bộ sản phẩm phục vụ quản lý phía Admin (phân trang và lọc theo trạng thái duyệt).
     *
     * @param page Trang hiện tại (1-based)
     * @param pageSize Số lượng phần tử mỗi trang
     * @param approvalStatus Trạng thái kiểm duyệt cần lọc (nullable)
     * @return danh sách sản phẩm thỏa mãn điều kiện
     * @throws SQLException nếu xảy ra lỗi cơ sở dữ liệu
     */
    public List<Product> getAllAdminProducts(int page, int pageSize, String approvalStatus, Integer categoryId) throws SQLException {
        if (page < 1) page = 1;
        return productDAO.findAllAdminProducts(page, pageSize, approvalStatus, categoryId);
    }

    public int countAllAdminProducts(String approvalStatus, Integer categoryId) throws SQLException {
        return productDAO.countAllAdminProducts(approvalStatus, categoryId);
    }

    /**
     * Phê duyệt sản phẩm và đẩy lên sàn giao dịch công khai.
     * Admin có quyền đè danh mục và gắn mác Organic/Imported khi duyệt.
     *
     * @param productId ID sản phẩm
     * @param isOrganic nhãn hữu cơ
     * @param isImported nhãn nhập khẩu
     * @param categoryId ID danh mục được chỉ định
     * @return true nếu cập nhật thành công, ngược lại false
     * @throws SQLException nếu xảy ra lỗi cơ sở dữ liệu
     */
    public boolean approveProduct(int productId, boolean isOrganic, boolean isImported, int categoryId) throws SQLException {
        if (productId <= 0) {
            throw new IllegalArgumentException("ID sản phẩm không hợp lệ.");
        }
        if (categoryId <= 0) {
            throw new IllegalArgumentException("ID danh mục không hợp lệ.");
        }
        boolean updated = productDAO.updateApprovalStatus(productId, "APPROVED", null, isOrganic, isImported, categoryId);
        // Bug fix: sau khi duyệt, đảm bảo sản phẩm có status ACTIVE để hiển thị công khai
        // (sản phẩm có thể đã bị chì tiếp theo hoặc INACTIVE trước đó)
        if (updated) {
            productDAO.updateStatus(productId, "ACTIVE");
        }
        return updated;
    }

    /**
     * Từ chối phê duyệt sản phẩm và ghi nhận lý do.
     *
     * @param productId ID sản phẩm
     * @param reason Lý do từ chối phê duyệt
     * @return true nếu cập nhật thành công, ngược lại false
     * @throws SQLException nếu xảy ra lỗi cơ sở dữ liệu
     */
    public boolean rejectProduct(int productId, String reason) throws SQLException {
        if (productId <= 0) {
            throw new IllegalArgumentException("ID sản phẩm không hợp lệ.");
        }
        if (reason == null || reason.trim().isEmpty()) {
            throw new IllegalArgumentException("Lý do từ chối không được để trống.");
        }
        Product p = productDAO.findOneById(productId);
        if (p == null) {
            throw new IllegalArgumentException("Sản phẩm không tồn tại.");
        }
        return productDAO.updateApprovalStatus(productId, "REJECTED", reason.trim(), p.getIsOrganic(), p.getIsImported(), p.getCategoryId());
    }

    /**
     * Gỡ bỏ/Ẩn sản phẩm vi phạm bởi Admin (Cập nhật trạng thái thành DELETED).
     *
     * @param productId ID sản phẩm
     * @return true nếu gỡ bỏ thành công, ngược lại false
     * @throws SQLException nếu xảy ra lỗi cơ sở dữ liệu
     */
    public boolean banProduct(int productId) throws SQLException {
        if (productId <= 0) {
            throw new IllegalArgumentException("ID sản phẩm không hợp lệ.");
        }
        // Bug fix: sử dụng deleteProduct (transactional) thay vì banProduct (đơn giản)
        // để đảm bảo:
        //   1. Biến thể sản phẩm bị vô hiệu hóa (is_active = 0)
        //   2. Xóa khỏi giỏ hàng của mọi khách hàng (cart_items)
        //   3. Tắt các chương trình khuyến mãi có liên quan
        //   4. Đặt status = DELETED
        productDAO.deleteProduct(productId);
        return true;
    }

    // ── Private helpers ────────────────────────────────────────────────────

    private void validateProduct(Product product) {
        if (product == null) throw new IllegalArgumentException("Dữ liệu sản phẩm không được null.");
        if (product.getName() == null || product.getName().trim().isEmpty()) {
            throw new IllegalArgumentException("Tên sản phẩm không được để trống.");
        }
        if (product.getOwnerId() <= 0) {
            throw new IllegalArgumentException("Owner ID không hợp lệ.");
        }
    }
}
