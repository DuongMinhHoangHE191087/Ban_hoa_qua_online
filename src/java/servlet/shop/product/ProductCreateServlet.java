package servlet.shop.product;
import dao.catalog.ProductPackagingOptionDAO;

import config.AppConfig;
import dao.catalog.CategoryDAO;
import dao.catalog.ProductDAO;
import dao.catalog.ProductImageDAO;
import dao.catalog.ProductVariantDAO;
import model.entity.catalog.Category;
import model.entity.catalog.Product;
import model.entity.catalog.ProductImage;
import model.entity.catalog.ProductVariant;
import model.entity.auth.User;
import model.response.ApiResponse;
import util.SessionUtil;
import util.FileUploadUtil;

import util.LoggerUtil;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import jakarta.servlet.http.Part;
import java.io.IOException;
import java.math.BigDecimal;
import java.util.logging.Logger;
import java.sql.SQLException;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;
import util.ErrorMessageUtil;

/**
 * ProductCreateServlet — Servlet xử lý thêm mới sản phẩm và upload ảnh cho shop
 URL: /shop/product-create
 */
@WebServlet("/shop/product-create")
@MultipartConfig(
    fileSizeThreshold = 1024 * 1024 * 2, // 2MB
    maxFileSize = AppConfig.MAX_UPLOAD_SIZE_BYTES * 5, // 25MB
    maxRequestSize = AppConfig.MAX_UPLOAD_SIZE_BYTES * 10 // 50MB
)//upload file
public class ProductCreateServlet extends HttpServlet {

    // Khởi tạo Logger để ghi lại nhật ký hoạt động (log) của class này thay cho System.out.println
    private static final Logger log = Logger.getLogger(ProductCreateServlet.class.getName());

    private final ProductDAO productDAO = new ProductDAO();
    private final CategoryDAO categoryDAO = new CategoryDAO();
    private final ProductImageDAO productImageDAO = new ProductImageDAO();
    private final ProductVariantDAO productVariantDAO = new ProductVariantDAO();
    private final dao.system.SystemConfigDAO systemConfigDAO = new dao.system.SystemConfigDAO();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        resp.sendRedirect(req.getContextPath() + "/shop/products");
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        req.setCharacterEncoding("UTF-8");
        resp.setContentType("text/html;charset=UTF-8");
        resp.setCharacterEncoding("UTF-8");

        HttpSession session = req.getSession();
        User currentUser = SessionUtil.getCurrentUser(session);
        if (currentUser == null || !AppConfig.ROLE_SHOP_OWNER.equals(currentUser.getRole())) {
            resp.sendRedirect(req.getContextPath() + "/auth/login");
            return;
        }

        // 1. Đọc các trường thông tin
        String name = req.getParameter("name");
        String description = req.getParameter("description");
        String originCountry = req.getParameter("originCountry");
        String originRegion = req.getParameter("originRegion");
        String harvestDateStr = req.getParameter("harvestDate");
        String shelfLifeStr = req.getParameter("shelfLifeDays");
        String storageInstruction = req.getParameter("storageInstruction");
        String categoryIdStr = req.getParameter("categoryId");
        
        boolean isOrganic = req.getParameter("isOrganic") != null;
        boolean isImported = req.getParameter("isImported") != null;
        String seasonStartMonthStr = req.getParameter("seasonStartMonth");
        String seasonEndMonthStr = req.getParameter("seasonEndMonth");
        
        // Đọc danh sách biến thể
        String[] variantLabels = req.getParameterValues("variantLabel");
        String[] variantPrices = req.getParameterValues("variantPrice");
        String[] variantStocks = req.getParameterValues("variantStock");
        String[] variantWeights = req.getParameterValues("variantWeight");
        String[] variantDiscountPrices = req.getParameterValues("variantDiscountPrice");
        String[] variantDiscountStarts = req.getParameterValues("variantDiscountStart");
        String[] variantDiscountEnds = req.getParameterValues("variantDiscountEnd");

        // Đọc danh sách đóng gói chọn thêm
        String[] packagingLabels = req.getParameterValues("packagingLabel");
        String[] packagingPriceAdds = req.getParameterValues("packagingPriceAdd");

        // Giữ lại giá trị cũ phòng khi validate thất bại
        req.setAttribute("oldName", name);
        req.setAttribute("oldDescription", description);
        req.setAttribute("oldOriginCountry", originCountry);
        req.setAttribute("oldOriginRegion", originRegion);
        req.setAttribute("oldHarvestDate", harvestDateStr);
        req.setAttribute("oldShelfLife", shelfLifeStr);
        req.setAttribute("oldStorageInstruction", storageInstruction);
        req.setAttribute("oldCategoryId", categoryIdStr);

        List<String> errors = new ArrayList<>();

        // 2. Validate dữ liệu cơ bản
        if (name == null || name.trim().isEmpty()) {
            errors.add("Tên sản phẩm không được để trống.");
        }

        int categoryId = 0;
        try {
            categoryId = Integer.parseInt(categoryIdStr);
        } catch (NumberFormatException e) {
            errors.add("Vui lòng chọn danh mục hợp lệ.");
        }

        // Validate danh sách biến thể
        if (variantLabels == null || variantLabels.length == 0) {
            errors.add("Sản phẩm phải có ít nhất một phân loại/biến thể.");
        } else {
            java.time.LocalDateTime now = java.time.LocalDateTime.now();
            for (int i = 0; i < variantLabels.length; i++) {
                String label = variantLabels[i];
                if (label == null || label.trim().isEmpty()) {
                    errors.add("Tên phân loại tại vị trí thứ " + (i + 1) + " không được để trống.");
                }
                
                String pStr = (variantPrices != null && variantPrices.length > i) ? variantPrices[i] : null;
                BigDecimal price = BigDecimal.ZERO;
                boolean isPriceValid = false;
                try {
                    price = new BigDecimal(pStr);
                    if (price.compareTo(BigDecimal.ZERO) <= 0) {
                        errors.add("Giá bán phân loại '" + (label != null ? label : "") + "' phải lớn hơn 0.");
                    } else {
                        isPriceValid = true;
                    }
                } catch (Exception e) {
                    errors.add("Giá bán phân loại '" + (label != null ? label : "") + "' không đúng định dạng số.");
                }

                String dpStr = (variantDiscountPrices != null && variantDiscountPrices.length > i) ? variantDiscountPrices[i] : null;
                String dsStr = (variantDiscountStarts != null && variantDiscountStarts.length > i) ? variantDiscountStarts[i] : null;
                String deStr = (variantDiscountEnds != null && variantDiscountEnds.length > i) ? variantDiscountEnds[i] : null;

                boolean hasDiscountPrice = dpStr != null && !dpStr.trim().isEmpty();
                boolean hasDiscountStart = dsStr != null && !dsStr.trim().isEmpty();
                boolean hasDiscountEnd = deStr != null && !deStr.trim().isEmpty();

                if (hasDiscountPrice || hasDiscountStart || hasDiscountEnd) {
                    if (!hasDiscountPrice || !hasDiscountStart || !hasDiscountEnd) {
                        errors.add("Phân loại '" + (label != null ? label : "") + "' cấu hình giảm giá phải điền đầy đủ cả giá khuyến mãi, ngày bắt đầu và ngày kết thúc.");
                    } else {
                        BigDecimal discPrice = BigDecimal.ZERO;
                        boolean isDiscPriceValid = false;
                        try {
                            discPrice = new BigDecimal(dpStr.trim());
                            if (discPrice.compareTo(BigDecimal.ZERO) < 0) {
                                errors.add("Giá khuyến mãi của phân loại '" + (label != null ? label : "") + "' không được âm.");
                            } else if (isPriceValid && discPrice.compareTo(price) >= 0) {
                                errors.add("Giá khuyến mãi của phân loại '" + (label != null ? label : "") + "' phải nhỏ hơn giá gốc.");
                            } else {
                                isDiscPriceValid = true;
                            }
                        } catch (Exception e) {
                            errors.add("Giá khuyến mãi của phân loại '" + (label != null ? label : "") + "' không đúng định dạng số.");
                        }

                        java.time.LocalDateTime vDiscStart = null;
                        java.time.LocalDateTime vDiscEnd = null;
                        try {
                            vDiscStart = java.time.LocalDateTime.parse(dsStr.trim());
                        } catch (Exception e) {
                            errors.add("Ngày bắt đầu giảm giá của phân loại '" + (label != null ? label : "") + "' không đúng định dạng.");
                        }

                        try {
                            vDiscEnd = java.time.LocalDateTime.parse(deStr.trim());
                        } catch (Exception e) {
                            errors.add("Ngày kết thúc giảm giá của phân loại '" + (label != null ? label : "") + "' không đúng định dạng.");
                        }

                        if (vDiscStart != null && vDiscEnd != null) {
                            // Cho phép trễ tối đa 5 phút để tránh lệch giờ client-server
                            if (vDiscStart.isBefore(now.minusMinutes(5))) {
                                errors.add("Ngày bắt đầu giảm giá của phân loại '" + (label != null ? label : "") + "' không được ở trong quá khứ.");
                            }
                            if (vDiscEnd.isBefore(now.minusMinutes(5))) {
                                errors.add("Ngày kết thúc giảm giá của phân loại '" + (label != null ? label : "") + "' không được ở trong quá khứ.");
                            }
                            if (!vDiscEnd.isAfter(vDiscStart)) {
                                errors.add("Ngày kết thúc giảm giá của phân loại '" + (label != null ? label : "") + "' phải sau ngày bắt đầu.");
                            }
                        }
                    }
                }
            }
        }

        if (originCountry == null || originCountry.trim().isEmpty()) {
            errors.add("Quốc gia là bắt buộc.");
        }
        if (originRegion == null || originRegion.trim().isEmpty()) {
            errors.add("Vùng sản xuất là bắt buộc.");
        }

        LocalDate harvestDate = null;
        if (harvestDateStr == null || harvestDateStr.trim().isEmpty()) {
            errors.add("Ngày thu hoạch là bắt buộc.");
        } else {
            try {
                harvestDate = LocalDate.parse(harvestDateStr);
                if (harvestDate.isAfter(LocalDate.now())) {
                    errors.add("Ngày thu hoạch không được vượt quá ngày hiện tại.");
                }
            } catch (DateTimeParseException e) {
                errors.add("Ngày thu hoạch không đúng định dạng YYYY-MM-DD.");
            }
        }

        Integer shelfLifeDays = null;
        if (shelfLifeStr == null || shelfLifeStr.trim().isEmpty()) {
            errors.add("Hạn sử dụng (Số ngày) là bắt buộc.");
        } else {
            try {
                shelfLifeDays = Integer.parseInt(shelfLifeStr);
                if (shelfLifeDays <= 0) {
                    errors.add("Hạn sử dụng phải lớn hơn 0 ngày.");
                }
            } catch (NumberFormatException e) {
                errors.add("Hạn sử dụng phải là số ngày (nguyên dương).");
            }
        }

        // 3. Validate file ảnh trước khi ghi xuống đĩa
        List<Part> imageParts = new ArrayList<>();
        Part verificationDocPart = null;
        try {
            verificationDocPart = req.getPart("verificationDoc");
            if (verificationDocPart != null && verificationDocPart.getSize() > 0) {
                String filename = verificationDocPart.getSubmittedFileName();
                if (!FileUploadUtil.isAllowedDoc(filename)) {
                    errors.add("Giấy tờ xác nhận nông sản không đúng định dạng (chỉ hỗ trợ: pdf, jpg, jpeg, png, docx).");
                }
            } else {
                errors.add("Vui lòng tải lên giấy tờ xác nhận nông sản sạch/hữu cơ/nhập khẩu.");
            }
            
            for (Part part : req.getParts()) {
                if ("images".equals(part.getName()) && part.getSize() > 0) {
                    String filename = part.getSubmittedFileName();
                    if (filename != null && !filename.trim().isEmpty()) {
                        if (!FileUploadUtil.isAllowedImage(filename)) {
                            errors.add("Tệp tin '" + filename + "' không phải là định dạng ảnh được phép (chỉ hỗ trợ: jpg, jpeg, png, webp).");
                        } else {
                            imageParts.add(part);
                        }
                    }
                }
            }
        } catch (Exception e) {
            errors.add(ErrorMessageUtil.MSG_FILE_ERROR);
        }

        // 4. Nếu có lỗi, chuyển ngược lại form
        if (!errors.isEmpty()) {
            if ("XMLHttpRequest".equalsIgnoreCase(req.getHeader("X-Requested-With"))) {
                util.JsonUtil.writeJson(resp, ApiResponse.ok(java.util.Map.of("errors", errors)));
                return;
            }
            SessionUtil.flashError(session, String.join("<br>", errors));
            resp.sendRedirect(req.getContextPath() + "/shop/products");
            return;
        }

        // 5. Lưu thông tin vào Database
        try {
            String uploadDir = getServletContext().getRealPath("");
            String docPath = FileUploadUtil.saveShopDoc(verificationDocPart, uploadDir, currentUser.getUserId());

            Product p = new Product();
            p.setOwnerId(currentUser.getUserId());
            p.setCategoryId(categoryId);
            p.setName(name.trim());
            p.setDescription(description != null ? description.trim() : null);
            p.setOriginCountry(originCountry != null ? originCountry.trim() : null);
            p.setOriginRegion(originRegion != null ? originRegion.trim() : null);
            p.setHarvestDate(harvestDate);
            p.setShelfLifeDays(shelfLifeDays);
            p.setStorageInstruction(storageInstruction != null ? storageInstruction.trim() : null);
            p.setStatus("ACTIVE");
            p.setIsOrganic(isOrganic);
            p.setIsImported(isImported);
            
            String autoApproveVal = null;
            try {
                autoApproveVal = systemConfigDAO.getValue("product_auto_approve");
            } catch (Exception ex) {
                LoggerUtil.warn(log, "Không thể đọc cấu hình product_auto_approve", ex);
            }
            boolean isAutoApprove = "true".equalsIgnoreCase(autoApproveVal);
            p.setApprovalStatus(isAutoApprove ? "APPROVED" : "PENDING");
            
            p.setVerificationDocPath(docPath);
            
            try {
                if (seasonStartMonthStr != null && !seasonStartMonthStr.trim().isEmpty()) {
                    p.setSeasonStartMonth(Integer.parseInt(seasonStartMonthStr.trim()));
                }
                if (seasonEndMonthStr != null && !seasonEndMonthStr.trim().isEmpty()) {
                    p.setSeasonEndMonth(Integer.parseInt(seasonEndMonthStr.trim()));
                }
            } catch (NumberFormatException e) {
                LoggerUtil.warn(log, "Tháng mùa vụ không hợp lệ", e);
            }

            // Lưu sản phẩm và nhận ID tự sinh
            int productId = productDAO.save(p);

            // Lưu hình ảnh sản phẩm
            int imageIndex = 0;
            for (Part part : imageParts) {
                String relativePath = FileUploadUtil.save(part, uploadDir);
                if (relativePath != null) {
                    ProductImage img = new ProductImage();
                    img.setProductId(productId);
                    img.setFilePath(relativePath);
                    img.setDisplayOrder(imageIndex);
                    img.setIsPrimary(imageIndex == 0);
                    productImageDAO.save(img);
                    imageIndex++;
                }
            }

            // Lưu danh sách các biến thể sản phẩm
            if (variantLabels != null) {
                for (int i = 0; i < variantLabels.length; i++) {
                    ProductVariant variant = new ProductVariant();
                    variant.setProductId(productId);
                    variant.setSku("SP-" + productId + "-" + (i + 1));
                    variant.setVariantLabel(variantLabels[i].trim());
                    
                    BigDecimal vPrice = BigDecimal.ZERO;
                    if (variantPrices != null && variantPrices.length > i && variantPrices[i] != null) {
                        try {
                            vPrice = new BigDecimal(variantPrices[i].trim());
                        } catch (NumberFormatException e) {
                            LoggerUtil.warn(log, "Giá biến thể không hợp lệ: " + variantPrices[i], e);
                        }
                    }
                    variant.setPrice(vPrice);
                    variant.setStockQuantity(0);

                    BigDecimal vWeight = new BigDecimal("1.000");
                    if (variantWeights != null && variantWeights.length > i && variantWeights[i] != null && !variantWeights[i].trim().isEmpty()) {
                        try {
                            vWeight = new BigDecimal(variantWeights[i].trim());
                        } catch (NumberFormatException e) {
                            LoggerUtil.warn(log, "Cân nặng biến thể không hợp lệ: " + variantWeights[i], e);
                        }
                    }
                    variant.setWeightKg(vWeight);

                    BigDecimal vDiscPrice = null;
                    if (variantDiscountPrices != null && variantDiscountPrices.length > i && variantDiscountPrices[i] != null && !variantDiscountPrices[i].trim().isEmpty()) {
                        try {
                            vDiscPrice = new BigDecimal(variantDiscountPrices[i].trim());
                        } catch (NumberFormatException e) {
                            LoggerUtil.warn(log, "Giá khuyến mãi biến thể không hợp lệ: " + variantDiscountPrices[i], e);
                        }
                    }
                    variant.setDiscountPrice(vDiscPrice);

                    java.time.LocalDateTime vDiscStart = null;
                    if (variantDiscountStarts != null && variantDiscountStarts.length > i && variantDiscountStarts[i] != null && !variantDiscountStarts[i].trim().isEmpty()) {
                        try {
                            vDiscStart = java.time.LocalDateTime.parse(variantDiscountStarts[i].trim());
                        } catch (Exception e) {
                            LoggerUtil.warn(log, "Ngày bắt đầu giảm giá không hợp lệ: " + variantDiscountStarts[i], e);
                        }
                    }
                    variant.setDiscountStart(vDiscStart);

                    java.time.LocalDateTime vDiscEnd = null;
                    if (variantDiscountEnds != null && variantDiscountEnds.length > i && variantDiscountEnds[i] != null && !variantDiscountEnds[i].trim().isEmpty()) {
                        try {
                            vDiscEnd = java.time.LocalDateTime.parse(variantDiscountEnds[i].trim());
                        } catch (Exception e) {
                            LoggerUtil.warn(log, "Ngày kết thúc giảm giá không hợp lệ: " + variantDiscountEnds[i], e);
                        }
                    }
                    variant.setDiscountEnd(vDiscEnd);

                    variant.setIsActive(true);
                    productVariantDAO.save(variant);
                }
            }

            // Lưu danh sách các bao bì tùy chọn
            if (packagingLabels != null) {
                dao.catalog.ProductPackagingOptionDAO ppoDAO = new dao.catalog.ProductPackagingOptionDAO();
                for (int i = 0; i < packagingLabels.length; i++) {
                    String pLabel = packagingLabels[i];
                    if (pLabel != null && !pLabel.trim().isEmpty()) {
                        BigDecimal priceAdd = BigDecimal.ZERO;
                        if (packagingPriceAdds != null && packagingPriceAdds.length > i && packagingPriceAdds[i] != null) {
                            try {
                                priceAdd = new BigDecimal(packagingPriceAdds[i].trim());
                            } catch (NumberFormatException e) {
                                LoggerUtil.warn(log, "Giá bao bì không hợp lệ: " + packagingPriceAdds[i], e);
                            }
                        }
                        model.entity.catalog.ProductPackagingOption option = new model.entity.catalog.ProductPackagingOption();
                        option.setProductId(productId);
                        option.setLabel(pLabel.trim());
                        option.setPriceAdd(priceAdd);
                        option.setIsActive(true);
                        ppoDAO.save(option);
                    }
                }
            }

            if ("XMLHttpRequest".equalsIgnoreCase(req.getHeader("X-Requested-With"))) {
                util.JsonUtil.writeJson(resp, ApiResponse.ok(java.util.Map.of("message", "Thêm sản phẩm mới thành công!")));
                return;
            }

            SessionUtil.flashSuccess(session, "Thêm sản phẩm mới thành công!");
            resp.sendRedirect(req.getContextPath() + "/shop/products");

        } catch (SQLException e) {
            if ("XMLHttpRequest".equalsIgnoreCase(req.getHeader("X-Requested-With"))) {
                util.ServletUtil.sendJsonInternalServerError(
                        req,
                        resp,
                        log,
                        "ProductCreateServlet#doPost",
                        "Lỗi hệ thống khi lưu sản phẩm.",
                        e);
                return;
            }
            SessionUtil.flashError(session, ErrorMessageUtil.MSG_DB_ERROR);
            resp.sendRedirect(req.getContextPath() + "/shop/products");
        }
    }
}
