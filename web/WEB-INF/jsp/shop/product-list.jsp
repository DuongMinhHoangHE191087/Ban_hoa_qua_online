<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
    <%@ taglib prefix="c" uri="jakarta.tags.core" %>
        <%@ taglib prefix="fmt" uri="jakarta.tags.fmt" %>
            <%@ taglib prefix="fn" uri="jakarta.tags.functions" %>
            <%@ taglib prefix="ft" uri="/WEB-INF/tld/fruitmkt.tld" %>
                <!DOCTYPE html>
                <html lang="vi">

                <head>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>Quản lý sản phẩm | MetaFruit</title>
                    <link rel="icon" type="image/png" href="${pageContext.request.contextPath}/favicon.png">

                    <!-- Google Fonts & Icons -->
                    <link rel="preconnect" href="https://fonts.googleapis.com">
                    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
                    <link
                    <link rel="icon" type="image/png" href="${pageContext.request.contextPath}/favicon.png">

                    <!-- Google Fonts & Icons -->
                    <link rel="preconnect" href="https://fonts.googleapis.com">
                    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
                    <link
                        href="https://fonts.googleapis.com/css2?family=Lexend:wght@300;400;500;600;700;800&display=swap"
                        rel="stylesheet">
                    <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/fontawesome.all.min.css">
                    <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/main.css">
                    <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/ui-overrides.css">
                    <link rel="stylesheet"
                        href="${pageContext.request.contextPath}/assets/css/material-symbols-outlined.css">

                    <!-- Tailwind & SweetAlert -->
                    <jsp:include page="/WEB-INF/jsp/common/tailwind-config.jsp" />
                    <script src="${pageContext.request.contextPath}/assets/js/sweetalert2.all.min.js"></script>
                </head>

                <body class="antialiased text-txt bg-background">
                    <div class="flex min-h-screen">

                        <!-- Shared Sidebar -->
                        <jsp:include page="/WEB-INF/jsp/common/shop-sidebar.jsp">
                            <jsp:param name="activePage" value="products" />
                        </jsp:include>

                        <!-- Main Content -->
                        <main class="flex-1 p-6 md:p-8 overflow-y-auto animate-fade-in-up opacity-0">

                            <!-- Page Header -->
                            <div
                                class="flex items-center justify-between bg-gradient-to-r from-primary-lt to-secondary-container/20 border border-primary-fixed/60 p-6 rounded-2xl shadow-sm mb-8">
                                <div>
                                    <h1 class="text-xl md:text-2xl font-extrabold text-primary-dark tracking-tight">Quản lý Sản phẩm</h1>
                                    <p class="text-txt-2 text-xs md:text-sm mt-1">Xem, thêm mới, sửa thông tin, ẩn/hiện hoặc xóa các sản phẩm hoa quả sạch của bạn.</p>
                                </div>

                                <button onclick="openCreateModal()"
                                    class="bg-gradient-to-r from-primary to-[#5b7a22] hover:from-[#435919] hover:to-primary-hover text-white font-bold text-sm px-5 py-3 rounded-xl transition-all shadow-md hover:shadow-lg flex items-center gap-2 active:scale-95 duration-200 cursor-pointer border-0">
                                    <span class="material-symbols-outlined text-[18px]">add_box</span>
                                    <span>Thêm sản phẩm mới</span>
                                </button>
                            </div>



                            <!-- Search and Filter Bar -->
                            <div class="glass-card rounded-2xl p-6 mb-6">
                                <form action="${pageContext.request.contextPath}/shop/products" method="GET"
                                    class="flex flex-col gap-4">
                                    <!-- Search Input Row -->
                                    <div class="flex flex-col md:flex-row items-center gap-3">
                                        <div class="relative flex-grow w-full">
                                            <span
                                                class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-txt-3">
                                                <span class="material-symbols-outlined text-[20px]">search</span>
                                            </span>
                                            <input type="text" name="keyword" value="<c:out value=" ${keyword}" />"
                                            placeholder="Tìm kiếm sản phẩm theo tên hoặc mô tả..."
                                            class="w-full pl-10 pr-4 py-2.5 border border-border rounded-xl text-sm
                                            focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all
                                            outline-none" />
                                        </div>
                                        <div class="flex items-center gap-2 w-full md:w-auto shrink-0">
                                            <button type="submit"
                                                class="bg-primary hover:bg-primary-hover text-white font-semibold text-sm px-6 py-2.5 rounded-xl transition-all shadow-sm flex items-center justify-center gap-1 active:scale-95 duration-150 cursor-pointer border-0 w-full md:w-auto">
                                                <span class="material-symbols-outlined text-[18px]">search</span> Tìm
                                                kiếm
                                            </button>
                                            <c:if
                                                test="${not empty keyword || not empty categoryId || (not empty stockStatus && stockStatus != 'ALL') || (not empty approvalStatus && approvalStatus != 'ALL') || (not empty sellStatus && sellStatus != 'ALL')}">
                                                <a href="${pageContext.request.contextPath}/shop/products"
                                                    class="bg-gray-100 hover:bg-gray-200 text-txt-2 hover:text-txt font-semibold text-sm px-5 py-2.5 rounded-xl transition-all flex items-center justify-center gap-1 active:scale-95 duration-150 no-underline w-full md:w-auto">
                                                    <span
                                                        class="material-symbols-outlined text-[18px]">restart_alt</span>
                                                    Xóa bộ lọc
                                                </a>
                                            </c:if>
                                        </div>
                                    </div>

                                    <!-- Dropdown Filters Row -->
                                    <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-3">
                                        <!-- Category Filter -->
                                        <div class="flex flex-col gap-1.5">
                                            <label class="text-xs font-semibold text-txt-2">Danh mục</label>
                                            <select name="categoryId" onchange="this.form.submit()"
                                                class="form-control-custom text-sm py-2">
                                                <option value="">Tất cả danh mục</option>
                                                <c:forEach var="cat" items="${categories}">
                                                    <option value="${cat.categoryId}" ${categoryId==cat.categoryId
                                                        ? 'selected' : '' }>
                                                        <c:out value="${cat.name}" />
                                                    </option>
                                                </c:forEach>
                                            </select>
                                        </div>

                                        <!-- Stock Status Filter -->
                                        <div class="flex flex-col gap-1.5">
                                            <label class="text-xs font-semibold text-txt-2">Tồn kho</label>
                                            <select name="stockStatus" onchange="this.form.submit()"
                                                class="form-control-custom text-sm py-2">
                                                <option value="ALL" ${stockStatus=='ALL' ? 'selected' : '' }>Tất cả
                                                </option>
                                                <option value="IN_STOCK" ${stockStatus=='IN_STOCK' ? 'selected' : '' }>
                                                    Còn hàng</option>
                                                <option value="OUT_OF_STOCK" ${stockStatus=='OUT_OF_STOCK' ? 'selected'
                                                    : '' }>Hết hàng</option>
                                            </select>
                                        </div>

                                        <!-- Approval Status Filter -->
                                        <div class="flex flex-col gap-1.5">
                                            <label class="text-xs font-semibold text-txt-2">Kiểm duyệt</label>
                                            <select name="approvalStatus" onchange="this.form.submit()"
                                                class="form-control-custom text-sm py-2">
                                                <option value="ALL" ${approvalStatus=='ALL' ? 'selected' : '' }>Tất cả
                                                    trạng thái</option>
                                                <option value="APPROVED" ${approvalStatus=='APPROVED' ? 'selected' : ''
                                                    }>Đã duyệt</option>
                                                <option value="PENDING" ${approvalStatus=='PENDING' ? 'selected' : '' }>
                                                    Chờ duyệt</option>
                                                <option value="REJECTED" ${approvalStatus=='REJECTED' ? 'selected' : ''
                                                    }>Bị từ chối</option>
                                            </select>
                                        </div>

                                        <!-- Selling Status Filter -->
                                        <div class="flex flex-col gap-1.5">
                                            <label class="text-xs font-semibold text-txt-2">Trạng thái bán</label>
                                            <select name="sellStatus" onchange="this.form.submit()"
                                                class="form-control-custom text-sm py-2">
                                                <option value="ALL" ${sellStatus=='ALL' ? 'selected' : '' }>Tất cả
                                                </option>
                                                <option value="ACTIVE" ${sellStatus=='ACTIVE' ? 'selected' : '' }>Đang
                                                    bán</option>
                                                <option value="INACTIVE" ${sellStatus=='INACTIVE' ? 'selected' : '' }>
                                                    Đang ẩn</option>
                                                <option value="OUT_OF_SEASON" ${sellStatus=='OUT_OF_SEASON' ? 'selected'
                                                    : '' }>Hết vụ</option>
                                            </select>
                                        </div>
                                    </div>
                                </form>

                                <!-- Result Stats -->
                                <c:if
                                    test="${not empty keyword || not empty categoryId || (not empty stockStatus && stockStatus != 'ALL') || (not empty approvalStatus && approvalStatus != 'ALL') || (not empty sellStatus && sellStatus != 'ALL')}">
                                    <div
                                        class="text-xs text-txt-2 font-medium mt-4 pt-3 border-t border-border flex items-center justify-between">
                                        <span>Kết quả lọc: Tìm thấy <strong
                                                class="text-primary">${products.size()}</strong> sản phẩm.</span>
                                        <a href="${pageContext.request.contextPath}/shop/products"
                                            class="text-primary hover:underline font-semibold flex items-center gap-0.5">
                                            <span class="material-symbols-outlined text-[14px]">restart_alt</span> Thiết
                                            lập lại bộ lọc
                                        </a>
                                    </div>
                                </c:if>
                            </div>

                            <!-- Product Table Grid -->
                            <div class="glass-card rounded-2xl overflow-hidden mb-8">
                                <c:choose>
                                    <c:when test="${empty products}">
                                        <div class="text-center py-20 px-4">
                                            <span
                                                class="material-symbols-outlined text-[64px] text-primary/30 mb-4">box_edit</span>
                                            <c:choose>
                                                <c:when
                                                    test="${not empty keyword || not empty categoryId || (not empty stockStatus && stockStatus != 'ALL') || (not empty approvalStatus && approvalStatus != 'ALL') || (not empty sellStatus && sellStatus != 'ALL')}">
                                                    <h3 class="text-lg font-bold">Không tìm thấy sản phẩm nào khớp với
                                                        bộ lọc hiện tại</h3>
                                                    <p class="text-xs text-[#475569] mt-1 max-w-md mx-auto font-light">
                                                        Thử thay đổi bộ lọc hoặc xóa các tiêu chí tìm kiếm để hiển thị
                                                        các sản phẩm khác.</p>
                                                    <a href="${pageContext.request.contextPath}/shop/products"
                                                        class="inline-flex items-center gap-2 bg-primary hover:bg-primary-hover text-white text-xs font-semibold px-6 py-3 rounded-full mt-6 transition-all shadow-sm cursor-pointer no-underline">
                                                        <span
                                                            class="material-symbols-outlined text-[16px]">restart_alt</span>
                                                        Xóa toàn bộ bộ lọc
                                                    </a>
                                                </c:when>
                                                <c:otherwise>
                                                    <h3 class="text-lg font-bold">Cửa hàng của bạn chưa có sản phẩm nào
                                                    </h3>
                                                    <p class="text-xs text-txt-2 mt-1 max-w-md mx-auto font-light">Bắt
                                                        đầu đưa trái cây sạch, hữu cơ tươi ngon của bạn tiếp cận hàng
                                                        ngàn khách hàng bằng cách bấm nút thêm sản phẩm!</p>
                                                    <button onclick="openCreateModal()"
                                                        class="inline-flex items-center gap-2 bg-primary hover:bg-primary-hover text-white text-xs font-semibold px-6 py-3 rounded-full mt-6 transition-all shadow-sm border-0 cursor-pointer">
                                                        <span class="material-symbols-outlined text-[16px]">add</span>
                                                        Thêm sản phẩm đầu tiên
                                                    </button>
                                                </c:otherwise>
                                            </c:choose>
                                        </div>
                                    </c:when>
                                    <c:otherwise>
                                        <div class="table-responsive">
                                            <table class="table">
                                                <thead>
                                                    <tr>
                                                        <th>Sản phẩm</th>
                                                        <th>Danh mục</th>
                                                        <th>Giá bán</th>
                                                        <th class="text-center">Tồn kho</th>
                                                        <th class="text-center">Tương tác</th>
                                                        <th class="text-center">Kiểm duyệt</th>
                                                        <th class="text-center">Trạng thái bán</th>
                                                        <th class="text-right">Thao tác</th>
                                                    </tr>
                                                </thead>
                                                <tbody>
                                                    <c:forEach var="item" items="${products}">
                                                        <tr id="product-row-${item.productId}">
                                                            <!-- Product Detail Thumbnail & Origin -->
                                                            <td class="flex items-center gap-4">
                                                                <div
                                                                    class="w-12 h-12 rounded-xl overflow-hidden bg-emerald-50 border border-gray-150 shrink-0 shadow-sm relative group">
                                                                    <img src="${item.image}" alt="${item.name}"
                                                                        class="w-full h-full object-cover group-hover:scale-110 transition-transform duration-300"
                                                                        onerror="this.src='https://images.unsplash.com/photo-1610832958506-ee5633619144?w=100&auto=format&fit=crop&q=80'">
                                                                </div>
                                                                <div>
                                                                    <h4 class="font-bold text-txt hover:text-primary transition-colors cursor-pointer"
                                                                        onclick="window.location.href='${pageContext.request.contextPath}/products/detail?id=${item.productId}'">
                                                                        <c:out value="${item.name}" />
                                                                    </h4>
                                                                    <div
                                                                        class="flex items-center gap-1.5 text-xs text-txt-3 font-light mt-0.5">
                                                                        <span
                                                                            class="material-symbols-outlined text-[14px] text-primary/70">location_on</span>
                                                                        <span>
                                                                            <c:out value="${item.originRegion}" />,
                                                                            <c:out value="${item.originCountry}" />
                                                                        </span>
                                                                    </div>
                                                                </div>
                                                            </td>

                                                            <!-- Category -->
                                                            <td class="text-txt-2 font-medium">
                                                                <c:out value="${item.categoryName}" />
                                                            </td>

                                                            <!-- Price -->
                                                            <td class="font-bold text-primary">
                                                                <c:choose>
                                                                    <c:when test="${item.hasMultipleVariants}">
                                                                        <ft:currency value="${item.minPrice}" /> -
                                                                        <ft:currency value="${item.maxPrice}" />
                                                                        <span
                                                                            class="block text-[10px] text-txt-3 font-normal">(${item.unit})</span>
                                                                    </c:when>
                                                                    <c:otherwise>
                                                                        <ft:currency value="${item.price}" />
                                                                        <span
                                                                            class="text-[10px] text-txt-3 font-normal">
                                                                            /
                                                                            <c:out value="${item.unit}" />
                                                                        </span>
                                                                    </c:otherwise>
                                                                </c:choose>
                                                            </td>

                                                            <!-- Stock Status Badge -->
                                                            <td class="text-center">
                                                                <c:choose>
                                                                    <c:when test="${item.stock > 10}">
                                                                        <span
                                                                            class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
                                                                            ${item.stock}
                                                                            <c:out
                                                                                value="${item.hasMultipleVariants ? 'sản phẩm' : item.unit}" />
                                                                        </span>
                                                                    </c:when>
                                                                    <c:when test="${item.stock > 0}">
                                                                        <span
                                                                            class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-semibold bg-amber-50 text-amber-700 border border-amber-200">
                                                                            Còn ít: ${item.stock}
                                                                        </span>
                                                                    </c:when>
                                                                    <c:otherwise>
                                                                        <span
                                                                            class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-semibold bg-red-50 text-red-700 border border-red-200 animate-pulse">
                                                                            Hết hàng
                                                                        </span>
                                                                    </c:otherwise>
                                                                </c:choose>
                                                            </td>

                                                            <!-- Interactive counts -->
                                                            <td class="text-center text-xs text-txt-2 font-light">
                                                                <div class="flex flex-col items-center">
                                                                    <span class="flex items-center gap-1"><span
                                                                            class="material-symbols-outlined text-[14px]">visibility</span>
                                                                        Lượt xem: ${item.viewCount}</span>
                                                                    <span
                                                                        class="flex items-center gap-1 mt-1 font-semibold text-primary"><span
                                                                            class="material-symbols-outlined text-[14px]">shopping_cart</span>
                                                                        Đã bán: ${item.soldQuantity}</span>
                                                                </div>
                                                            </td>

                                                            <!-- Approval Status Badge -->
                                                            <td class="text-center">
                                                                <div class="flex flex-col items-center justify-center">
                                                                    <c:choose>
                                                                        <c:when
                                                                            test="${item.approvalStatus == 'APPROVED'}">
                                                                            <span
                                                                                class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-emerald-50 border border-emerald-200 text-emerald-800 text-[10px] font-bold">
                                                                                <i class="fa-solid fa-circle-check"></i>
                                                                                Đã duyệt
                                                                            </span>
                                                                        </c:when>
                                                                        <c:when
                                                                            test="${item.approvalStatus == 'REJECTED'}">
                                                                            <span
                                                                                class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-rose-50 border border-rose-200 text-rose-800 text-[10px] font-bold cursor-help"
                                                                                title="Lý do từ chối: ${item.rejectionReason}">
                                                                                <i class="fa-solid fa-circle-xmark"></i>
                                                                                Bị từ chối
                                                                            </span>
                                                                            <span
                                                                                class="text-[9px] text-rose-600 font-semibold mt-1 max-w-[120px] truncate"
                                                                                title="${item.rejectionReason}">
                                                                                Lý do: ${item.rejectionReason}
                                                                            </span>
                                                                        </c:when>
                                                                        <c:otherwise>
                                                                            <span
                                                                                class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-yellow-50 border border-yellow-200 text-yellow-800 text-[10px] font-bold">
                                                                                <i class="fa-solid fa-clock"></i> Chờ
                                                                                duyệt
                                                                            </span>
                                                                        </c:otherwise>
                                                                    </c:choose>
                                                                </div>
                                                            </td>

                                                            <!-- AJAX Toggle Sale Switch -->
                                                            <td class="text-center">
                                                                <div
                                                                    class="flex flex-col items-center justify-center gap-1">
                                                                    <c:if test="${item.status == 'OUT_OF_SEASON'}">
                                                                        <span
                                                                            class="text-[10px] font-bold text-amber-600 bg-amber-50 px-1.5 py-0.5 rounded border border-amber-200">Hết
                                                                            vụ</span>
                                                                    </c:if>
                                                                    <label
                                                                        class="relative inline-flex items-center cursor-pointer select-none">
                                                                        <input type="checkbox"
                                                                            id="toggle-status-${item.productId}"
                                                                            class="sr-only peer" ${item.status=='ACTIVE'
                                                                            || item.status=='OUT_OF_SEASON' ? 'checked'
                                                                            : '' }
                                                                            onchange="toggleSaleStatus('${item.productId}', this)">
                                                                        <div
                                                                            class="w-11 h-6 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary shadow-inner">
                                                                        </div>
                                                                    </label>
                                                                </div>
                                                            </td>

                                                            <!-- Actions (Edit/Delete) -->
                                                            <td class="text-right">
                                                                <div class="inline-flex items-center gap-2">
                                                                    <!-- Edit button -->
                                                                    <button onclick="openEditModal('${item.productId}')"
                                                                        class="w-9 h-9 rounded-xl border border-primary/20 bg-white text-primary hover:bg-primary hover:text-white transition-all shadow-sm active:scale-90 flex items-center justify-center cursor-pointer border-0"
                                                                        title="Sửa thông tin">
                                                                        <span
                                                                            class="material-symbols-outlined text-[18px]">edit</span>
                                                                    </button>
                                                                    <!-- Delete button -->
                                                                    <button data-product-id="${item.productId}"
                                                                        data-product-name="<c:out value='${item.name}'/>"
                                                                        onclick="confirmSoftDelete(this)"
                                                                        class="w-9 h-9 rounded-xl border border-red-200 bg-white text-red-600 hover:bg-red-600 hover:text-white transition-all shadow-sm active:scale-90 flex items-center justify-center cursor-pointer border-0"
                                                                        title="Xóa mềm">
                                                                        <span
                                                                            class="material-symbols-outlined text-[18px]">delete</span>
                                                                    </button>
                                                                </div>
                                                            </td>
                                                        </tr>
                                                    </c:forEach>
                                                </tbody>
                                            </table>
                                        </div>
                                        <div class="px-6 py-4 border-t border-border flex justify-end">
                                            <ft:pagination current="${currentPage}" total="${totalPages}" baseUrl="${pageContext.request.contextPath}/shop/products?keyword=${fn:escapeXml(keyword)}&categoryId=${categoryId}&stockStatus=${stockStatus}&approvalStatus=${approvalStatus}&sellStatus=${sellStatus}" />
                                        </div>
                                    </c:otherwise>
                                </c:choose>
                            </div>

                        </main>
                    </div>

                    <!-- Unified Product Modal (Create & Edit) -->
                    <div id="productModal" class="fixed inset-0 z-50 overflow-y-auto hidden">
                        <!-- Backdrop -->
                        <div class="fixed inset-0 bg-black/50 backdrop-blur-sm transition-opacity"
                            onclick="closeProductModal()"></div>

                        <!-- Modal Box -->
                        <div class="flex min-h-full items-center justify-center p-4">
                            <div
                                class="relative transform overflow-hidden rounded-2xl bg-white text-left shadow-2xl transition-all w-full max-w-3xl glass-card flex flex-col max-h-[90vh]">
                                <!-- Header -->
                                <div
                                    class="flex items-center justify-between px-6 py-5 border-b border-border bg-[#f9fdf9]">
                                    <h3 id="productModalTitle"
                                        class="text-base font-bold text-primary flex items-center gap-2">
                                        <span class="material-symbols-outlined text-[24px]">add_box</span>
                                        Đăng bán sản phẩm mới
                                    </h3>
                                    <button onclick="closeProductModal()"
                                        class="text-txt-2 hover:text-txt cursor-pointer border-0 bg-transparent">
                                        <span class="material-symbols-outlined">close</span>
                                    </button>
                                </div>

                                <!-- Form Body (Scrollable) -->
                                <form id="productForm" onsubmit="submitProductForm(event)" enctype="multipart/form-data"
                                    class="overflow-y-auto p-6 md:p-8 space-y-6">
                                    <input type="hidden" name="_csrf" value="${sessionScope._csrfToken}">
                                    <input type="hidden" name="id" id="modal-productId">

                                    <!-- 1. Basic Information Component -->
                                    <div>
                                        <h2
                                            class="text-xs font-bold text-primary border-b border-primary/10 pb-1.5 mb-4 flex items-center gap-1.5 uppercase tracking-wider">
                                            <span class="material-symbols-outlined text-[16px]">info</span>
                                            Thông tin cơ bản
                                        </h2>

                                        <div class="space-y-4">
                                            <!-- Product Name -->
                                            <div>
                                                <label for="modal-name"
                                                    class="block text-xs font-bold text-txt-2 mb-1.5">Tên sản phẩm hoa
                                                    quả <span class="text-red-500">*</span></label>
                                                <input type="text" name="name" id="modal-name" required
                                                    placeholder="Ví dụ: Sầu Riêng Chín Hóa"
                                                    class="form-control-custom">
                                            </div>

                                            <!-- Description -->
                                            <div>
                                                <label for="modal-description"
                                                    class="block text-xs font-bold text-txt-2 mb-1.5">Mô tả sản
                                                    phẩm</label>
                                                <textarea name="description" id="modal-description" rows="3"
                                                    placeholder="Nhập mô tả sản phẩm, hương vị, chứng chỉ..."
                                                    class="form-control-custom"></textarea>
                                            </div>

                                            <!-- Category & Status -->
                                            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                                                <div>
                                                    <label for="modal-categoryId"
                                                        class="block text-xs font-bold text-txt-2 mb-1.5">Danh mục sản
                                                        phẩm <span class="text-red-500">*</span></label>
                                                    <select name="categoryId" id="modal-categoryId" required
                                                        class="form-control-custom py-[0.55rem]">
                                                        <option value="">-- Chọn danh mục --</option>
                                                        <c:forEach var="cat" items="${categories}">
                                                            <option value="${cat.categoryId}">
                                                                <c:out value="${cat.name}" />
                                                            </option>
                                                        </c:forEach>
                                                    </select>
                                                </div>
                                                <div id="modal-status-container" class="hidden">
                                                    <label for="modal-status"
                                                        class="block text-xs font-bold text-txt-2 mb-1.5">Trạng thái bán
                                                        hàng <span class="text-red-500">*</span></label>
                                                    <select name="status" id="modal-status" required
                                                        class="form-control-custom py-[0.55rem]">
                                                        <option value="ACTIVE">Công khai bán (ACTIVE)</option>
                                                        <option value="INACTIVE">Tạm ẩn hiển thị (INACTIVE)</option>
                                                        <option value="OUT_OF_SEASON">Hết vụ thu hoạch (OUT_OF_SEASON)
                                                        </option>
                                                    </select>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Nhãn & Mùa vụ -->
                                    <div>
                                        <h2
                                            class="text-xs font-bold text-primary border-b border-primary/10 pb-1.5 mb-4 flex items-center gap-1.5 uppercase tracking-wider">
                                            <span class="material-symbols-outlined text-[16px]">eco</span>
                                            Nhãn sản phẩm & Mùa vụ
                                        </h2>
                                        <div class="space-y-4">
                                            <div class="flex items-center gap-6">
                                                <label
                                                    class="flex items-center gap-2 cursor-pointer font-bold text-xs text-txt-2 select-none">
                                                    <input type="checkbox" name="isOrganic" id="modal-isOrganic"
                                                        class="rounded text-primary focus:ring-primary">
                                                    <span>Sản phẩm Hữu Cơ (Organic)</span>
                                                </label>
                                                <label
                                                    class="flex items-center gap-2 cursor-pointer font-bold text-xs text-txt-2 select-none">
                                                    <input type="checkbox" name="isImported" id="modal-isImported"
                                                        class="rounded text-primary focus:ring-primary">
                                                    <span>Sản phẩm Nhập Khẩu</span>
                                                </label>
                                            </div>
                                            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                                                <div>
                                                    <label for="modal-seasonStartMonth"
                                                        class="block text-xs font-bold text-txt-2 mb-1.5">Mùa vụ bắt đầu
                                                        (Tháng)</label>
                                                    <select name="seasonStartMonth" id="modal-seasonStartMonth"
                                                        class="form-control-custom">
                                                        <option value="">-- Suốt năm --</option>
                                                        <c:forEach var="m" begin="1" end="12">
                                                            <option value="${m}">Tháng ${m}</option>
                                                        </c:forEach>
                                                    </select>
                                                </div>
                                                <div>
                                                    <label for="modal-seasonEndMonth"
                                                        class="block text-xs font-bold text-txt-2 mb-1.5">Mùa vụ kết
                                                        thúc (Tháng)</label>
                                                    <select name="seasonEndMonth" id="modal-seasonEndMonth"
                                                        class="form-control-custom">
                                                        <option value="">-- Suốt năm --</option>
                                                        <c:forEach var="m" begin="1" end="12">
                                                            <option value="${m}">Tháng ${m}</option>
                                                        </c:forEach>
                                                    </select>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- 2. Dynamic Variants Component -->
                                    <div>
                                        <div
                                            class="flex items-center justify-between border-b border-primary/10 pb-1.5 mb-4">
                                            <h2
                                                class="text-xs font-bold text-primary flex items-center gap-1.5 uppercase tracking-wider">
                                                <span class="material-symbols-outlined text-[16px]">layers</span>
                                                Phân loại bán <span class="text-red-500">*</span>
                                            </h2>
                                            <button type="button" onclick="addVariantRow()"
                                                class="inline-flex items-center gap-1 text-[11px] font-bold text-primary hover:text-primary-hover bg-primary-lt hover:bg-primary/10 px-2.5 py-1.5 rounded-lg border-0 cursor-pointer transition-colors">
                                                <span class="material-symbols-outlined text-[14px]">add_circle</span>
                                                Thêm phân loại
                                            </button>
                                        </div>

                                        <div class="space-y-3" id="modal-variants-container">
                                            <!-- Variant rows dynamically appended here -->
                                        </div>
                                    </div>

                                    <!-- 2.5 Dynamic Packaging Options Component -->
                                    <div>
                                        <div
                                            class="flex items-center justify-between border-b border-primary/10 pb-1.5 mb-4">
                                            <h2
                                                class="text-xs font-bold text-primary flex items-center gap-1.5 uppercase tracking-wider">
                                                <span class="material-symbols-outlined text-[16px]">inventory_2</span>
                                                Tùy chọn đóng gói (Bao bì, hộp quà...)
                                            </h2>
                                            <button type="button" onclick="addPackagingRow()"
                                                class="inline-flex items-center gap-1 text-[11px] font-bold text-primary hover:text-primary-hover bg-primary-lt hover:bg-primary/10 px-2.5 py-1.5 rounded-lg border-0 cursor-pointer transition-colors">
                                                <span class="material-symbols-outlined text-[14px]">add_circle</span>
                                                Thêm tùy chọn
                                            </button>
                                        </div>

                                        <div class="space-y-3" id="modal-packaging-container">
                                            <!-- Packaging rows dynamically appended here -->
                                        </div>
                                    </div>

                                    <!-- 3. Quality & Expiry Metadata Component -->
                                    <div>
                                        <h2
                                            class="text-xs font-bold text-primary border-b border-primary/10 pb-1.5 mb-4 flex items-center gap-1.5 uppercase tracking-wider">
                                            <span class="material-symbols-outlined text-[16px]">verified_user</span>
                                            Xuất xứ & Hạn sử dụng
                                        </h2>

                                        <div class="space-y-4">
                                            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                                                <div>
                                                    <label for="modal-originCountry"
                                                        class="block text-xs font-bold text-txt-2 mb-1.5">Quốc
                                                        gia <span class="text-red-500">*</span></label>
                                                    <input type="text" name="originCountry" id="modal-originCountry"
                                                        value="Việt Nam" class="form-control-custom" required maxlength="100">
                                                </div>
                                                <div>
                                                    <label for="modal-originRegion"
                                                        class="block text-xs font-bold text-txt-2 mb-1.5">Vùng sản
                                                        xuất <span class="text-red-500">*</span></label>
                                                    <input type="text" name="originRegion" id="modal-originRegion"
                                                        placeholder="Ví dụ: Đắk Lắk, Đà Lạt..."
                                                        class="form-control-custom" required maxlength="150">
                                                </div>
                                            </div>

                                            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                                                <div>
                                                    <label for="modal-harvestDate"
                                                        class="block text-xs font-bold text-txt-2 mb-1.5">Ngày thu
                                                        hoạch <span class="text-red-500">*</span></label>
                                                    <input type="date" name="harvestDate" id="modal-harvestDate"
                                                        class="form-control-custom" required>
                                                </div>
                                                <div>
                                                    <label for="modal-shelfLifeDays"
                                                        class="block text-xs font-bold text-txt-2 mb-1.5">Hạn sử dụng
                                                        (Số ngày)<span class="text-red-500">*</span></label>
                                                    <input type="number" name="shelfLifeDays" id="modal-shelfLifeDays"
                                                        min="1" max="3650" placeholder="Ví dụ: 7" class="form-control-custom" required>
                                                </div>
                                            </div>

                                            <div>
                                                <label for="modal-storageInstruction"
                                                    class="block text-xs font-bold text-txt-2 mb-1.5">Hướng dẫn bảo
                                                    quản</label>
                                                <input type="text" name="storageInstruction"
                                                    id="modal-storageInstruction"
                                                    placeholder="Ví dụ: Bảo quản ngăn mát..."
                                                    class="form-control-custom">
                                            </div>
                                        </div>
                                    </div>

                                    <!-- 4. Existing Images (Edit Only) -->
                                    <div id="modal-existing-images-section" class="hidden">
                                        <h2
                                            class="text-xs font-bold text-primary border-b border-primary/10 pb-1.5 mb-4 flex items-center gap-1.5 uppercase tracking-wider">
                                            <span class="material-symbols-outlined text-[16px]">collections</span>
                                            Album hình ảnh hiện tại
                                            <span class="text-[10px] text-txt-3 font-normal normal-case ml-1">(kéo thả
                                                để sắp xếp · nhấn ⭐ để đặt ảnh chính)</span>
                                        </h2>
                                        <div id="modal-existing-images" class="grid grid-cols-2 sm:grid-cols-4 gap-3">
                                        </div>
                                    </div>

                                    <!-- 5. Upload New Images Component -->
                                    <div>
                                        <h2
                                            class="text-xs font-bold text-primary border-b border-primary/10 pb-1.5 mb-4 flex items-center gap-1.5 uppercase tracking-wider">
                                            <span class="material-symbols-outlined text-[16px]">photo_library</span>
                                            Thêm hình ảnh mới <span class="text-red-500"
                                                id="modal-image-required-star">*</span>
                                        </h2>

                                        <label for="modal-images-input"
                                            class="flex flex-col items-center justify-center relative border-2 border-dashed border-primary/30 hover:border-primary rounded-xl p-6 text-center transition-all bg-emerald-50/20 hover:bg-emerald-50/40 cursor-pointer group">
                                            <input type="file" name="images" id="modal-images-input" multiple
                                                accept="image/*" class="hidden" onchange="addNewImagePreviews(this)">
                                            <span
                                                class="material-symbols-outlined text-[36px] text-primary/50 group-hover:scale-110 transition-transform mb-2">cloud_upload</span>
                                            <h4 class="text-xs font-bold text-txt">Kéo thả hoặc nhấp để chọn ảnh (có thể
                                                chọn nhiều lần, ảnh cũ không bị mất)</h4>
                                        </label>

                                        <div id="modal-file-list-preview"
                                            class="grid grid-cols-2 sm:grid-cols-4 gap-3 mt-4 hidden"></div>
                                    </div>

                                    <!-- Verification Document -->
                                    <div>
                                        <h2
                                            class="text-xs font-bold text-primary border-b border-primary/10 pb-1.5 mb-4 flex items-center gap-1.5 uppercase tracking-wider">
                                            <span class="material-symbols-outlined text-[16px]">description</span>
                                            Giấy tờ kiểm định chất lượng (PDF, Word, Ảnh) <span class="text-red-500"
                                                id="modal-doc-required-star">*</span>
                                        </h2>
                                        <div class="space-y-3">
                                            <input type="file" name="verificationDoc" id="modal-verificationDoc"
                                                accept=".pdf,.jpg,.jpeg,.png,.docx" class="form-control-custom">
                                            <p class="text-[11px] text-txt-3">Yêu cầu đính kèm giấy chứng nhận hữu cơ,
                                                xuất xứ nông sản để Admin phê duyệt. Kích thước tối đa 25MB.</p>

                                            <%-- Existing document display --%>
                                                <div id="modal-current-doc-container"
                                                    class="hidden p-3 rounded-xl bg-slate-50 border border-border flex items-center justify-between text-xs text-txt-2">
                                                    <span class="font-semibold flex items-center gap-1"><span
                                                            class="material-symbols-outlined text-primary text-[16px]">file_present</span>
                                                        Tài liệu đã tải lên</span>
                                                    <a id="modal-current-doc-link" href="#" target="_blank"
                                                        class="text-primary hover:text-primary-hover font-bold flex items-center gap-0.5 underline">
                                                        Xem tài liệu cũ <span
                                                            class="material-symbols-outlined text-[14px]">open_in_new</span>
                                                    </a>
                                                </div>
                                        </div>
                                    </div>

                                    <!-- Footer / Buttons -->
                                    <div class="flex justify-end gap-3 pt-6 border-t border-[#e2ece7]">
                                        <button type="button" onclick="closeProductModal()"
                                            class="border border-gray-300 hover:bg-gray-50 text-txt-2 font-bold text-xs px-6 py-3 rounded-xl transition-all active:scale-95 duration-200 cursor-pointer">
                                            Hủy bỏ
                                        </button>
                                        <button type="submit" id="modal-submit-btn"
                                            class="bg-primary hover:bg-primary-hover text-white font-bold text-xs px-8 py-3 rounded-xl transition-all shadow-md active:scale-95 duration-200 cursor-pointer border-0">
                                            Đăng bán ngay
                                        </button>
                                    </div>
                                </form>
                            </div>
                        </div>
                    </div>

                    <!-- Hidden inputs to safely pass server variables to JS without IDE syntax errors -->
                    <input type="hidden" id="js-ctx" value="${pageContext.request.contextPath}">
                    <input type="hidden" id="js-csrf" value="${sessionScope._csrfToken}">

                    <!-- AJAX Callouts & SweetAlert style modal -->
                    <script>
                        const CTX = document.getElementById('js-ctx').value;
                        const CSRF = document.getElementById('js-csrf').value;
                        window.csrfToken = CSRF;

                        document.addEventListener('DOMContentLoaded', function () {
                            const harvestDateInput = document.getElementById('modal-harvestDate');
                            if (harvestDateInput) {
                                const todayStr = new Date().toISOString().split('T')[0];
                                harvestDateInput.setAttribute('max', todayStr);
                            }
                        });

                        function handleJSONResponse(response) {
                            const contentType = response.headers.get("content-type");
                            if (!response.ok || !contentType || contentType.indexOf("application/json") === -1) {
                                if (contentType && contentType.indexOf("application/json") !== -1) {
                                    return response.json().then(errData => {
                                        throw new Error(errData.message || errData.error || 'Lỗi hệ thống (Mã: ' + response.status + ')');
                                    });
                                }
                                if (response.status === 403) {
                                    throw new Error('CSRF_ERROR');
                                }
                                throw new Error('Lỗi hệ thống (Mã: ' + response.status + ')');
                            }
                            return response.json();
                        }

                        function handleAjaxError(err, defaultMessage) {
                            console.error(err);
                            if (err.message === 'CSRF_ERROR' || err.message.includes('CSRF')) {
                                Swal.fire({
                                    icon: 'warning',
                                    title: 'Phiên làm việc hết hạn',
                                    text: 'Phiên làm việc của bạn đã hết hạn hoặc được làm mới. Vui lòng làm mới trang.',
                                    confirmButtonText: 'Làm mới ngay',
                                    confirmButtonColor: '#4d661c'
                                }).then(() => {
                                    window.location.reload();
                                });
                            } else {
                                Swal.fire({
                                    icon: 'error',
                                    title: 'Lỗi',
                                    text: err.message || defaultMessage || "Lỗi kết nối máy chủ.",
                                    confirmButtonColor: '#4d661c'
                                });
                            }
                        }

                        /**
                         * AJAX Toggle switch for sales display status
                         */
                        function toggleSaleStatus(productId, checkbox) {
                            const isChecked = checkbox.checked;
                            const newStatus = isChecked ? 'ACTIVE' : 'INACTIVE';

                            checkbox.disabled = true;

                            const params = new URLSearchParams();
                            params.append('action', 'toggle');
                            params.append('productId', productId);
                            params.append('status', newStatus);
                            params.append('_csrf', window.csrfToken || CSRF);

                            fetch(CTX + '/shop/product-status', {
                                method: 'POST',
                                headers: {
                                    'Content-Type': 'application/x-www-form-urlencoded',
                                    'X-CSRF-Token': window.csrfToken || CSRF,
                                    'X-Requested-With': 'XMLHttpRequest'
                                },
                                body: params
                            })
                                .then(handleJSONResponse)
                                .then(data => {
                                    checkbox.disabled = false;
                                    if (data.success) {
                                        Swal.fire({
                                            toast: true,
                                            position: 'top-end',
                                            icon: 'success',
                                            title: 'Đã cập nhật trạng thái bán thành công!',
                                            showConfirmButton: false,
                                            timer: 2000,
                                            timerProgressBar: true
                                        });
                                    } else {
                                        checkbox.checked = !isChecked; // Rollback
                                        Swal.fire({
                                            icon: 'error',
                                            title: 'Thất bại',
                                            text: data.message || "Không thể cập nhật trạng thái.",
                                            confirmButtonColor: '#4d661c'
                                        });
                                    }
                                })
                                .catch(err => {
                                    checkbox.disabled = false;
                                    checkbox.checked = !isChecked; // Rollback
                                    handleAjaxError(err, "Lỗi kết nối máy chủ khi cập nhật trạng thái.");
                                });
                        }

                        /**
                         * Show custom modal to confirm soft delete
                         */
                        function confirmSoftDelete(button) {
                            const productId = button.getAttribute('data-product-id');
                            const productName = button.getAttribute('data-product-name');

                            Swal.fire({
                                title: 'Xác nhận xóa?',
                                text: 'Bạn có chắc chắn muốn xóa sản phẩm "' + productName + '"? Lưu ý: Sản phẩm sẽ bị ẩn khỏi gian hàng nhưng các đơn hàng cũ vẫn hiển thị bình thường.',
                                icon: 'warning',
                                showCancelButton: true,
                                confirmButtonColor: '#4d661c',
                                cancelButtonColor: '#d33',
                                confirmButtonText: 'Đồng ý xóa',
                                cancelButtonText: 'Hủy bỏ',
                                background: '#ffffff',
                                customClass: {
                                    popup: 'rounded-2xl font-sans'
                                }
                            }).then((result) => {
                                if (result.isConfirmed) {
                                    executeSoftDelete(productId);
                                }
                            });
                        }

                        /**
                         * AJAX Soft Delete
                         */
                        function executeSoftDelete(productId) {
                            const row = document.getElementById('product-row-' + productId);
                            if (!row) return;

                            const params = new URLSearchParams();
                            params.append('action', 'delete');
                            params.append('productId', productId);
                            params.append('_csrf', window.csrfToken || CSRF);

                            fetch(CTX + '/shop/product-status', {
                                method: 'POST',
                                headers: {
                                    'Content-Type': 'application/x-www-form-urlencoded',
                                    'X-CSRF-Token': window.csrfToken || CSRF,
                                    'X-Requested-With': 'XMLHttpRequest'
                                },
                                body: params
                            })
                                .then(handleJSONResponse)
                                .then(data => {
                                    if (data.success) {
                                        Swal.fire({
                                            icon: 'success',
                                            title: 'Đã xóa!',
                                            text: 'Sản phẩm đã được ẩn và xóa thành công.',
                                            confirmButtonColor: '#4d661c',
                                            timer: 1500,
                                            showConfirmButton: false
                                        });

                                        row.classList.add('row-fadeout');
                                        setTimeout(() => {
                                            row.remove();
                                            const tbody = document.querySelector('tbody');
                                            if (tbody && tbody.children.length === 0) {
                                                window.location.reload();
                                            }
                                        }, 500);
                                    } else {
                                        Swal.fire({
                                            icon: 'error',
                                            title: 'Lỗi',
                                            text: data.message || "Không thể xóa sản phẩm.",
                                            confirmButtonColor: '#4d661c'
                                        });
                                    }
                                })
                                .catch(err => {
                                    handleAjaxError(err, "Lỗi kết nối máy chủ khi thực hiện xóa sản phẩm.");
                                });
                        }

                        /* Modal Operations */
                        function openCreateModal() {
                            const form = document.getElementById('productForm');
                            form.reset();

                            document.getElementById('modal-productId').value = '';
                            document.getElementById('productModalTitle').innerHTML = `
            <span class="material-symbols-outlined text-[24px]">add_box</span>
            Đăng bán sản phẩm mới
        `;
                            document.getElementById('modal-submit-btn').textContent = 'Đăng bán ngay';

                            // Hide edit-only sections
                            document.getElementById('modal-status-container').classList.add('hidden');
                            document.getElementById('modal-existing-images-section').classList.add('hidden');
                            document.getElementById('modal-existing-images').innerHTML = '';

                            // Reset new image state
                            newImageFiles = new DataTransfer();
                            document.getElementById('modal-file-list-preview').innerHTML = '';
                            document.getElementById('modal-file-list-preview').classList.add('hidden');

                            // Make image file input required for new products
                            const imageInput = document.getElementById('modal-images-input');
                            imageInput.value = '';
                            imageInput.required = true;
                            document.getElementById('modal-image-required-star').classList.remove('hidden');

                            // Make verification document required for new products
                            const docInput = document.getElementById('modal-verificationDoc');
                            docInput.value = '';
                            docInput.required = true;
                            document.getElementById('modal-doc-required-star').classList.remove('hidden');
                            document.getElementById('modal-current-doc-container').classList.add('hidden');

                            // Initialize with one empty variant row
                            document.getElementById('modal-variants-container').innerHTML = '';
                            addVariantRow({ variantLabel: 'kg', price: '', stockQuantity: '' });

                            // Reset checkboxes & seasons & packagings
                            document.getElementById('modal-isOrganic').checked = false;
                            document.getElementById('modal-isImported').checked = false;
                            document.getElementById('modal-seasonStartMonth').value = '';
                            document.getElementById('modal-seasonEndMonth').value = '';
                            document.getElementById('modal-packaging-container').innerHTML = '';

                            document.getElementById('productModal').classList.remove('hidden');
                        }

                        function openEditModal(productId) {
                            Swal.fire({
                                title: 'Đang tải thông tin...',
                                text: 'Vui lòng chờ trong giây lát',
                                allowOutsideClick: false,
                                didOpen: () => {
                                    Swal.showLoading();
                                }
                            });

                            fetch(CTX + '/shop/product-edit?id=' + productId, {
                                headers: {
                                    'X-Requested-With': 'XMLHttpRequest'
                                }
                            })
                                .then(handleJSONResponse)
                                .then(apiResponse => {
                                    Swal.close();
                                    if (apiResponse.success) {
                                        const data = apiResponse.data;
                                        const form = document.getElementById('productForm');
                                        form.reset();

                                        document.getElementById('modal-productId').value = data.product.productId;
                                        document.getElementById('productModalTitle').innerHTML = `
                    <span class="material-symbols-outlined text-[24px]">edit</span>
                    Chỉnh sửa thông tin sản phẩm
                `;
                                        document.getElementById('modal-submit-btn').textContent = 'Lưu thay đổi';

                                        // Show edit-only sections
                                        document.getElementById('modal-status-container').classList.remove('hidden');
                                        document.getElementById('modal-status').value = data.product.status || 'ACTIVE';
                                        document.getElementById('modal-existing-images-section').classList.remove('hidden');

                                        // Populate fields
                                        document.getElementById('modal-name').value = data.product.name;
                                        document.getElementById('modal-description').value = data.product.description || '';
                                        document.getElementById('modal-categoryId').value = data.product.categoryId;
                                        document.getElementById('modal-originCountry').value = data.product.originCountry || '';
                                        document.getElementById('modal-originRegion').value = data.product.originRegion || '';
                                        document.getElementById('modal-harvestDate').value = data.product.harvestDate || '';
                                        document.getElementById('modal-shelfLifeDays').value = data.product.shelfLifeDays || '';
                                        document.getElementById('modal-storageInstruction').value = data.product.storageInstruction || '';

                                        // Image file input not required since images already exist
                                        const imageInput = document.getElementById('modal-images-input');
                                        imageInput.value = '';
                                        imageInput.required = false;
                                        document.getElementById('modal-image-required-star').classList.add('hidden');

                                        // Verification document not required since it already exists
                                        const docInput = document.getElementById('modal-verificationDoc');
                                        docInput.value = '';
                                        docInput.required = false;
                                        document.getElementById('modal-doc-required-star').classList.add('hidden');

                                        // Show current document link if exists
                                        const docContainer = document.getElementById('modal-current-doc-container');
                                        const docLink = document.getElementById('modal-current-doc-link');
                                        if (data.product.verificationDocPath) {
                                            let path = data.product.verificationDocPath;
                                            if (path.startsWith('build/')) path = path.substring(6);
                                            docLink.href = CTX + '/' + path;
                                            docContainer.classList.remove('hidden');
                                        } else {
                                            docContainer.classList.add('hidden');
                                        }

                                        // Reset new file accumulator
                                        newImageFiles = new DataTransfer();
                                        document.getElementById('modal-file-list-preview').innerHTML = '';
                                        document.getElementById('modal-file-list-preview').classList.add('hidden');

                                        // Render existing images with drag-drop reorder + set-primary + delete
                                        const existingImagesContainer = document.getElementById('modal-existing-images');
                                        existingImagesContainer.innerHTML = '';
                                        if (data.images && data.images.length > 0) {
                                            data.images.forEach(img => {
                                                appendExistingImageCard(img, data.product.productId);
                                            });
                                            // Init once via event delegation — handles future DOM changes too
                                            initImageDragDrop(existingImagesContainer);
                                        } else {
                                            existingImagesContainer.innerHTML = '<p class="text-xs text-txt-3 italic py-4">Sản phẩm hiện chưa có hình ảnh nào.</p>';
                                        }

                                        // Render variants list
                                        const variantsContainer = document.getElementById('modal-variants-container');
                                        variantsContainer.innerHTML = '';
                                        if (data.variants && data.variants.length > 0) {
                                            data.variants.forEach(variant => {
                                                addVariantRow(variant);
                                            });
                                        } else {
                                            addVariantRow({ variantLabel: 'kg', price: '', stockQuantity: '' });
                                        }

                                        // Populate checkboxes & seasons
                                        document.getElementById('modal-isOrganic').checked = data.product.isOrganic;
                                        document.getElementById('modal-isImported').checked = data.product.isImported;
                                        document.getElementById('modal-seasonStartMonth').value = data.product.seasonStartMonth || '';
                                        document.getElementById('modal-seasonEndMonth').value = data.product.seasonEndMonth || '';

                                        // Render packaging list
                                        const packagingContainer = document.getElementById('modal-packaging-container');
                                        packagingContainer.innerHTML = '';
                                        if (data.packagingOptions && data.packagingOptions.length > 0) {
                                            data.packagingOptions.forEach(opt => {
                                                addPackagingRow(opt);
                                            });
                                        }

                                        document.getElementById('productModal').classList.remove('hidden');
                                    } else {
                                        Swal.fire({
                                            icon: 'error',
                                            title: 'Lỗi',
                                            text: apiResponse.error || apiResponse.message || 'Không thể tải thông tin sản phẩm.',
                                            confirmButtonColor: '#4d661c'
                                        });
                                    }
                                })
                                .catch(err => {
                                    console.error(err);
                                    Swal.fire({
                                        icon: 'error',
                                        title: 'Lỗi',
                                        text: err.message || 'Lỗi kết nối máy chủ.',
                                        confirmButtonColor: '#4d661c'
                                    });
                                });
                        }

                        function closeProductModal() {
                            document.getElementById('productModal').classList.add('hidden');
                        }

                        // ─── Image management helpers ───────────────────────────────────────────

                        function appendExistingImageCard(img, productId) {
                            const container = document.getElementById('modal-existing-images');
                            const card = document.createElement('div');
                            card.id = 'image-card-modal-' + img.imageId;
                            card.className = 'img-card relative rounded-xl overflow-hidden aspect-square border bg-white p-1 group shadow-sm ' + (img.isPrimary ? 'border-primary' : 'border-gray-200');
                            card.setAttribute('draggable', 'true');
                            card.dataset.imageId = img.imageId;

                            let path = img.filePath || '';
                            if (path.startsWith('build/')) path = path.substring(6);

                            const altText = img.isPrimary ? 'Ảnh chính' : 'Ảnh phụ';
                            const badgeClass = img.isPrimary ? 'bg-primary text-white' : 'bg-white/90 text-txt-2';

                            let primaryBtnHtml = '';
                            if (!img.isPrimary) {
                                primaryBtnHtml = '<button type="button" title="Đặt làm ảnh chính" ' +
                                    'onclick="setExistingImagePrimary(' + img.imageId + ', ' + productId + ')" ' +
                                    'class="w-8 h-8 rounded-full bg-amber-400 hover:bg-amber-500 text-white flex items-center justify-center shadow active:scale-90 transition-transform cursor-pointer border-0 text-[13px]">' +
                                    '⭐' +
                                    '</button>';
                            }

                            card.innerHTML =
                                '<img src="' + CTX + '/' + path + '" alt="' + altText + '" class="w-full h-full object-cover rounded-lg">' +
                                '<div class="absolute top-1.5 left-1.5 z-10">' +
                                '<span class="text-[8px] font-bold px-1.5 py-0.5 rounded shadow-sm ' + badgeClass + '">' +
                                altText +
                                '</span>' +
                                '</div>' +
                                '<div class="absolute inset-1 rounded-lg bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity duration-200 flex items-center justify-center gap-2">' +
                                primaryBtnHtml +
                                '<button type="button" title="Xóa ảnh" ' +
                                'onclick="deleteExistingImageModal(' + img.imageId + ')" ' +
                                'class="w-8 h-8 rounded-full bg-red-600 hover:bg-red-700 text-white flex items-center justify-center shadow active:scale-90 transition-transform cursor-pointer border-0">' +
                                '<span class="material-symbols-outlined text-[16px]">delete</span>' +
                                '</button>' +
                                '</div>';

                            container.appendChild(card);
                        }

                        function setExistingImagePrimary(imageId, productId) {
                            const params = new URLSearchParams();
                            params.append('action', 'set-primary');
                            params.append('imageId', imageId);
                            params.append('productId', productId);
                            params.append('_csrf', window.csrfToken || CSRF);

                            fetch(CTX + '/shop/product-status', {
                                method: 'POST',
                                headers: {
                                    'Content-Type': 'application/x-www-form-urlencoded',
                                    'X-CSRF-Token': window.csrfToken || CSRF,
                                    'X-Requested-With': 'XMLHttpRequest'
                                },
                                body: params
                            })
                                .then(handleJSONResponse)
                                .then(data => {
                                    if (data.success) {
                                        // Re-render all existing image cards with updated primary state
                                        const container = document.getElementById('modal-existing-images');
                                        container.querySelectorAll('.img-card').forEach(c => {
                                            const cid = parseInt(c.dataset.imageId);
                                            const isPrimary = cid === imageId;
                                            const badge = c.querySelector('.absolute.top-1\.5.left-1\.5 span');
                                            if (badge) {
                                                badge.textContent = isPrimary ? '\u2b50 \u1ea2nh ch\u00ednh' : '\u1ea2nh ph\u1ee5';
                                                badge.className = 'text-[8px] font-bold px-1.5 py-0.5 rounded shadow-sm ' + (isPrimary ? 'bg-primary text-white' : 'bg-white/90 text-txt-2');
                                            }
                                            c.className = c.className.replace(/border-primary|border-gray-200/g, isPrimary ? 'border-primary' : 'border-gray-200');
                                        });
                                        Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: 'Đã đặt làm ảnh chính!', showConfirmButton: false, timer: 1800, timerProgressBar: true });
                                    } else {
                                        Swal.fire({ icon: 'error', title: 'Lỗi', text: data.message || 'Không thể cập nhật.', confirmButtonColor: '#4d661c' });
                                    }
                                })
                                .catch(err => {
                                    handleAjaxError(err, "Lỗi kết nối máy chủ khi cập nhật ảnh chính.");
                                });
                        }

                        function initImageDragDrop(container) {
                            // Use event delegation — works even after DOM mutations (delete/add)
                            let dragSrc = null;

                            container.addEventListener('dragstart', function (e) {
                                const card = e.target.closest('.img-card');
                                if (!card) return;
                                dragSrc = card;
                                card.classList.add('dragging');
                                e.dataTransfer.effectAllowed = 'move';
                            });
                            container.addEventListener('dragend', function (e) {
                                const card = e.target.closest('.img-card');
                                if (!card) return;
                                card.classList.remove('dragging');
                                container.querySelectorAll('.img-card').forEach(c => c.classList.remove('drag-over'));
                                // Persist new order after drag ends
                                const ids = Array.from(container.querySelectorAll('.img-card'))
                                    .map(c => c.dataset.imageId).filter(Boolean);
                                if (ids.length === 0) return;
                                const params = new URLSearchParams();
                                params.append('action', 'reorder-images');
                                params.append('imageIds', ids.join(','));
                                params.append('_csrf', window.csrfToken || CSRF);
                                fetch(CTX + '/shop/product-status', {
                                    method: 'POST',
                                    headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'X-CSRF-Token': window.csrfToken || CSRF, 'X-Requested-With': 'XMLHttpRequest' },
                                    body: params
                                }).catch(err => console.warn('Reorder save failed:', err));
                            });
                            container.addEventListener('dragover', function (e) {
                                e.preventDefault();
                                e.dataTransfer.dropEffect = 'move';
                                const card = e.target.closest('.img-card');
                                if (card && card !== dragSrc) {
                                    container.querySelectorAll('.img-card').forEach(c => c.classList.remove('drag-over'));
                                    card.classList.add('drag-over');
                                }
                            });
                            container.addEventListener('dragleave', function (e) {
                                const card = e.target.closest('.img-card');
                                if (card) card.classList.remove('drag-over');
                            });
                            container.addEventListener('drop', function (e) {
                                e.preventDefault();
                                const targetCard = e.target.closest('.img-card');
                                if (!targetCard) return;
                                targetCard.classList.remove('drag-over');
                                if (dragSrc && targetCard !== dragSrc) {
                                    const allCards = Array.from(container.querySelectorAll('.img-card'));
                                    const srcIdx = allCards.indexOf(dragSrc);
                                    const tgtIdx = allCards.indexOf(targetCard);
                                    if (srcIdx < tgtIdx) container.insertBefore(dragSrc, targetCard.nextSibling);
                                    else container.insertBefore(dragSrc, targetCard);
                                }
                            });
                        }

                        // ─── New image file previews (accumulates; individual delete) ─────────────
                        // We store selected files in a DataTransfer object to allow removing individual files
                        let newImageFiles = new DataTransfer();

                        function addNewImagePreviews(input) {
                            // Accumulate new files without clearing existing ones
                            Array.from(input.files).forEach(f => newImageFiles.items.add(f));
                            input.value = ''; // reset so same file can be selected again if needed

                            // Sync the actual input files
                            const realInput = document.getElementById('modal-images-input');
                            realInput.files = newImageFiles.files;

                            renderNewImagePreviews();
                        }

                        function removeNewImage(index) {
                            const newDT = new DataTransfer();
                            Array.from(newImageFiles.files).forEach((f, i) => {
                                if (i !== index) newDT.items.add(f);
                            });
                            newImageFiles = newDT;
                            const realInput = document.getElementById('modal-images-input');
                            realInput.files = newImageFiles.files;
                            renderNewImagePreviews();
                        }

                        function renderNewImagePreviews() {
                            const previewContainer = document.getElementById('modal-file-list-preview');
                            previewContainer.innerHTML = '';
                            const files = newImageFiles.files;
                            if (files.length === 0) {
                                previewContainer.classList.add('hidden');
                                return;
                            }
                            previewContainer.classList.remove('hidden');
                            // Check if there are existing images to determine if the first new image will be primary
                            const existingCount = document.querySelectorAll('#modal-existing-images .img-card').length;
                            Array.from(files).forEach((file, index) => {
                                const isPrimary = existingCount === 0 && index === 0;
                                const card = document.createElement('div');
                                card.className = 'new-img-card';
                                const reader = new FileReader();
                                reader.onload = e => {
                                    const resultSrc = e.target.result;
                                    const fname = file.name;
                                    const badgeClass = isPrimary ? 'badge-primary' : 'badge-secondary';
                                    const badgeText = isPrimary ? '\u2b50 Ch\u00ednh' : 'Ph\u1ee5 ' + (index + 1);
                                    card.innerHTML = '<img src="' + resultSrc + '" alt="' + fname + '" class="w-full h-full object-cover">'
                                        + '<span class="' + badgeClass + '">' + badgeText + '</span>'
                                        + '<button class="btn-rm" type="button" onclick="removeNewImage(' + index + ')" title="X\u00f3a \u1ea3nh n\u00e0y">\u2715</button>';
                                };
                                reader.readAsDataURL(file);
                                previewContainer.appendChild(card);
                            });
                        }

                        // ─── Variant rows ─────────────────────────────────────────────────────────
                        function addVariantRow(data = {}) {
                            const container = document.getElementById('modal-variants-container');
                            const isEditMode = !!document.getElementById('modal-productId').value;
                            const row = document.createElement('div');
                            row.className = "variant-row bg-slate-50/70 border border-border p-4 rounded-xl relative group flex flex-col gap-3 transition-all hover:bg-slate-50";

                            const variantId = data.variantId || '';
                            const variantLabel = data.variantLabel || '';
                            const price = data.price !== undefined ? data.price : '';
                            const stock = data.stockQuantity !== undefined ? data.stockQuantity : '';
                            const weightKg = data.weightKg !== undefined ? data.weightKg : '1.000';
                            const discountPrice = data.discountPrice !== undefined && data.discountPrice !== null ? data.discountPrice : '';
                            let discountStart = data.discountStart !== undefined && data.discountStart !== null ? data.discountStart : '';
                            let discountEnd = data.discountEnd !== undefined && data.discountEnd !== null ? data.discountEnd : '';
                            if (discountStart && discountStart.length > 16) discountStart = discountStart.substring(0, 16);
                            if (discountEnd && discountEnd.length > 16) discountEnd = discountEnd.substring(0, 16);

                            const nowLocal = new Date(Date.now() - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 16);
                            let minStart = discountStart ? discountStart : nowLocal;
                            let minEnd = discountStart ? discountStart : nowLocal;

                            row.innerHTML =
                                '<input type="hidden" name="variantId" value="' + variantId + '">' +
                                '<input type="hidden" name="variantStock" value="' + stock + '">' +
                                '<div class="grid grid-cols-1 md:grid-cols-12 gap-3 items-end w-full">' +
                                '<!-- Variant Name/Label -->' +
                                '<div class="col-span-1 md:col-span-4">' +
                                '<label class="block text-[10px] font-bold text-txt-2 mb-1">Tên phân loại / Đơn vị <span class="text-red-500">*</span></label>' +
                                '<input type="text" name="variantLabel" required placeholder="Ví dụ: kg, Hộp 500g, Thùng 5kg" ' +
                                'value="' + variantLabel + '" ' +
                                'class="form-control-custom py-1.5 text-xs">' +
                                '</div>' +
                                '<!-- Price -->' +
                                '<div class="col-span-1 md:col-span-3">' +
                                '<label class="block text-[10px] font-bold text-txt-2 mb-1">Giá bán lẻ (VND) <span class="text-red-500">*</span></label>' +
                                '<div class="relative rounded-xl">' +
                                '<input type="number" name="variantPrice" required min="1000" step="1000" placeholder="50000" ' +
                                'value="' + price + '" ' +
                                'class="form-control-custom py-1.5 text-xs pr-10">' +
                                '<span class="absolute right-3 top-1/2 -translate-y-1/2 text-[10px] text-txt-3 font-bold">VND</span>' +
                                '</div>' +
                                '</div>' +
                                '<!-- Weight (Kg) -->' +
                                '<div class="col-span-1 md:col-span-3">' +
                                '<label class="block text-[10px] font-bold text-txt-2 mb-1">Cân nặng (Kg) <span class="text-red-500">*</span></label>' +
                                '<div class="relative rounded-xl">' +
                                '<input type="number" name="variantWeight" required min="0.001" step="0.001" placeholder="1.0" ' +
                                'value="' + weightKg + '" ' +
                                'class="form-control-custom py-1.5 text-xs pr-8">' +
                                '<span class="absolute right-3 top-1/2 -translate-y-1/2 text-[10px] text-txt-3 font-bold">Kg</span>' +
                                '</div>' +
                                '</div>' +
                                '<!-- Delete button -->' +
                                '<div class="col-span-1 md:col-span-2 flex justify-end pb-0.5">' +
                                '<button type="button" onclick="removeVariantRow(this)" class="w-8 h-8 rounded-lg bg-red-50 hover:bg-red-100 text-red-600 flex items-center justify-center border-0 cursor-pointer transition-colors active:scale-95">' +
                                '<span class="material-symbols-outlined text-[16px]">delete</span>' +
                                '</button>' +
                                '</div>' +
                                '</div>' +
                                '<!-- Discount section -->' +
                                '<div class="bg-primary/5 p-3 rounded-lg border border-primary/10 mt-2">' +
                                '<div class="flex items-center gap-2 mb-2">' +
                                '<span class="material-symbols-outlined text-[16px] text-primary">sell</span>' +
                                '<span class="text-[10px] font-bold text-primary uppercase tracking-wider">Giảm giá sản phẩm (Tùy chọn)</span>' +
                                '</div>' +
                                '<div class="grid grid-cols-1 md:grid-cols-3 gap-3">' +
                                '<div>' +
                                '<label class="block text-[9px] font-bold text-txt-2 mb-1">Giá khuyến mãi (VND)</label>' +
                                '<input type="number" name="variantDiscountPrice" min="0" step="1000" placeholder="Giá sau giảm" ' +
                                'value="' + discountPrice + '" ' +
                                'class="form-control-custom py-1 text-xs">' +
                                '</div>' +
                                '<div>' +
                                '<label class="block text-[9px] font-bold text-txt-2 mb-1">Thời gian bắt đầu</label>' +
                                '<input type="datetime-local" name="variantDiscountStart" ' +
                                'value="' + discountStart + '" ' +
                                'data-original="' + discountStart + '" ' +
                                'min="' + minStart + '" ' +
                                'onchange="validateDiscountDateInput(this)" ' +
                                'class="form-control-custom py-1 text-xs">' +
                                '</div>' +
                                '<div>' +
                                '<label class="block text-[9px] font-bold text-txt-2 mb-1">Thời gian kết thúc</label>' +
                                '<input type="datetime-local" name="variantDiscountEnd" ' +
                                'value="' + discountEnd + '" ' +
                                'data-original="' + discountEnd + '" ' +
                                'min="' + minEnd + '" ' +
                                'onchange="validateDiscountDateInput(this)" ' +
                                'class="form-control-custom py-1 text-xs">' +
                                '</div>' +
                                '</div>' +
                                '</div>';

                            container.appendChild(row);
                            updateVariantDeleteButtons();
                        }

                        function removeVariantRow(button) {
                            const row = button.closest('.variant-row');
                            row.remove();
                            updateVariantDeleteButtons();
                        }

                        function updateVariantDeleteButtons() {
                            const rows = document.querySelectorAll('.variant-row');
                            rows.forEach(row => {
                                const deleteBtn = row.querySelector('button[onclick="removeVariantRow(this)"]');
                                if (deleteBtn) {
                                    deleteBtn.style.display = rows.length <= 1 ? 'none' : 'flex';
                                }
                            });
                        }

                        // ─── Packaging options ──────────────────────────────────────────────────
                        function addPackagingRow(data = {}) {
                            const container = document.getElementById('modal-packaging-container');
                            const row = document.createElement('div');
                            row.className = "packaging-row bg-slate-50/70 border border-border p-3 rounded-xl relative flex flex-col md:flex-row gap-3 items-end transition-all hover:bg-slate-50";

                            const packagingId = data.packagingId || '';
                            const label = data.label || '';
                            const priceAdd = data.priceAdd !== undefined ? data.priceAdd : '';

                            row.innerHTML =
                                '<input type="hidden" name="packagingId" value="' + packagingId + '">' +
                                '<!-- Packaging Label -->' +
                                '<div class="flex-grow w-full">' +
                                '<label class="block text-[10px] font-bold text-txt-2 mb-1">Tên loại đóng gói <span class="text-red-500">*</span></label>' +
                                '<input type="text" name="packagingLabel" required placeholder="Ví dụ: Hộp gỗ cao cấp, Khay xốp bảo vệ" ' +
                                'value="' + label + '" ' +
                                'class="form-control-custom py-1.5 text-xs">' +
                                '</div>' +
                                '<!-- Price Add -->' +
                                '<div class="w-full md:w-48">' +
                                '<label class="block text-[10px] font-bold text-txt-2 mb-1">Phụ phí cộng thêm (VND) <span class="text-red-500">*</span></label>' +
                                '<div class="relative rounded-xl">' +
                                '<input type="number" name="packagingPriceAdd" required min="0" step="1000" placeholder="10000" ' +
                                'value="' + priceAdd + '" ' +
                                'class="form-control-custom py-1.5 text-xs pr-10">' +
                                '<span class="absolute right-3 top-1/2 -translate-y-1/2 text-[10px] text-txt-3 font-bold">VND</span>' +
                                '</div>' +
                                '</div>' +
                                '<!-- Delete button -->' +
                                '<div class="flex shrink-0 items-center justify-center pb-0.5">' +
                                '<button type="button" onclick="removePackagingRow(this)" class="w-8 h-8 rounded-lg bg-red-50 hover:bg-red-100 text-red-600 flex items-center justify-center border-0 cursor-pointer transition-colors active:scale-95">' +
                                '<span class="material-symbols-outlined text-[16px]">delete</span>' +
                                '</button>' +
                                '</div>';
                            container.appendChild(row);
                        }

                        function removePackagingRow(button) {
                            button.closest('.packaging-row').remove();
                        }

                        function deleteExistingImageModal(imageId) {
                            Swal.fire({
                                title: 'Xác nhận xóa?',
                                text: 'Bạn có chắc chắn muốn xóa bức ảnh này? Tệp ảnh sẽ bị xóa vĩnh viễn khỏi máy chủ.',
                                icon: 'warning',
                                showCancelButton: true,
                                confirmButtonColor: '#d33',
                                cancelButtonColor: '#4d661c',
                                confirmButtonText: 'Đồng ý xóa',
                                cancelButtonText: 'Hủy bỏ',
                                background: '#ffffff',
                                customClass: {
                                    popup: 'rounded-2xl font-sans'
                                }
                            }).then((result) => {
                                if (result.isConfirmed) {
                                    const card = document.getElementById('image-card-modal-' + imageId);
                                    if (!card) return;

                                    const params = new URLSearchParams();
                                    params.append('action', 'delete-image');
                                    params.append('imageId', imageId);
                                    params.append('_csrf', window.csrfToken || CSRF);

                                    fetch(CTX + '/shop/product-status', {
                                        method: 'POST',
                                        headers: {
                                            'Content-Type': 'application/x-www-form-urlencoded',
                                            'X-CSRF-Token': window.csrfToken || CSRF,
                                            'X-Requested-With': 'XMLHttpRequest'
                                        },
                                        body: params
                                    })
                                        .then(handleJSONResponse)
                                        .then(data => {
                                            if (data.success) {
                                                card.classList.add('img-card-fadeout');
                                                setTimeout(() => {
                                                    card.remove();
                                                }, 400);
                                                Swal.fire({
                                                    icon: 'success',
                                                    title: 'Đã xóa!',
                                                    text: 'Hình ảnh đã được xóa thành công.',
                                                    confirmButtonColor: '#4d661c',
                                                    timer: 1500,
                                                    showConfirmButton: false
                                                });
                                            } else {
                                                Swal.fire({
                                                    icon: 'error',
                                                    title: 'Lỗi',
                                                    text: data.message || "Không thể xóa ảnh.",
                                                    confirmButtonColor: '#4d661c'
                                                });
                                            }
                                        })
                                        .catch(err => {
                                            handleAjaxError(err, "Lỗi kết nối máy chủ khi xóa hình ảnh.");
                                        });
                                }
                            });
                        }

                        function submitProductForm(event) {
                            event.preventDefault();
                            const form = document.getElementById('productForm');

                            // Client-side validation: Discount dates
                            const variantRows = document.querySelectorAll('.variant-row');
                            const now = new Date();
                            const errors = [];

                            variantRows.forEach((row, index) => {
                                const labelInput = row.querySelector('[name="variantLabel"]');
                                const label = (labelInput && labelInput.value.trim()) || `số ${index + 1}`;
                                const priceInput = row.querySelector('[name="variantPrice"]');
                                const price = parseFloat(priceInput.value) || 0;

                                const dpInput = row.querySelector('[name="variantDiscountPrice"]');
                                const dsInput = row.querySelector('[name="variantDiscountStart"]');
                                const deInput = row.querySelector('[name="variantDiscountEnd"]');

                                const dpVal = dpInput ? dpInput.value.trim() : '';
                                const dsVal = dsInput ? dsInput.value.trim() : '';
                                const deVal = deInput ? deInput.value.trim() : '';

                                const hasDp = dpVal !== '';
                                const hasDs = dsVal !== '';
                                const hasDe = deVal !== '';

                                if (hasDp || hasDs || hasDe) {
                                    if (!hasDp || !hasDs || !hasDe) {
                                        errors.push(`Phân loại "${label}": Cấu hình giảm giá phải điền đầy đủ cả giá khuyến mãi, ngày bắt đầu và ngày kết thúc.`);
                                    } else {
                                        const dp = parseFloat(dpVal) || 0;
                                        if (dp < 0) {
                                            errors.push(`Phân loại "${label}": Giá khuyến mãi không được âm.`);
                                        }
                                        if (dp >= price) {
                                            errors.push(`Phân loại "${label}": Giá khuyến mãi phải nhỏ hơn giá gốc.`);
                                        }

                                        const ds = new Date(dsVal);
                                        const de = new Date(deVal);

                                        if (isNaN(ds.getTime())) {
                                            errors.push(`Phân loại "${label}": Ngày bắt đầu giảm giá không hợp lệ.`);
                                        }
                                        if (isNaN(de.getTime())) {
                                            errors.push(`Phân loại "${label}": Ngày kết thúc giảm giá không hợp lệ.`);
                                        }

                                        if (!isNaN(ds.getTime()) && !isNaN(de.getTime())) {
                                            // Only check past date if it is changed or if it is a new variant
                                            const originalDsVal = dsInput.dataset.original || '';
                                            const originalDeVal = deInput.dataset.original || '';
                                            const dsChanged = originalDsVal === '' || dsVal !== originalDsVal;
                                            const deChanged = originalDeVal === '' || deVal !== originalDeVal;

                                            // 5-minute grace period
                                            const compareTime = new Date(now.getTime() - 5 * 60 * 1000);

                                            if (dsChanged && ds < compareTime) {
                                                errors.push(`Phân loại "${label}": Ngày bắt đầu giảm giá không được ở trong quá khứ.`);
                                            }
                                            if (deChanged && de < compareTime) {
                                                errors.push(`Phân loại "${label}": Ngày kết thúc giảm giá không được ở trong quá khứ.`);
                                            }
                                            if (de <= ds) {
                                                errors.push(`Phân loại "${label}": Ngày kết thúc giảm giá phải sau ngày bắt đầu.`);
                                            }
                                        }
                                    }
                                }
                            });

                            if (errors.length > 0) {
                                let errorHtml = '<ul class="list-disc list-inside text-left text-xs font-semibold text-red-600 space-y-1">';
                                errors.forEach(err => {
                                    errorHtml += '<li>' + err + '</li>';
                                });
                                errorHtml += '</ul>';

                                Swal.fire({
                                    icon: 'error',
                                    title: 'Lỗi thông tin',
                                    html: errorHtml,
                                    confirmButtonColor: '#4d661c'
                                });
                                return;
                            }

                            const formData = new FormData(form);

                            const productId = document.getElementById('modal-productId').value;
                            const isEdit = !!productId;
                            const url = CTX + (isEdit ? '/shop/product-edit' : '/shop/product-create');

                            Swal.fire({
                                title: isEdit ? 'Đang lưu thay đổi...' : 'Đang lưu sản phẩm...',
                                text: 'Vui lòng chờ trong giây lát',
                                allowOutsideClick: false,
                                didOpen: () => {
                                    Swal.showLoading();
                                }
                            });

                            // Ensure CSRF token is in formData (for multipart, req.getParameter won't find it)
                            const token = window.csrfToken || CSRF;
                            formData.set('_csrf', token);

                            fetch(url, {
                                method: 'POST',
                                headers: {
                                    'X-Requested-With': 'XMLHttpRequest',
                                    'X-CSRF-Token': token
                                },
                                body: formData
                            })
                                .then(handleJSONResponse)
                                .then(data => {
                                    if (data.success) {
                                        Swal.fire({
                                            icon: 'success',
                                            title: 'Thành công!',
                                            text: (data.data && data.data.message) || data.message || (isEdit ? 'Thông tin sản phẩm đã được cập nhật.' : 'Sản phẩm mới đã được đăng bán.'),
                                            confirmButtonColor: '#4d661c'
                                        }).then(() => {
                                            closeProductModal();
                                            window.location.reload();
                                        });
                                    } else {
                                        let errorHtml = '<ul class="list-disc list-inside text-left text-xs font-semibold text-red-600 space-y-1">';
                                        if (data.errors) {
                                            data.errors.forEach(err => {
                                                errorHtml += '<li>' + err + '</li>';
                                            });
                                        } else {
                                            errorHtml += '<li>' + (data.error || (data.data && data.data.message) || data.message || 'Lỗi không xác định') + '</li>';
                                        }
                                        errorHtml += '</ul>';

                                        Swal.fire({
                                            icon: 'error',
                                            title: 'Lỗi thông tin',
                                            html: errorHtml,
                                            confirmButtonColor: '#4d661c'
                                        });
                                    }
                                })
                                .catch(err => {
                                    handleAjaxError(err, "Lỗi kết nối máy chủ khi lưu sản phẩm.");
                                });
                        }

                        function validateDiscountDateInput(input) {
                            const val = input.value.trim();
                            if (val === '') return;

                            const selectedDate = new Date(val);
                            if (isNaN(selectedDate.getTime())) return;

                            const originalVal = input.dataset.original || '';
                            const isChanged = originalVal === '' || val !== originalVal;

                            if (isChanged) {
                                const now = new Date();
                                // Grace period of 5 minutes to prevent normal delay alert issues
                                const compareTime = new Date(now.getTime() - 5 * 60 * 1000);

                                if (selectedDate < compareTime) {
                                    const row = input.closest('.variant-row');
                                    const labelInput = row ? row.querySelector('[name="variantLabel"]') : null;
                                    const label = (labelInput && labelInput.value.trim()) || 'phân loại';
                                    const fieldName = input.name === 'variantDiscountStart' ? 'bắt đầu' : 'kết thúc';

                                    Swal.fire({
                                        icon: 'warning',
                                        title: 'Ngày không hợp lệ',
                                        text: `Phân loại "${label}": Ngày ${fieldName} giảm giá không được ở trong quá khứ.`,
                                        confirmButtonColor: '#4d661c'
                                    });

                                    input.value = originalVal;
                                    return;
                                }
                            }

                            // Verify that discount end date is after start date
                            const row = input.closest('.variant-row');
                            if (!row) return;
                            const dsInput = row.querySelector('[name="variantDiscountStart"]');
                            const deInput = row.querySelector('[name="variantDiscountEnd"]');

                            // Dynamically update min of end date picker when start date is changed
                            if (input.name === 'variantDiscountStart' && deInput) {
                                deInput.min = input.value || new Date(Date.now() - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 16);
                            }

                            if (dsInput && deInput && dsInput.value.trim() !== '' && deInput.value.trim() !== '') {
                                const ds = new Date(dsInput.value.trim());
                                const de = new Date(deInput.value.trim());
                                if (!isNaN(ds.getTime()) && !isNaN(de.getTime()) && de <= ds) {
                                    const labelInput = row.querySelector('[name="variantLabel"]');
                                    const label = (labelInput && labelInput.value.trim()) || 'phân loại';
                                    Swal.fire({
                                        icon: 'warning',
                                        title: 'Ngày không hợp lệ',
                                        text: `Phân loại "${label}": Ngày kết thúc giảm giá phải sau ngày bắt đầu.`,
                                        confirmButtonColor: '#4d661c'
                                    });
                                    input.value = originalVal;
                                }
                            }
                        }
                    </script>
                </body>

                </html>
