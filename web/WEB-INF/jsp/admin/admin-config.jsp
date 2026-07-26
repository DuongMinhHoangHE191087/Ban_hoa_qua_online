<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"  uri="jakarta.tags.core" %>
<%@ taglib prefix="fmt" uri="jakarta.tags.fmt" %>
<%@ taglib prefix="fn" uri="jakarta.tags.functions" %>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cấu hình Hệ thống – Admin MetaFruit</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/fontawesome.all.min.css">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/main.css">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/ui-overrides.css">
    <!-- Tailwind & SweetAlert -->
    <jsp:include page="/WEB-INF/jsp/common/tailwind-config.jsp" />
    <script src="${pageContext.request.contextPath}/assets/js/sweetalert2.all.min.js"></script>
</head>
<body class="antialiased text-txt bg-background">
<div class="admin-layout">
    <%-- Sidebar --%>
    <jsp:include page="/WEB-INF/jsp/common/admin-sidebar.jsp">
        <jsp:param name="activeMenu" value="config"/>
    </jsp:include>

    <%-- Main --%>
    <main class="admin-main p-6 md:p-8 animate-fade-in-up opacity-0">

        <%-- Page header --%>
        <div class="flex items-center justify-between bg-surface border border-border p-6 rounded-2xl shadow-sm mb-8">
            <div>
                <h1 class="text-xl md:text-2xl font-extrabold text-primary-dark tracking-tight">Cấu hình Hệ thống</h1>
                <p class="text-txt-2 text-xs md:text-sm mt-1">Thay đổi phí nền tảng, cấu hình logo, và các tham số vận hành chung của nền tảng.</p>
            </div>
            <div class="bg-surface/60 px-4 py-2 rounded-xl border border-primary-fixed/50 text-primary-dark font-bold text-sm shadow-sm backdrop-blur-sm">
                <i class="fa-solid fa-server mr-2 text-primary"></i> Global Settings
            </div>
        </div>

        <jsp:include page="/WEB-INF/jsp/common/alert.jsp" />

        <div class="glass-card overflow-hidden">
            <div class="px-6 py-4 border-b border-border bg-slate-50/50 flex items-center justify-between">
                <h3 class="font-bold text-txt text-sm"><i class="fa-solid fa-sliders text-primary mr-1"></i> Tham số cấu hình</h3>
            </div>

            <div class="overflow-x-auto">
                <table class="w-full text-left text-sm">
                    <thead>
                        <tr class="bg-surface-2 border-b border-border text-txt-2 text-xs uppercase tracking-wider">
                            <th class="px-6 py-3.5 font-bold">Khóa (Key)</th>
                            <th class="px-6 py-3.5 font-bold">Giá trị hiện tại</th>
                            <th class="px-6 py-3.5 font-bold">Mô tả</th>
                            <th class="px-6 py-3.5 font-bold">Kiểu</th>
                            <th class="px-6 py-3.5 font-bold">Cập nhật cuối</th>
                            <th class="px-6 py-3.5 font-bold text-center">Hành động</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-[#f1f5f9]">
                        <c:choose>
                            <c:when test="${empty configs}">
                                <tr>
                                    <td colspan="6" class="px-6 py-12 text-center text-txt-3">Chưa có cấu hình nào trong database.</td>
                                </tr>
                            </c:when>
                            <c:otherwise>
                                <c:forEach var="c" items="${configs}">
                                    <tr class="hover:bg-slate-50 transition-colors">
                                        <td class="px-6 py-4 font-mono font-bold text-primary text-xs"><c:out value="${c.config_key}" /></td>
                                        <td class="px-6 py-4 font-bold text-txt">
                                            <c:choose>
                                                <c:when test="${c.config_key == 'WEBSITE_LOGO_URL' && not empty c.config_value}">
                                                    <div class="flex items-center gap-2">
                                                        <img src="<c:out value='${c.config_value}' />" alt="Logo" class="h-8 rounded shadow-sm border border-slate-200 bg-white p-1">
                                                        <span class="truncate max-w-[150px] text-xs text-txt-3"><c:out value="${c.config_value}" /></span>
                                                    </div>
                                                </c:when>
                                                <c:when test="${c.config_key == 'gemini_api_key' && not empty c.config_value}">
                                                    <span class="text-txt-3" title="API Key được ẩn vì lý do bảo mật">••••••••••••</span>
                                                </c:when>
                                                <c:when test="${c.data_type == 'DECIMAL' && c.config_key == 'platform_fee_rate'}">
                                                    <span class="text-orange-600">
                                                        <fmt:formatNumber value="${c.config_value * 100}" pattern="#.##"/>%
                                                    </span>
                                                </c:when>
                                                <c:when test="${c.data_type == 'BOOLEAN'}">
                                                    <form id="toggle-form-${c.config_key}" method="POST" action="${pageContext.request.contextPath}/admin/config" class="m-0 inline-flex items-center">
                                                        <input type="hidden" name="_csrf" value="${sessionScope._csrfToken}">
                                                        <input type="hidden" name="action" value="update">
                                                        <input type="hidden" name="configKey" value="${fn:escapeXml(c.config_key)}">
                                                        <input type="hidden" name="configValue" value="${c.config_value == 'true' ? 'false' : 'true'}">
                                                        <input type="hidden" name="reason" value="Bật/Tắt cấu hình ${fn:escapeXml(c.config_key)} qua giao diện điều khiển">
                                                        <label class="relative inline-flex items-center cursor-pointer select-none">
                                                            <input type="checkbox" ${c.config_value == 'true' ? 'checked' : ''} 
                                                                   onchange="confirmToggleConfig('${fn:escapeXml(c.config_key)}', '${fn:escapeXml(c.config_key)}', this.checked)" 
                                                                   class="sr-only peer">
                                                            <div class="w-11 h-6 bg-slate-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary"></div>
                                                            <span class="ms-3 text-xs font-bold text-txt-2">
                                                                <c:choose>
                                                                    <c:when test="${c.config_value == 'true'}">
                                                                        <span class="text-emerald-600"><i class="fa-solid fa-circle-check mr-1"></i> Bật</span>
                                                                    </c:when>
                                                                    <c:otherwise>
                                                                        <span class="text-slate-500"><i class="fa-solid fa-circle-xmark mr-1"></i> Tắt</span>
                                                                    </c:otherwise>
                                                                </c:choose>
                                                            </span>
                                                        </label>
                                                    </form>
                                                </c:when>
                                                <c:otherwise>
                                                    <c:out value="${c.config_value}" />
                                                </c:otherwise>
                                            </c:choose>
                                        </td>
                                        <td class="px-6 py-4 text-txt-2 text-xs"><c:out value="${c.description}" /></td>
                                        <td class="px-6 py-4">
                                            <span class="px-2 py-1 bg-slate-100 border border-slate-200 rounded text-[10px] font-mono text-slate-500"><c:out value="${c.data_type}" /></span>
                                        </td>
                                        <td class="px-6 py-4 text-xs text-txt-3">
                                            <fmt:formatDate value="${c.updated_at}" pattern="dd/MM/yyyy HH:mm" /><br/>
                                            <span class="text-[10px] text-primary">bởi <c:out value="${not empty c.admin_name ? c.admin_name : 'Hệ thống'}" /></span>
                                        </td>
                                        <td class="px-6 py-4 text-center">
                                            <button
                                                    data-key="${fn:escapeXml(c.config_key)}"
                                                    data-value="${fn:escapeXml(c.config_value)}"
                                                    data-desc="${fn:escapeXml(c.description)}"
                                                    data-type="${fn:escapeXml(c.data_type)}"
                                                    onclick="openEditModal(this)"
                                                    class="bg-white hover:bg-slate-50 border border-slate-200 text-txt-2 hover:text-primary font-bold px-3 py-1.5 rounded-lg text-xs transition-all cursor-pointer shadow-sm">
                                                <i class="fa-solid fa-pen mr-1"></i> Sửa
                                            </button>
                                        </td>
                                    </tr>
                                </c:forEach>
                            </c:otherwise>
                        </c:choose>
                    </tbody>
                </table>
            </div>
        </div>

    </main>
</div>

<%-- Maintenance Actions --%>
<div class="px-6 md:px-8 pb-8">
    <div class="glass-card border-red-200 overflow-hidden">
        <div class="px-6 py-4 border-b border-red-100 bg-red-50 flex items-center justify-between">
            <h3 class="font-bold text-red-800 text-sm"><i class="fa-solid fa-triangle-exclamation mr-1"></i> Tác vụ Bảo trì Hệ thống (Nguy hiểm)</h3>
        </div>
        <div class="p-6">
            <div class="flex items-start gap-4">
                <div class="w-12 h-12 rounded-full bg-red-100 flex items-center justify-center shrink-0">
                    <i class="fa-solid fa-users-slash text-red-600 text-xl"></i>
                </div>
                <div>
                    <h4 class="font-bold text-txt mb-1">Đăng xuất tất cả phiên đăng nhập (Xóa Refresh Tokens)</h4>
                    <p class="text-sm text-txt-2 mb-4">Hành động này sẽ xóa toàn bộ token duy trì đăng nhập của tất cả người dùng. Bất kỳ ai đang không truy cập hoặc tải lại trang sau khi phiên bộ nhớ hết hạn sẽ phải đăng nhập lại. Sử dụng tính năng này trước khi bảo trì hệ thống.</p>
                    <div class="mb-4 flex items-center gap-2 bg-red-50 border border-red-200 p-3 rounded-lg">
                        <input type="checkbox" id="confirmDangerAction" class="rounded text-red-600 focus:ring-red-500 cursor-pointer" onchange="toggleDangerButton(this)">
                        <label for="confirmDangerAction" class="text-xs font-semibold text-red-800 cursor-pointer select-none">Tôi xác nhận hiểu rõ rủi ro và muốn kích hoạt hành động này</label>
                    </div>
                    <form method="POST" action="${pageContext.request.contextPath}/admin/config" onsubmit="return confirmClearSessions(event)">
                        <input type="hidden" name="_csrf" value="${sessionScope._csrfToken}">
                        <input type="hidden" name="action" value="clearAllSessions">
                        <button type="submit" id="btnDangerSubmit" disabled class="bg-slate-400 text-white font-bold px-4 py-2 rounded-xl text-xs transition-all shadow cursor-not-allowed opacity-50">
                            <i class="fa-solid fa-right-from-bracket mr-1"></i> Thực hiện Xóa phiên
                        </button>
                    </form>
                </div>
            </div>
        </div>
    </div>
</div>

<%-- Edit Config Modal --%>
<div id="editModal" class="hidden fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
    <div class="bg-white rounded-2xl w-full max-w-md shadow-2xl border border-border">
        <div class="flex items-center justify-between px-6 py-4 border-b border-border bg-slate-50/50 rounded-t-2xl">
            <h3 class="font-black text-txt text-base flex items-center gap-2"><i class="fa-solid fa-sliders text-primary"></i> Sửa tham số cấu hình</h3>
            <button class="text-txt-3 hover:text-red-500 text-xl focus:outline-none cursor-pointer transition-colors" onclick="closeModal('editModal')">&times;</button>
        </div>
        <form method="POST" action="${pageContext.request.contextPath}/admin/config" class="p-6">
            <input type="hidden" name="_csrf" value="${sessionScope._csrfToken}">
            <input type="hidden" name="action" value="update">
            
            <div class="mb-4">
                <label class="block text-xs font-bold text-txt-2 mb-1.5 uppercase tracking-wide">Khóa (Key)</label>
                <input type="text" name="configKey" id="editKey" class="w-full rounded-xl border border-slate-300 bg-slate-100 text-slate-500 p-3 text-sm font-mono cursor-not-allowed" readonly>
            </div>
            
            <div class="mb-4">
                <label class="block text-xs font-bold text-txt-2 mb-1.5 uppercase tracking-wide">Mô tả (Read-only)</label>
                <div id="editDesc" class="text-xs text-txt-3 p-3 bg-slate-50 border border-dashed border-slate-200 rounded-xl"></div>
            </div>

            <div class="mb-4">
                                <label class="block text-xs font-bold text-txt-2 mb-1.5 uppercase tracking-wide">Giá trị mới <span class="text-red-500">*</span></label>
                                <input type="text" name="configValue" id="editValue" class="w-full rounded-xl border border-slate-300 focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none p-3 text-sm font-bold text-txt transition-all shadow-inner" required>
                                <select id="editValueSelect" class="hidden w-full rounded-xl border border-slate-300 focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none p-3 text-sm font-bold text-txt transition-all shadow-inner">
                                    <option value="true">True (Bật)</option>
                                    <option value="false">False (Tắt)</option>
                                </select>
                                <p id="editHelper" class="text-[10px] text-slate-500 mt-1.5 ml-1"></p>
                            </div>
            
            <button type="submit" class="w-full py-3 bg-primary hover:bg-primary-dk text-white font-bold rounded-xl text-xs tracking-wider uppercase transition-all shadow-md active:scale-95 cursor-pointer mt-2">
                <i class="fa-solid fa-save mr-1"></i> Lưu cấu hình
            </button>
        </form>
    </div>
</div>

<script>
    function openModal(id) {
        document.getElementById(id).classList.remove('hidden');
    }
    
    function closeModal(id) {
        document.getElementById(id).classList.add('hidden');
    }
    
    function confirmToggleConfig(key, displayName, willEnable) {
        const actionText = willEnable ? 'bật' : 'tắt';
        const formId = 'toggle-form-' + key;
        Swal.fire({
            title: 'Xác nhận thay đổi?',
            html: `Bạn có chắc chắn muốn <b>\${actionText}</b> cấu hình <b>\${displayName}</b> không?`,
            icon: 'question',
            showCancelButton: true,
            confirmButtonColor: '#4d661c',
            cancelButtonColor: '#94a3b8',
            confirmButtonText: 'Đồng ý',
            cancelButtonText: 'Hủy'
        }).then((result) => {
            if (result.isConfirmed) {
                document.getElementById(formId).submit();
            } else {
                const checkbox = document.querySelector(`#\${formId} input[type="checkbox"]`);
                if (checkbox) {
                    checkbox.checked = !willEnable;
                }
            }
        });
    }

    function openEditModal(btn) {
        const key = btn.dataset.key || '';
        const val = btn.dataset.value || '';
        const desc = btn.dataset.desc || '';
        const type = btn.dataset.type || '';
        document.getElementById('editKey').value = key;
        document.getElementById('editDesc').innerText = desc || 'Không có mô tả.';
        
        const valueInput = document.getElementById('editValue');
        const valueSelect = document.getElementById('editValueSelect');
        let helper = document.getElementById('editHelper');
        
        if (type === 'BOOLEAN') {
            valueInput.classList.add('hidden');
            valueInput.removeAttribute('name');
            valueInput.required = false;
            
            valueSelect.classList.remove('hidden');
            valueSelect.setAttribute('name', 'configValue');
            valueSelect.value = val === 'true' ? 'true' : 'false';
            
            helper.innerHTML = '<i class="fa-solid fa-circle-info text-blue-500 mr-1"></i> Chọn chế độ Bật hoặc Tắt.';
        } else {
            valueSelect.classList.add('hidden');
            valueSelect.removeAttribute('name');
            
            valueInput.classList.remove('hidden');
            valueInput.setAttribute('name', 'configValue');
            valueInput.value = val;
            valueInput.required = true;
            
            if (key === 'platform_fee_rate') {
                helper.innerHTML = '<i class="fa-solid fa-circle-info text-blue-500 mr-1"></i> Nhập tỷ lệ phí, ví dụ 5 hoặc 0.05 đều được. Hệ thống sẽ lưu theo dạng thập phân (0.05 = 5%).';
                valueInput.type = 'number';
                valueInput.step = '0.01';
            } else if (key === 'WEBSITE_LOGO_URL') {
                helper.innerHTML = '<i class="fa-solid fa-circle-info text-blue-500 mr-1"></i> Nhập URL ảnh hợp lệ hoặc đường dẫn tương đối bắt đầu bằng /.';
                valueInput.type = 'text';
                valueInput.removeAttribute('step');
            } else if (key === 'gemini_api_key') {
                helper.innerHTML = '<i class="fa-solid fa-circle-info text-blue-500 mr-1"></i> Có thể để trống để dùng biến môi trường GEMINI_API_KEY.';
                valueInput.type = 'text';
                valueInput.removeAttribute('step');
            } else if (type === 'DECIMAL') {
                helper.innerHTML = '<i class="fa-solid fa-circle-info text-blue-500 mr-1"></i> Nhập số thập phân (ví dụ: 10.5 hoặc 5)';
                valueInput.type = 'number';
                valueInput.step = '0.01';
            } else if (type === 'INT') {
                helper.innerHTML = '<i class="fa-solid fa-circle-info text-blue-500 mr-1"></i> Nhập số nguyên (ví dụ: 10)';
                valueInput.type = 'number';
                valueInput.step = '1';
            } else {
                helper.innerHTML = '<i class="fa-solid fa-circle-info text-blue-500 mr-1"></i> Nhập văn bản hoặc đường dẫn (URL)';
                valueInput.type = 'text';
                valueInput.removeAttribute('step');
            }
        }
        
        openModal('editModal');
    }

    window.onclick = e => {
        if (e.target === document.getElementById('editModal')) closeModal('editModal');
    };

    function toggleDangerButton(chk) {
        const btn = document.getElementById('btnDangerSubmit');
        if (chk.checked) {
            btn.disabled = false;
            btn.className = "bg-red-600 hover:bg-red-700 text-white font-bold px-4 py-2 rounded-xl text-xs transition-all shadow-md active:scale-95 cursor-pointer";
        } else {
            btn.disabled = true;
            btn.className = "bg-slate-400 text-white font-bold px-4 py-2 rounded-xl text-xs transition-all shadow cursor-not-allowed opacity-50";
        }
    }

    function confirmClearSessions(event) {
        event.preventDefault();
        Swal.fire({
            title: 'Xóa toàn bộ phiên đăng nhập?',
            html: 'Bạn có <b>CHẮC CHẮN</b> muốn xóa toàn bộ phiên đăng nhập của tất cả người dùng không?<br><small class="text-red-600 font-semibold">Hành động này sẽ buộc mọi người dùng phải đăng nhập lại!</small>',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#ef4444',
            cancelButtonColor: '#e5e7eb',
            confirmButtonText: 'Đồng ý xóa',
            cancelButtonText: 'Hủy'
        }).then(r => { if (r.isConfirmed) event.target.submit(); });
        return false;
    }
</script>
</body>
</html>
