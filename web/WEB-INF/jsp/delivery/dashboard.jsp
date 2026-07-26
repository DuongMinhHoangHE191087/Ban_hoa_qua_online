<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%@ taglib prefix="fmt" uri="jakarta.tags.fmt" %>
<jsp:include page="/WEB-INF/jsp/common/header.jsp">
    <jsp:param name="pageTitle" value="MetaFruit | Tổng quan giao hàng" />
</jsp:include>

<script src="${pageContext.request.contextPath}/assets/js/tailwind.js?plugins=forms"></script>
<script>
tailwind.config = {
    theme: {
        extend: {
            colors: {
                primary: '#16A34A',
                'primary-hover': '#15803D',
                'primary-light': '#DCFCE7',
                'primary-mid': '#4ADE80',
                'txt': '#0F172A',
                'txt-2': '#475569',
                'txt-3': '#94A3B8',
                'border-c': '#BBF7D0',
                'bg-page': '#F0FDF4',
            },
            fontFamily: { sans: ['Lexend', 'sans-serif'] }
        }
    }
}
</script>

<main class="max-w-7xl mx-auto px-4 md:px-8 py-10 font-sans text-txt">

    <%-- Header --%>
    <div class="flex flex-col md:flex-row md:items-center md:justify-between mb-8 gap-4">
        <div>
            <div class="flex items-center gap-3 mb-1">
                <div class="w-10 h-10 rounded-2xl bg-primary flex items-center justify-center shadow-md">
                    <i class="fa-solid fa-truck-fast text-white text-lg"></i>
                </div>
                <h1 class="text-2xl md:text-3xl font-extrabold text-[#14532D] tracking-tight">Tổng quan giao hàng</h1>
            </div>
            <p class="text-txt-2 text-sm ml-1">Quản lý và cập nhật trạng thái các đơn hàng được phân công</p>
        </div>
        <div class="flex items-center gap-3">
            <a href="${pageContext.request.contextPath}/auth/logout"
               class="flex items-center gap-2 bg-white border border-border-c text-primary font-bold text-xs px-4 py-2.5 rounded-xl hover:bg-primary-light transition-all shadow-sm">
                <i class="fa-solid fa-right-from-bracket"></i> Đăng xuất
            </a>
        </div>
    </div>

    <%-- Status Filter Tabs --%>
    <div class="flex flex-wrap gap-2 mb-8 bg-white/60 border border-border-c p-2 rounded-2xl backdrop-blur">
        <a href="${pageContext.request.contextPath}/delivery/dashboard" class="tab-pill ${empty filterStatus ? 'bg-primary text-white shadow-sm' : 'text-txt-2 hover:bg-primary-light hover:text-primary'}">
            <i class="fa-solid fa-list"></i> Tất cả
        </a>
        <a href="${pageContext.request.contextPath}/delivery/dashboard?status=ASSIGNED" class="tab-pill ${filterStatus == 'ASSIGNED' ? 'bg-blue-600 text-white shadow-sm' : 'text-txt-2 hover:bg-blue-50 hover:text-blue-600'}">
            <i class="fa-solid fa-inbox"></i> Mới nhận
        </a>
        <a href="${pageContext.request.contextPath}/delivery/dashboard?status=PICKED_UP" class="tab-pill ${filterStatus == 'PICKED_UP' ? 'bg-amber-500 text-white shadow-sm' : 'text-txt-2 hover:bg-amber-50 hover:text-amber-600'}">
            <i class="fa-solid fa-box"></i> Đã lấy hàng
        </a>
        <a href="${pageContext.request.contextPath}/delivery/dashboard?status=IN_TRANSIT" class="tab-pill ${filterStatus == 'IN_TRANSIT' ? 'bg-purple-600 text-white shadow-sm' : 'text-txt-2 hover:bg-purple-50 hover:text-purple-600'}">
            <i class="fa-solid fa-truck"></i> Đang giao
        </a>
        <a href="${pageContext.request.contextPath}/delivery/dashboard?status=DELIVERED" class="tab-pill ${filterStatus == 'DELIVERED' ? 'bg-emerald-600 text-white shadow-sm' : 'text-txt-2 hover:bg-emerald-50 hover:text-emerald-600'}">
            <i class="fa-solid fa-circle-check"></i> Đã giao
        </a>
        <a href="${pageContext.request.contextPath}/delivery/dashboard?status=FAILED" class="tab-pill ${filterStatus == 'FAILED' ? 'bg-red-600 text-white shadow-sm' : 'text-txt-2 hover:bg-red-50 hover:text-red-600'}">
            <i class="fa-solid fa-circle-xmark"></i> Thất bại
        </a>
    </div>

    <%-- Empty State --%>
    <c:if test="${empty deliveryList}">
        <div class="glass-card rounded-3xl text-center py-20 px-6">
            <div class="w-20 h-20 rounded-full bg-primary-light flex items-center justify-center mx-auto mb-5">
                <i class="fa-solid fa-box-open text-3xl text-primary"></i>
            </div>
            <h2 class="text-lg font-bold text-[#0C4A6E] mb-2">Chưa có đơn hàng nào</h2>
            <p class="text-txt-3 text-sm max-w-xs mx-auto">Hiện tại bạn chưa được phân công giao đơn hàng nào. Hãy chờ đợi hoặc liên hệ Quản lý.</p>
        </div>
    </c:if>

    <%-- Delivery Cards Grid --%>
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <c:forEach var="dto" items="${deliveryList}">
            <div class="glass-card rounded-3xl overflow-hidden flex flex-col hover:-translate-y-1 hover:shadow-lg transition-all duration-300 cursor-default">

                <%-- Card Header --%>
                <div class="px-5 py-4 border-b border-border-c bg-gradient-to-r from-[#EFF6FF] to-[#F0F9FF] flex justify-between items-center">
                    <div>
                        <span class="text-xs text-txt-3 font-medium">Đơn hàng</span>
                        <h3 class="font-extrabold text-[#0C4A6E] text-base">
                            <a href="${pageContext.request.contextPath}/delivery/detail?id=${dto.deliveryId}" class="hover:underline hover:text-primary flex items-center gap-1.5">
                                #${dto.orderId} <i class="fa-regular fa-eye text-xs text-txt-3"></i>
                            </a>
                        </h3>
                    </div>
                    <%-- Status Badge --%>
                    <c:choose>
                        <c:when test="${empty dto.delivery.staffId}">
                            <span class="status-badge bg-sky-100 text-sky-800 border border-sky-300 font-extrabold animate-pulse">
                                <i class="fa-solid fa-hourglass-half text-[9px]"></i> Chờ Shipper nhận đơn
                            </span>
                        </c:when>
                        <c:when test="${dto.deliveryStatus == 'ASSIGNED'}">
                            <span class="status-badge bg-blue-50 text-blue-700 border border-blue-200">
                                <i class="fa-solid fa-inbox text-[9px]"></i> Mới nhận
                            </span>
                        </c:when>
                        <c:when test="${dto.deliveryStatus == 'PICKED_UP'}">
                            <span class="status-badge bg-amber-50 text-amber-700 border border-amber-200">
                                <i class="fa-solid fa-box text-[9px]"></i> Đã lấy hàng
                            </span>
                        </c:when>
                        <c:when test="${dto.deliveryStatus == 'IN_TRANSIT'}">
                            <span class="status-badge bg-purple-50 text-purple-700 border border-purple-200">
                                <i class="fa-solid fa-truck text-[9px]"></i> Đang giao
                            </span>
                        </c:when>
                        <c:when test="${dto.deliveryStatus == 'DELIVERED'}">
                            <span class="status-badge bg-emerald-50 text-emerald-700 border border-emerald-200">
                                <i class="fa-solid fa-circle-check text-[9px]"></i> Đã giao
                            </span>
                        </c:when>
                        <c:when test="${dto.deliveryStatus == 'FAILED'}">
                            <span class="status-badge bg-red-50 text-red-700 border border-red-200">
                                <i class="fa-solid fa-circle-xmark text-[9px]"></i> Thất bại
                            </span>
                        </c:when>
                    </c:choose>
                </div>

                <%-- Card Body --%>
                <div class="p-5 flex-grow flex flex-col gap-3">

                    <%-- Recipient Info --%>
                    <c:if test="${not empty dto.recipientName}">
                        <div class="flex items-start gap-2.5 text-sm">
                            <div class="w-7 h-7 rounded-xl bg-sky-50 flex items-center justify-center shrink-0 mt-0.5">
                                <i class="fa-solid fa-user text-primary text-[11px]"></i>
                            </div>
                            <div>
                                <span class="text-xs text-txt-3 block font-semibold uppercase tracking-wider">Người nhận</span>
                                <span class="font-bold text-txt"><c:out value="${dto.recipientName}"/></span>
                                <c:if test="${not empty dto.recipientPhone}">
                                    <span class="text-txt-2 ml-1 text-xs">(<c:out value="${dto.recipientPhone}"/>)</span>
                                </c:if>
                            </div>
                        </div>
                    </c:if>

                    <%-- Delivery Address --%>
                    <c:if test="${not empty dto.deliveryAddress}">
                        <div class="flex items-start gap-2.5 text-sm">
                            <div class="w-7 h-7 rounded-xl bg-sky-50 flex items-center justify-center shrink-0 mt-0.5">
                                <i class="fa-solid fa-location-dot text-primary text-[11px]"></i>
                            </div>
                            <div>
                                <span class="text-xs text-txt-3 block font-semibold uppercase tracking-wider">Địa chỉ giao</span>
                                <p class="text-txt font-medium leading-snug"><c:out value="${dto.deliveryAddress}"/></p>
                            </div>
                        </div>
                    </c:if>

                    <%-- Estimated Delivery Time --%>
                    <div class="flex items-start gap-2.5 text-sm">
                        <div class="w-7 h-7 rounded-xl bg-sky-50 flex items-center justify-center shrink-0 mt-0.5">
                            <i class="fa-regular fa-clock text-primary text-[11px]"></i>
                        </div>
                        <div>
                            <span class="text-xs text-txt-3 block font-semibold uppercase tracking-wider">Dự kiến giao</span>
                            <c:choose>
                                <c:when test="${not empty dto.estimatedDeliveryTime}">
                                    <b class="text-primary font-bold">${dto.estimatedDeliveryTime}</b>
                                </c:when>
                                <c:otherwise>
                                    <span class="text-txt-3 italic text-xs">Chưa thiết lập</span>
                                </c:otherwise>
                            </c:choose>
                            <c:if test="${not empty dto.delivery.staffId && dto.deliveryStatus != 'DELIVERED' && dto.deliveryStatus != 'FAILED'}">
                                <button type="button" onclick="openEstimateModal('${dto.deliveryId}')"
                                    class="ml-2 text-primary hover:text-primary-hover underline text-[11px] font-bold cursor-pointer bg-none border-none">Cập nhật</button>
                            </c:if>
                        </div>
                    </div>

                    <%-- Failure Reason --%>
                    <c:if test="${dto.deliveryStatus == 'FAILED' && not empty dto.failureReason}">
                        <div class="bg-red-50 border border-red-100 rounded-xl p-3 text-xs text-red-700 font-semibold">
                            <i class="fa-solid fa-triangle-exclamation mr-1"></i>
                            <strong>Lý do thất bại:</strong> <c:out value="${dto.failureReason}"/>
                        </div>
                    </c:if>
                </div>

                <%-- Card Footer - Action Buttons --%>
                <div class="px-5 pb-5 mt-auto">
                    <c:choose>
                        <c:when test="${empty dto.delivery.staffId}">
                            <button onclick="claimOrder('${dto.deliveryId}')"
                                class="w-full bg-[#0369A1] hover:bg-[#0284C7] text-white font-bold py-3 rounded-2xl transition-all shadow-md active:scale-95 cursor-pointer border-0 flex items-center justify-center gap-2">
                                <i class="fa-solid fa-hand-holding-hand"></i> Nhận đơn giao hàng này
                            </button>
                        </c:when>
                        <c:when test="${dto.deliveryStatus == 'ASSIGNED'}">
                            <button onclick="updateStatus('${dto.deliveryId}', 'PICKED_UP')"
                                class="w-full bg-primary hover:bg-primary-hover text-white font-bold py-3 rounded-2xl transition-all shadow-md active:scale-95 cursor-pointer border-0 flex items-center justify-center gap-2">
                                <i class="fa-solid fa-box-open"></i> Xác nhận Đã Lấy Hàng
                            </button>
                        </c:when>
                        <c:when test="${dto.deliveryStatus == 'PICKED_UP'}">
                            <button onclick="updateStatus('${dto.deliveryId}', 'IN_TRANSIT')"
                                class="w-full bg-purple-600 hover:bg-purple-700 text-white font-bold py-3 rounded-2xl transition-all shadow-md active:scale-95 cursor-pointer border-0 flex items-center justify-center gap-2">
                                <i class="fa-solid fa-truck"></i> Bắt đầu Giao Hàng
                            </button>
                        </c:when>
                        <c:when test="${dto.deliveryStatus == 'IN_TRANSIT'}">
                            <div class="flex gap-2">
                                <button onclick="openProofModal('${dto.deliveryId}')"
                                    class="flex-1 bg-emerald-600 hover:bg-emerald-700 text-white font-bold py-3 rounded-2xl transition-all shadow-sm active:scale-95 cursor-pointer border-0 flex items-center justify-center gap-1.5">
                                    <i class="fa-solid fa-check"></i> Giao thành công
                                </button>
                                <button onclick="openFailModal('${dto.deliveryId}')"
                                    class="flex-1 bg-red-50 hover:bg-red-600 text-red-600 hover:text-white font-bold py-3 rounded-2xl border border-red-200 transition-all shadow-sm active:scale-95 cursor-pointer flex items-center justify-center gap-1.5">
                                    <i class="fa-solid fa-xmark"></i> Thất bại
                                </button>
                            </div>
                        </c:when>
                        <c:otherwise>
                            <div class="w-full bg-slate-50 text-txt-3 font-bold py-3 rounded-2xl text-center text-sm border border-slate-100">
                                <i class="fa-solid fa-check-double mr-1"></i> Đã hoàn tất xử lý
                            </div>
                        </c:otherwise>
                    </c:choose>
                </div>
            </div>
        </c:forEach>
    </div>
</main>

<%-- Modal: Giao Thành Công (Proof) --%>
<div id="proofModal" class="hidden fixed inset-0 bg-black/40 backdrop-blur-sm z-[1000] flex items-center justify-center p-4">
    <div class="bg-white w-full max-w-md p-6 rounded-3xl shadow-2xl border border-emerald-100">
        <form action="${pageContext.request.contextPath}/delivery/confirm-success" method="POST" enctype="multipart/form-data">
            <h3 class="text-emerald-700 font-extrabold text-lg flex items-center gap-2 mb-2">
                <span class="w-9 h-9 rounded-2xl bg-emerald-50 flex items-center justify-center">
                    <i class="fa-solid fa-check-circle text-emerald-600"></i>
                </span>
                Xác nhận Giao Thành Công
            </h3>
            <p class="text-xs text-txt-2 mb-5">Tải lên ảnh bằng chứng giao hàng (định dạng ảnh) để hoàn tất xác nhận.</p>
            <input type="hidden" id="proofDeliveryId" name="deliveryId">
            <input type="hidden" name="_csrf" value="${sessionScope._csrfToken}">
            <div class="mb-5">
                <label class="block text-xs font-bold text-txt-2 mb-1.5">Ảnh Bằng Chứng <span class="text-red-500">*</span></label>
                <input type="file" id="proofImage" name="proofImage" accept="image/*" required
                    class="w-full px-3 py-2 border border-[#BAE6FD] rounded-2xl text-sm text-txt-2
                           file:mr-4 file:py-2.5 file:px-5
                           file:rounded-xl file:border-0
                           file:text-xs file:font-bold
                           file:bg-emerald-50 file:text-emerald-700
                           hover:file:bg-emerald-100 file:transition-all
                           focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 bg-white cursor-pointer file:cursor-pointer">
            </div>
            <div class="flex gap-3 justify-end">
                <button type="button" onclick="closeModal('proofModal')" class="px-5 py-2.5 rounded-2xl bg-slate-100 hover:bg-slate-200 text-txt-2 font-bold text-xs transition-all">Hủy</button>
                <button type="submit" class="px-5 py-2.5 rounded-2xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs transition-all shadow-md">Xác nhận giao thành công</button>
            </div>
        </form>
    </div>
</div>

<%-- Modal: Giao Thất Bại --%>
<div id="failModal" class="hidden fixed inset-0 bg-black/40 backdrop-blur-sm z-[1000] flex items-center justify-center p-4">
    <div class="bg-white w-full max-w-md p-6 rounded-3xl shadow-2xl border border-red-100">
        <h3 class="text-red-700 font-extrabold text-lg flex items-center gap-2 mb-4">
            <span class="w-9 h-9 rounded-2xl bg-red-50 flex items-center justify-center">
                <i class="fa-solid fa-circle-xmark text-red-600"></i>
            </span>
            Báo Cáo Giao Hàng Thất Bại
        </h3>
        <input type="hidden" id="failDeliveryId">
        <div class="mb-5">
            <label class="block text-xs font-bold text-txt-2 mb-1.5">Lý do thất bại <span class="text-red-500">*</span></label>
            <textarea id="failureReason" rows="3" placeholder="Ví dụ: Khách không nghe máy, sai địa chỉ..."
                class="w-full px-4 py-3 border border-red-200 rounded-2xl text-sm focus:outline-none focus:border-red-400 focus:ring-2 focus:ring-red-100 resize-none"></textarea>
        </div>
        <div class="flex gap-3 justify-end">
            <button onclick="closeModal('failModal')" class="px-5 py-2.5 rounded-2xl bg-slate-100 hover:bg-slate-200 text-txt-2 font-bold text-xs transition-all">Hủy</button>
            <button onclick="submitFail()" class="px-5 py-2.5 rounded-2xl bg-red-600 hover:bg-red-700 text-white font-bold text-xs transition-all shadow-md">Xác nhận Thất bại</button>
        </div>
    </div>
</div>

<%-- Modal: Cập nhật Thời Gian Dự Kiến --%>
<div id="estimateModal" class="hidden fixed inset-0 bg-black/40 backdrop-blur-sm z-[1000] flex items-center justify-center p-4">
    <div class="bg-white w-full max-w-md p-6 rounded-3xl shadow-2xl border border-border-c">
        <h3 class="text-primary font-extrabold text-lg flex items-center gap-2 mb-4">
            <span class="w-9 h-9 rounded-2xl bg-primary-light flex items-center justify-center">
                <i class="fa-regular fa-clock text-primary"></i>
            </span>
            Cập nhật Thời Gian Giao Dự Kiến
        </h3>
        <input type="hidden" id="estDeliveryId">
        <div class="mb-5">
            <label class="block text-xs font-bold text-txt-2 mb-1.5">Thời gian giao hàng dự kiến <span class="text-red-500">*</span></label>
            <input type="datetime-local" id="estimatedTime"
                class="w-full px-4 py-3 border border-border-c rounded-2xl text-sm focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10">
        </div>
        <div class="flex gap-3 justify-end">
            <button onclick="closeModal('estimateModal')" class="px-5 py-2.5 rounded-2xl bg-slate-100 hover:bg-slate-200 text-txt-2 font-bold text-xs transition-all">Hủy</button>
            <button onclick="submitEstimate()" class="px-5 py-2.5 rounded-2xl bg-primary hover:bg-primary-hover text-white font-bold text-xs transition-all shadow-md">Lưu thời gian</button>
        </div>
    </div>
</div>

<script>
function closeModal(id) { document.getElementById(id).classList.add('hidden'); }
function openProofModal(id) {
    document.getElementById('proofDeliveryId').value = id;
    document.getElementById('proofImage').value = '';
    document.getElementById('proofModal').classList.remove('hidden');
}
function openFailModal(id) {
    document.getElementById('failDeliveryId').value = id;
    document.getElementById('failureReason').value = '';
    document.getElementById('failModal').classList.remove('hidden');
}
function openEstimateModal(id) {
    document.getElementById('estDeliveryId').value = id;
    document.getElementById('estimateModal').classList.remove('hidden');
}

async function apiCall(data) {
    try {
        const res = await fetch('${pageContext.request.contextPath}/delivery/api/update', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': window.csrfToken || '',
                'X-Requested-With': 'XMLHttpRequest'
            },
            body: JSON.stringify(data)
        });
        const ct = res.headers.get("content-type") || '';
        if (!res.ok) {
            const errData = ct.includes("application/json") ? await res.json() : {};
            throw new Error(errData.error || errData.message || ('Lỗi hệ thống (Mã: ' + res.status + ')'));
        }
        const result = await res.json();
        if (result.success) {
            location.reload();
        } else {
            alert("Lỗi: " + (result.error || result.message));
        }
    } catch (e) {
        alert(e.message || "Lỗi mạng!");
    }
}

async function claimOrder(id) {
    if (await appConfirm("Bạn có chắc chắn muốn đảm nhận đơn giao hàng này không?")) {
        apiCall({ action: "CLAIM", deliveryId: id });
    }
}

async function updateStatus(id, status) {
    if (await appConfirm("Xác nhận chuyển trạng thái sang: " + status + "?")) {
        apiCall({ action: "STATUS", deliveryId: id, status: status });
    }
}
// submitSuccess function removed since proof form is now submitted natively
function submitFail() {
    const id = document.getElementById('failDeliveryId').value;
    const reason = document.getElementById('failureReason').value.trim();
    if (!reason) { alert("Vui lòng nhập lý do thất bại!"); return; }
    closeModal('failModal');
    apiCall({ action: "STATUS", deliveryId: id, status: "FAILED", failureReason: reason });
}
function submitEstimate() {
    const id = document.getElementById('estDeliveryId').value;
    const time = document.getElementById('estimatedTime').value;
    if (!time) { alert("Vui lòng chọn thời gian!"); return; }
    closeModal('estimateModal');
    apiCall({ action: "ESTIMATE", deliveryId: id, estimatedTime: time });
}

// Close modals on backdrop click
['proofModal','failModal','estimateModal'].forEach(id => {
    document.getElementById(id).addEventListener('click', function(e) {
        if (e.target === this) closeModal(id);
    });
});
</script>

<jsp:include page="/WEB-INF/jsp/common/footer.jsp" />
