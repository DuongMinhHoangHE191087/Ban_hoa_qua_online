<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
    <%@ taglib prefix="c" uri="jakarta.tags.core" %>
        <%@ taglib prefix="ft" uri="/WEB-INF/tld/fruitmkt.tld" %>
            <!DOCTYPE html>
            <html lang="vi">

            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Quản lý Tồn kho | MetaFruit</title>
                <link rel="icon" type="image/png" href="${pageContext.request.contextPath}/favicon.png">

                <link rel="icon" type="image/png" href="${pageContext.request.contextPath}/favicon.png">

                <!-- Google Fonts & Icons -->
                <link rel="preconnect" href="https://fonts.googleapis.com">
                <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
                <link href="https://fonts.googleapis.com/css2?family=Lexend:wght@300;400;500;600;700;800&display=swap"
                    rel="stylesheet">
                <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/fontawesome.all.min.css">
                <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/main.css">
                <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/ui-overrides.css">

                <!-- Tailwind & SweetAlert -->
                <jsp:include page="/WEB-INF/jsp/common/tailwind-config.jsp" />
                <script src="${pageContext.request.contextPath}/assets/js/sweetalert2.all.min.js"></script>

            </head>

            <body class="antialiased text-txt bg-background">
                <div class="flex min-h-screen">

                    <!-- Shared Sidebar -->
                    <jsp:include page="/WEB-INF/jsp/common/shop-sidebar.jsp">
                        <jsp:param name="activePage" value="inventory" />
                    </jsp:include>

                    <!-- Main Content -->
                    <main class="flex-1 p-6 md:p-8 overflow-y-auto animate-fade-in-up opacity-0">

                        <!-- Page Header -->
                        <div
                            class="flex items-center justify-between bg-gradient-to-r from-primary-lt to-secondary-container/20 border border-primary-fixed/60 p-6 rounded-2xl shadow-sm mb-8">
                            <div>
                                <h1 class="text-xl md:text-2xl font-extrabold text-primary-dark tracking-tight">Nhập
                                    hàng &amp; Tồn kho</h1>
                                <p class="text-txt-2 text-xs md:text-sm mt-1">Nhập thêm hàng vào kho, xem lịch sử và số
                                    lượng phân loại hiện tại.</p>
                            </div>
                            <div
                                class="hidden md:flex items-center gap-2 bg-surface/80 border border-primary-fixed/80 px-4 py-2 rounded-xl text-primary-dark shadow-sm">
                                <i class="fa-solid fa-warehouse text-primary"></i>
                                <span class="text-xs font-bold uppercase tracking-wider">Tồn kho</span>
                            </div>
                        </div>



                        <!-- Database Schema Error -->
                        <c:if test="${not empty inventoryError}">
                            <div
                                class="flex items-center gap-3 p-4 mb-6 rounded-2xl border-l-4 border-amber-500 bg-amber-50 text-amber-800 shadow-sm text-sm font-semibold">
                                <i class="fa-solid fa-triangle-exclamation text-amber-600"></i>
                                <span class="flex-1">
                                    <c:out value="${inventoryError}" />
                                </span>
                            </div>
                        </c:if>

                        <!-- Main Grid: Form + Tables -->
                        <div class="grid grid-cols-1 lg:grid-cols-5 gap-6">

                            <!-- Left: Restock Form (2 cols) -->
                            <div class="lg:col-span-2">
                                <div class="glass-card rounded-2xl overflow-hidden">
                                    <div class="flex items-center gap-3 p-5 border-b border-[#e2ece7] bg-[#f9fdf9]">
                                        <div
                                            class="w-9 h-9 rounded-xl bg-[#edf7f2] text-primary flex items-center justify-center">
                                            <i class="fa-solid fa-plus"></i>
                                        </div>
                                        <h2 class="text-sm font-bold text-txt">Nhập kho sản phẩm</h2>
                                    </div>
                                    <div class="p-5">
                                        <form action="${pageContext.request.contextPath}/shop/inventory" method="POST"
                                            id="restockForm">
                                            <input type="hidden" name="_csrf" value="${sessionScope._csrfToken}">

                                            <div class="mb-4">
                                                <label class="block text-xs font-bold text-txt-2 mb-2" for="actionType">
                                                    Loại tác vụ <span class="text-red-500">*</span>
                                                </label>
                                                <select name="actionType" id="actionType" required
                                                    class="w-full px-4 py-2.5 border border-border rounded-xl text-sm bg-white focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all">
                                                    <option value="RESTOCK" ${oldActionType == 'RESTOCK' ? 'selected' : ''}>Nhập hàng</option>
                                                    <option value="REDUCE" ${oldActionType == 'REDUCE' ? 'selected' : ''}>Báo cáo Hao hụt/Hỏng</option>
                                                </select>
                                            </div>

                                            <div class="mb-4">
                                                <label class="block text-xs font-bold text-txt-2 mb-2" for="variantId">
                                                    Sản phẩm &amp; Phân loại <span class="text-red-500">*</span>
                                                </label>
                                                <select name="variantId" id="variantId" required
                                                    class="w-full px-4 py-2.5 border border-border rounded-xl text-sm bg-white focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all">
                                                    <option value="" disabled ${empty oldVariantId ? 'selected' : ''}>-- Chọn phân loại sản phẩm --</option>
                                                    <c:forEach var="v" items="${variants}">
                                                        <option value="${v.variantId}" data-shelflife="${v.shelfLifeDays}" data-name="${v.productName} - ${v.variantLabel}" ${oldVariantId == v.variantId ? 'selected' : ''}>
                                                            ${v.productName} - ${v.variantLabel} (Hiện tại: ${v.stockQuantity})
                                                        </option>
                                                    </c:forEach>
                                                </select>
                                            </div>

                                            <div class="mb-4">
                                                <label class="block text-xs font-bold text-txt-2 mb-2" for="quantity">
                                                    Số lượng <span class="text-red-500">*</span>
                                                </label>
                                                <input type="number" name="quantity" id="quantity" min="1" required
                                                    placeholder="Ví dụ: 10, 50, 100" value="${oldQuantity}"
                                                    class="w-full px-4 py-2.5 border border-border rounded-xl text-sm focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all">
                                            </div>

                                            <div class="mb-4" id="batchGroup" style="display: none;">
                                                <label class="block text-xs font-bold text-txt-2 mb-2" for="batchId">
                                                    Chọn lô hàng để giảm <span class="text-red-500">*</span>
                                                </label>
                                                <select name="batchId" id="batchId"
                                                    class="w-full px-4 py-2.5 border border-border rounded-xl text-sm bg-white focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all">
                                                    <option value="" disabled selected>-- Chọn lô hàng --</option>
                                                </select>
                                            </div>

                                            <div class="mb-4" id="expiryGroup">
                                                <label class="block text-xs font-bold text-txt-2 mb-2" for="expiresAt">
                                                    Ngày hết hạn <span class="text-txt-3 font-normal">(Tùy chọn)</span>
                                                </label>
                                                <input type="date" name="expiresAt" id="expiresAt" value="${oldExpiresAt}"
                                                    class="w-full px-4 py-2.5 border border-border rounded-xl text-sm focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all">
                                            </div>

                                            <%-- Ngày nhập kho ẩn, tự động lấy ngày hôm nay qua JS --%>
                                                <input type="hidden" name="changedAt" id="changedAt">

                                                <div class="mb-4">
                                                    <label class="block text-xs font-bold text-txt-2 mb-2"
                                                        id="noteLabel" for="note">Ghi chú</label>
                                                    <input type="text" name="note" id="note" value="${oldNote}"
                                                        class="w-full px-4 py-2.5 border border-border rounded-xl text-sm focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all"
                                                        placeholder="Ghi chú (ví dụ: Nhập hàng từ nhà cung cấp A)">
                                                </div>

                                                <button type="submit"
                                                    class="w-full mt-6 py-3 px-4 bg-gradient-to-r from-primary to-[#5b7a22] hover:from-[#435919] hover:to-primary-hover text-white font-bold text-sm rounded-xl shadow-md hover:shadow-lg shadow-primary/20 hover:shadow-primary/30 transform hover:-translate-y-0.5 active:translate-y-0 transition-all duration-150 flex items-center justify-center gap-2 cursor-pointer border-0">
                                                    <i id="submitBtnIcon"
                                                        class="fa-solid fa-circle-arrow-down text-base"></i>
                                                    <span id="submitBtnText">Nhập kho sản phẩm</span>
                                                </button>
                                        </form>
                                    </div>
                                </div>
                            </div>

                            <!-- Right Columns (Tables Column) -->
                            <div class="lg:col-span-3 flex flex-col gap-6">

                                <!-- Stock Levels Card -->
                                <div class="bg-white border border-border rounded-2xl shadow-sm overflow-hidden h-fit">
                                    <div
                                        class="p-5 border-b border-border bg-[#f9fdf9] flex items-center justify-between gap-3">
                                        <h2 class="text-sm font-bold text-txt whitespace-nowrap"><i
                                                class="fa-solid fa-boxes-stacked mr-2"></i>Số lượng tồn kho hiện tại
                                        </h2>
                                        <div class="relative flex-1 max-w-[220px]">
                                            <i
                                                class="fa-solid fa-magnifying-glass absolute left-3 top-1/2 -translate-y-1/2 text-txt-3 text-xs pointer-events-none"></i>
                                            <input id="stockSearch" type="text" placeholder="Tìm sản phẩm, SKU..."
                                                class="w-full pl-8 pr-3 py-1.5 border border-border rounded-lg text-xs focus:outline-none focus:border-primary transition-all bg-white">
                                        </div>
                                    </div>
                                    <div class="p-0">
                                        <div class="w-full overflow-auto max-h-[260px] scrollbar-thin">
                                            <table id="stockTable" class="w-full border-collapse text-left">
                                                <thead
                                                    class="bg-[#f8fcf9] text-xs font-bold uppercase tracking-wider text-txt-2 sticky top-0 z-10 border-b border-border">
                                                    <tr>
                                                        <th class="px-5 py-3.5">Sản phẩm &amp; Phân loại</th>
                                                        <th class="px-5 py-3.5">SKU</th>
                                                        <th class="px-5 py-3.5">Tồn kho hiện tại</th>
                                                    </tr>
                                                </thead>
                                                <tbody>
                                                    <c:forEach var="v" items="${variants}">
                                                        <tr data-row class="hover:bg-primary/5 transition-colors cursor-pointer variant-row" data-variant-id="${v.variantId}">
                                                            <td class="px-5 py-3.5 border-b border-border text-sm">
                                                                <div class="flex items-center gap-2">
                                                                    <c:choose>
                                                                        <c:when test="${not empty v.batches}">
                                                                            <i class="fa-solid fa-chevron-right transition-transform duration-200 text-txt-3 text-xs w-4 inline-block" id="arrow-${v.variantId}"></i>
                                                                        </c:when>
                                                                        <c:otherwise>
                                                                            <span class="w-4 inline-block"></span>
                                                                        </c:otherwise>
                                                                    </c:choose>
                                                                    <div>
                                                                        <strong class="text-txt font-bold">${v.productName}</strong>
                                                                        <div class="text-[#94a3b8] text-xs">${v.variantLabel}</div>
                                                                    </div>
                                                                </div>
                                                            </td>
                                                            <td class="px-5 py-3.5 border-b border-border text-sm">
                                                                <code>${v.sku}</code></td>
                                                            <td class="px-5 py-3.5 border-b border-border text-sm">
                                                                <div class="flex items-center justify-between">
                                                                    <c:choose>
                                                                        <c:when test="${v.stockQuantity <= 0}">
                                                                            <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold bg-red-50 text-red-700 border border-red-200 shadow-sm whitespace-nowrap">
                                                                                <i class="fa-solid fa-circle-xmark mr-1 text-[10px]"></i>
                                                                                Hết hàng (0)
                                                                            </span>
                                                                        </c:when>
                                                                        <c:when test="${v.stockQuantity < 10}">
                                                                            <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold bg-amber-50 text-amber-700 border border-amber-200 shadow-sm whitespace-nowrap">
                                                                                <i class="fa-solid fa-triangle-exclamation mr-1 text-[10px]"></i>
                                                                                Sắp hết (${v.stockQuantity})
                                                                            </span>
                                                                        </c:when>
                                                                        <c:otherwise>
                                                                            <span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold bg-emerald-50 text-emerald-700 border border-emerald-200 shadow-sm whitespace-nowrap">
                                                                                <i class="fa-solid fa-circle-check mr-1 text-[10px]"></i>
                                                                                Còn hàng (${v.stockQuantity})
                                                                            </span>
                                                                        </c:otherwise>
                                                                    </c:choose>
                                                                    <c:if test="${not empty v.batches}">
                                                                        <span class="text-xs text-primary font-medium hover:underline ml-2">Chi tiết lô (${v.batches.size()})</span>
                                                                    </c:if>
                                                                </div>
                                                            </td>
                                                        </tr>

                                                        <!-- Collapsible Batches Row -->
                                                        <c:if test="${not empty v.batches}">
                                                            <tr id="batches-row-${v.variantId}" class="hidden bg-slate-50/50" data-parent-row>
                                                                <td colspan="3" class="px-8 py-4 border-b border-border">
                                                                    <div class="text-xs font-bold text-txt-2 mb-2 uppercase tracking-wider">Danh sách các lô hàng đang lưu trữ:</div>
                                                                    <div class="overflow-x-auto rounded-xl border border-border bg-white shadow-inner">
                                                                        <table class="w-full text-left text-xs border-collapse">
                                                                            <thead>
                                                                                <tr class="bg-slate-100/80 border-b border-border text-txt-2 font-bold uppercase tracking-wider">
                                                                                    <th class="px-4 py-2">Mã Lô</th>
                                                                                    <th class="px-4 py-2">Ngày Nhập</th>
                                                                                    <th class="px-4 py-2">Ngày Hết Hạn</th>
                                                                                    <th class="px-4 py-2">Trạng Thái</th>
                                                                                    <th class="px-4 py-2 text-right">Số Lượng Còn Lại / Đã Nhập</th>
                                                                                </tr>
                                                                            </thead>
                                                                            <tbody>
                                                                                <c:forEach var="batch" items="${v.batches}">
                                                                                    <tr class="hover:bg-slate-50 border-b border-slate-100 last:border-0">
                                                                                        <td class="px-4 py-2.5 font-mono text-txt-2">#${batch.logId}</td>
                                                                                        <td class="px-4 py-2.5 text-txt-2">${batch.formattedChangedAt}</td>
                                                                                        <td class="px-4 py-2.5">
                                                                                            <c:choose>
                                                                                                <c:when test="${empty batch.expiresAt}">
                                                                                                    <span class="text-txt-3 italic">Không có</span>
                                                                                                </c:when>
                                                                                                <c:otherwise>
                                                                                                    <span class="font-medium">${batch.formattedExpiresAt}</span>
                                                                                                </c:otherwise>
                                                                                            </c:choose>
                                                                                        </td>
                                                                                        <td class="px-4 py-2.5">
                                                                                            <c:choose>
                                                                                                <c:when test="${batch.expiringSoon}">
                                                                                                    <span class="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-50 text-amber-700 border border-amber-200">
                                                                                                        <i class="fa-solid fa-triangle-exclamation mr-1 text-[8px]"></i>Sắp hết hạn
                                                                                                    </span>
                                                                                                </c:when>
                                                                                                <c:when test="${not empty batch.expiresAt}">
                                                                                                    <span class="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
                                                                                                        <i class="fa-solid fa-circle-check mr-1 text-[8px]"></i>Còn hạn
                                                                                                    </span>
                                                                                                </c:when>
                                                                                                <c:otherwise>
                                                                                                    <span class="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-bold bg-slate-50 text-slate-500 border border-slate-200">
                                                                                                        <i class="fa-solid fa-minus mr-1 text-[8px]"></i>Không hạn
                                                                                                    </span>
                                                                                                </c:otherwise>
                                                                                            </c:choose>
                                                                                        </td>
                                                                                        <td class="px-4 py-2.5 text-right font-medium">
                                                                                            <span class="text-emerald-700 font-bold">${batch.remainingQuantity}</span>
                                                                                            <span class="text-txt-3"> / ${batch.quantityDelta}</span>
                                                                                        </td>
                                                                                    </tr>
                                                                                </c:forEach>
                                                                            </tbody>
                                                                        </table>
                                                                    </div>
                                                                </td>
                                                            </tr>
                                                        </c:if>
                                                    </c:forEach>
                                                    <c:if test="${empty variants}">
                                                        <tr>
                                                            <td colspan="3"
                                                                class="text-center py-8 text-[#94a3b8] italic">
                                                                Chưa có sản phẩm nào!
                                                            </td>
                                                        </tr>
                                                    </c:if>
                                                </tbody>
                                            </table>
                                        </div>
                                    </div>
                                </div>

                                 <!-- History Column -->
                                <div class="bg-white border border-border rounded-2xl shadow-sm overflow-hidden h-fit">
                                    <div
                                        class="p-5 border-b border-border bg-[#f9fdf9] flex items-center justify-between gap-3">
                                        <h2 class="text-sm font-bold text-txt whitespace-nowrap"><i
                                                class="fa-solid fa-clock-rotate-left mr-2"></i>Lịch sử biến động kho
                                        </h2>
                                        <div class="relative flex-1 max-w-[220px]">
                                            <i
                                                class="fa-solid fa-magnifying-glass absolute left-3 top-1/2 -translate-y-1/2 text-txt-3 text-xs pointer-events-none"></i>
                                            <input id="historySearch" type="text"
                                                placeholder="Tìm sản phẩm, loại, ghi chú..."
                                                class="w-full pl-8 pr-3 py-1.5 border border-border rounded-lg text-xs focus:outline-none focus:border-primary transition-all bg-white">
                                        </div>
                                    </div>
                                    <div class="p-0">
                                        <div class="w-full overflow-auto max-h-[260px] scrollbar-thin">
                                            <table id="historyTable" class="w-full border-collapse text-left">
                                                <thead
                                                    class="bg-[#f8fcf9] text-xs font-bold uppercase tracking-wider text-txt-2 sticky top-0 z-10 border-b border-border">
                                                    <tr>
                                                        <th class="px-5 py-3.5">Mã</th>
                                                        <th class="px-5 py-3.5">Sản phẩm &amp; Phân loại</th>
                                                        <th class="px-5 py-3.5">Thay đổi</th>
                                                        <th class="px-5 py-3.5">Loại</th>
                                                        <th class="px-5 py-3.5">Ghi chú</th>
                                                        <th class="px-5 py-3.5">Thời gian</th>
                                                        <th class="px-5 py-3.5">Người thực hiện</th>
                                                    </tr>
                                                </thead>
                                                <tbody>
                                                    <c:forEach var="log" items="${restockLogs}">
                                                        <tr data-row class="hover:bg-primary/5 transition-colors">
                                                            <td class="px-5 py-3.5 border-b border-border text-sm">
                                                                #${log.logId}</td>
                                                            <td class="px-5 py-3.5 border-b border-border text-sm">
                                                                <strong
                                                                    class="text-txt font-bold">${log.productName}</strong>
                                                                <div class="text-[#94a3b8] text-xs">${log.variantLabel}
                                                                </div>
                                                            </td>
                                                            <td class="px-5 py-3.5 border-b border-border text-sm">
                                                                <span
                                                                    class="font-bold px-2 py-0.5 rounded text-xs ${log.quantityDelta >= 0 ? 'bg-emerald-50 text-emerald-700' : 'bg-red-50 text-red-700'}">
                                                                    ${log.quantityDelta >= 0 ? '+' :
                                                                    ''}${log.quantityDelta}
                                                                </span>
                                                            </td>
                                                            <td class="px-5 py-3.5 border-b border-border text-sm">
                                                                <c:choose>
                                                                    <c:when test="${log.changeType == 'ORDER_RESERVE'}">
                                                                        <span
                                                                            class="px-2 py-0.5 rounded text-[11px] font-semibold bg-blue-50 text-blue-700 border border-blue-200 whitespace-nowrap">📦
                                                                            Giữ hàng</span>
                                                                    </c:when>
                                                                    <c:when test="${log.changeType == 'ORDER_CONFIRM'}">
                                                                        <span
                                                                            class="px-2 py-0.5 rounded text-[11px] font-semibold bg-violet-50 text-violet-700 border border-violet-200 whitespace-nowrap">✅
                                                                            Đã bán</span>
                                                                    </c:when>
                                                                    <c:when test="${log.changeType == 'ORDER_RELEASE'}">
                                                                        <span
                                                                            class="px-2 py-0.5 rounded text-[11px] font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 whitespace-nowrap">↩
                                                                            Hoàn kho</span>
                                                                    </c:when>
                                                                    <c:when test="${log.changeType == 'EXPIRED'}">
                                                                        <span
                                                                            class="px-2 py-0.5 rounded text-[11px] font-semibold bg-orange-50 text-orange-700 border border-orange-200 whitespace-nowrap">⏰
                                                                            Hết hạn</span>
                                                                    </c:when>
                                                                    <c:when test="${log.changeType == 'SPOILED'}">
                                                                        <span
                                                                            class="px-2 py-0.5 rounded text-[11px] font-semibold bg-red-50 text-red-700 border border-red-200 whitespace-nowrap">🗑
                                                                            Thối hỏng</span>
                                                                    </c:when>
                                                                    <c:when test="${log.changeType == 'RETURN'}">
                                                                        <span
                                                                            class="px-2 py-0.5 rounded text-[11px] font-semibold bg-yellow-50 text-yellow-700 border border-yellow-200 whitespace-nowrap">↩
                                                                            Trả hàng</span>
                                                                    </c:when>
                                                                    <c:otherwise>
                                                                        <span
                                                                            class="px-2 py-0.5 rounded text-[11px] font-semibold bg-gray-100 text-gray-700 border border-gray-200 whitespace-nowrap">⚙
                                                                            Điều chỉnh</span>
                                                                    </c:otherwise>
                                                                </c:choose>
                                                            </td>
                                                            <td class="px-5 py-3.5 border-b border-border text-sm">
                                                                <c:choose>
                                                                    <c:when test="${not empty log.note}">
                                                                        <span class="text-txt">${log.note}</span>
                                                                    </c:when>
                                                                    <c:otherwise>
                                                                        <span class="text-[#94a3b8]">-</span>
                                                                    </c:otherwise>
                                                                </c:choose>
                                                            </td>
                                                            <td class="px-5 py-3.5 border-b border-border text-sm">
                                                                ${log.formattedChangedAt}</td>
                                                            <td class="px-5 py-3.5 border-b border-border text-sm">
                                                                <c:choose>
                                                                    <c:when test="${log.changeType == 'MANUAL_ADJUST' || log.changeType == 'SPOILED'}">
                                                                        ${log.changedByName}
                                                                    </c:when>
                                                                    <c:otherwise>
                                                                        <span class="text-[#94a3b8] italic">Hệ thống</span>
                                                                    </c:otherwise>
                                                                </c:choose>
                                                            </td>
                                                        </tr>
                                                    </c:forEach>
                                                    <c:if test="${empty restockLogs}">
                                                        <tr>
                                                            <td colspan="7"
                                                                class="text-center py-8 text-[#94a3b8] italic">
                                                                Chưa có lịch sử biến động kho nào!
                                                            </td>
                                                        </tr>
                                                    </c:if>
                                                </tbody>
                                            </table>
                                        </div>
                                    </div>
                                </div>

                            </div>
                        </div>

                        <script id="batchesJsonData" type="application/json">
                            ${not empty batchesJson ? batchesJson : '{}'}
                        </script>
                        <script>
                            window.csrfToken = '${sessionScope._csrfToken}';
                            try {
                                window.batchesByVariant = JSON.parse(document.getElementById('batchesJsonData').textContent || '{}');
                            } catch (e) {
                                window.batchesByVariant = {};
                            }

                            window.toggleBatches = function(variantId) {
                                const row = document.getElementById('batches-row-' + variantId);
                                const arrow = document.getElementById('arrow-' + variantId);
                                if (row) {
                                    row.classList.toggle('hidden');
                                }
                                if (arrow) {
                                    arrow.classList.toggle('rotate-90');
                                }
                            };

                            document.addEventListener('DOMContentLoaded', function () {
                                const todayStr = new Date().toISOString().split('T')[0];

                                // 1. Tự động set ngày nhập kho = hôm nay (hidden input)
                                const changedAtInput = document.getElementById('changedAt');
                                if (changedAtInput) {
                                    changedAtInput.value = todayStr;
                                }

                                // 2. Dynamic button text và layout theo loại tác vụ
                                const actionTypeSelect = document.getElementById('actionType');
                                const submitBtnText = document.getElementById('submitBtnText');
                                const submitBtnIcon = document.getElementById('submitBtnIcon');
                                const expiryGroup = document.getElementById('expiryGroup');
                                const expiresInput = document.getElementById('expiresAt');
                                const noteInput = document.getElementById('note');
                                const noteLabel = document.getElementById('noteLabel');
                                const variantSelect = document.getElementById('variantId');

                                const expiryHint = document.createElement('div');
                                expiryHint.className = 'text-[11px] text-txt-3 mt-1.5 font-medium';
                                expiryHint.id = 'expiryHint';
                                if (expiresInput && expiresInput.parentNode) {
                                    expiresInput.parentNode.appendChild(expiryHint);
                                }

                                if (expiresInput) {
                                    expiresInput.min = todayStr;
                                }

                                function updateMaxExpiry() {
                                    if (!variantSelect || !expiresInput) return;
                                    const selectedOpt = variantSelect.options[variantSelect.selectedIndex];
                                    if (!selectedOpt || selectedOpt.disabled) {
                                        expiresInput.removeAttribute('max');
                                        expiryHint.innerHTML = '';
                                        return;
                                    }
                                    
                                    const shelfLifeDays = selectedOpt.getAttribute('data-shelflife');
                                    if (shelfLifeDays && shelfLifeDays > 0) {
                                        const maxDate = new Date();
                                        maxDate.setDate(maxDate.getDate() + parseInt(shelfLifeDays));
                                        const maxDateStr = maxDate.toISOString().split('T')[0];
                                        
                                        expiresInput.max = maxDateStr;
                                        
                                        const formattedMaxDate = maxDate.getDate().toString().padStart(2, '0') + '/' + 
                                                                 (maxDate.getMonth() + 1).toString().padStart(2, '0') + '/' + 
                                                                 maxDate.getFullYear();
                                        expiryHint.innerHTML = '<i class="fa-solid fa-circle-info mr-1 text-primary"></i>Hạn sử dụng tối đa của sản phẩm này: <strong>' + shelfLifeDays + ' ngày</strong> (đến ngày <strong>' + formattedMaxDate + '</strong>)';
                                    } else {
                                        expiresInput.removeAttribute('max');
                                        expiryHint.innerHTML = '';
                                    }
                                }

                                if (variantSelect) {
                                    variantSelect.addEventListener('change', updateMaxExpiry);
                                    updateMaxExpiry();
                                }

                                const batchGroup = document.getElementById('batchGroup');
                                const batchSelect = document.getElementById('batchId');

                                function populateBatches() {
                                    if (!variantSelect || !batchSelect) return;
                                    const variantId = variantSelect.value;
                                    batchSelect.innerHTML = '<option value="" disabled selected>-- Chọn lô hàng --</option>';
                                    if (!variantId) return;

                                    const batches = window.batchesByVariant[variantId];
                                    if (batches && batches.length > 0) {
                                        batches.forEach(function (b) {
                                            const opt = document.createElement('option');
                                            opt.value = b.logId;
                                            var label = (b.logId && b.logId > 0) ? ('Lô #' + b.logId) : 'Lô kho hiện tại';
                                            opt.textContent = label + ' - HSD: ' + b.expiresAt + ' (Còn lại: ' + b.remainingQuantity + ')';
                                            batchSelect.appendChild(opt);
                                        });
                                    } else {
                                        const opt = document.createElement('option');
                                        opt.value = "";
                                        opt.textContent = "Không có lô hàng khả dụng (Hết hàng)";
                                        opt.disabled = true;
                                        batchSelect.appendChild(opt);
                                    }
                                }

                                if (variantSelect) {
                                    variantSelect.addEventListener('change', populateBatches);
                                }

                                function updateFormLayout() {
                                    if (!actionTypeSelect || !submitBtnText || !submitBtnIcon) return;
                                    const v = actionTypeSelect.value;
                                    if (v === 'RESTOCK') {
                                        submitBtnText.textContent = 'Nhập kho sản phẩm';
                                        submitBtnIcon.className = 'fa-solid fa-circle-arrow-down text-base';
                                        if (expiryGroup) expiryGroup.style.display = 'block';
                                        if (expiresInput) expiresInput.disabled = false;
                                        if (batchGroup) batchGroup.style.display = 'none';
                                        if (batchSelect) {
                                            batchSelect.required = false;
                                            batchSelect.disabled = true;
                                        }
                                        if (noteInput) {
                                            noteInput.placeholder = 'Ghi chú (ví dụ: Nhập hàng từ nhà cung cấp A)';
                                            noteInput.required = false;
                                        }
                                        if (noteLabel) noteLabel.innerHTML = 'Ghi chú';
                                    } else {
                                        submitBtnText.textContent = 'Giảm kho sản phẩm';
                                        submitBtnIcon.className = 'fa-solid fa-circle-minus text-base';
                                        if (expiryGroup) expiryGroup.style.display = 'none';
                                        if (expiresInput) {
                                            expiresInput.disabled = true;
                                            expiresInput.value = '';
                                        }
                                        if (batchGroup) batchGroup.style.display = 'block';
                                        if (batchSelect) {
                                            batchSelect.required = true;
                                            batchSelect.disabled = false;
                                        }
                                        populateBatches();
                                        if (noteInput) {
                                            noteInput.placeholder = 'Nhập lý do giảm kho (thối hỏng, hết hạn, hao hụt...) *';
                                            noteInput.required = true;
                                        }
                                        if (noteLabel) noteLabel.innerHTML = 'Ghi chú <span class="text-red-500">*</span>';
                                    }
                                }

                                if (actionTypeSelect) {
                                    actionTypeSelect.addEventListener('change', updateFormLayout);
                                    updateFormLayout();
                                }

                                // 3. CSRF attach on submit & validation
                                const form = document.getElementById('restockForm');
                                if (form) {
                                    form.addEventListener('submit', function (e) {
                                        const csrfInput = this.querySelector('input[name="_csrf"]');
                                        if (csrfInput && (!csrfInput.value || csrfInput.value.trim() === '')) {
                                            csrfInput.value = window.csrfToken || '';
                                        }
                                        // Luôn cập nhật changedAt = ngày hôm nay ngay trước khi submit
                                        if (changedAtInput) {
                                            changedAtInput.value = todayStr;
                                        }

                                        // Chặn ngày hết hạn trong quá khứ khi nhập kho
                                        if (actionTypeSelect && actionTypeSelect.value === 'RESTOCK' && expiresInput && expiresInput.value) {
                                            if (expiresInput.value < todayStr) {
                                                e.preventDefault();
                                                if (window.Swal) {
                                                    Swal.fire({
                                                        icon: 'error',
                                                        title: 'Lỗi nhập liệu',
                                                        text: 'Ngày hết hạn không được là ngày trong quá khứ.',
                                                        confirmButtonColor: '#4d661c'
                                                    });
                                                } else {
                                                    alert('Ngày hết hạn không được là ngày trong quá khứ.');
                                                }
                                                return false;
                                            }

                                            // Chặn ngày hết hạn vượt quá tối đa
                                            const maxVal = expiresInput.getAttribute('max');
                                            if (maxVal && expiresInput.value > maxVal) {
                                                e.preventDefault();
                                                if (window.Swal) {
                                                    Swal.fire({
                                                        icon: 'error',
                                                        title: 'Lỗi nhập liệu',
                                                        text: 'Ngày hết hạn không được vượt quá hạn sử dụng của sản phẩm.',
                                                        confirmButtonColor: '#4d661c'
                                                    });
                                                } else {
                                                    alert('Ngày hết hạn vượt quá hạn sử dụng tối đa cho phép.');
                                                }
                                                return false;
                                            }
                                        }

                                        // Chặn số lượng giảm vượt quá tồn còn lại của lô khi giảm kho
                                        const quantityInput = document.getElementById('quantity');
                                        if (actionTypeSelect && actionTypeSelect.value === 'REDUCE' && quantityInput) {
                                            const qtyVal = parseInt(quantityInput.value) || 0;
                                            const variantId = variantSelect ? variantSelect.value : null;
                                            const batchIdVal = batchSelect ? batchSelect.value : null;
                                            if (variantId && batchIdVal && window.batchesByVariant[variantId]) {
                                                const batches = window.batchesByVariant[variantId];
                                                const selectedBatch = batches.find(function(b) { return String(b.logId) === String(batchIdVal); });
                                                if (selectedBatch && qtyVal > selectedBatch.remainingQuantity) {
                                                    e.preventDefault();
                                                    if (window.Swal) {
                                                        Swal.fire({
                                                            icon: 'error',
                                                            title: 'Vượt quá tồn kho lô',
                                                            text: 'Số lượng giảm (' + qtyVal + ') vượt quá số lượng tồn còn lại của lô được chọn (chỉ còn ' + selectedBatch.remainingQuantity + ' sản phẩm).',
                                                            confirmButtonColor: '#4d661c'
                                                        });
                                                    } else {
                                                        alert('Số lượng giảm (' + qtyVal + ') vượt quá số lượng tồn còn lại của lô (chỉ còn ' + selectedBatch.remainingQuantity + ' sản phẩm).');
                                                    }
                                                    return false;
                                                }
                                            }
                                        }
                                    });
                                }

                                // Attach click listener dynamically to variant rows
                                document.querySelectorAll('#stockTable tbody tr.variant-row').forEach(function (tr) {
                                    tr.addEventListener('click', function () {
                                        const variantId = this.getAttribute('data-variant-id');
                                        window.toggleBatches(variantId);
                                    });
                                });

                                // ── 4. Tìm kiếm bảng Tồn kho hiện tại ────────────────────────────
                                const stockSearch = document.getElementById('stockSearch');
                                if (stockSearch) {
                                    stockSearch.addEventListener('input', function () {
                                        const q = this.value.trim().toLowerCase();
                                        document.querySelectorAll('#stockTable tbody tr[data-row].variant-row').forEach(function (tr) {
                                            const isMatch = !q || tr.textContent.toLowerCase().includes(q);
                                            tr.style.display = isMatch ? '' : 'none';
                                            
                                            // Handle parent row display for matching rows
                                            const variantId = tr.getAttribute('data-variant-id');
                                            if (variantId) {
                                                const parentRow = document.getElementById('batches-row-' + variantId);
                                                if (parentRow && !isMatch) {
                                                    parentRow.classList.add('hidden');
                                                    const arrow = document.getElementById('arrow-' + variantId);
                                                    if (arrow) arrow.classList.remove('rotate-90');
                                                }
                                            }
                                        });
                                    });
                                }

                                // ── 5. Tìm kiếm bảng Lịch sử biến động kho ──────────────────────
                                const historySearch = document.getElementById('historySearch');
                                if (historySearch) {
                                    historySearch.addEventListener('input', function () {
                                        const q = this.value.trim().toLowerCase();
                                        document.querySelectorAll('#historyTable tbody tr[data-row]').forEach(function (tr) {
                                            tr.style.display = (!q || tr.textContent.toLowerCase().includes(q)) ? '' : 'none';
                                        });
                                    });
                                }
                            });
                        </script>
            </body>

            </html>