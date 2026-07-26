package dao.cart;

import dao.system.BaseDAO;
import model.entity.cart.Cart;
import model.entity.cart.CartItem;
import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;

/**
 * CartDAO — DAO cho entity Cart.
 *
 * QUY TẮC:
 *   - Chỉ chứa SQL, không chứa business logic
 *   - Dùng PreparedStatement, KHÔNG nối chuỗi SQL
 *   - Mỗi method ném SQLException để Service xử lý
 *   - Dùng try-with-resources cho Connection + PreparedStatement
 *
 * @author fruitmkt-team
 */
public class CartDAO extends BaseDAO {

    /**
     * Tìm giỏ hàng theo ID khách hàng.
     */
    public List<Cart> findByCustomer(int customerId) throws SQLException {
        List<Cart> list = new ArrayList<>();
        String sql = "SELECT * FROM cart WHERE customer_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, customerId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    /**
     * Tạo giỏ hàng mới cho khách hàng và trả về cart_id tự sinh.
     */
    public int createForCustomer(int customerId) throws SQLException {
        String sql = "INSERT INTO cart (customer_id, created_at, updated_at) VALUES (?, GETDATE(), GETDATE())";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, customerId);
            ps.executeUpdate();
            try (ResultSet rs = ps.getGeneratedKeys()) {
                if (rs.next()) {
                    return rs.getInt(1);
                }
            }
        }
        throw new SQLException("Tạo giỏ hàng thất bại, không lấy được mã khóa tự tăng.");
    }

    public Cart addItem(int cartId, int variantId, int quantity) throws SQLException {
        return addItem(cartId, variantId, quantity, null);
    }

    /**
     * Thêm sản phẩm vào giỏ (cộng dồn nếu đã có dòng cùng variant + packaging).
     *
     * <p>SELECT + INSERT/UPDATE + touch được bọc trong MỘT transaction để chống TOCTOU:
     * gợi ý khóa {@code WITH (UPDLOCK, HOLDLOCK)} tạo key-range lock theo
     * (cart_id, variant_id, packaging_id), nên hai request thêm cùng lúc sẽ tuần tự hóa —
     * tránh tạo dòng trùng hoặc mất cập nhật số lượng.</p>
     */
    public Cart addItem(int cartId, int variantId, int quantity, Integer packagingId) throws SQLException {
        String selectSql = packagingId != null
                ? "SELECT cart_item_id, quantity FROM cart_items WITH (UPDLOCK, HOLDLOCK) WHERE cart_id = ? AND variant_id = ? AND packaging_id = ?"
                : "SELECT cart_item_id, quantity FROM cart_items WITH (UPDLOCK, HOLDLOCK) WHERE cart_id = ? AND variant_id = ? AND packaging_id IS NULL";
        String insertSql = "INSERT INTO cart_items (cart_id, variant_id, quantity, packaging_id, added_at) VALUES (?, ?, ?, ?, GETDATE())";
        String updateSql = "UPDATE cart_items SET quantity = ? WHERE cart_item_id = ?";
        String touchSql = "UPDATE cart SET updated_at = GETDATE() WHERE cart_id = ?";

        try (Connection conn = getConnection()) {
            conn.setAutoCommit(false);
            try {
                int existingCartItemId = -1;
                int existingQuantity = 0;
                try (PreparedStatement ps = conn.prepareStatement(selectSql)) {
                    ps.setInt(1, cartId);
                    ps.setInt(2, variantId);
                    if (packagingId != null) {
                        ps.setInt(3, packagingId);
                    }
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            existingCartItemId = rs.getInt("cart_item_id");
                            existingQuantity = rs.getInt("quantity");
                        }
                    }
                }

                if (existingCartItemId != -1) {
                    try (PreparedStatement ps = conn.prepareStatement(updateSql)) {
                        ps.setInt(1, existingQuantity + quantity);
                        ps.setInt(2, existingCartItemId);
                        ps.executeUpdate();
                    }
                } else {
                    try (PreparedStatement ps = conn.prepareStatement(insertSql)) {
                        ps.setInt(1, cartId);
                        ps.setInt(2, variantId);
                        ps.setInt(3, quantity);
                        if (packagingId != null) {
                            ps.setInt(4, packagingId);
                        } else {
                            ps.setNull(4, Types.INTEGER);
                        }
                        ps.executeUpdate();
                    }
                }

                try (PreparedStatement ps = conn.prepareStatement(touchSql)) {
                    ps.setInt(1, cartId);
                    ps.executeUpdate();
                }

                conn.commit();
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            } finally {
                conn.setAutoCommit(true);
            }
        }
        return findCartById(cartId);
    }

    /**
     * Cập nhật số lượng sản phẩm trong giỏ hàng.
     */
    public void updateItemQuantity(int cartItemId, int quantity) throws SQLException {
        String sql = "UPDATE cart_items SET quantity = ? WHERE cart_item_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, quantity);
            ps.setInt(2, cartItemId);
            ps.executeUpdate();
            
            int cartId = findCartIdByItemId(cartItemId);
            if (cartId != -1) {
                touchCart(cartId);
            }
        }
    }

    public void updateItemVariant(int cartItemId, int newVariantId) throws SQLException {
        String sql = "UPDATE cart_items SET variant_id = ? WHERE cart_item_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, newVariantId);
            ps.setInt(2, cartItemId);
            ps.executeUpdate();
            
            int cartId = findCartIdByItemId(cartItemId);
            if (cartId != -1) {
                touchCart(cartId);
            }
        }
    }

    /**
     * Xóa sản phẩm khỏi giỏ hàng.
     */
    public Cart removeItem(int cartItemId) throws SQLException {
        int cartId = findCartIdByItemId(cartItemId);
        if (cartId != -1) {
            String sql = "DELETE FROM cart_items WHERE cart_item_id = ?";
            try (Connection conn = getConnection();
                 PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setInt(1, cartItemId);
                ps.executeUpdate();
            }
            touchCart(cartId);
            return findCartById(cartId);
        }
        return null;
    }

    /**
     * Xóa sạch toàn bộ sản phẩm trong giỏ hàng.
     */
    public Cart clearCart(int cartId) throws SQLException {
        String sql = "DELETE FROM cart_items WHERE cart_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, cartId);
            ps.executeUpdate();
        }
        touchCart(cartId);
        return findCartById(cartId);
    }

    public void deleteItemsByCustomer(Connection conn, int customerId, List<Integer> variantIds) throws SQLException {
        if (variantIds == null || variantIds.isEmpty()) {
            return;
        }
        StringBuilder sql = new StringBuilder(
                "DELETE FROM cart_items WHERE cart_id = (SELECT cart_id FROM cart WHERE customer_id = ?) AND variant_id IN (");
        for (int i = 0; i < variantIds.size(); i++) {
            sql.append("?");
            if (i < variantIds.size() - 1) {
                sql.append(",");
            }
        }
        sql.append(")");
        try (PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            ps.setInt(1, customerId);
            for (int i = 0; i < variantIds.size(); i++) {
                ps.setInt(i + 2, variantIds.get(i));
            }
            ps.executeUpdate();
        }
    }

    public void deleteItemsByCustomerByCartItemIds(Connection conn, int customerId, List<Integer> cartItemIds) throws SQLException {
        if (cartItemIds == null || cartItemIds.isEmpty()) {
            return;
        }
        StringBuilder sql = new StringBuilder(
                "DELETE FROM cart_items WHERE cart_id = (SELECT cart_id FROM cart WHERE customer_id = ?) AND cart_item_id IN (");
        for (int i = 0; i < cartItemIds.size(); i++) {
            sql.append("?");
            if (i < cartItemIds.size() - 1) {
                sql.append(",");
            }
        }
        sql.append(")");
        try (PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            ps.setInt(1, customerId);
            for (int i = 0; i < cartItemIds.size(); i++) {
                ps.setInt(i + 2, cartItemIds.get(i));
            }
            ps.executeUpdate();
        }
    }

    /**
     * Lấy danh sách sản phẩm trong giỏ hàng.
     */
    public List<CartItem> findItems(int cartId) throws SQLException {
        List<CartItem> list = new ArrayList<>();
        String sql = "SELECT ci.*, pv.variant_label, pv.price, pv.stock_quantity, pv.weight_kg, pv.product_id, p.name AS product_name, pi.file_path AS image_path, "
                   + "ppo.label AS packaging_label, ppo.price_add AS packaging_price_add, "
                   + "pv.discount_price, pv.discount_start, pv.discount_end, "
                   + "p.owner_id AS shop_id, sop.shop_name "
                   + "FROM cart_items ci "
                   + "JOIN product_variants pv ON ci.variant_id = pv.variant_id "
                   + "JOIN products p ON pv.product_id = p.product_id "
                   + "LEFT JOIN shop_owner_profiles sop ON p.owner_id = sop.user_id "
                   + "LEFT JOIN product_images pi ON p.product_id = pi.product_id AND pi.is_primary = 1 "
                   + "LEFT JOIN product_packaging_options ppo ON ci.packaging_id = ppo.packaging_id AND ppo.product_id = pv.product_id "
                   + "WHERE ci.cart_id = ? ORDER BY ci.added_at DESC";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, cartId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapCartItemRowWithDetails(rs));
                }
            }
        }
        return list;
    }

    private Cart findCartById(int cartId) throws SQLException {
        String sql = "SELECT * FROM cart WHERE cart_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, cartId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return mapRow(rs);
                }
            }
        }
        return null;
    }

    /**
     * Tìm một CartItem theo ID.
     */
    public CartItem findItemById(int cartItemId) throws SQLException {
        String sql = "SELECT ci.*, pv.variant_label, pv.price, pv.stock_quantity, pv.weight_kg, pv.product_id, p.name AS product_name, pi.file_path AS image_path, "
                   + "ppo.label AS packaging_label, ppo.price_add AS packaging_price_add, "
                   + "pv.discount_price, pv.discount_start, pv.discount_end, "
                   + "p.owner_id AS shop_id, sop.shop_name "
                   + "FROM cart_items ci "
                   + "JOIN product_variants pv ON ci.variant_id = pv.variant_id "
                   + "JOIN products p ON pv.product_id = p.product_id "
                   + "LEFT JOIN shop_owner_profiles sop ON p.owner_id = sop.user_id "
                   + "LEFT JOIN product_images pi ON p.product_id = pi.product_id AND pi.is_primary = 1 "
                   + "LEFT JOIN product_packaging_options ppo ON ci.packaging_id = ppo.packaging_id AND ppo.product_id = pv.product_id "
                   + "WHERE ci.cart_item_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, cartItemId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return mapCartItemRowWithDetails(rs);
                }
            }
        }
        return null;
    }

    private void touchCart(int cartId) throws SQLException {
        String sql = "UPDATE cart SET updated_at = GETDATE() WHERE cart_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, cartId);
            ps.executeUpdate();
        }
    }

    private int findCartIdByItemId(int cartItemId) throws SQLException {
        String sql = "SELECT cart_id FROM cart_items WHERE cart_item_id = ?";
        try (Connection conn = getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, cartItemId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getInt("cart_id");
                }
            }
        }
        return -1;
    }

    private CartItem mapCartItemRow(ResultSet rs) throws SQLException {
        CartItem ci = new CartItem();
        ci.setCartItemId(rs.getInt("cart_item_id"));
        ci.setCartId(rs.getInt("cart_id"));
        ci.setVariantId(rs.getInt("variant_id"));
        ci.setQuantity(rs.getInt("quantity"));
        
        int pkgId = rs.getInt("packaging_id");
        ci.setPackagingId(rs.wasNull() ? null : pkgId);
        
        Timestamp addedAtVal = rs.getTimestamp("added_at");
        if (addedAtVal != null) {
            ci.setAddedAt(addedAtVal.toLocalDateTime());
        }
        return ci;
    }

    private CartItem mapCartItemRowWithDetails(ResultSet rs) throws SQLException {
        CartItem ci = mapCartItemRow(rs);
        ci.setVariantLabel(rs.getString("variant_label"));
        
        BigDecimal price = rs.getBigDecimal("price");
        BigDecimal discountPrice = rs.getBigDecimal("discount_price");
        Timestamp discountStartVal = rs.getTimestamp("discount_start");
        Timestamp discountEndVal = rs.getTimestamp("discount_end");
        
        BigDecimal activePrice = price;
        if (discountPrice != null && discountStartVal != null && discountEndVal != null) {
            java.time.LocalDateTime now = java.time.LocalDateTime.now();
            java.time.LocalDateTime discountStart = discountStartVal.toLocalDateTime();
            java.time.LocalDateTime discountEnd = discountEndVal.toLocalDateTime();
            if ((now.isAfter(discountStart) || now.isEqual(discountStart)) && 
                (now.isBefore(discountEnd) || now.isEqual(discountEnd))) {
                activePrice = discountPrice;
            }
        }
        ci.setPrice(activePrice);
        ci.setBasePrice(price);
        
        ci.setStockQuantity(rs.getInt("stock_quantity"));
        ci.setWeightKg(rs.getBigDecimal("weight_kg"));
        ci.setProductName(rs.getString("product_name"));
        ci.setImagePath(rs.getString("image_path"));
        ci.setProductId(rs.getInt("product_id"));
        ci.setShopId(rs.getInt("shop_id"));
        String shopName = rs.getString("shop_name");
        ci.setShopName(shopName != null ? shopName.trim() : "Cửa hàng");
        ci.setPackagingLabel(rs.getString("packaging_label"));
        ci.setPackagingPriceAdd(rs.getBigDecimal("packaging_price_add"));
        return ci;
    }

    /**
     * Ghi đè toàn bộ items của giỏ hàng (phục vụ Beacon API Unload sync).
     * Chạy trong Single DB Transaction.
     */
    public void replaceCartItems(int cartId, List<CartItem> items) throws SQLException {
        String deleteSql = "DELETE FROM cart_items WHERE cart_id = ?";
        String insertSql = "INSERT INTO cart_items (cart_id, variant_id, quantity, packaging_id, added_at) VALUES (?, ?, ?, ?, GETDATE())";
        
        try (Connection conn = getConnection()) {
            conn.setAutoCommit(false);
            try {
                // 1. Xóa sạch items cũ
                try (PreparedStatement psDelete = conn.prepareStatement(deleteSql)) {
                    psDelete.setInt(1, cartId);
                    psDelete.executeUpdate();
                }
                
                // 2. Insert items mới
                if (items != null && !items.isEmpty()) {
                    try (PreparedStatement psInsert = conn.prepareStatement(insertSql)) {
                        for (CartItem item : items) {
                            psInsert.setInt(1, cartId);
                            psInsert.setInt(2, item.getVariantId());
                            psInsert.setInt(3, item.getQuantity());
                            if (item.getPackagingId() != null) {
                                psInsert.setInt(4, item.getPackagingId());
                            } else {
                                psInsert.setNull(4, Types.INTEGER);
                            }
                            psInsert.addBatch();
                        }
                        psInsert.executeBatch();
                    }
                }
                
                // 3. Touch updated_at của Cart
                String touchSql = "UPDATE cart SET updated_at = GETDATE() WHERE cart_id = ?";
                try (PreparedStatement psTouch = conn.prepareStatement(touchSql)) {
                    psTouch.setInt(1, cartId);
                    psTouch.executeUpdate();
                }
                
                conn.commit();
            } catch (SQLException e) {
                conn.rollback();
                throw e;
            } finally {
                conn.setAutoCommit(true);
            }
        }
    }

    /** Ánh xạ ResultSet -> Cart — gọi trong mọi query SELECT */
    private Cart mapRow(ResultSet rs) throws SQLException {
        Cart c = new Cart();
        c.setCartId(rs.getInt("cart_id"));
        c.setCustomerId(rs.getInt("customer_id"));
        
        Timestamp createdAtVal = rs.getTimestamp("created_at");
        if (createdAtVal != null) {
            c.setCreatedAt(createdAtVal.toLocalDateTime());
        }
        
        Timestamp updatedAtVal = rs.getTimestamp("updated_at");
        if (updatedAtVal != null) {
            c.setUpdatedAt(updatedAtVal.toLocalDateTime());
        }
        return c;
    }
}
