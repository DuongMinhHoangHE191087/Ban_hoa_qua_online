package dao.catalog;

import dao.system.BaseDAO;
import model.entity.catalog.Product;
import model.dto.product.ProductDTO;
import util.PaginationHelper;
import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Locale;

/**
 * ProductDAO — DAO cho entity Product.
 *
 * QUY TẮC:
 * - Chỉ chứa SQL, không chứa business logic
 * - Dùng PreparedStatement, KHÔNG nối chuỗi SQL
 * - Mỗi method ném SQLException để Service xử lý
 * - Dùng try-with-resources cho Connection + PreparedStatement
 *
 * @author fruitmkt-team
 */// khang
public class ProductDAO extends BaseDAO {

    // khang
    /**
     * Tìm sản phẩm theo ID.
     */
    public List<Product> findById(int id) throws SQLException {
        List<Product> list = new ArrayList<>();
        Product product = findOneById(id);
        if (product != null) {
            list.add(product);
        }
        return list;
    }

    /**
     * Tìm sản phẩm theo ID và trả về 1 object duy nhất.
     */
    public Product findOneById(int id) throws SQLException {
        String sql = "SELECT * FROM products WHERE product_id = ?";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return mapRow(rs);
                }
            }
        }
        return null;
    }

    public static final String DTO_SELECT_FIELDS = "p.product_id, p.owner_id, p.category_id, p.name, CAST(NULL AS NVARCHAR(MAX)) AS description, "
            + "p.origin_country, p.origin_region, p.harvest_date, p.shelf_life_days, "
            + "p.storage_instruction, p.status, p.view_count, p.rating, p.sold_quantity, "
            + "p.is_organic, p.is_imported, p.approval_status, CAST(NULL AS NVARCHAR(255)) AS verification_doc_path, "
            + "p.rejection_reason, p.season_start_month, p.season_end_month, p.created_at, p.updated_at";

    private static final String SEARCH_COLLATION = "Vietnamese_100_CI_AI";

    private String buildPublicVisibilityClause(String alias) {
        return alias + ".status = 'ACTIVE' AND " + alias + ".approval_status = 'APPROVED' "
                + "AND EXISTS (SELECT 1 FROM shop_owner_profiles sp WHERE sp.user_id = " + alias
                + ".owner_id AND sp.approval_status = 'APPROVED') "
                + "AND (" + alias + ".season_start_month IS NULL OR " + alias + ".season_end_month IS NULL "
                + "OR (" + alias + ".season_start_month <= " + alias + ".season_end_month "
                + "AND MONTH(GETDATE()) BETWEEN " + alias + ".season_start_month AND " + alias + ".season_end_month) "
                + "OR (" + alias + ".season_start_month > " + alias + ".season_end_month "
                + "AND (MONTH(GETDATE()) >= " + alias + ".season_start_month OR MONTH(GETDATE()) <= " + alias
                + ".season_end_month)))";
    }

    private String buildActiveStockExistsClause(String alias) {
        return "EXISTS (SELECT 1 FROM product_variants pv_stock "
                + "WHERE pv_stock.product_id = " + alias + ".product_id "
                + "AND pv_stock.is_active = 1 AND pv_stock.stock_quantity > 0)";
    }

    private static final class SearchTerms {
        private final String normalizedKeyword;
        private final List<String> tokens;

        private SearchTerms(String normalizedKeyword, List<String> tokens) {
            this.normalizedKeyword = normalizedKeyword;
            this.tokens = tokens;
        }

        private boolean hasKeyword() {
            return normalizedKeyword != null && !normalizedKeyword.isEmpty();
        }
    }

    private SearchTerms prepareSearchTerms(String keyword) {
        if (keyword == null) {
            return new SearchTerms(null, new ArrayList<>());
        }

        String normalized = keyword.trim()
                .replaceAll("[^\\p{L}\\p{Nd}]+", " ")
                .replaceAll("\\s+", " ")
                .toLowerCase(Locale.ROOT);
        if (normalized.isEmpty()) {
            return new SearchTerms(null, new ArrayList<>());
        }

        LinkedHashSet<String> uniqueTokens = new LinkedHashSet<>();
        for (String token : normalized.split(" ")) {
            String cleaned = token.trim();
            if (cleaned.isEmpty()) {
                continue;
            }
            if (cleaned.length() < 2 && !cleaned.chars().allMatch(Character::isDigit)) {
                continue;
            }
            uniqueTokens.add(cleaned);
        }
        return new SearchTerms(normalized, new ArrayList<>(uniqueTokens));
    }

    private String buildSearchBlob(String productAlias, String categoryAlias) {
        return "("
                + "ISNULL(CAST(" + productAlias + ".product_id AS NVARCHAR(20)), N'') + N' '"
                + " + ISNULL(" + productAlias + ".name, N'') + N' '"
                + " + ISNULL(" + productAlias + ".description, N'') + N' '"
                + " + ISNULL(" + productAlias + ".origin_country, N'') + N' '"
                + " + ISNULL(" + productAlias + ".origin_region, N'') + N' '"
                + " + ISNULL(" + productAlias + ".storage_instruction, N'') + N' '"
                + " + ISNULL(" + categoryAlias + ".name, N'') + N' '"
                + " + CASE WHEN " + productAlias + ".is_organic = 1 THEN N'huu co' ELSE N'' END + N' '"
                + " + CASE WHEN " + productAlias + ".is_imported = 1 THEN N'nhap khau' ELSE N'' END"
                + ") COLLATE " + SEARCH_COLLATION;
    }

    private String buildSearchScoreExpression(String searchBlob, SearchTerms terms) {
        if (!terms.hasKeyword()) {
            return "0";
        }

        StringBuilder score = new StringBuilder("CASE WHEN ");
        score.append(searchBlob).append(" LIKE ? THEN 1000 ELSE 0 END");
        for (int i = 0; i < terms.tokens.size(); i++) {
            score.append(" + CASE WHEN ").append(searchBlob).append(" LIKE ? THEN 100 ELSE 0 END");
        }
        return score.toString();
    }

    private String buildSearchRankJoin(String searchBlob, SearchTerms terms) {
        if (!terms.hasKeyword()) {
            return "";
        }
        return "CROSS APPLY (SELECT " + buildSearchScoreExpression(searchBlob, terms) + " AS relevance_score) sr ";
    }

    private void bindSearchParameters(List<Object> params, SearchTerms terms) {
        if (!terms.hasKeyword()) {
            return;
        }
        params.add("%" + terms.normalizedKeyword + "%");
        for (String token : terms.tokens) {
            params.add("%" + token + "%");
        }
    }

    private int getSearchRelevanceThreshold(SearchTerms terms) {
        if (!terms.hasKeyword()) {
            return 0;
        }
        int tokenCount = terms.tokens.size();
        if (tokenCount <= 1) {
            return 100;
        }
        int requiredMatches = Math.max(2, (tokenCount + 1) / 2);
        return requiredMatches * 100;
    }

    /**
     * Lấy danh sách toàn bộ sản phẩm có phân trang (Tối ưu hóa Deferred Join).
     */
    public List<Product> findAll(int page, int pageSize) throws SQLException {
        List<Product> list = new ArrayList<>();
        String sql = "SELECT " + DTO_SELECT_FIELDS + " FROM products p "
                + "JOIN (SELECT product_id FROM products p WHERE " + buildPublicVisibilityClause("p") + " AND "
                + buildActiveStockExistsClause("p") + " "
                + "ORDER BY product_id DESC " + PaginationHelper.OFFSET_FETCH_SQL + ") temp "
                + "ON p.product_id = temp.product_id "
                + "ORDER BY p.product_id DESC";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            PaginationHelper.bindOffsetFetch(ps, 1, page, pageSize);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    /**
     * Lấy danh sách sản phẩm theo ID của chủ cửa hàng.
     */
    public List<Product> findByOwner(int ownerId) throws SQLException {
        List<Product> list = new ArrayList<>();
        String sql = "SELECT * FROM products WHERE owner_id = ? AND status != 'DELETED' ORDER BY product_id DESC";
        // khang
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, ownerId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    public List<Product> findByOwner(int ownerId, int page, int pageSize, String keyword, Integer categoryId,
            String approvalStatus, String sellStatus, String stockStatus) throws SQLException {
        List<Product> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder("SELECT * FROM products WHERE owner_id = ? AND status != 'DELETED' ");
        List<Object> params = new ArrayList<>();
        params.add(ownerId);

        if (keyword != null && !keyword.trim().isEmpty()) {
            sql.append("AND name LIKE ? ");
            params.add("%" + keyword.trim() + "%");
        }
        if (categoryId != null) {
            sql.append("AND category_id = ? ");
            params.add(categoryId);
        }
        if (approvalStatus != null && !approvalStatus.trim().isEmpty() && !"ALL".equalsIgnoreCase(approvalStatus)) {
            sql.append("AND approval_status = ? ");
            params.add(approvalStatus.trim());
        }
        if (sellStatus != null && !sellStatus.trim().isEmpty() && !"ALL".equalsIgnoreCase(sellStatus)) {
            sql.append("AND status = ? ");
            params.add(sellStatus.trim());
        }
        if (stockStatus != null && !stockStatus.trim().isEmpty() && !"ALL".equalsIgnoreCase(stockStatus)) {
            if ("IN_STOCK".equalsIgnoreCase(stockStatus)) {
                sql.append(
                        "AND EXISTS (SELECT 1 FROM product_variants pv WHERE pv.product_id = products.product_id AND pv.is_active = 1 AND pv.stock_quantity > 0) ");
            } else if ("OUT_OF_STOCK".equalsIgnoreCase(stockStatus)) {
                sql.append(
                        "AND NOT EXISTS (SELECT 1 FROM product_variants pv WHERE pv.product_id = products.product_id AND pv.is_active = 1 AND pv.stock_quantity > 0) ");
            }
        }

        sql.append("ORDER BY product_id DESC ").append(util.PaginationHelper.OFFSET_FETCH_SQL);

        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int index = 1;
            for (Object param : params) {
                ps.setObject(index++, param);
            }
            util.PaginationHelper.bindOffsetFetch(ps, index, page, pageSize);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    public int countByOwner(int ownerId, String keyword, Integer categoryId, String approvalStatus, String sellStatus,
            String stockStatus) throws SQLException {
        StringBuilder sql = new StringBuilder(
                "SELECT COUNT(*) FROM products WHERE owner_id = ? AND status != 'DELETED' ");
        List<Object> params = new ArrayList<>();
        params.add(ownerId);

        if (keyword != null && !keyword.trim().isEmpty()) {
            sql.append("AND name LIKE ? ");
            params.add("%" + keyword.trim() + "%");
        }
        if (categoryId != null) {
            sql.append("AND category_id = ? ");
            params.add(categoryId);
        }
        if (approvalStatus != null && !approvalStatus.trim().isEmpty() && !"ALL".equalsIgnoreCase(approvalStatus)) {
            sql.append("AND approval_status = ? ");
            params.add(approvalStatus.trim());
        }
        if (sellStatus != null && !sellStatus.trim().isEmpty() && !"ALL".equalsIgnoreCase(sellStatus)) {
            sql.append("AND status = ? ");
            params.add(sellStatus.trim());
        }
        if (stockStatus != null && !stockStatus.trim().isEmpty() && !"ALL".equalsIgnoreCase(stockStatus)) {
            if ("IN_STOCK".equalsIgnoreCase(stockStatus)) {
                sql.append(
                        "AND EXISTS (SELECT 1 FROM product_variants pv WHERE pv.product_id = products.product_id AND pv.is_active = 1 AND pv.stock_quantity > 0) ");
            } else if ("OUT_OF_STOCK".equalsIgnoreCase(stockStatus)) {
                sql.append(
                        "AND NOT EXISTS (SELECT 1 FROM product_variants pv WHERE pv.product_id = products.product_id AND pv.is_active = 1 AND pv.stock_quantity > 0) ");
            }
        }

        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int index = 1;
            for (Object param : params) {
                ps.setObject(index++, param);
            }
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt(1);
                }
            }
        }
        return 0;
    }

    public List<Product> findRecentByOwner(int ownerId, int limit) throws SQLException {
        List<Product> list = new ArrayList<>();
        if (limit <= 0) {
            return list;
        }
        String sql = "SELECT * FROM products WHERE owner_id = ? AND status != 'DELETED' "
                + "ORDER BY product_id DESC OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, ownerId);
            ps.setInt(2, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    /**
     * Tìm kiếm sản phẩm của chủ cửa hàng theo tên hoặc mô tả.
     */
    public List<Product> findByOwnerAndKeyword(int ownerId, String keyword) throws SQLException {
        List<Product> list = new ArrayList<>();
        String sql = "SELECT * FROM products WHERE owner_id = ? AND status != 'DELETED' AND (name LIKE ? OR description LIKE ?) ORDER BY product_id DESC";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, ownerId);
            String k = "%" + keyword.trim() + "%";
            ps.setString(2, k);
            ps.setString(3, k);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    /**
     * Lấy danh sách sản phẩm đang ACTIVE của một shop owner cụ thể.
     */
    public Map<Integer, Product> findActiveByOwner(int ownerId) throws SQLException {
        Map<Integer, Product> map = new LinkedHashMap<>();
        String sql = "SELECT * FROM products WHERE owner_id = ? AND " + buildPublicVisibilityClause("products")
                + " AND " + buildActiveStockExistsClause("products") + " ORDER BY product_id DESC";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, ownerId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Product product = mapRow(rs);
                    map.put(product.getProductId(), product);
                }
            }
        }
        return map;
    }

    /**
     * Lấy danh sách sản phẩm theo Category ID có phân trang (Tối ưu hóa Deferred
     * Join).
     */
    public List<Product> findByCategory(int categoryId, int page, int pageSize) throws SQLException {
        List<Product> list = new ArrayList<>();
        String sql = "SELECT " + DTO_SELECT_FIELDS + " FROM products p "
                + "JOIN (SELECT product_id FROM products p WHERE p.category_id = ? AND "
                + buildPublicVisibilityClause("p") + " AND " + buildActiveStockExistsClause("p") + " "
                + "ORDER BY product_id DESC " + PaginationHelper.OFFSET_FETCH_SQL + ") temp "
                + "ON p.product_id = temp.product_id "
                + "ORDER BY p.product_id DESC";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, categoryId);
            PaginationHelper.bindOffsetFetch(ps, 2, page, pageSize);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    /**
     * Lấy danh sách tất cả sản phẩm đang có chương trình khuyến mãi hoạt động
     * (Flash Sale).
     */
    public List<Product> findFlashSaleProducts() throws SQLException {
        List<Product> list = new ArrayList<>();
        String sql = "SELECT DISTINCT p.* FROM products p "
                + "JOIN promotions pr ON p.product_id = pr.product_id "
                + "WHERE " + buildPublicVisibilityClause("p") + " AND " + buildActiveStockExistsClause("p")
                + " AND pr.scope = 'PRODUCT' AND pr.is_active = 1 AND pr.is_deleted = 0 "
                + "AND pr.valid_from <= GETDATE() AND pr.valid_until >= GETDATE() "
                + "ORDER BY p.product_id DESC";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql);
                ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                list.add(mapRow(rs));
            }
        }
        return list;
    }

    /**
     * Tìm kiếm sản phẩm theo từ khóa, danh mục, khoảng giá và phân trang.
     */
    public List<Product> search(String keyword, Integer categoryId, java.math.BigDecimal minPrice,
            java.math.BigDecimal maxPrice, int page, int pageSize) throws SQLException {
        List<Product> list = new ArrayList<>();
        SearchTerms searchTerms = prepareSearchTerms(keyword);
        String searchBlob = buildSearchBlob("p", "c");
        StringBuilder sql = new StringBuilder("SELECT DISTINCT p.*");
        if (searchTerms.hasKeyword()) {
            sql.append(", sr.relevance_score AS relevance_score");
        }
        sql.append(" FROM products p ");
        sql.append("LEFT JOIN categories c ON c.category_id = p.category_id ");
        if (minPrice != null || maxPrice != null) {
            sql.append("JOIN product_variants pv ON p.product_id = pv.product_id ");
        }
        if (searchTerms.hasKeyword()) {
            sql.append(buildSearchRankJoin(searchBlob, searchTerms));
        }
        sql.append("WHERE ").append(buildPublicVisibilityClause("p")).append(" AND ")
                .append(buildActiveStockExistsClause("p")).append(" ");

        List<Object> params = new ArrayList<>();
        if (searchTerms.hasKeyword()) {
            bindSearchParameters(params, searchTerms);
            sql.append("AND sr.relevance_score >= ? ");
            params.add(getSearchRelevanceThreshold(searchTerms));
        }
        if (categoryId != null) {
            sql.append("AND p.category_id = ? ");
            params.add(categoryId);
        }
        if (minPrice != null) {
            sql.append("AND pv.price >= ? ");
            params.add(minPrice);
        }
        if (maxPrice != null) {
            sql.append("AND pv.price <= ? ");
            params.add(maxPrice);
        }

        if (searchTerms.hasKeyword()) {
            sql.append("ORDER BY sr.relevance_score DESC, p.product_id DESC ");
        } else {
            sql.append("ORDER BY p.product_id DESC ");
        }
        sql.append(PaginationHelper.OFFSET_FETCH_SQL);

        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int paramIndex = 1;
            for (Object param : params) {
                ps.setObject(paramIndex++, param);
            }
            PaginationHelper.bindOffsetFetch(ps, paramIndex, page, pageSize);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    /**
     * Đếm tổng số sản phẩm ACTIVE khớp với bộ lọc tìm kiếm/danh mục để hỗ trợ phân
     * trang.
     */
    public int countSearch(String keyword, Integer categoryId, java.math.BigDecimal minPrice,
            java.math.BigDecimal maxPrice) throws SQLException {
        StringBuilder sql = new StringBuilder("SELECT COUNT(DISTINCT p.product_id) FROM products p ");
        sql.append("LEFT JOIN categories c ON c.category_id = p.category_id ");
        if (minPrice != null || maxPrice != null) {
            sql.append("JOIN product_variants pv ON p.product_id = pv.product_id ");// khang
        }
        SearchTerms searchTerms = prepareSearchTerms(keyword);
        String searchBlob = buildSearchBlob("p", "c");
        sql.append(buildSearchRankJoin(searchBlob, searchTerms));
        sql.append("WHERE ").append(buildPublicVisibilityClause("p")).append(" ");
        sql.append("AND ").append(buildActiveStockExistsClause("p")).append(" ");

        List<Object> params = new ArrayList<>();
        if (searchTerms.hasKeyword()) {
            bindSearchParameters(params, searchTerms);
            sql.append("AND sr.relevance_score >= ? ");
            params.add(getSearchRelevanceThreshold(searchTerms));
        }
        if (categoryId != null) {
            sql.append("AND p.category_id = ? ");
            params.add(categoryId);
        }
        if (minPrice != null) {
            sql.append("AND pv.price >= ? ");
            params.add(minPrice);
        }
        if (maxPrice != null) {
            sql.append("AND pv.price <= ? ");
            params.add(maxPrice);
        }

        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt(1);
                }
            }
        }
        return 0;
    }

    /**
     * Lưu sản phẩm mới vào DB.
     */
    public int save(Product product) throws SQLException {
        String sql = "INSERT INTO products (owner_id, category_id, name, description, origin_country, origin_region, harvest_date, shelf_life_days, storage_instruction, status, view_count, rating, sold_quantity, is_organic, is_imported, season_start_month, season_end_month, approval_status, verification_doc_path, created_at, updated_at) "
                + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, GETDATE(), GETDATE())";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, product.getOwnerId());
            ps.setInt(2, product.getCategoryId());
            ps.setString(3, product.getName());
            ps.setString(4, product.getDescription());
            ps.setString(5, product.getOriginCountry());
            ps.setString(6, product.getOriginRegion());

            if (product.getHarvestDate() != null) {
                ps.setDate(7, java.sql.Date.valueOf(product.getHarvestDate()));
            } else {
                ps.setNull(7, Types.DATE);
            }

            if (product.getShelfLifeDays() != null) {
                ps.setInt(8, product.getShelfLifeDays());
            } else {
                ps.setNull(8, Types.INTEGER);
            }

            ps.setString(9, product.getStorageInstruction());
            ps.setString(10, product.getStatus() != null ? product.getStatus() : "ACTIVE");
            ps.setInt(11, product.getViewCount());
            ps.setBigDecimal(12, product.getRating() != null ? product.getRating() : java.math.BigDecimal.ZERO);
            ps.setInt(13, product.getSoldQuantity());
            ps.setBoolean(14, product.getIsOrganic());
            ps.setBoolean(15, product.getIsImported());

            if (product.getSeasonStartMonth() != null) {
                ps.setInt(16, product.getSeasonStartMonth());
            } else {
                ps.setNull(16, Types.INTEGER);
            }

            if (product.getSeasonEndMonth() != null) {
                ps.setInt(17, product.getSeasonEndMonth());
            } else {
                ps.setNull(17, Types.INTEGER);
            }

            ps.setString(18, product.getApprovalStatus() != null ? product.getApprovalStatus() : "PENDING");
            ps.setString(19, product.getVerificationDocPath());

            ps.executeUpdate();
            try (ResultSet rs = ps.getGeneratedKeys()) {
                if (rs.next()) {
                    return rs.getInt(1);
                }
            }
        }
        throw new SQLException("Lưu sản phẩm thất bại, không lấy được mã khóa tự tăng.");
    }

    /**
     * Cập nhật thông tin sản phẩm.
     */
    public void update(Product product) throws SQLException {
        String sql = "UPDATE products SET owner_id = ?, category_id = ?, name = ?, description = ?, origin_country = ?, origin_region = ?, harvest_date = ?, shelf_life_days = ?, storage_instruction = ?, status = ?, view_count = ?, rating = ?, sold_quantity = ?, is_organic = ?, is_imported = ?, season_start_month = ?, season_end_month = ?, approval_status = ?, verification_doc_path = ?, rejection_reason = ?, updated_at = GETDATE() WHERE product_id = ?";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, product.getOwnerId());
            ps.setInt(2, product.getCategoryId());
            ps.setString(3, product.getName());
            ps.setString(4, product.getDescription());
            ps.setString(5, product.getOriginCountry());
            ps.setString(6, product.getOriginRegion());

            if (product.getHarvestDate() != null) {
                ps.setDate(7, java.sql.Date.valueOf(product.getHarvestDate()));
            } else {
                ps.setNull(7, Types.DATE);
            }

            if (product.getShelfLifeDays() != null) {
                ps.setInt(8, product.getShelfLifeDays());
            } else {
                ps.setNull(8, Types.INTEGER);
            }

            ps.setString(9, product.getStorageInstruction());
            // Bug fix: guard null status — UPDATE dùng "ACTIVE" mặc định nếu không có giá
            // trị
            ps.setString(10, product.getStatus() != null ? product.getStatus() : "ACTIVE");
            ps.setInt(11, product.getViewCount());
            // Bug fix: guard null rating — tránh NullPointerException khi sản phẩm chưa có
            // đánh giá nào
            ps.setBigDecimal(12, product.getRating() != null ? product.getRating() : java.math.BigDecimal.ZERO);
            ps.setInt(13, product.getSoldQuantity());
            ps.setBoolean(14, product.getIsOrganic());
            ps.setBoolean(15, product.getIsImported());

            if (product.getSeasonStartMonth() != null) {
                ps.setInt(16, product.getSeasonStartMonth());
            } else {
                ps.setNull(16, Types.INTEGER);
            }

            if (product.getSeasonEndMonth() != null) {
                ps.setInt(17, product.getSeasonEndMonth());
            } else {
                ps.setNull(17, Types.INTEGER);
            }

            ps.setString(18, product.getApprovalStatus());
            ps.setString(19, product.getVerificationDocPath());
            ps.setString(20, product.getRejectionReason());
            ps.setInt(21, product.getProductId());

            ps.executeUpdate();
        }
    }

    /**
     * Cập nhật trạng thái sản phẩm.
     */
    public void updateStatus(int productId, String status) throws SQLException {
        String sql = "UPDATE products SET status = ?, updated_at = GETDATE() WHERE product_id = ?";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, status);
            ps.setInt(2, productId);
            ps.executeUpdate();
        }
    }

    /**
     * Cập nhật ngày thu hoạch và trạng thái sản phẩm trong một Transaction
     * Connection.
     */
    public void updateHarvestDateAndStatus(Connection conn, int productId, java.time.LocalDate harvestDate,
            String status) throws SQLException {
        String sql = "UPDATE products SET harvest_date = ?, status = ?, updated_at = GETDATE() WHERE product_id = ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setDate(1, java.sql.Date.valueOf(harvestDate));
            ps.setString(2, status);
            ps.setInt(3, productId);
            ps.executeUpdate();
        }
    }

    /**
     * Tạo thông báo yêu cầu nhập kho gửi đến chủ shop, lưu vết customerId và
     * productId trong message.
     */
    public void createRestockNotification(int ownerId, int customerId, int productId, String productName)
            throws SQLException {
        String sql = "INSERT INTO notifications (user_id, type, title, message, action_url, is_read, created_at) "
                + "VALUES (?, 'SYSTEM', ?, ?, ?, 0, GETDATE())";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, ownerId);
            ps.setString(2, "Yêu cầu nhập kho vụ mới");
            ps.setString(3, "[RestockRequest: customer=" + customerId + ", product=" + productId
                    + "] Khách hàng quan tâm và yêu cầu nhập kho vụ mới cho sản phẩm: " + productName);
            ps.setString(4, "/shop/inventory");
            ps.executeUpdate();
        }
    }

    /**
     * Kiểm tra xem khách hàng đã gửi yêu cầu nhập kho cho sản phẩm này trong ngày
     * hôm nay chưa.
     */
    public boolean hasRequestedRestockToday(int ownerId, int customerId, int productId) throws SQLException {
        String sql = "SELECT COUNT(*) FROM notifications "
                + "WHERE user_id = ? AND type = 'SYSTEM' "
                + "AND message LIKE ? "
                + "AND CAST(created_at AS DATE) = CAST(GETDATE() AS DATE)";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, ownerId);
            ps.setString(2, "%[RestockRequest: customer=" + customerId + ", product=" + productId + "]%");
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt(1) > 0;
                }
            }
        }
        return false;
    }

    public void autoDeactivateExpiredProducts() throws SQLException {
        String sqlDeactivate = "UPDATE products SET status = 'OUT_OF_SEASON', updated_at = GETDATE() "
                + "WHERE status = 'ACTIVE' AND ("
                + "  (harvest_date IS NOT NULL AND shelf_life_days IS NOT NULL AND shelf_life_days > 0 "
                + "   AND DATEADD(day, shelf_life_days, harvest_date) <= CAST(GETDATE() AS DATE))"
                + "  OR"
                + "  (season_start_month IS NOT NULL AND season_end_month IS NOT NULL AND ("
                + "    (season_start_month <= season_end_month AND MONTH(GETDATE()) NOT BETWEEN season_start_month AND season_end_month)"
                + "    OR"
                + "    (season_start_month > season_end_month AND MONTH(GETDATE()) < season_start_month AND MONTH(GETDATE()) > season_end_month)"
                + "  ))"
                + ")";

        String sqlReactivate = "UPDATE products SET status = 'ACTIVE', updated_at = GETDATE() "
                + "WHERE status = 'OUT_OF_SEASON' AND ("
                + "  (season_start_month IS NULL OR season_end_month IS NULL OR ("
                + "    (season_start_month <= season_end_month AND MONTH(GETDATE()) BETWEEN season_start_month AND season_end_month)"
                + "    OR"
                + "    (season_start_month > season_end_month AND (MONTH(GETDATE()) >= season_start_month OR MONTH(GETDATE()) <= season_end_month))"
                + "  ))"
                + "  AND NOT (harvest_date IS NOT NULL AND shelf_life_days IS NOT NULL AND shelf_life_days > 0 "
                + "           AND DATEADD(day, shelf_life_days, harvest_date) <= CAST(GETDATE() AS DATE))"
                + ")";

        try (Connection conn = getConnection()) {
            conn.setAutoCommit(false);
            try (PreparedStatement psDeact = conn.prepareStatement(sqlDeactivate);
                 PreparedStatement psReact = conn.prepareStatement(sqlReactivate)) {
                psDeact.executeUpdate();
                psReact.executeUpdate();
                conn.commit();
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            } finally {
                conn.setAutoCommit(true);
            }
        }
    }

    /**
     * Thực hiện xóa mềm sản phẩm (soft delete) một cách an toàn và triệt để:
     * 1. Cập nhật status của sản phẩm thành 'DELETED'
     * 2. Hủy kích hoạt tất cả các biến thể của sản phẩm (is_active = 0)
     * 3. Xóa các biến thể này khỏi giỏ hàng của tất cả khách hàng (cart_items)
     */
    public void deleteProduct(int productId) throws SQLException {
        String updateProductSql = "UPDATE products SET status = 'DELETED', updated_at = GETDATE() WHERE product_id = ?";
        String updateVariantsSql = "UPDATE product_variants SET is_active = 0, updated_at = GETDATE() WHERE product_id = ?";
        String deleteCartSql = "DELETE FROM cart_items WHERE variant_id IN (SELECT variant_id FROM product_variants WHERE product_id = ?)";
        String updatePromotionsSql = "UPDATE promotions SET is_active = 0, updated_at = GETDATE() WHERE product_id = ?";

        try (Connection conn = getConnection()) {
            conn.setAutoCommit(false);
            try (PreparedStatement psCart = conn.prepareStatement(deleteCartSql);
                    PreparedStatement psVar = conn.prepareStatement(updateVariantsSql);
                    PreparedStatement psProm = conn.prepareStatement(updatePromotionsSql);
                    PreparedStatement psProd = conn.prepareStatement(updateProductSql)) {

                // 1. Xóa các cart items của sản phẩm này
                psCart.setInt(1, productId);
                psCart.executeUpdate();

                // 2. Tắt các biến thể
                psVar.setInt(1, productId);
                psVar.executeUpdate();

                // 3. Tắt các khuyến mãi áp dụng riêng cho sản phẩm này
                psProm.setInt(1, productId);
                psProm.executeUpdate();

                // 4. Cập nhật status sản phẩm thành DELETED
                psProd.setInt(1, productId);
                psProd.executeUpdate();

                conn.commit();
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            } finally {
                conn.setAutoCommit(true);
            }
        }
    }

    /**
     * Tăng số lượng lượt xem của sản phẩm.
     */
    public void incrementViewCount(int productId) throws SQLException {
        String sql = "UPDATE products SET view_count = view_count + 1, updated_at = GETDATE() WHERE product_id = ?";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, productId);
            ps.executeUpdate();
        }
    }

    /**
     * Lấy Product ID từ Order Item ID để cập nhật rating.
     */
    public int getProductIdByOrderItem(int orderItemId) throws SQLException {
        String sql = "SELECT pv.product_id FROM order_items oi JOIN product_variants pv ON oi.variant_id = pv.variant_id WHERE oi.order_item_id = ?";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, orderItemId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt("product_id");
                }
            }
        }
        return -1;
    }

    /**
     * Lấy Product ID từ Review ID để cập nhật rating.
     */
    public int getProductIdByReview(int reviewId) throws SQLException {
        String sql = "SELECT pv.product_id FROM reviews r JOIN order_items oi ON r.order_item_id = oi.order_item_id JOIN product_variants pv ON oi.variant_id = pv.variant_id WHERE r.review_id = ?";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, reviewId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt("product_id");
                }
            }
        }
        return -1;
    }

    /**
     * Tính toán lại và cập nhật điểm đánh giá trung bình (rating) cho sản phẩm
     * dựa trên các đánh giá hợp lệ (không bị ẩn).
     */
    public void recalculateRating(int productId) throws SQLException {
        String sql = "UPDATE products SET rating = ISNULL((SELECT AVG(CAST(r.rating AS DECIMAL(3,2))) "
                + "FROM reviews r "
                + "JOIN order_items oi ON r.order_item_id = oi.order_item_id "
                + "JOIN product_variants pv ON oi.variant_id = pv.variant_id "
                + "WHERE pv.product_id = ? AND r.is_hidden = 0), 0) "
                + "WHERE product_id = ?";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, productId);
            ps.setInt(2, productId);
            ps.executeUpdate();
        }
    }

    /**
     * Tìm kiếm các sản phẩm tương tự cùng danh mục (Category) phục vụ hiển thị
     * danh sách gợi ý ở trang chi tiết sản phẩm. Loại trừ sản phẩm hiện tại.
     * Sắp xếp theo số lượng bán (sold_quantity DESC) và lượt xem (view_count DESC).
     *
     * @param productId  ID sản phẩm hiện tại cần loại trừ
     * @param categoryId ID danh mục của sản phẩm hiện tại
     * @param limit      Số lượng sản phẩm tương tự tối đa cần lấy
     * @return danh sách các sản phẩm tương tự
     * @throws SQLException nếu xảy ra lỗi truy vấn cơ sở dữ liệu
     */
    public List<Product> findSimilarProducts(int productId, int categoryId, int limit) throws SQLException {
        List<Product> list = new ArrayList<>();
        String sql = "SELECT * FROM products "
                + "WHERE category_id = ? AND product_id != ? AND " + buildPublicVisibilityClause("products") + " AND "
                + buildActiveStockExistsClause("products") + " "
                + "ORDER BY sold_quantity DESC, view_count DESC, product_id DESC "
                + "OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, categoryId);
            ps.setInt(2, productId);
            ps.setInt(3, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    /**
     * Lấy danh sách sản phẩm ACTIVE của một shop owner cụ thể,
     * loại trừ sản phẩm hiện tại đang xem, giới hạn số lượng.
     * Phục vụ phần "Xem thêm từ cửa hàng này" trên trang chi tiết sản phẩm.
     *
     * @param ownerId          ID của chủ cửa hàng
     * @param excludeProductId ID sản phẩm đang xem (loại trừ khỏi danh sách)
     * @param limit            Số lượng sản phẩm tối đa cần lấy
     * @return danh sách sản phẩm khác của shop
     * @throws SQLException nếu xảy ra lỗi truy vấn
     */
    public List<Product> findByOwnerAndActiveStatus(int ownerId, int excludeProductId, int limit) throws SQLException {
        List<Product> list = new ArrayList<>();
        String sql = "SELECT * FROM products "
                + "WHERE owner_id = ? AND product_id != ? AND " + buildPublicVisibilityClause("products") + " AND "
                + buildActiveStockExistsClause("products") + " "
                + "ORDER BY sold_quantity DESC, view_count DESC, product_id DESC "
                + "OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, ownerId);
            ps.setInt(2, excludeProductId);
            ps.setInt(3, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    /**
     * Đếm số lượng biến thể sản phẩm có số lượng tồn kho <= threshold của chủ cửa
     * hàng.
     */
    public int getLowStockCountByOwner(int ownerId, int threshold) throws SQLException {
        String sql = "SELECT COUNT(*) FROM product_variants pv "
                + "JOIN products p ON pv.product_id = p.product_id "
                + "WHERE p.owner_id = ? AND pv.stock_quantity <= ? AND pv.is_active = 1 AND p.status = 'ACTIVE'";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, ownerId);
            ps.setInt(2, threshold);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt(1);
                }
            }
        }
        return 0;
    }

    /**
     * Lấy danh sách biến thể sản phẩm sắp hết hàng (tồn kho <= threshold) của chủ
     * cửa hàng.
     */
    public List<Map<String, Object>> getLowStockVariantsByOwner(int ownerId, int threshold) throws SQLException {
        List<Map<String, Object>> list = new ArrayList<>();
        String sql = "SELECT pv.variant_id, pv.product_id, pv.sku, pv.variant_label, pv.price, pv.stock_quantity, p.name AS product_name "
                + "FROM product_variants pv "
                + "JOIN products p ON pv.product_id = p.product_id "
                + "WHERE p.owner_id = ? AND pv.stock_quantity <= ? AND pv.is_active = 1 AND p.status = 'ACTIVE' "
                + "ORDER BY pv.stock_quantity ASC";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, ownerId);
            ps.setInt(2, threshold);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("variantId", rs.getInt("variant_id"));
                    map.put("productId", rs.getInt("product_id"));
                    map.put("sku", rs.getString("sku"));
                    map.put("variantLabel", rs.getString("variant_label"));
                    map.put("price", rs.getBigDecimal("price"));
                    map.put("stockQuantity", rs.getInt("stock_quantity"));
                    map.put("productName", rs.getString("product_name"));
                    list.add(map);
                }
            }
        }
        return list;
    }

    /** Ánh xạ ResultSet -> Product — gọi trong mọi query SELECT */
    private Product mapRow(ResultSet rs) throws SQLException {
        Product p = new Product();
        p.setProductId(rs.getInt("product_id"));
        p.setOwnerId(rs.getInt("owner_id"));
        p.setCategoryId(rs.getInt("category_id"));
        p.setName(rs.getString("name"));
        p.setDescription(rs.getString("description"));
        p.setOriginCountry(rs.getString("origin_country"));
        p.setOriginRegion(rs.getString("origin_region"));

        java.sql.Date harvestDateVal = rs.getDate("harvest_date");
        if (harvestDateVal != null) {
            p.setHarvestDate(harvestDateVal.toLocalDate());
        }

        int shelfLife = rs.getInt("shelf_life_days");
        p.setShelfLifeDays(rs.wasNull() ? null : shelfLife);

        p.setStorageInstruction(rs.getString("storage_instruction"));
        p.setStatus(rs.getString("status"));
        p.setViewCount(rs.getInt("view_count"));
        p.setRating(rs.getBigDecimal("rating"));
        p.setSoldQuantity(rs.getInt("sold_quantity"));
        p.setIsOrganic(rs.getBoolean("is_organic"));
        p.setIsImported(rs.getBoolean("is_imported"));
        p.setApprovalStatus(rs.getString("approval_status"));
        p.setVerificationDocPath(rs.getString("verification_doc_path"));
        p.setRejectionReason(rs.getString("rejection_reason"));

        int startMonth = rs.getInt("season_start_month");
        p.setSeasonStartMonth(rs.wasNull() ? null : startMonth);

        int endMonth = rs.getInt("season_end_month");
        p.setSeasonEndMonth(rs.wasNull() ? null : endMonth);

        Timestamp createdAtVal = rs.getTimestamp("created_at");
        if (createdAtVal != null) {
            p.setCreatedAt(createdAtVal.toLocalDateTime());
        }

        Timestamp updatedAtVal = rs.getTimestamp("updated_at");
        if (updatedAtVal != null) {
            p.setUpdatedAt(updatedAtVal.toLocalDateTime());
        }

        return p;
    }

    /**
     * Lấy danh sách sản phẩm chờ kiểm duyệt (PENDING)
     */
    public List<Product> findPendingProducts() throws SQLException {
        List<Product> list = new ArrayList<>();
        String sql = "SELECT * FROM products WHERE approval_status = 'PENDING' AND status != 'DELETED' ORDER BY product_id DESC";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql);
                ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                list.add(mapRow(rs));
            }
        }
        return list;
    }

    /**
     * Lấy danh sách sản phẩm phục vụ trang quản trị Admin (phân trang và lọc theo
     * trạng thái duyệt)
     */
    public List<Product> findAllAdminProducts(int page, int pageSize, String approvalStatusFilter) throws SQLException {
        return findAllAdminProducts(page, pageSize, approvalStatusFilter, null);
    }

    public List<Product> findAllAdminProducts(int page, int pageSize, String approvalStatusFilter,
            Integer categoryIdFilter) throws SQLException {
        List<Product> list = new ArrayList<>();
        int offset = (page - 1) * pageSize;
        StringBuilder sql = new StringBuilder("SELECT * FROM products WHERE status != 'DELETED' ");
        List<Object> params = new ArrayList<>();

        if (categoryIdFilter != null && categoryIdFilter > 0) {
            sql.append("AND category_id = ? ");
            params.add(categoryIdFilter);
        }

        if (approvalStatusFilter != null && !approvalStatusFilter.trim().isEmpty()) {
            sql.append("AND approval_status = ? ");
            params.add(approvalStatusFilter.trim());
        }

        sql.append("ORDER BY product_id DESC OFFSET ? ROWS FETCH NEXT ? ROWS ONLY");
        params.add(offset);
        params.add(pageSize);

        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    /**
     * Đếm số lượng sản phẩm phục vụ trang quản trị Admin (lọc theo trạng thái
     * duyệt)
     */
    public int countAllAdminProducts(String approvalStatusFilter) throws SQLException {
        return countAllAdminProducts(approvalStatusFilter, null);
    }

    public int countAllAdminProducts(String approvalStatusFilter, Integer categoryIdFilter) throws SQLException {
        StringBuilder sql = new StringBuilder("SELECT COUNT(*) FROM products WHERE status != 'DELETED' ");
        List<Object> params = new ArrayList<>();

        if (categoryIdFilter != null && categoryIdFilter > 0) {
            sql.append("AND category_id = ? ");
            params.add(categoryIdFilter);
        }

        if (approvalStatusFilter != null && !approvalStatusFilter.trim().isEmpty()) {
            sql.append("AND approval_status = ? ");
            params.add(approvalStatusFilter.trim());
        }

        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt(1);
                }
            }
        }
        return 0;
    }

    /**
     * Cập nhật trạng thái phê duyệt sản phẩm bởi Admin.
     * Cập nhật cả nhãn Organic/Imported và Category ID nếu được Admin chỉ định khi
     * duyệt.
     */
    public boolean updateApprovalStatus(int productId, String approvalStatus, String rejectionReason, boolean isOrganic,
            boolean isImported, int categoryId) throws SQLException {
        String sql = "UPDATE products SET approval_status = ?, rejection_reason = ?, is_organic = ?, is_imported = ?, category_id = ?, updated_at = GETDATE() WHERE product_id = ?";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, approvalStatus);
            ps.setString(2, rejectionReason);
            ps.setBoolean(3, isOrganic);
            ps.setBoolean(4, isImported);
            ps.setInt(5, categoryId);
            ps.setInt(6, productId);
            return ps.executeUpdate() > 0;
        }
    }

    /**
     * Ẩn/Xóa sản phẩm vi phạm bởi Admin (soft delete)
     */
    public boolean banProduct(int productId) throws SQLException {
        String sql = "UPDATE products SET status = 'DELETED', updated_at = GETDATE() WHERE product_id = ?";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, productId);
            return ps.executeUpdate() > 0;
        }
    }

    /**
     * Lấy trang tiếp theo của sản phẩm sử dụng Keyset (Cursor) Pagination.
     * Thích hợp cho infinite scroll hoặc lượng dữ liệu lớn.
     * 
     * @param lastProductId ID của sản phẩm cuối cùng của trang trước (0 nếu là
     *                      trang đầu)
     * @param limit         Số lượng sản phẩm muốn lấy
     */
    public List<Product> findNextProducts(int lastProductId, int limit) throws SQLException {
        List<Product> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder("SELECT ");
        sql.append(DTO_SELECT_FIELDS);
        sql.append(" FROM products p WHERE ").append(buildPublicVisibilityClause("p")).append(" AND ")
                .append(buildActiveStockExistsClause("p"));
        if (lastProductId > 0) {
            sql.append(" AND p.product_id < ?");
        }
        sql.append(" ORDER BY p.product_id DESC OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY");

        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int paramIndex = 1;
            if (lastProductId > 0) {
                ps.setInt(paramIndex++, lastProductId);
            }
            ps.setInt(paramIndex, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRowDTO(rs));
                }
            }
        }
        return list;
    }

    private ProductDTO mapRowDTO(ResultSet rs) throws SQLException {
        Product p = mapRow(rs);
        ProductDTO dto = new ProductDTO();
        dto.setProductId(p.getProductId());
        dto.setOwnerId(p.getOwnerId());
        dto.setCategoryId(p.getCategoryId());
        dto.setName(p.getName());
        dto.setDescription(p.getDescription());
        dto.setOriginCountry(p.getOriginCountry());
        dto.setOriginRegion(p.getOriginRegion());
        dto.setHarvestDate(p.getHarvestDate());
        dto.setShelfLifeDays(p.getShelfLifeDays());
        dto.setStorageInstruction(p.getStorageInstruction());
        dto.setStatus(p.getStatus());
        dto.setViewCount(p.getViewCount());
        dto.setRating(p.getRating());
        dto.setSoldQuantity(p.getSoldQuantity());
        dto.setIsOrganic(p.getIsOrganic());
        dto.setIsImported(p.getIsImported());
        dto.setApprovalStatus(p.getApprovalStatus());
        dto.setVerificationDocPath(p.getVerificationDocPath());
        dto.setRejectionReason(p.getRejectionReason());
        dto.setSeasonStartMonth(p.getSeasonStartMonth());
        dto.setSeasonEndMonth(p.getSeasonEndMonth());
        dto.setCreatedAt(p.getCreatedAt());
        dto.setUpdatedAt(p.getUpdatedAt());
        return dto;
    }

    /**
     * Lấy danh sách toàn bộ sản phẩm đang hoạt động và đã được phê duyệt để nạp làm
     * context cho AI.
     */
    public List<Product> findAllActiveForAI() throws SQLException {
        List<Product> list = new ArrayList<>();
        String sql = "SELECT product_id, category_id, name, description, origin_country, origin_region, storage_instruction, is_imported, view_count, rating, sold_quantity FROM products p WHERE "
                + buildPublicVisibilityClause("p") + " AND " + buildActiveStockExistsClause("p")
                + " ORDER BY product_id DESC";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql);
                ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Product p = new Product();
                p.setProductId(rs.getInt("product_id"));
                p.setCategoryId(rs.getInt("category_id"));
                p.setName(rs.getString("name"));
                p.setDescription(rs.getString("description"));
                p.setOriginCountry(rs.getString("origin_country"));
                p.setOriginRegion(rs.getString("origin_region"));
                p.setStorageInstruction(rs.getString("storage_instruction"));
                p.setIsImported(rs.getBoolean("is_imported"));
                p.setViewCount(rs.getInt("view_count"));
                p.setRating(rs.getBigDecimal("rating"));
                p.setSoldQuantity(rs.getInt("sold_quantity"));
                list.add(p);
            }
        }
        return list;
    }

    public List<Map<String, Object>> findAllActiveBriefForAI() throws SQLException {
        List<Map<String, Object>> list = new ArrayList<>();
        String sql = "SELECT p.product_id, p.name, p.status, ISNULL(SUM(pv.stock_quantity), 0) AS total_stock "
                + "FROM products p "
                + "LEFT JOIN product_variants pv ON p.product_id = pv.product_id AND pv.is_active = 1 "
                + "WHERE " + buildPublicVisibilityClause("p") + " "
                + "GROUP BY p.product_id, p.name, p.status "
                + "HAVING ISNULL(SUM(pv.stock_quantity), 0) > 0 "
                + "ORDER BY p.product_id DESC";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql);
                ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Map<String, Object> map = new HashMap<>();
                map.put("productId", rs.getInt("product_id"));
                map.put("name", rs.getString("name"));
                map.put("status", rs.getString("status"));
                map.put("stock", rs.getInt("total_stock"));
                list.add(map);
            }
        }
        return list;
    }

    /**
     * Lấy thông tin ngắn gọn của danh sách sản phẩm theo ID để hiển thị trong AI
     * chat.
     */
    public List<Map<String, Object>> findBriefProductsByIds(List<Integer> ids) throws SQLException {
        List<Map<String, Object>> list = new ArrayList<>();
        if (ids == null || ids.isEmpty()) {
            return list;
        }

        StringBuilder placeholders = new StringBuilder();
        for (int i = 0; i < ids.size(); i++) {
            placeholders.append("?");
            if (i < ids.size() - 1) {
                placeholders.append(",");
            }
        }

        String sql = "SELECT p.product_id, p.name, "
                + "       (SELECT TOP 1 pv.variant_id FROM product_variants pv WHERE pv.product_id = p.product_id AND pv.is_active = 1 AND pv.stock_quantity > 0 ORDER BY pv.price ASC) AS variant_id, "
                + "       (SELECT TOP 1 pv.price FROM product_variants pv WHERE pv.product_id = p.product_id AND pv.is_active = 1 AND pv.stock_quantity > 0 ORDER BY pv.price ASC) AS price, "
                + "       (SELECT TOP 1 pv.variant_label FROM product_variants pv WHERE pv.product_id = p.product_id AND pv.is_active = 1 AND pv.stock_quantity > 0 ORDER BY pv.price ASC) AS unit, "
                // B8: Fallback — lấy ảnh primary trước, nếu không có thì lấy ảnh bất kỳ
                + "       (SELECT TOP 1 pi.file_path FROM product_images pi WHERE pi.product_id = p.product_id ORDER BY pi.is_primary DESC, pi.display_order ASC) AS image "
                + "FROM products p "
                + "WHERE p.product_id IN (" + placeholders.toString() + ") AND " + buildPublicVisibilityClause("p")
                + " AND " + buildActiveStockExistsClause("p");

        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            for (int i = 0; i < ids.size(); i++) {
                ps.setInt(i + 1, ids.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("productId", rs.getInt("product_id"));
                    map.put("variantId", rs.getInt("variant_id"));
                    map.put("name", rs.getString("name"));
                    map.put("price", rs.getBigDecimal("price"));
                    map.put("unit", rs.getString("unit"));
                    map.put("image", rs.getString("image"));
                    list.add(map);
                }
            }
        }
        return list;
    }

    /**
     * Lấy danh sách sản phẩm theo nhiều ID, giữ lại các sản phẩm ACTIVE và
     * APPROVED.
     */
    public Map<Integer, Product> findByIds(Collection<Integer> ids) throws SQLException {
        Map<Integer, Product> map = new LinkedHashMap<>();
        if (ids == null || ids.isEmpty()) {
            return map;
        }

        Collection<Integer> distinctIds = new LinkedHashSet<>(ids);
        StringBuilder placeholders = new StringBuilder();
        int index = 0;
        for (Integer ignored : distinctIds) {
            if (index++ > 0) {
                placeholders.append(",");
            }
            placeholders.append("?");
        }

        String sql = "SELECT * FROM products p WHERE p.product_id IN (" + placeholders + ") "
                + "AND " + buildPublicVisibilityClause("p") + " AND " + buildActiveStockExistsClause("p");
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            int paramIndex = 1;
            for (Integer id : distinctIds) {
                ps.setInt(paramIndex++, id);
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Product product = mapRow(rs);
                    map.put(product.getProductId(), product);
                }
            }
        }
        return map;
    }

    private Map<String, Object> mapRowToProductMap(ResultSet rs, String contextPath) throws SQLException {
        Map<String, Object> item = new HashMap<>();
        int productId = rs.getInt("product_id");
        item.put("productId", productId);
        item.put("name", rs.getString("name"));
        item.put("description", rs.getString("description"));
        BigDecimal rating = rs.getBigDecimal("rating");
        item.put("rating", rating != null ? rating : BigDecimal.ZERO);
        int soldQuantity = rs.getInt("sold_quantity");
        item.put("soldQuantity", soldQuantity);

        String imagePath = rs.getString("primary_image_path");
        if (imagePath != null && !imagePath.trim().isEmpty()) {
            imagePath = imagePath.trim().replace('\\', '/');
        }
        if (imagePath == null) {
            imagePath = contextPath + "/assets/img/placeholder.png";
        } else if (!imagePath.startsWith("http://") && !imagePath.startsWith("https://")) {
            if (!imagePath.startsWith("/")) {
                imagePath = "/" + imagePath;
            }
            imagePath = contextPath + imagePath;
        }
        item.put("image", imagePath);

        BigDecimal basePrice = rs.getBigDecimal("cheapest_price");
        if (basePrice == null) {
            basePrice = new BigDecimal("45000");
        }
        String unit = rs.getString("cheapest_unit");
        if (unit == null) {
            unit = "kg";
        }
        int stockRemaining = rs.getInt("cheapest_stock");
        if (rs.wasNull()) {
            stockRemaining = 10;
        }
        item.put("unit", unit);

        String promoType = rs.getString("discount_type");
        if (promoType != null) {
            BigDecimal discountValue = rs.getBigDecimal("discount_value");
            BigDecimal discountMax = rs.getBigDecimal("discount_max");
            BigDecimal finalPrice = basePrice;
            int discountPercent = 0;

            if ("PERCENT".equals(promoType)) {
                discountPercent = discountValue.intValue();
                BigDecimal discountAmount = basePrice.multiply(discountValue).divide(new BigDecimal("100"), 2,
                        java.math.RoundingMode.HALF_UP);
                if (discountMax != null && discountMax.compareTo(BigDecimal.ZERO) > 0) {
                    if (discountAmount.compareTo(discountMax) > 0) {
                        discountAmount = discountMax;
                    }
                }
                finalPrice = basePrice.subtract(discountAmount);
            } else if ("FIXED".equals(promoType)) {
                finalPrice = basePrice.subtract(discountValue);
                if (basePrice.compareTo(BigDecimal.ZERO) > 0) {
                    discountPercent = discountValue.multiply(new BigDecimal("100"))
                            .divide(basePrice, 0, java.math.RoundingMode.HALF_UP).intValue();
                }
            }

            if (finalPrice.compareTo(BigDecimal.ZERO) < 0) {
                finalPrice = BigDecimal.ZERO;
            }

            item.put("price", finalPrice);
            item.put("originalPrice", basePrice);
            item.put("discountPercent", discountPercent);
            item.put("stockRemaining", stockRemaining);
            item.put("stockTotal", Math.max(stockRemaining + soldQuantity, stockRemaining));
        } else {
            BigDecimal originalPrice = rs.getBigDecimal("original_price");
            if (originalPrice == null)
                originalPrice = basePrice;

            if (originalPrice.compareTo(basePrice) > 0) {
                int discountPercent = originalPrice.subtract(basePrice)
                        .multiply(new BigDecimal("100"))
                        .divide(originalPrice, 0, java.math.RoundingMode.HALF_UP)
                        .intValue();
                item.put("price", basePrice);
                item.put("originalPrice", originalPrice);
                item.put("discountPercent", discountPercent);
            } else {
                item.put("price", basePrice);
                item.put("originalPrice", basePrice);
                item.put("discountPercent", 0);
            }
            item.put("stockRemaining", stockRemaining);
            item.put("stockTotal", Math.max(stockRemaining + soldQuantity, stockRemaining));
        }
        try {
            java.sql.Timestamp validUntil = rs.getTimestamp("valid_until");
            if (validUntil != null) {
                item.put("validUntil", validUntil.getTime());
            }
        } catch (SQLException e) {
            // Bỏ qua nếu cột không tồn tại trong ResultSet
        }
        return item;
    }

    public List<Map<String, Object>> findFlashSaleProductsOptimized(String contextPath) throws SQLException {
        List<Map<String, Object>> list = new ArrayList<>();
        String sql = "SELECT p.product_id, p.name, p.description, p.rating, p.sold_quantity, "
                + "       pi.file_path AS primary_image_path, "
                + "       pv.cheapest_price, pv.original_price, pv.variant_label AS cheapest_unit, pv.stock_quantity AS cheapest_stock, "
                + "       pr.discount_type, pr.discount_value, pr.discount_max, pr.valid_until "
                + "FROM products p "
                + "LEFT JOIN product_images pi ON pi.product_id = p.product_id AND pi.is_primary = 1 "
                + "LEFT JOIN ( "
                + "    SELECT product_id, price AS cheapest_price, price AS original_price, variant_label, stock_quantity, "
                + "           ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY price ASC, variant_id ASC) as rn "
                + "    FROM product_variants "
                + "    WHERE is_active = 1 AND stock_quantity > 0 "
                + ") pv ON pv.product_id = p.product_id AND pv.rn = 1 "
                + "CROSS APPLY (SELECT TOP 1 pr.discount_type, pr.discount_value, pr.discount_max, pr.valid_until "
                + "    FROM promotions pr WHERE pr.product_id = p.product_id "
                + "    AND pr.scope = 'PRODUCT' AND pr.is_active = 1 AND pr.is_deleted = 0 "
                + "    AND pr.valid_from <= GETDATE() AND pr.valid_until >= GETDATE() "
                + "    ORDER BY pr.discount_value DESC, pr.promo_id DESC) pr "
                + "WHERE " + buildPublicVisibilityClause("p") + " "
                + "  AND pv.product_id IS NOT NULL "
                + "ORDER BY p.product_id DESC";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql);
                ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                list.add(mapRowToProductMap(rs, contextPath));
            }
        }
        return list;
    }

    public List<Map<String, Object>> findBestSellersOptimized(int limit, String contextPath) throws SQLException {
        List<Map<String, Object>> list = new ArrayList<>();
        String sql = "SELECT TOP (?) p.product_id, p.name, p.description, p.rating, p.sold_quantity, "
                + "       pi.file_path AS primary_image_path, "
                + "       pv.cheapest_price, pv.original_price, pv.variant_label AS cheapest_unit, pv.stock_quantity AS cheapest_stock, "
                + "       pr.discount_type, pr.discount_value, pr.discount_max, pr.valid_until "
                + "FROM products p "
                + "LEFT JOIN product_images pi ON pi.product_id = p.product_id AND pi.is_primary = 1 "
                + "LEFT JOIN ( "
                + "    SELECT product_id, price AS cheapest_price, price AS original_price, variant_label, stock_quantity, "
                + "           ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY price ASC, variant_id ASC) as rn "
                + "    FROM product_variants "
                + "    WHERE is_active = 1 AND stock_quantity > 0 "
                + ") pv ON pv.product_id = p.product_id AND pv.rn = 1 "
                + "LEFT JOIN promotions pr ON pr.product_id = p.product_id "
                + "    AND pr.scope = 'PRODUCT' AND pr.is_active = 1 AND pr.is_deleted = 0 "
                + "    AND pr.valid_from <= GETDATE() AND pr.valid_until >= GETDATE() "
                + "WHERE " + buildPublicVisibilityClause("p") + " AND pv.product_id IS NOT NULL "
                + "ORDER BY p.sold_quantity DESC, p.product_id DESC";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRowToProductMap(rs, contextPath));
                }
            }
        }
        return list;
    }

    public List<Map<String, Object>> findSeasonalProductsOptimized(int limit, String contextPath) throws SQLException {
        List<Map<String, Object>> list = new ArrayList<>();
        String sql = "SELECT TOP (?) p.product_id, p.name, p.description, p.rating, p.sold_quantity, "
                + "       pi.file_path AS primary_image_path, "
                + "       pv.cheapest_price, pv.original_price, pv.variant_label AS cheapest_unit, pv.stock_quantity AS cheapest_stock, "
                + "       pr.discount_type, pr.discount_value, pr.discount_max, pr.valid_until "
                + "FROM products p "
                + "LEFT JOIN product_images pi ON pi.product_id = p.product_id AND pi.is_primary = 1 "
                + "LEFT JOIN ( "
                + "    SELECT product_id, price AS cheapest_price, price AS original_price, variant_label, stock_quantity, "
                + "           ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY price ASC, variant_id ASC) as rn "
                + "    FROM product_variants "
                + "    WHERE is_active = 1 AND stock_quantity > 0 "
                + ") pv ON pv.product_id = p.product_id AND pv.rn = 1 "
                + "LEFT JOIN promotions pr ON pr.product_id = p.product_id "
                + "    AND pr.scope = 'PRODUCT' AND pr.is_active = 1 AND pr.is_deleted = 0 "
                + "    AND pr.valid_from <= GETDATE() AND pr.valid_until >= GETDATE() "
                + "WHERE " + buildPublicVisibilityClause("p") + " AND pv.product_id IS NOT NULL "
                + "ORDER BY p.rating DESC, p.product_id DESC";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRowToProductMap(rs, contextPath));
                }
            }
        }
        return list;
    }

    public List<Map<String, Object>> findOrganicProductsOptimized(int limit, String contextPath) throws SQLException {
        List<Map<String, Object>> list = new ArrayList<>();
        String sql = "SELECT TOP (?) p.product_id, p.name, p.description, p.rating, p.sold_quantity, "
                + "       pi.file_path AS primary_image_path, "
                + "       pv.cheapest_price, pv.original_price, pv.variant_label AS cheapest_unit, pv.stock_quantity AS cheapest_stock, "
                + "       pr.discount_type, pr.discount_value, pr.discount_max, pr.valid_until "
                + "FROM products p "
                + "LEFT JOIN product_images pi ON pi.product_id = p.product_id AND pi.is_primary = 1 "
                + "LEFT JOIN ( "
                + "    SELECT product_id, price AS cheapest_price, price AS original_price, variant_label, stock_quantity, "
                + "           ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY price ASC, variant_id ASC) as rn "
                + "    FROM product_variants "
                + "    WHERE is_active = 1 AND stock_quantity > 0 "
                + ") pv ON pv.product_id = p.product_id AND pv.rn = 1 "
                + "LEFT JOIN promotions pr ON pr.product_id = p.product_id "
                + "    AND pr.scope = 'PRODUCT' AND pr.is_active = 1 AND pr.is_deleted = 0 "
                + "    AND pr.valid_from <= GETDATE() AND pr.valid_until >= GETDATE() "
                + "WHERE " + buildPublicVisibilityClause("p") + " AND p.is_organic = 1 AND pv.product_id IS NOT NULL "
                + "ORDER BY p.sold_quantity DESC, p.product_id DESC";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRowToProductMap(rs, contextPath));
                }
            }
        }
        return list;
    }

    public List<Map<String, Object>> findImportedProductsOptimized(int limit, String contextPath) throws SQLException {
        List<Map<String, Object>> list = new ArrayList<>();
        String sql = "SELECT TOP (?) p.product_id, p.name, p.description, p.rating, p.sold_quantity, "
                + "       pi.file_path AS primary_image_path, "
                + "       pv.cheapest_price, pv.original_price, pv.variant_label AS cheapest_unit, pv.stock_quantity AS cheapest_stock, "
                + "       pr.discount_type, pr.discount_value, pr.discount_max, pr.valid_until "
                + "FROM products p "
                + "LEFT JOIN product_images pi ON pi.product_id = p.product_id AND pi.is_primary = 1 "
                + "LEFT JOIN ( "
                + "    SELECT product_id, price AS cheapest_price, price AS original_price, variant_label, stock_quantity, "
                + "           ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY price ASC, variant_id ASC) as rn "
                + "    FROM product_variants "
                + "    WHERE is_active = 1 AND stock_quantity > 0 "
                + ") pv ON pv.product_id = p.product_id AND pv.rn = 1 "
                + "LEFT JOIN promotions pr ON pr.product_id = p.product_id "
                + "    AND pr.scope = 'PRODUCT' AND pr.is_active = 1 AND pr.is_deleted = 0 "
                + "    AND pr.valid_from <= GETDATE() AND pr.valid_until >= GETDATE() "
                + "WHERE " + buildPublicVisibilityClause("p") + " AND p.is_imported = 1 AND pv.product_id IS NOT NULL "
                + "ORDER BY p.sold_quantity DESC, p.product_id DESC";
        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRowToProductMap(rs, contextPath));
                }
            }
        }
        return list;
    }

    public List<Map<String, Object>> searchProductsOptimized(String keyword, Integer categoryId, int page, int pageSize,
            String contextPath) throws SQLException {
        List<Map<String, Object>> list = new ArrayList<>();
        int offset = (page - 1) * pageSize;
        SearchTerms searchTerms = prepareSearchTerms(keyword);
        String searchBlob = buildSearchBlob("p", "c");

        StringBuilder sql = new StringBuilder();
        sql.append("SELECT p.product_id, p.name, p.description, p.rating, p.sold_quantity, ");
        sql.append("       pi.file_path AS primary_image_path, ");
        sql.append(
                "       pv.cheapest_price, pv.original_price, pv.variant_label AS cheapest_unit, pv.stock_quantity AS cheapest_stock, ");
        sql.append("       pr.discount_type, pr.discount_value, pr.discount_max, pr.valid_until ");
        sql.append("FROM products p ");
        sql.append("JOIN ( ");
        sql.append("    SELECT p.product_id");
        if (searchTerms.hasKeyword()) {
            sql.append(", sr.relevance_score ");
        }
        sql.append("    FROM products p ");
        sql.append("    LEFT JOIN categories c ON c.category_id = p.category_id ");
        sql.append(buildSearchRankJoin(searchBlob, searchTerms));
        sql.append("    WHERE ").append(buildPublicVisibilityClause("p")).append(" ");
        sql.append("      AND ").append(buildActiveStockExistsClause("p")).append(" ");

        List<Object> params = new ArrayList<>();
        if (searchTerms.hasKeyword()) {
            bindSearchParameters(params, searchTerms);
            sql.append("      AND sr.relevance_score >= ? ");
            params.add(getSearchRelevanceThreshold(searchTerms));
        }
        if (categoryId != null) {
            sql.append("    AND p.category_id = ? ");
            params.add(categoryId);
        }

        if (searchTerms.hasKeyword()) {
            sql.append("    ORDER BY sr.relevance_score DESC, p.product_id DESC ");
        } else {
            sql.append("    ORDER BY p.product_id DESC ");
        }
        sql.append("    OFFSET ? ROWS FETCH NEXT ? ROWS ONLY ");
        sql.append(") temp ON p.product_id = temp.product_id ");
        sql.append("LEFT JOIN product_images pi ON pi.product_id = p.product_id AND pi.is_primary = 1 ");
        sql.append("LEFT JOIN ( ");
        sql.append("    SELECT product_id, variant_label, stock_quantity, ");
        sql.append("           CASE ");
        sql.append(
                "               WHEN discount_price IS NOT NULL AND discount_start IS NOT NULL AND discount_end IS NOT NULL AND GETDATE() BETWEEN discount_start AND discount_end ");
        sql.append("               THEN discount_price ");
        sql.append("               ELSE price ");
        sql.append("           END AS cheapest_price, ");
        sql.append("           price AS original_price, ");
        sql.append("           ROW_NUMBER() OVER ( ");
        sql.append("               PARTITION BY product_id ");
        sql.append("               ORDER BY CASE ");
        sql.append(
                "                   WHEN discount_price IS NOT NULL AND discount_start IS NOT NULL AND discount_end IS NOT NULL AND GETDATE() BETWEEN discount_start AND discount_end ");
        sql.append("                   THEN discount_price ");
        sql.append("                   ELSE price ");
        sql.append("               END ASC, variant_id ASC ");
        // Clean up ending
        sql.append("           ) as rn ");
        sql.append("    FROM product_variants ");
        sql.append("    WHERE is_active = 1 AND stock_quantity > 0 ");
        sql.append(") pv ON pv.product_id = p.product_id AND pv.rn = 1 ");
        sql.append("LEFT JOIN promotions pr ON pr.product_id = p.product_id ");
        sql.append("    AND pr.scope = 'PRODUCT' AND pr.is_active = 1 AND pr.is_deleted = 0 ");
        sql.append("    AND pr.valid_from <= GETDATE() AND pr.valid_until >= GETDATE() ");
        if (searchTerms.hasKeyword()) {
            sql.append("ORDER BY temp.relevance_score DESC, p.product_id DESC");
        } else {
            sql.append("ORDER BY p.product_id DESC");
        }

        params.add(offset);
        params.add(pageSize);

        try (Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRowToProductMap(rs, contextPath));
                }
            }
        }
        return list;
    }
}
