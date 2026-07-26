<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%@ taglib prefix="ft" uri="/WEB-INF/tld/fruitmkt.tld" %>
<jsp:include page="/WEB-INF/jsp/common/header.jsp">
    <jsp:param name="pageTitle" value="MetaFruit | Chi tiết giao hàng #${delivery.deliveryId}"/>
</jsp:include>

<script src="${pageContext.request.contextPath}/assets/js/tailwind.js"></script>
<script>
tailwind.config = {
    theme: {
        extend: {
            colors: {
                primary: '#16A34A', 'primary-hover': '#15803D', 'primary-light': '#DCFCE7',
                'txt': '#0F172A', 'txt-2': '#475569', 'txt-3': '#94A3B8',
                'border-c': '#BBF7D0', 'bg-page': '#F0FDF4'
            },
            fontFamily: { sans: ['Lexend', 'sans-serif'] }
        }
    }
}
</script>

<main class="max-w-4xl mx-auto px-4 md:px-8 py-10 font-sans text-txt">

    <%-- Back Button + Title --%>
    <div class="mb-7">
        <a href="${pageContext.request.contextPath}/delivery/dashboard"
           class="text-primary hover:text-primary-hover text-sm font-bold flex items-center gap-1.5 mb-3 w-fit">
            <i class="fa-solid fa-arrow-left"></i> Quay lại tổng quan
        </a>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div class="flex items-center gap-3">
                <div class="w-11 h-11 rounded-2xl bg-primary flex items-center justify-center shadow-md">
                    <i class="fa-solid fa-truck-fast text-white text-lg"></i>
                </div>
                <div>
                    <h1 class="text-2xl font-extrabold text-[#14532D] tracking-tight">Chi tiết giao hàng #${delivery.deliveryId}</h1>
                    <p class="text-txt-3 text-xs">Mã đơn hàng: #${delivery.orderId}</p>
                </div>
            </div>
            <%-- Status Badge --%>
            <c:if test="${not empty delivery}">
                <div>
                    <c:choose>
                        <c:when test="${empty delivery.staffId}">
                            <span class="status-badge bg-sky-100 text-sky-800 border border-sky-300 font-extrabold animate-pulse">
                                <i class="fa-solid fa-hourglass-half text-[9px]"></i> Chờ Shipper nhận đơn
                            </span>
                        </c:when>
                        <c:when test="${delivery.status == 'ASSIGNED'}">
                            <span class="status-badge bg-blue-50 text-blue-700 border border-blue-200">
                                <i class="fa-solid fa-inbox text-[9px]"></i> Mới nhận
                            </span>
                        </c:when>
                        <c:when test="${delivery.status == 'PICKED_UP'}">
                            <span class="status-badge bg-amber-50 text-amber-700 border border-amber-200">
                                <i class="fa-solid fa-box text-[9px]"></i> Đã lấy hàng
                            </span>
                        </c:when>
                        <c:when test="${delivery.status == 'IN_TRANSIT'}">
                            <span class="status-badge bg-purple-50 text-purple-700 border border-purple-200">
                                <i class="fa-solid fa-truck text-[9px]"></i> Đang giao
                            </span>
                        </c:when>
                        <c:when test="${delivery.status == 'DELIVERED'}">
                            <span class="status-badge bg-emerald-50 text-emerald-700 border border-emerald-200">
                                <i class="fa-solid fa-circle-check text-[9px]"></i> Đã giao thành công
                            </span>
                        </c:when>
                        <c:when test="${delivery.status == 'FAILED'}">
                            <span class="status-badge bg-red-50 text-red-700 border border-red-200">
                                <i class="fa-solid fa-circle-xmark text-[9px]"></i> Giao hàng thất bại
                            </span>
                        </c:when>
                    </c:choose>
                </div>
            </c:if>
        </div>
    </div>

    <%-- Error Alert --%>
    <c:if test="${not empty errorMsg}">
        <div class="flex items-center gap-3 p-4 mb-6 rounded-2xl bg-red-50 border-l-4 border-red-400 text-red-800 text-sm font-semibold shadow-sm">
            <i class="fa-solid fa-circle-exclamation"></i>
            <span class="flex-1"><c:out value="${errorMsg}"/></span>
        </div>
    </c:if>

    <%-- Delivery not found --%>
    <c:if test="${empty delivery}">
        <div class="glass-card rounded-3xl text-center py-20 px-6">
            <i class="fa-solid fa-circle-exclamation text-4xl text-red-400 mb-4"></i>
            <h2 class="text-lg font-bold text-red-700 mb-2">Không tìm thấy đơn giao hàng</h2>
            <p class="text-txt-3 text-sm">Đơn giao hàng này không tồn tại hoặc bạn không có quyền xem.</p>
        </div>
    </c:if>

    <c:if test="${not empty delivery}">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">

            <%-- Left Column: Journey Status + Estimated Time --%>
            <div class="flex flex-col gap-6">

                <%-- Journey Steps --%>
                <div class="glass-card rounded-3xl p-6">
                    <h2 class="font-bold text-[#14532D] text-base mb-4 flex items-center gap-2">
                        <i class="fa-solid fa-route text-primary"></i> Hành trình giao hàng
                    </h2>
                    <div class="flex flex-col gap-0">
                        <c:set var="s" value="${delivery.status}"/>
                        <c:forEach var="step" items="ASSIGNED,PICKED_UP,IN_TRANSIT,DELIVERED" varStatus="vs">
                            <c:set var="done" value="${s == 'ASSIGNED' && vs.index == 0
                                || (s == 'PICKED_UP' && vs.index <= 1)
                                || (s == 'IN_TRANSIT' && vs.index <= 2)
                                || (s == 'DELIVERED' && vs.index <= 3)}"/>
                            <c:set var="current" value="${s == step}"/>
                            <div class="flex items-start gap-3 pb-5 relative">
                                <c:if test="${!vs.last}">
                                    <div class="absolute left-[13px] top-7 bottom-0 w-[2px] ${done ? 'bg-primary' : 'bg-slate-200'}"></div>
                                </c:if>
                                <div class="w-7 h-7 rounded-full shrink-0 flex items-center justify-center border-2 z-10
                                    ${done ? 'bg-primary border-primary' : (current ? 'bg-primary-light border-primary' : 'bg-slate-100 border-slate-200')}">
                                    <i class="fa-solid ${done ? 'fa-check' : 'fa-circle'} text-[10px] ${done ? 'text-white' : (current ? 'text-primary' : 'text-slate-300')}"></i>
                                </div>
                                <div>
                                    <span class="font-bold text-sm ${done ? 'text-primary' : 'text-txt-3'}">
                                        <c:choose>
                                            <c:when test="${step == 'ASSIGNED'}">Đã gán / Nhận đơn</c:when>
                                            <c:when test="${step == 'PICKED_UP'}">Đã lấy hàng từ Shop</c:when>
                                            <c:when test="${step == 'IN_TRANSIT'}">Đang trên đường giao</c:when>
                                            <c:when test="${step == 'DELIVERED'}">Giao thành công</c:when>
                                        </c:choose>
                                    </span>
                                    <c:if test="${step == 'DELIVERED' && not empty delivery.deliveredAt}">
                                        <span class="block text-xs text-txt-3">${delivery.deliveredAt}</span>
                                    </c:if>
                                    <c:if test="${step == 'PICKED_UP' && not empty delivery.pickedUpAt}">
                                        <span class="block text-xs text-txt-3">${delivery.pickedUpAt}</span>
                                    </c:if>
                                </div>
                            </div>
                        </c:forEach>

                        <c:if test="${delivery.status == 'FAILED'}">
                            <div class="flex items-start gap-3 mt-1">
                                <div class="w-7 h-7 rounded-full bg-red-600 border-2 border-red-600 flex items-center justify-center shrink-0">
                                    <i class="fa-solid fa-xmark text-white text-[10px]"></i>
                                </div>
                                <div>
                                    <span class="font-bold text-sm text-red-600">Giao hàng thất bại</span>
                                    <c:if test="${not empty delivery.failureReason}">
                                        <p class="text-xs text-red-500 mt-0.5">${delivery.failureReason}</p>
                                    </c:if>
                                </div>
                            </div>
                        </c:if>
                    </div>
                </div>

                <%-- Time Estimator --%>
                <div class="glass-card rounded-3xl p-6">
                    <div class="flex items-center justify-between mb-3">
                        <h2 class="font-bold text-[#0C4A6E] text-base flex items-center gap-2">
                            <i class="fa-regular fa-clock text-primary"></i> Thời gian giao dự kiến
                        </h2>
                        <c:if test="${not empty delivery.staffId && delivery.status != 'DELIVERED' && delivery.status != 'FAILED'}">
                            <button type="button" onclick="openEstimateModal('${delivery.deliveryId}')"
                                class="text-primary hover:text-primary-hover underline text-xs font-bold cursor-pointer">
                                Cập nhật
                            </button>
                        </c:if>
                    </div>
                    <c:choose>
                        <c:when test="${not empty delivery.estimatedDeliveryTime}">
                            <p class="text-2xl font-extrabold text-primary">${delivery.estimatedDeliveryTime}</p>
                        </c:when>
                        <c:otherwise>
                            <p class="text-txt-3 italic text-sm">Chưa thiết lập</p>
                        </c:otherwise>
                    </c:choose>
                </div>

                <%-- Action Button Card --%>
                <div class="glass-card rounded-3xl p-6 flex flex-col gap-3">
                    <h2 class="font-bold text-[#0C4A6E] text-base mb-1 flex items-center gap-2">
                        <i class="fa-solid fa-sliders text-primary"></i> Thao tác nhanh
                    </h2>
                    <div>
                        <c:choose>
                            <c:when test="${empty delivery.staffId}">
                                <button onclick="claimOrder('${delivery.deliveryId}')"
                                    class="w-full bg-[#0369A1] hover:bg-[#0284C7] text-white font-bold py-3 rounded-2xl transition-all shadow-md active:scale-95 cursor-pointer border-0 flex items-center justify-center gap-2">
                                    <i class="fa-solid fa-hand-holding-hand"></i> Nhận đơn giao hàng này
                                </button>
                            </c:when>
                            <c:when test="${delivery.status == 'ASSIGNED'}">
                                <button onclick="updateStatus('${delivery.deliveryId}', 'PICKED_UP')"
                                    class="w-full bg-primary hover:bg-primary-hover text-white font-bold py-3 rounded-2xl transition-all shadow-md active:scale-95 cursor-pointer border-0 flex items-center justify-center gap-2">
                                    <i class="fa-solid fa-box-open"></i> Xác nhận Đã Lấy Hàng
                                </button>
                            </c:when>
                            <c:when test="${delivery.status == 'PICKED_UP'}">
                                <button onclick="updateStatus('${delivery.deliveryId}', 'IN_TRANSIT')"
                                    class="w-full bg-purple-600 hover:bg-purple-700 text-white font-bold py-3 rounded-2xl transition-all shadow-md active:scale-95 cursor-pointer border-0 flex items-center justify-center gap-2">
                                    <i class="fa-solid fa-truck"></i> Bắt đầu Giao Hàng
                                </button>
                            </c:when>
                            <c:when test="${delivery.status == 'IN_TRANSIT'}">
                                <div class="flex gap-3">
                                    <button onclick="openProofModal('${delivery.deliveryId}')"
                                        class="flex-1 bg-emerald-600 hover:bg-emerald-700 text-white font-bold py-3 rounded-2xl transition-all shadow-sm active:scale-95 cursor-pointer border-0 flex items-center justify-center gap-1.5">
                                        <i class="fa-solid fa-check"></i> Giao thành công
                                    </button>
                                    <button onclick="openFailModal('${delivery.deliveryId}')"
                                        class="flex-1 bg-red-50 hover:bg-red-600 text-red-600 hover:text-white font-bold py-3 rounded-2xl border border-red-200 transition-all shadow-sm active:scale-95 cursor-pointer flex items-center justify-center gap-1.5">
                                        <i class="fa-solid fa-xmark"></i> Thất bại
                                    </button>
                                </div>
                            </c:when>
                            <c:otherwise>
                                <div class="w-full bg-slate-50 text-txt-3 font-bold py-3 rounded-2xl text-center text-sm border border-slate-100">
                                    <i class="fa-solid fa-check-double mr-1"></i> Đã hoàn tất xử lý đơn hàng
                                </div>
                            </c:otherwise>
                        </c:choose>
                    </div>
                </div>
            </div>

            <%-- Right Column: Address Details (Point A & B) + Proof Image --%>
            <div class="flex flex-col gap-6">

                <%-- Address Details Card --%>
                <div class="glass-card rounded-3xl p-6">
                    <h2 class="font-bold text-[#0C4A6E] text-base mb-4 flex items-center gap-2">
                        <i class="fa-solid fa-map-location-dot text-primary"></i> Bản đồ hành trình giao nhận
                    </h2>
                    <div class="flex flex-col gap-6 relative">
                        <%-- Line Connector between A and B --%>
                        <div class="absolute left-4.5 top-9 bottom-9 w-0.5 border-l-2 border-dashed border-primary/40"></div>

                        <%-- Point A: Pickup Point --%>
                        <div class="flex items-start gap-4">
                            <div class="w-9 h-9 rounded-full bg-primary-light border border-primary text-primary flex items-center justify-center shrink-0 z-10 shadow-sm font-bold text-xs">
                                A
                            </div>
                            <div>
                                <span class="text-xs text-txt-3 block font-bold uppercase tracking-wider">Lấy hàng từ (Shop)</span>
                                <h3 class="font-extrabold text-txt text-sm mt-0.5"><c:out value="${shopName}"/></h3>
                                <p class="text-txt-2 text-xs leading-relaxed mt-0.5"><c:out value="${pickupAddress}"/></p>
                            </div>
                        </div>

                        <%-- Point B: Delivery Point --%>
                        <div class="flex items-start gap-4">
                            <div class="w-9 h-9 rounded-full bg-emerald-100 border border-emerald-500 text-emerald-700 flex items-center justify-center shrink-0 z-10 shadow-sm font-bold text-xs">
                                B
                            </div>
                            <div>
                                <span class="text-xs text-txt-3 block font-bold uppercase tracking-wider">Giao đến (Khách hàng)</span>
                                <h3 class="font-extrabold text-txt text-sm mt-0.5">
                                    <c:out value="${order.recipientName}"/>
                                    <c:if test="${not empty order.recipientPhone}">
                                        <span class="text-xs font-normal text-txt-2">(${order.recipientPhone})</span>
                                    </c:if>
                                </h3>
                                <p class="text-txt-2 text-xs leading-relaxed mt-0.5"><c:out value="${order.deliveryAddress}"/></p>
                                <c:if test="${not empty order.notes}">
                                    <div class="mt-2 bg-slate-50 border border-slate-100 rounded-xl p-2.5 text-xs text-txt-2 italic">
                                        <strong>Ghi chú:</strong> <c:out value="${order.notes}"/>
                                    </div>
                                </c:if>
                            </div>
                        </div>
                    </div>
                </div>

                <%-- Proof Image Embed --%>
                <c:if test="${not empty delivery.proofImageUrl}">
                    <div class="glass-card rounded-3xl p-6">
                        <h2 class="font-bold text-[#0C4A6E] text-base mb-3 flex items-center gap-2">
                            <i class="fa-solid fa-image text-emerald-600"></i> Ảnh bằng chứng giao hàng
                        </h2>
                        <a href="${delivery.proofImageUrl}" target="_blank" class="block hover:opacity-90 transition-opacity rounded-2xl overflow-hidden border border-border-c shadow-sm">
                            <img src="${delivery.proofImageUrl}" alt="Ảnh giao hàng" class="w-full max-h-60 object-cover">
                        </a>
                    </div>
                </c:if>
            </div>
        </div>
    </c:if>
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
                class="w-full px-4 py-3 border border-[#BAE6FD] rounded-2xl text-sm focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10">
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
    const el = document.getElementById(id);
    if (el) {
        el.addEventListener('click', function(e) {
            if (e.target === this) closeModal(id);
        });
    }
});
</script>

<jsp:include page="/WEB-INF/jsp/common/footer.jsp"/>
