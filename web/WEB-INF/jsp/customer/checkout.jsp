<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"  uri="jakarta.tags.core" %>
<%@ taglib prefix="fn" uri="jakarta.tags.functions" %>
<%@ taglib prefix="ft" uri="/WEB-INF/tld/fruitmkt.tld" %>
<jsp:include page="/WEB-INF/jsp/common/header.jsp"><jsp:param name="pageTitle" value="Thanh toán - MetaFruit"/></jsp:include>

<div class="pt-24 pb-12 px-margin-mobile md:px-margin-desktop max-w-7xl mx-auto font-sans antialiased text-on-background min-h-screen animate-fade-in-up opacity-0">
    
    <c:choose>
        <%-- MÀN HÌNH ĐẶT HÀNG THÀNH CÔNG --%>
        <c:when test="${not empty isSuccess}">
            <div class="max-w-2xl mx-auto text-center py-16 glass-card rounded-xl border border-white/50 p-8 flex flex-col items-center gap-6 mt-12 shadow-xl">
                <!-- Checkmark Icon Animated -->
                <div class="w-20 h-20 rounded-full bg-emerald-100 flex items-center justify-center text-primary border border-emerald-200 shadow-md">
                    <span class="material-symbols-outlined text-[48px] font-bold">verified</span>
                </div>
                
                <div>
                    <h1 class="text-3xl font-bold text-inverse-surface tracking-tight">Đặt Hàng Thành Công!</h1>
                    <p class="text-on-surface-variant mt-3 text-sm leading-relaxed max-w-md mx-auto">
                        Cảm ơn bạn đã mua nông sản sạch tại <strong>MetaFruit</strong>. Đơn hàng của bạn đã được chuyển tới nhà vườn đóng gói lạnh giao hỏa tốc!
                    </p>
                </div>

                <div class="w-full bg-[#d1ffd8]/60 border border-[#bcfdc9] rounded-2xl p-5 text-start text-xs text-on-surface-variant space-y-2">
                    <div class="flex justify-between border-b border-emerald-100/30 pb-2">
                        <span>Trạng thái thanh toán</span>
                        <span class="text-primary font-bold">Thành công (COD / Chờ xử lý)</span>
                    </div>
                    <div class="flex justify-between border-b border-emerald-100/30 pb-2">
                        <span>Mã đơn hàng</span>
                        <span class="text-inverse-surface font-bold">#<c:out value="${param.orderId}"/></span>
                    </div>
                    <div class="flex justify-between">
                        <span>Dự kiến giao hàng</span>
                        <span class="text-inverse-surface font-bold">Trong 2 - 3 tiếng (Giao Hỏa Tốc)</span>
                    </div>
                </div>

                <div class="flex flex-col sm:flex-row gap-4 w-full justify-center">
                    <a href="${pageContext.request.contextPath}/home" class="bg-[#14532D] text-white font-bold py-3.5 px-8 rounded-lg hover:bg-opacity-90 transition-all shadow-md active:scale-95 text-sm flex items-center justify-center gap-2 cursor-pointer">
                        <span class="material-symbols-outlined text-lg">shopping_basket</span>
                        <span>Tiếp tục mua sắm</span>
                    </a>
                </div>
            </div>

            <%-- CRITICAL SCRIPT: RESET GIỎ HÀNG LOCAL STORAGE CHỌN LỌC --%>
            <%-- Đọc danh sách cart_item_id đã mua từ session attribute (không lộ trên URL) --%>
            <c:set var="purgedIds" value="${sessionScope._purgedCartItemIds}"/>
            <c:remove var="_purgedCartItemIds" scope="session"/>
            <script>
                document.addEventListener('DOMContentLoaded', () => {
                    const purgedIdsRaw = '<c:out value="${purgedIds}" default=""/>';
                    const purgedIds = (purgedIdsRaw.match(/\d+/g) || []).map(id => parseInt(id, 10)).filter(id => !isNaN(id) && id > 0);
                    if (purgedIds.length > 0) {
                        console.log('[FruitMkt] Selective local cart purge. Selection IDs:', purgedIds);

                        const keys = ['userCart', 'guestCart'];
                        keys.forEach(key => {
                            try {
                                let items = JSON.parse(localStorage.getItem(key)) || [];
                                if (items.length > 0) {
                                    items = items.filter(item => {
                                        const itemCartItemId = parseInt(item.cartItemId, 10);
                                        if (!isNaN(itemCartItemId) && itemCartItemId > 0) {
                                            return !purgedIds.includes(itemCartItemId);
                                        }
                                        return !purgedIds.includes(parseInt(item.variantId, 10));
                                    });
                                    localStorage.setItem(key, JSON.stringify(items));
                                }
                            } catch (e) {
                                console.warn('[FruitMkt] Lỗi lọc giỏ local ' + key + ':', e);
                            }
                        });

                        if (typeof GuestCart !== 'undefined') {
                            GuestCart.updateBadge();
                        } else {
                            const badge = document.getElementById('cart-badge');
                            if (badge) {
                                const items = JSON.parse(localStorage.getItem('userCart')) || [];
                                badge.textContent = items.reduce((sum, i) => sum + i.quantity, 0);
                            }
                        }
                    } else {
                        // Fallback: xóa toàn bộ
                        localStorage.removeItem('userCart');
                        localStorage.removeItem('guestCart');
                        if (typeof GuestCart !== 'undefined') {
                            GuestCart.clear();
                            GuestCart.updateBadge();
                        }
                    }
                });
            </script>
        </c:when>

        <%-- FORM THANH TOÁN chuẩn mẫu Check_Out_UI.html --%>
        <c:otherwise>
            <div class="flex items-center justify-between bg-surface border border-border p-6 rounded-2xl shadow-sm mb-8 animate-fade-in-up">
                <div>
                    <h1 class="text-xl md:text-2xl font-extrabold text-primary-dark tracking-tight">Hoàn Tất Đơn Hàng</h1>
                    <p class="text-txt-2 text-xs md:text-sm mt-1">Vui lòng kiểm tra lại thông tin giao nhận, hình thức thanh toán và xác nhận đặt hàng.</p>
                </div>
                <a href="${pageContext.request.contextPath}/cart" class="bg-white border border-border hover:bg-slate-50 text-primary hover:text-primary-dk font-bold px-4 py-2.5 rounded-xl text-xs transition-all shadow-sm flex items-center gap-1.5 active:scale-95 text-decoration-none">
                    <span class="material-symbols-outlined text-sm">arrow_back</span> Quay lại giỏ hàng
                </a>
            </div>

            <form id="checkoutForm" action="${pageContext.request.contextPath}/checkout" method="post" onsubmit="return validateCheckoutForm()" class="grid grid-cols-1 lg:grid-cols-12 gap-gutter">
                <input type="hidden" name="_csrf" value="${sessionScope._csrfToken}">
                <input type="hidden" name="cartItemIds" value="<c:out value="${param.cartItemIds}"/>">
                <input type="hidden" name="variantIds" value="<c:out value="${param.variantIds}"/>">

                <!-- LEFT COLUMN: Forms -->
                <div class="lg:col-span-8 flex flex-col gap-8">
                    <!-- Step Progress Indicator -->
                    <div class="bg-white border border-emerald-100 rounded-2xl p-6 shadow-sm animate-fade-in-up">
                        <div class="flex items-center justify-between relative max-w-xs mx-auto">
                            <!-- Connecting Line -->
                            <div class="absolute left-0 right-0 top-4 h-0.5 bg-slate-100 -translate-y-1/2 z-0"></div>
                            <div id="stepLineProgress" class="absolute left-0 top-4 h-0.5 bg-primary -translate-y-1/2 z-0 transition-all duration-300" style="width: 0%;"></div>

                            <!-- Step 1 -->
                            <div class="z-10 flex flex-col items-center gap-1.5 cursor-pointer" onclick="goToStep(1)">
                                <div id="stepCircle-1" class="w-8 h-8 rounded-full bg-primary text-white flex items-center justify-center font-bold text-xs transition-all shadow-sm">1</div>
                                <span id="stepTitle-1" class="text-[11px] font-bold text-primary">Nhập thông tin</span>
                            </div>
                            <!-- Step 2 -->
                            <div class="z-10 flex flex-col items-center gap-1.5 cursor-pointer" onclick="goToStep(2)">
                                <div id="stepCircle-2" class="w-8 h-8 rounded-full bg-slate-100 text-slate-500 flex items-center justify-center font-bold text-xs transition-all">2</div>
                                <span id="stepTitle-2" class="text-[11px] font-semibold text-slate-400">Xác nhận</span>
                            </div>
                        </div>
                    </div>

                    <!-- Step 1 Container: Delivery Info, Payment & Voucher -->
                    <div id="step-1-container" class="flex flex-col gap-6 animate-fade-in-up">
                        <!-- Section 1: Delivery Info -->
                        <section class="glass-card rounded-xl p-6 md:p-8">
                            <div class="flex items-center gap-3 mb-6 text-primary border-b border-[#b1f2be] pb-3">
                                <span class="material-symbols-outlined text-2xl">local_shipping</span>
                                <h2 class="font-headline-md text-headline-md font-bold">Thông tin giao hàng</h2>
                            </div>
                            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                                <%-- Shopee/TikTok Style Address Selector --%>
                                <div class="flex flex-col gap-2 md:col-span-2 mb-2">
                                    <label class="font-label-md text-label-md text-[#14532D] font-bold">Địa chỉ nhận hàng</label>
                                    
                                    <!-- 1. Selected Address Display Card -->
                                    <div id="selectedAddressCard" class="bg-white border border-[#bcfdc9] rounded-xl p-4 shadow-sm flex items-start justify-between gap-4 transition-all duration-200">
                                        <div class="flex-grow space-y-1">
                                            <div class="flex items-center gap-2 flex-wrap">
                                                <span id="displayRecipientName" class="font-bold text-sm text-slate-800"></span>
                                                <span class="text-gray-300">|</span>
                                                <span id="displayRecipientPhone" class="text-xs text-slate-600 font-semibold"></span>
                                                <span id="defaultBadge" class="hidden px-2 py-0.5 bg-red-100 text-red-700 text-[9px] font-bold rounded-full border border-red-200">Mặc định</span>
                                            </div>
                                            <p id="displayAddressDetail" class="text-xs text-slate-600 leading-relaxed"></p>
                                        </div>
                                        <button type="button" onclick="toggleAddressSelectionList()" class="text-primary hover:underline font-bold text-xs flex items-center gap-0.5 shrink-0 cursor-pointer">
                                            Thay đổi <span class="material-symbols-outlined text-[16px] transition-transform duration-200" id="expandIcon">expand_more</span>
                                        </button>
                                    </div>

                                    <!-- 2. Collapsible Address List -->
                                    <div id="addressSelectionList" class="hidden mt-3 space-y-3 bg-[#d1ffd8]/20 border border-[#bcfdc9]/40 rounded-xl p-4 transition-all duration-300">
                                        <div class="text-[10px] font-bold uppercase tracking-wider text-[#31694b] mb-2">Chọn địa chỉ nhận hàng khác</div>
                                        <div id="addressOptionsContainer" class="space-y-2 max-h-60 overflow-y-auto pr-1">
                                            <!-- Rendered dynamically by JS -->
                                        </div>
                                        <div class="flex justify-between items-center border-t border-emerald-100/50 pt-3 mt-3">
                                            <button type="button" onclick="showInlineAddressForm('add')" class="text-primary hover:underline text-xs font-bold flex items-center gap-0.5 cursor-pointer">
                                                <span class="material-symbols-outlined text-[16px]">add</span> Thêm địa chỉ mới
                                            </button>
                                            <button type="button" onclick="toggleAddressSelectionList()" class="text-slate-500 hover:text-slate-700 text-xs font-bold cursor-pointer">
                                                Đóng
                                            </button>
                                        </div>
                                    </div>

                                    <!-- 3. Collapsible Inline Form -->
                                    <div id="inlineAddressForm" class="hidden overflow-hidden transition-all duration-300 border-t border-emerald-100 pt-4 mt-4 space-y-4">
                                        <div class="text-xs font-bold text-[#14532D]" id="inlineFormTitle">Thêm địa chỉ nhận hàng mới</div>
                                        <input type="hidden" id="inlineAddressId" value="">
                                        <input type="hidden" id="inlineAction" value="add">
                                        
                                        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                                            <div class="flex flex-col gap-1.5">
                                                <label class="text-[10px] font-bold text-slate-700" for="mRecipientName">Họ và tên người nhận *</label>
                                                <input type="text" id="mRecipientName" class="w-full px-3 py-2.5 border border-slate-200 rounded-lg text-xs focus:outline-none focus:border-[#14532D] bg-white">
                                            </div>
                                            <div class="flex flex-col gap-1.5">
                                                <label class="text-[10px] font-bold text-slate-700" for="mRecipientPhone">Số điện thoại nhận hàng *</label>
                                                <input type="text" id="mRecipientPhone" class="w-full px-3 py-2.5 border border-slate-200 rounded-lg text-xs focus:outline-none focus:border-[#14532D] bg-white">
                                            </div>
                                            <div class="flex flex-col gap-1.5 md:col-span-2">
                                                <label class="text-[10px] font-bold text-slate-700" for="mAddressDetail">Địa chỉ chi tiết *</label>
                                                <textarea id="mAddressDetail" rows="2" placeholder="Số nhà, tên đường, phường/xã, quận/huyện, tỉnh/thành phố..."
                                                          class="w-full px-3 py-2.5 border border-slate-200 rounded-lg text-xs focus:outline-none focus:border-[#14532D] resize-none bg-white"></textarea>
                                            </div>
                                        </div>
                                        
                                        <div class="flex items-center gap-2">
                                            <input type="checkbox" id="mIsDefault" class="rounded text-[#14532D] focus:ring-[#14532D] h-4 w-4 cursor-pointer">
                                            <label for="mIsDefault" class="text-[10px] text-slate-700 font-bold cursor-pointer select-none">Đặt làm địa chỉ nhận hàng mặc định</label>
                                        </div>
                                        
                                        <div class="flex justify-end gap-2.5 pt-3 border-t border-slate-100">
                                            <button type="button" id="btnCancelInlineAddress" onclick="hideInlineAddressForm()" class="px-4 py-2 border border-slate-200 hover:bg-slate-50 text-[10px] font-bold text-slate-600 rounded-lg transition-colors bg-white cursor-pointer">Hủy bỏ</button>
                                            <button type="button" id="btnSaveCheckoutAddress" onclick="handleInlineAddressSubmit()" class="px-4 py-2 bg-[#14532D] text-white text-[10px] font-bold rounded-lg transition-colors border-0 cursor-pointer hover:bg-opacity-95">Lưu địa chỉ</button>
                                        </div>
                                    </div>
                                </div>

                                <!-- Hidden inputs to be posted to the servlet -->
                                <input type="hidden" id="fullName" name="fullName">
                                <input type="hidden" id="phone" name="phone">
                                <input type="hidden" id="deliveryAddress" name="deliveryAddress">
                                <input type="hidden" id="saveAddressToBook" name="saveAddressToBook" value="false">
                                <div class="flex flex-col gap-2 md:col-span-2">
                                    <label class="font-label-md text-label-md text-[#14532D] font-bold" for="deliveryTimeSlot">Khung giờ nhận hàng *</label>
                                    <select class="form-input rounded-lg px-4 py-3 font-body-md text-body-md w-full bg-white border border-[#bcfdc9] focus:outline-none focus:border-[#14532D]" id="deliveryTimeSlot" name="deliveryTimeSlot">
                                        <option value="08:00-12:00">08:00 - 12:00 (Buổi sáng)</option>
                                        <option value="12:00-16:00">12:00 - 16:00 (Buổi chiều)</option>
                                        <option value="16:00-20:00">16:00 - 20:00 (Buổi tối)</option>
                                        <option value="Giao hỏa tốc" selected>Giao hỏa tốc (Trong vòng 2 giờ)</option>
                                    </select>
                                </div>
                                <div class="flex flex-col gap-2 md:col-span-2">
                                    <label class="font-label-md text-label-md text-[#14532D]" for="notes">Ghi chú (Tuỳ chọn)</label>
                                    <textarea class="form-input rounded-lg px-4 py-3 font-body-md text-body-md w-full" id="notes" name="notes" placeholder="Ghi chú thêm cho người giao hàng..." rows="3"></textarea>
                                </div>
                            </div>
                        </section>

                        <!-- Section 2: Payment Methods -->
                        <section class="glass-card rounded-xl p-6 md:p-8">
                            <div class="flex items-center gap-3 mb-6 text-primary border-b border-[#b1f2be] pb-3">
                                <span class="material-symbols-outlined text-2xl">payments</span>
                                <h2 class="font-headline-md text-headline-md font-bold">Phương thức thanh toán</h2>
                            </div>
                            <div class="flex flex-col gap-4">
                                <!-- Option 1: COD -->
                                <label class="flex items-start gap-4 p-4 rounded-lg border border-outline-variant hover:border-primary bg-white/40 cursor-pointer transition-colors">
                                    <div class="flex items-center h-6">
                                        <input checked="" class="custom-radio w-5 h-5 text-primary focus:ring-primary border-[#14532D]" name="paymentMethod" type="radio" value="COD">
                                    </div>
                                    <div class="flex flex-col">
                                        <span class="font-label-md text-label-md text-on-surface font-bold">Thanh toán khi nhận hàng (COD)</span>
                                        <span class="font-body-md text-body-md text-on-surface-variant text-sm mt-1">Thanh toán bằng tiền mặt khi giao hàng tận nơi.</span>
                                    </div>
                                    <span class="material-symbols-outlined ml-auto text-primary opacity-70">local_atm</span>
                                </label>
                                
                                <!-- Option 2: Bank QR -->
                                <label class="flex items-start gap-4 p-4 rounded-lg border border-outline-variant hover:border-primary bg-white/40 cursor-pointer transition-colors">
                                    <div class="flex items-center h-6">
                                        <input class="custom-radio w-5 h-5 text-primary focus:ring-primary border-[#14532D]" name="paymentMethod" type="radio" value="CK">
                                    </div>
                                    <div class="flex flex-col">
                                        <span class="font-label-md text-label-md text-on-surface font-bold">Chuyển khoản QR ngân hàng</span>
                                        <span class="font-body-md text-body-md text-on-surface-variant text-sm mt-1">Thông tin và mã QR chuyển khoản sẽ hiển thị sau khi đặt hàng.</span>
                                    </div>
                                    <span class="material-symbols-outlined ml-auto text-primary opacity-70">account_balance</span>
                                </label>
                            </div>
                        </section>

                        <!-- Section 3: Mã Giảm Giá -->
                        <section class="glass-card rounded-xl p-6 md:p-8" id="coupon-section">
                            <div class="flex items-center gap-3 mb-4 text-primary border-b border-[#b1f2be] pb-3">
                                <span class="material-symbols-outlined text-2xl">loyalty</span>
                                <h2 class="font-headline-md text-headline-md font-bold">Voucher shop / Voucher sàn / Freeship</h2>
                            </div>
                            <!-- Một ô nhập mã giảm giá duy nhất cho cả 3 slot -->
                            <div>
                                <label class="block text-sm font-bold text-[#14532D] mb-1" for="couponInput">Nhập mã voucher shop, voucher sàn, freeship hoặc voucher thanh toán</label>
                                <div class="flex gap-2">
                                    <input type="text" id="couponInput" placeholder="Nhập mã voucher (VD: SHOP10, SAAN5, SALE20)"
                                        class="form-input rounded-lg px-3 py-2.5 text-sm flex-1 uppercase font-semibold tracking-wider"
                                        style="text-transform:uppercase"/>
                                    <button type="button" onclick="applyCoupon()"
                                        class="bg-[#14532D] text-white font-bold px-5 py-2.5 rounded-lg text-sm hover:bg-opacity-90 transition-all cursor-pointer flex-shrink-0 active:scale-95 duration-150 shadow-md">
                                        Áp dụng
                                    </button>
                                </div>
                                <p id="couponMsg" class="text-xs mt-2 hidden"></p>
                            </div>
                            
                            <!-- Container hiển thị các mã đã áp dụng -->
                            <div id="appliedCouponsContainer" class="mt-4 hidden border-t border-dashed border-emerald-200 pt-3">
                                <span class="text-xs font-bold text-on-surface-variant block mb-2">Mã đã áp dụng:</span>
                                <div id="appliedCouponsList" class="flex flex-col gap-2">
                                    <!-- Rendered dynamically via JS -->
                                </div>
                            </div>

                            <!-- Hidden inputs để gửi lên Servlet khi Submit -->
                            <input type="hidden" name="shopCouponCode" id="shopCouponCode"/>
                            <input type="hidden" name="systemCouponCode" id="systemCouponCode"/>
                        </section>

                        <!-- Navigation for Step 1 -->
                        <div class="flex justify-end mt-4">
                            <button type="button" onclick="goToStep(2)" class="bg-[#14532D] text-white font-bold py-3 px-6 rounded-xl hover:bg-opacity-95 transition-all shadow-sm active:scale-95 text-xs flex items-center gap-1.5 cursor-pointer">
                                Tiếp tục xác nhận <span class="material-symbols-outlined text-sm">arrow_forward</span>
                            </button>
                        </div>
                    </div>

                    <!-- Step 2 Container: Confirmation - Order Items List Grouped by Shop -->
                    <div id="step-2-container" class="hidden flex flex-col gap-6">
                        <!-- Confirmation: Delivery & Payment Summary -->
                        <section class="glass-card rounded-xl p-6 md:p-8 border-l-4 border-primary">
                            <div class="flex items-center gap-3 mb-4 text-primary border-b border-[#b1f2be] pb-3">
                                <span class="material-symbols-outlined text-2xl">task_alt</span>
                                <h2 class="font-headline-md text-headline-md font-bold">Xác nhận thông tin đơn hàng</h2>
                            </div>
                            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs">
                                <!-- Delivery Info -->
                                <div class="bg-emerald-50/60 border border-emerald-100 rounded-xl p-4 space-y-1.5" id="confirm-delivery-card">
                                    <div class="flex items-center gap-1.5 text-primary font-bold text-[11px] uppercase tracking-wider mb-2">
                                        <span class="material-symbols-outlined text-sm">local_shipping</span> Giao hàng đến
                                    </div>
                                    <p id="confirm-name" class="font-bold text-slate-800"></p>
                                    <p id="confirm-phone" class="text-slate-600"></p>
                                    <p id="confirm-address" class="text-slate-500 leading-relaxed"></p>
                                    <p id="confirm-timeslot" class="text-primary font-semibold mt-1"></p>
                                </div>
                                <!-- Payment Info -->
                                <div class="bg-blue-50/60 border border-blue-100 rounded-xl p-4 space-y-1.5" id="confirm-payment-card">
                                    <div class="flex items-center gap-1.5 text-blue-700 font-bold text-[11px] uppercase tracking-wider mb-2">
                                        Thanh toán
                                    </div>
                                    <p id="confirm-payment-method" class="font-bold text-slate-800"></p>
                                    <div id="confirm-coupon-info" class="hidden mt-2 space-y-1"></div>
                                </div>
                            </div>
                        </section>

                        <!-- Section 4: Order Items List Grouped by Shop -->
                        <section class="glass-card rounded-xl p-6 md:p-8">
                        <div class="flex items-center justify-between mb-6 border-b border-[#b1f2be] pb-3">
                            <div class="flex items-center gap-3 text-primary">
                                <span class="material-symbols-outlined text-2xl">shopping_basket</span>
                                <h2 class="font-headline-md text-headline-md font-bold">Chi tiết sản phẩm theo Cửa hàng</h2>
                            </div>
                            <a class="font-label-md text-label-md text-primary hover:underline flex items-center gap-1 font-semibold text-sm" href="${pageContext.request.contextPath}/cart">
                                Sửa giỏ hàng
                            </a>
                        </div>
                        <div class="flex flex-col gap-6">
                            <%-- BƯỚC 1: Tìm danh sách các shopId duy nhất (dùng JSTL string concat) --%>
                            <c:set var="uniqueShopIds" value="," />
                            <c:forEach var="item" items="${cartSummary.items}">
                                <c:set var="shopIdStr" value=",${item.shopId}," />
                                <c:if test="${not fn:contains(uniqueShopIds, shopIdStr)}">
                                    <c:set var="uniqueShopIds" value="${uniqueShopIds}${item.shopId}," />
                                </c:if>
                            </c:forEach>
                            <c:set var="cleanOwnerIds" value="" />
                            <c:forEach var="item" items="${cartSummary.items}">
                                <c:set var="oId" value="${item.shopId}" />
                                <c:if test="${not fn:contains(cleanOwnerIds, oId)}">
                                    <c:set var="cleanOwnerIds" value="${cleanOwnerIds}${empty cleanOwnerIds ? '' : ','}${oId}" />
                                </c:if>
                            </c:forEach>

                            <%-- BƯỚC 2: Duyệt qua từng shopId và hiển thị --%>
                            <c:forEach var="sId" items="${fn:split(uniqueShopIds, ',')}">
                                <c:if test="${not empty sId}">
                                    <c:set var="sName" value="" />
                                    <c:set var="shopSubtotal" value="0" />
                                    <c:forEach var="item" items="${cartSummary.items}">
                                        <c:if test="${item.shopId == sId}">
                                            <c:set var="sName" value="${item.shopName}" />
                                            <c:set var="itemCost" value="${(item.price + item.packagingPriceAdd) * item.quantity}" />
                                            <c:set var="shopSubtotal" value="${shopSubtotal + itemCost}" />
                                        </c:if>
                                    </c:forEach>

                                    <%-- Card của từng Shop --%>
                                    <div class="bg-surface-container-lowest/80 border border-emerald-100 rounded-2xl p-5 hover:shadow-md transition-all">
                                        <div class="flex flex-col sm:flex-row sm:items-center justify-between border-b border-emerald-100/50 pb-3 mb-4 gap-2">
                                            <div class="flex items-center gap-2 text-primary-dark font-bold text-sm">
                                                <span class="material-symbols-outlined text-lg text-primary">storefront</span>
                                                <c:choose>
                                                    <c:when test="${sId > 0}">
                                                        <a href="${pageContext.request.contextPath}/shop-view?id=${sId}&idType=owner" class="hover:underline text-primary-dark transition-all">
                                                            Cửa hàng: <c:out value="${sName != null ? sName : 'Chưa có'}"/>
                                                        </a>
                                                    </c:when>
                                                    <c:otherwise>
                                                        <span>Cửa hàng: <c:out value="${sName != null ? sName : 'Chưa có'}"/></span>
                                                    </c:otherwise>
                                                </c:choose>
                                            </div>
                                            <div class="flex flex-wrap gap-3 text-[11px] text-txt-2 font-semibold">
                                                <span class="bg-primary-lt text-primary px-2.5 py-1 rounded-lg border border-primary-fixed">Phí giao hàng: 15.000 đ</span>
                                            </div>
                                        </div>
                                        <%-- Danh sách sản phẩm của Shop này --%>
                                        <c:set var="shopOutOfStockCount" value="0" />
                                        <c:set var="shopOverLimitCount" value="0" />
                                        <c:set var="shopHasStockIssue" value="false" />
                                        <c:forEach var="stockItem" items="${cartSummary.items}">
                                            <c:if test="${stockItem.shopId == sId and stockItem.stockQuantity <= 0}">
                                                <c:set var="shopOutOfStockCount" value="${shopOutOfStockCount + 1}" />
                                                <c:set var="shopHasStockIssue" value="true" />
                                            </c:if>
                                            <c:if test="${stockItem.shopId == sId and stockItem.stockQuantity > 0 and stockItem.quantity > stockItem.stockQuantity}">
                                                <c:set var="shopOverLimitCount" value="${shopOverLimitCount + 1}" />
                                                <c:set var="shopHasStockIssue" value="true" />
                                            </c:if>
                                        </c:forEach>
                                        <c:if test="${shopHasStockIssue}">
                                            <div class="mb-4 rounded-2xl border border-amber-200 bg-amber-50/90 text-amber-900 p-4 shadow-sm">
                                                <div class="flex items-start gap-3">
                                                    <span class="material-symbols-outlined text-xl mt-0.5">warning</span>
                                                    <div class="text-sm leading-relaxed">
                                                        <p class="font-bold">Shop này có <c:out value="${shopOutOfStockCount + shopOverLimitCount}"/> sản phẩm chưa thể thanh toán ngay.</p>
                                                        <p class="mt-1">
                                                            <c:if test="${shopOutOfStockCount > 0}">
                                                                <c:out value="${shopOutOfStockCount}"/> sản phẩm đã hết hàng.
                                                            </c:if>
                                                            <c:if test="${shopOverLimitCount > 0}">
                                                                <c:if test="${shopOutOfStockCount > 0}"> </c:if>
                                                                <c:out value="${shopOverLimitCount}"/> sản phẩm vượt số lượng còn lại.
                                                            </c:if>
                                                            Vui lòng quay lại giỏ hàng để đổi phân loại còn hàng hoặc giảm số lượng trước khi thanh toán.
                                                        </p>
                                                    </div>
                                                </div>
                                            </div>
                                        </c:if>
                                        <div class="divide-y divide-emerald-50/50">
                                            <c:forEach var="item" items="${cartSummary.items}">
                                                <c:if test="${item.shopId == sId}">
                                                    <c:set var="itemRowClass" value="" />
                                                    <c:set var="itemStockMessage" value="Tồn kho: ${item.stockQuantity} sản phẩm." />
                                                    <c:set var="itemStockBadgeClass" value="border-emerald-200 bg-emerald-50 text-emerald-700" />
                                                    <c:set var="itemStockTextClass" value="text-txt-2" />
                                                    <c:set var="itemStockBlocked" value="false" />
                                                    <c:choose>
                                                        <c:when test="${item.stockQuantity <= 0}">
                                                            <c:set var="itemRowClass" value="opacity-50 grayscale bg-rose-50/60 border-rose-200" />
                                                            <c:set var="itemStockMessage" value="Sản phẩm đã hết số lượng bạn cần mua, hiện chỉ còn 0 sản phẩm." />
                                                            <c:set var="itemStockBadgeClass" value="border-red-200 bg-red-50 text-red-700" />
                                                            <c:set var="itemStockTextClass" value="text-rose-700 font-semibold" />
                                                            <c:set var="itemStockBlocked" value="true" />
                                                        </c:when>
                                                        <c:when test="${item.quantity > item.stockQuantity}">
                                                            <c:set var="itemRowClass" value="bg-amber-50/60 border-amber-200" />
                                                            <c:set var="itemStockMessage" value="Bạn đang chọn ${item.quantity} sản phẩm nhưng hiện chỉ còn ${item.stockQuantity}. Hãy giảm số lượng hoặc đổi phân loại." />
                                                            <c:set var="itemStockBadgeClass" value="border-amber-200 bg-amber-50 text-amber-700" />
                                                            <c:set var="itemStockTextClass" value="text-amber-700 font-semibold" />
                                                            <c:set var="itemStockBlocked" value="true" />
                                                        </c:when>
                                                    </c:choose>
                                                    <div class="flex items-center gap-4 py-4 first:pt-0 last:pb-0 ${itemRowClass}" data-stock-blocked="${itemStockBlocked}" data-stock-quantity="${item.stockQuantity}" data-requested-quantity="${item.quantity}">
                                                         <c:choose>
                                                             <c:when test="${item.productId > 0}">
                                                                 <a href="${pageContext.request.contextPath}/products/detail?id=${item.productId}" class="w-16 h-16 rounded-xl overflow-hidden shrink-0 border border-emerald-100/30 bg-slate-50 block hover:opacity-90 transition-opacity">
                                                                     <c:choose>
                                                                         <c:when test="${not empty item.imagePath}">
                                                                             <c:set var="itemImg" value="${item.imagePath}"/>
                                                                             <c:choose>
                                                                                 <c:when test="${fn:startsWith(itemImg, 'http://') || fn:startsWith(itemImg, 'https://')}">
                                                                                     <img src="${itemImg}" alt="${item.productName}" class="w-full h-full object-cover">
                                                                                 </c:when>
                                                                                 <c:otherwise>
                                                                                     <c:set var="resolvedItemImg" value="${itemImg}"/>
                                                                                     <c:if test="${!fn:startsWith(resolvedItemImg, '/')}">
                                                                                         <c:set var="resolvedItemImg" value="/${resolvedItemImg}"/>
                                                                                     </c:if>
                                                                                     <img src="${pageContext.request.contextPath}${resolvedItemImg}" alt="${item.productName}" class="w-full h-full object-cover">
                                                                                 </c:otherwise>
                                                                             </c:choose>
                                                                         </c:when>
                                                                         <c:otherwise>
                                                                             <img src="${pageContext.request.contextPath}/assets/img/placeholder.png" alt="Placeholder" class="w-full h-full object-cover">
                                                                         </c:otherwise>
                                                                     </c:choose>
                                                                 </a>
                                                             </c:when>
                                                             <c:otherwise>
                                                                 <div class="w-16 h-16 rounded-xl overflow-hidden shrink-0 border border-emerald-100/30 bg-slate-50">
                                                                     <c:choose>
                                                                         <c:when test="${not empty item.imagePath}">
                                                                             <c:set var="itemImg" value="${item.imagePath}"/>
                                                                             <c:choose>
                                                                                 <c:when test="${fn:startsWith(itemImg, 'http://') || fn:startsWith(itemImg, 'https://')}">
                                                                                     <img src="${itemImg}" alt="${item.productName}" class="w-full h-full object-cover">
                                                                                 </c:when>
                                                                                 <c:otherwise>
                                                                                     <c:set var="resolvedItemImg" value="${itemImg}"/>
                                                                                     <c:if test="${!fn:startsWith(resolvedItemImg, '/')}">
                                                                                         <c:set var="resolvedItemImg" value="/${resolvedItemImg}"/>
                                                                                     </c:if>
                                                                                     <img src="${pageContext.request.contextPath}${resolvedItemImg}" alt="${item.productName}" class="w-full h-full object-cover">
                                                                                 </c:otherwise>
                                                                             </c:choose>
                                                                         </c:when>
                                                                         <c:otherwise>
                                                                             <img src="${pageContext.request.contextPath}/assets/img/placeholder.png" alt="Placeholder" class="w-full h-full object-cover">
                                                                         </c:otherwise>
                                                                     </c:choose>
                                                                 </div>
                                                             </c:otherwise>
                                                         </c:choose>
                                                        <div class="flex-grow min-w-0">
                                                            <h4 class="font-bold text-txt text-sm truncate">
                                                                <c:choose>
                                                                    <c:when test="${item.productId > 0}">
                                                                        <a href="${pageContext.request.contextPath}/products/detail?id=${item.productId}" class="hover:underline hover:text-primary transition-all">
                                                                            <c:out value="${item.productName}"/>
                                                                        </a>
                                                                    </c:when>
                                                                    <c:otherwise>
                                                                        <c:out value="${item.productName}"/>
                                                                    </c:otherwise>
                                                                </c:choose>
                                                            </h4>
                                                            <p class="text-[11px] text-txt-2 mt-1">Phân loại: <strong class="text-primary"><c:out value="${item.variantLabel}"/></strong></p>
                                                            <c:if test="${not empty item.packagingLabel}">
                                                                <span class="inline-block mt-1 bg-primary-lt text-primary px-2 py-0.5 rounded text-[10px] font-semibold border border-primary-fixed/30">
                                                                    Đóng gói: <c:out value="${item.packagingLabel}"/> (+<ft:currency value="${item.packagingPriceAdd}"/>)
                                                                </span>
                                                            </c:if>
                                                            <div class="mt-2 flex flex-wrap items-center gap-2">
                                                                <span class="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-semibold border ${itemStockBadgeClass}">
                                                                    <c:choose>
                                                                        <c:when test="${item.stockQuantity <= 0}">Hết hàng</c:when>
                                                                        <c:otherwise>Còn <c:out value="${item.stockQuantity}"/></c:otherwise>
                                                                    </c:choose>
                                                                </span>
                                                                <span class="text-[11px] ${itemStockTextClass}">
                                                                    <c:out value="${itemStockMessage}"/>
                                                                </span>
                                                            </div>
                                                        </div>
                                                        <div class="text-right shrink-0">
                                                            <span class="font-bold text-txt text-sm block">
                                                                <ft:currency value="${item.price + item.packagingPriceAdd}"/>
                                                            </span>
                                                            <span class="text-[11px] text-txt-3 block font-medium">x<c:out value="${item.quantity}"/></span>
                                                        </div>
                                                    </div>
                                                </c:if>
                                            </c:forEach>
                                        </div>
                                        
                                        <%-- Tóm tắt nhỏ cho từng Shop --%>
                                        <div class="border-t border-emerald-100/50 pt-3 mt-3 flex justify-between items-center text-xs text-txt-2">
                                            <c:set var="itemCount" value="0"/>
                                            <c:forEach var="item" items="${cartSummary.items}">
                                                <c:if test="${item.shopId == sId}">
                                                    <c:set var="itemCount" value="${itemCount + item.quantity}"/>
                                                </c:if>
                                            </c:forEach>
                                            <span>Tạm tính (${itemCount} sản phẩm):</span>
                                            <span class="font-bold text-txt"><ft:currency value="${shopSubtotal}"/></span>
                                        </div>
                                    </div>
                                </c:if>
                            </c:forEach>
                        </div>
                    </section>

                    <!-- Navigation for Step 2: Back + Place Order -->
                    <div class="flex justify-between items-center mt-4 gap-3">
                        <button type="button" onclick="goToStep(1)" class="bg-white border border-border hover:bg-slate-50 text-slate-700 font-bold py-3 px-6 rounded-xl text-xs transition-all shadow-sm flex items-center gap-1.5 active:scale-95 cursor-pointer">
                            <span class="material-symbols-outlined text-sm">arrow_back</span> Quay lại
                        </button>
                        <button type="submit" form="checkoutForm" class="bg-[#14532D] text-white font-bold py-3 px-8 rounded-xl hover:bg-opacity-90 transition-all shadow-md active:scale-95 text-xs flex items-center gap-1.5 cursor-pointer">
                            <span class="material-symbols-outlined text-sm">shopping_bag</span> Đặt hàng ngay
                        </button>
                    </div>
                </div>
            </div>

            <!-- RIGHT COLUMN: Sidebar Summary -->
            <div class="lg:col-span-4">
                    <div class="glass-card rounded-xl p-6 sticky top-24 border border-white/50 shadow-xl">
                        <h2 class="font-headline-md text-headline-md text-primary mb-6 font-bold border-b border-[#b1f2be] pb-3">Tổng kết đơn hàng</h2>
                        <div class="flex flex-col gap-4 font-body-md text-body-md text-on-surface mb-6">
                            <div class="flex justify-between items-center">
                                <span class="text-on-surface-variant">Tạm tính sau giảm giá sản phẩm (<c:out value="${fn:length(cartSummary.items)}"/> sản phẩm)</span>
                                <span class="font-bold text-inverse-surface" id="summary-subtotal"><ft:currency value="${cartSummary.subtotal}"/></span>
                            </div>
                            <div class="flex justify-between items-center">
                                <span class="text-on-surface-variant">Giảm giá sản phẩm</span>
                                <span class="font-bold text-red-600" id="summary-direct-sale">- <ft:currency value="${directSaleAmount}"/></span>
                            </div>
                            <div class="flex justify-between items-center" id="shop-discount-row" style="display:none!important">
                                <span class="text-on-surface-variant">Voucher shop</span>
                                <span class="font-bold text-red-600" id="summary-shop-discount">- 0 đ</span>
                            </div>
                            <div class="flex justify-between items-center" id="system-discount-row" style="display:none!important">
                                <span class="text-on-surface-variant">Voucher sàn</span>
                                <span class="font-bold text-red-600" id="summary-system-discount">- 0 đ</span>
                            </div>
                            <div class="flex justify-between items-center" id="payment-discount-row" style="display:none!important">
                                <span class="text-on-surface-variant">Voucher thanh toán</span>
                                <span class="font-bold text-red-600" id="summary-payment-discount">- 0 đ</span>
                            </div>
                            <div class="flex justify-between items-center" id="shipping-discount-row" style="display:none!important">
                                <span class="text-on-surface-variant">Freeship</span>
                                <span class="font-bold text-red-600" id="summary-shipping-discount">- 0 đ</span>
                            </div>
                            <div class="flex justify-between items-center">
                                <span class="text-on-surface-variant">Tổng trọng lượng</span>
                                <span class="font-bold text-inverse-surface"><c:out value="${cartSummary.totalWeight}"/> kg</span>
                            </div>
                            <div class="flex justify-between items-center">
                                <span class="text-on-surface-variant">Phí vận chuyển (Giao hỏa tốc)</span>
                                <span class="font-bold text-inverse-surface" id="summary-delivery"><ft:currency value="${cartSummary.deliveryFee}"/></span>
                            </div>
                        </div>
                        <div class="border-t border-[#BBF7D0] pt-4 mb-8">
                            <div class="flex justify-between items-end">
                                <span class="font-label-md text-label-md text-on-surface font-bold">Tổng cộng</span>
                                <span class="font-headline-md text-headline-md text-primary font-black text-2xl" id="summary-total"><ft:currency value="${cartSummary.total}"/></span>
                            </div>
                            <span class="block text-right text-xs text-on-surface-variant mt-1">(Đã bao gồm VAT & Cước bảo ôn chuỗi lạnh)</span>
                        </div>
                        <button id="submitBtn" type="submit" class="w-full py-4 rounded-lg bg-[#14532D] text-white font-label-md text-label-md flex justify-center items-center gap-2 hover:bg-opacity-90 transition-all font-bold cursor-pointer active:scale-95 shadow-md">
                            Đặt hàng ngay
                            <span class="material-symbols-outlined">arrow_forward</span>
                        </button>
                        <p class="text-center text-xs text-on-surface-variant mt-4 font-body-md flex items-center justify-center gap-1 opacity-80">
                            <span class="material-symbols-outlined text-sm">shield</span>
                            Thông tin của bạn được bảo mật tuyệt đối
                        </p>
                    </div>
                </div>
            </form>
        </c:otherwise>
    </c:choose>

</div>

<!-- Hidden inputs to safely pass server variables to JS without IDE syntax errors -->
<input type="hidden" id="js-subtotal" value="${cartSummary.subtotal}">
<input type="hidden" id="js-delivery" value="${cartSummary.deliveryFee}">
<input type="hidden" id="js-ctx" value="${pageContext.request.contextPath}">
<input type="hidden" id="js-owner-id" value="<c:out value='${shopOwnerId != null && shopOwnerId > 0 ? shopOwnerId : cleanOwnerIds}'/>">
<input type="hidden" id="js-csrf" value="${sessionScope._csrfToken}">

<!-- Hidden address elements for JS -->
<c:forEach var="addr" items="${userAddresses}">
    <span class="js-user-address-data" style="display:none;"
          data-address-id="${addr.addressId}"
          data-recipient-name="<c:out value="${addr.recipientName}"/>"
          data-recipient-phone="<c:out value="${addr.recipientPhone}"/>"
          data-address-detail="<c:out value="${addr.addressDetail}"/>"
          data-is-default="${addr['default'] ? 'true' : 'false'}"></span>
</c:forEach>

<script>
// ─── Coupon AJAX Logic (Merged Input) ─────────────────────────────
const SUBTOTAL    = parseFloat(document.getElementById('js-subtotal').value || '0');
const DELIVERY    = parseFloat(document.getElementById('js-delivery').value || '0');
const CTX         = document.getElementById('js-ctx').value;
const QUOTE_API   = CTX + '/api/checkout/quote';
const OWNER_ID    = document.getElementById('js-owner-id').value;
const CSRF_TOKEN  = document.getElementById('js-csrf').value;

let appliedShopCoupons = [];
let appliedSystemCoupons = [];
let quoteState = null;
let quoteRefreshTimer = null;
let quoteRefreshInFlight = null;

let shopCouponCode   = '';
let shopDiscount     = 0;
let systemCouponCode = '';
let systemDiscount   = 0;
let paymentDiscount   = 0;
let shippingDiscount  = 0;

function parseSelectionIdList(raw) {
    return String(raw || '')
        .split(',')
        .map(value => parseInt(value.trim(), 10))
        .filter(value => !Number.isNaN(value) && value > 0);
}

function getSelectedCartItemIds() {
    const raw = document.querySelector('input[name="cartItemIds"]')?.value || '';
    return parseSelectionIdList(raw);
}

function getSelectedVariantIds() {
    const raw = document.querySelector('input[name="variantIds"]')?.value || '';
    return parseSelectionIdList(raw);
}

function getSelectedPaymentMethod() {
    const selected = document.querySelector('input[name="paymentMethod"]:checked');
    return selected ? selected.value : 'COD';
}

function parseMoneyValue(value) {
    if (value === null || value === undefined || value === '') {
        return 0;
    }
    if (typeof value === 'number') {
        return Number.isFinite(value) ? value : 0;
    }
    const parsed = Number(String(value).replace(/,/g, '').trim());
    return Number.isFinite(parsed) ? parsed : 0;
}

function resolveCouponSlot(coupon) {
    const benefitTarget = (coupon && coupon.benefitTarget ? coupon.benefitTarget : 'MERCHANDISE')
        .toString()
        .trim()
        .toUpperCase();
    if (benefitTarget === 'SHIPPING') {
        return 'FREE_SHIPPING';
    }
    if (benefitTarget === 'PAYMENT_METHOD') {
        return 'PAYMENT_METHOD';
    }

    const discountScope = normalizeCouponScope(coupon && coupon.discountScope ? coupon.discountScope : 'SHOP');
    if (discountScope === 'SYSTEM' || discountScope === 'ALL') {
        return 'PLATFORM_MERCHANDISE';
    }
    return 'SELLER_MERCHANDISE';
}

function getCouponSlotLabel(slot) {
    switch ((slot || '').toString().trim().toUpperCase()) {
        case 'PLATFORM_MERCHANDISE':
            return 'Voucher sàn';
        case 'FREE_SHIPPING':
            return 'Freeship';
        case 'PAYMENT_METHOD':
            return 'Voucher phương thức thanh toán';
        default:
            return 'Voucher shop';
    }
}

function getCouponTargetLabel(coupon) {
    const slot = resolveCouponSlot(coupon);
    if (slot === 'FREE_SHIPPING') {
        return 'Phí ship';
    }
    if (slot === 'PAYMENT_METHOD') {
        return 'Phương thức thanh toán';
    }
    return 'Sản phẩm';
}

function sumQuoteSummaryField(quote, field) {
    if (!quote || !Array.isArray(quote.shopSummaries)) {
        return 0;
    }
    return quote.shopSummaries.reduce((sum, summary) => sum + parseMoneyValue(summary && summary[field]), 0);
}

function getCouponCodePayload() {
    return {
        shopCouponCodes: appliedShopCoupons.map(c => c.code),
        systemCouponCodes: appliedSystemCoupons.map(c => c.code)
    };
}

function syncCouponHiddenFields() {
    shopCouponCode = appliedShopCoupons.map(c => c.code).join(',');
    systemCouponCode = appliedSystemCoupons.map(c => c.code).join(',');

    const shopInput = document.getElementById('shopCouponCode');
    const systemInput = document.getElementById('systemCouponCode');
    if (shopInput) {
        shopInput.value = shopCouponCode;
    }
    if (systemInput) {
        systemInput.value = systemCouponCode;
    }
}

function scheduleQuoteRefresh() {
    if (quoteRefreshTimer) {
        clearTimeout(quoteRefreshTimer);
    }
    quoteRefreshTimer = setTimeout(() => {
        refreshQuotePreview({ silent: true }).catch(() => {});
    }, 120);
}

function buildQuoteRequest() {
    const deliveryAddress = document.getElementById('deliveryAddress')?.value || '';
    const deliveryTimeSlot = document.getElementById('deliveryTimeSlot')?.value || '';
    return {
        cartItemIds: getSelectedCartItemIds(),
        variantIds: getSelectedVariantIds(),
        deliveryAddress: deliveryAddress.trim(),
        deliveryTimeSlot: deliveryTimeSlot.trim(),
        paymentMethod: getSelectedPaymentMethod(),
        shopCouponCodes: appliedShopCoupons.map(c => c.code),
        systemCouponCodes: appliedSystemCoupons.map(c => c.code)
    };
}

function clearCouponMessage() {
    const msgEl = document.getElementById('couponMsg');
    if (!msgEl) return;
    msgEl.textContent = '';
    msgEl.className = 'text-xs mt-2 hidden';
}

function renderQuoteSummary(quote) {
    if (!quote) return;
    const fmt = (n) => new Intl.NumberFormat('vi-VN', {style:'currency', currency:'VND'}).format(parseMoneyValue(n));
    const subtotal = parseMoneyValue(quote.subtotal);
    const directSale = parseMoneyValue(quote.directSaleAmount);
    const delivery = parseMoneyValue(quote.deliveryFee);
    const shopDisc = sumQuoteSummaryField(quote, 'shopMerchandiseDiscountAmount');
    const systemDisc = sumQuoteSummaryField(quote, 'systemMerchandiseDiscountAmount');
    const paymentDisc = sumQuoteSummaryField(quote, 'paymentDiscountAmount');
    const shippingDisc = sumQuoteSummaryField(quote, 'shopShippingDiscountAmount')
        + sumQuoteSummaryField(quote, 'systemShippingDiscountAmount');
    const finalAmount = parseMoneyValue(quote.finalAmount);

    shopDiscount = shopDisc;
    systemDiscount = systemDisc;
    paymentDiscount = paymentDisc;
    shippingDiscount = shippingDisc;
    syncCouponHiddenFields();

    const subtotalEl = document.getElementById('summary-subtotal');
    const directSaleEl = document.getElementById('summary-direct-sale');
    const deliveryEl = document.getElementById('summary-delivery');
    const totalEl = document.getElementById('summary-total');
    const shopRow = document.getElementById('shop-discount-row');
    const systemRow = document.getElementById('system-discount-row');
    const paymentRow = document.getElementById('payment-discount-row');
    const shippingRow = document.getElementById('shipping-discount-row');
    const shopAmountEl = document.getElementById('summary-shop-discount');
    const systemAmountEl = document.getElementById('summary-system-discount');
    const paymentAmountEl = document.getElementById('summary-payment-discount');
    const shippingAmountEl = document.getElementById('summary-shipping-discount');

    if (subtotalEl) subtotalEl.textContent = fmt(subtotal);
    if (directSaleEl) directSaleEl.textContent = '- ' + fmt(directSale);
    if (deliveryEl) deliveryEl.textContent = fmt(delivery);
    if (totalEl) totalEl.textContent = fmt(finalAmount);

    if (shopRow && shopAmountEl) {
        if (shopDisc > 0) {
            shopRow.style.removeProperty('display');
            shopAmountEl.textContent = '- ' + fmt(shopDisc);
        } else {
            shopRow.style.setProperty('display', 'none', 'important');
        }
    }

    if (systemRow && systemAmountEl) {
        if (systemDisc > 0) {
            systemRow.style.removeProperty('display');
            systemAmountEl.textContent = '- ' + fmt(systemDisc);
        } else {
            systemRow.style.setProperty('display', 'none', 'important');
        }
    }

    if (paymentRow && paymentAmountEl) {
        if (paymentDisc > 0) {
            paymentRow.style.removeProperty('display');
            paymentAmountEl.textContent = '- ' + fmt(paymentDisc);
        } else {
            paymentRow.style.setProperty('display', 'none', 'important');
        }
    }

    if (shippingRow && shippingAmountEl) {
        if (shippingDisc > 0) {
            shippingRow.style.removeProperty('display');
            shippingAmountEl.textContent = '- ' + fmt(shippingDisc);
        } else {
            shippingRow.style.setProperty('display', 'none', 'important');
        }
    }
}

function refreshQuotePreview(options = {}) {
    const payload = buildQuoteRequest();
    const selectionIds = Array.isArray(payload.cartItemIds) && payload.cartItemIds.length > 0
        ? payload.cartItemIds
        : payload.variantIds;
    if (!selectionIds || selectionIds.length === 0) {
        return Promise.resolve(null);
    }

    const preserveCouponMessage = options.preserveCouponMessage === true;
    syncCouponHiddenFields();
    if (quoteRefreshInFlight) {
        return quoteRefreshInFlight;
    }

    const request = fetch(QUOTE_API, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json;charset=UTF-8',
            'X-CSRF-Token': CSRF_TOKEN,
            'X-XSRF-TOKEN': CSRF_TOKEN
        },
        credentials: 'same-origin',
        body: JSON.stringify(payload)
    })
        .then(r => r.json())
        .then(resp => {
            if (!resp || !resp.success) {
                throw new Error((resp && (resp.error || resp.message)) || 'Không thể tính giá thanh toán.');
            }
            quoteState = resp.data || null;
            if (quoteState) {
                renderQuoteSummary(quoteState);
                renderAppliedCoupons();
                populateConfirmationCard();
                if (Array.isArray(quoteState.errors) && quoteState.errors.length > 0) {
                    showCouponMsg(quoteState.errors[0], 'text-red-600 font-bold');
                } else if (Array.isArray(quoteState.warnings) && quoteState.warnings.length > 0) {
                    showCouponMsg(quoteState.warnings[0], 'text-amber-700 font-bold');
                } else if (!preserveCouponMessage) {
                    clearCouponMessage();
                }
            }
            return quoteState;
        })
        .catch(err => {
            console.warn('[Checkout Quote] Falling back to legacy recalculation:', err);
            quoteState = null;
            return recalculateAllAppliedCoupons().then(() => {
                updateSummary();
                renderAppliedCoupons();
                populateConfirmationCard();
                if (!options.silent && !preserveCouponMessage) {
                    showCouponMsg('Không thể cập nhật quote tức thời. Đang dùng cơ chế dự phòng.', 'text-amber-700 font-bold');
                }
                return null;
            });
        })
        .finally(() => {
            quoteRefreshInFlight = null;
        });

    quoteRefreshInFlight = request;
    return request;
}

function applyCoupon() {
    const inputEl = document.getElementById('couponInput');
    const code = inputEl.value.trim().toUpperCase();
    if (!code) return;

    if (appliedShopCoupons.some(c => c.code === code) || appliedSystemCoupons.some(c => c.code === code)) {
        showCouponMsg('Mã voucher này đã được áp dụng rồi.', 'text-red-600 font-bold');
        return;
    }

    showCouponMsg('Đang kiểm tra...', 'text-on-surface-variant');

    validateCouponAPI(code, 'SHOP')
        .then(data => {
            if (data.valid) {
                const benefitTarget = (data.benefitTarget || 'MERCHANDISE').toString().toUpperCase();
                if (benefitTarget === 'PRODUCT') {
                    showCouponMsg('Mã này là giảm tự động theo sản phẩm và không thể áp dụng thủ công tại trang thanh toán.', 'text-red-600 font-bold');
                    return;
                }
                const couponSlot = resolveCouponSlot({
                    discountScope: data.discountScope,
                    benefitTarget: benefitTarget
                });
                const existingCoupons = appliedShopCoupons.concat(appliedSystemCoupons);
                const ownerId = data.ownerId;
                const slotConflict = describeCouponSlotConflict({
                    code: code,
                    discountScope: data.discountScope,
                    benefitTarget: benefitTarget
                }, existingCoupons);
                if (slotConflict) {
                    showCouponMsg(slotConflict, 'text-red-600 font-bold');
                    return;
                }
                const stackConflict = describeCouponStackConflict({
                    code: code,
                    discountScope: data.discountScope,
                    benefitTarget: benefitTarget,
                    canStack: data.canStack
                }, existingCoupons);
                if (stackConflict) {
                    showCouponMsg(stackConflict, 'text-red-600 font-bold');
                    return;
                }

                appliedShopCoupons.push({
                    code: code,
                    ownerId: ownerId,
                    benefitTarget: benefitTarget,
                    discountScope: (data.discountScope || 'SHOP').toString().toUpperCase(),
                    couponSlot: couponSlot,
                    canStack: data.canStack,
                });
                
                const successMessage = benefitTarget === 'SHIPPING'
                    ? '✔ Đã áp dụng ' + getCouponSlotLabel(couponSlot) + '.'
                    : '✔ ' + data.message + ' (' + getCouponSlotLabel(couponSlot) + ')';
                showCouponMsg(successMessage, 'text-emerald-700 font-bold');
                inputEl.value = '';
                refreshQuotePreview({ silent: true, preserveCouponMessage: true });
            } else {
                return validateCouponAPI(code, 'SYSTEM')
                    .then(sysData => {
                        if (sysData.valid) {
                            const benefitTarget = (sysData.benefitTarget || 'MERCHANDISE').toString().toUpperCase();
                            if (benefitTarget === 'PRODUCT') {
                                showCouponMsg('Mã này là giảm tự động theo sản phẩm và không thể áp dụng thủ công tại trang thanh toán.', 'text-red-600 font-bold');
                                return;
                            }
                            const couponSlot = resolveCouponSlot({
                                discountScope: sysData.discountScope,
                                benefitTarget: benefitTarget
                            });
                            const existingCoupons = appliedShopCoupons.concat(appliedSystemCoupons);
                            const slotConflict = describeCouponSlotConflict({
                                code: code,
                                discountScope: sysData.discountScope,
                                benefitTarget: benefitTarget
                            }, existingCoupons);
                            if (slotConflict) {
                                showCouponMsg(slotConflict, 'text-red-600 font-bold');
                                return;
                            }
                            const stackConflict = describeCouponStackConflict({
                                code: code,
                                discountScope: sysData.discountScope,
                                benefitTarget: benefitTarget,
                                canStack: sysData.canStack
                            }, existingCoupons);
                            if (stackConflict) {
                                showCouponMsg(stackConflict, 'text-red-600 font-bold');
                                return;
                            }

                            appliedSystemCoupons.push({
                                code: code,
                                benefitTarget: benefitTarget,
                                discountScope: (sysData.discountScope || 'SYSTEM').toString().toUpperCase(),
                                couponSlot: couponSlot,
                                canStack: sysData.canStack
                            });
                            
                            const successMessage = benefitTarget === 'SHIPPING'
                                ? '✔ Đã áp dụng ' + getCouponSlotLabel(couponSlot) + '.'
                                : '✔ ' + sysData.message + ' (' + getCouponSlotLabel(couponSlot) + ')';
                            showCouponMsg(successMessage, 'text-emerald-700 font-bold');
                            inputEl.value = '';
                            refreshQuotePreview({ silent: true, preserveCouponMessage: true });
                        } else {
                            showCouponMsg('✘ ' + (sysData.message || data.message || 'Mã voucher không hợp lệ, đã hết hạn, hoặc không đủ điều kiện tối thiểu.'), 'text-red-600 font-bold');
                        }
                    });
            }
        })
        .catch(err => {
            console.error('[Coupon Log] Error validating coupon:', err);
            showCouponMsg('✘ Lỗi kết nối. Vui lòng thử lại.', 'text-red-600 font-bold');
        });
}

async function recalculateAllAppliedCoupons() {
    let merchandiseBase = SUBTOTAL;
    let shippingBase = DELIVERY;
    let sellerTotal = 0;
    let platformTotal = 0;
    let shippingTotal = 0;
    let paymentTotal = 0;

    const allCoupons = appliedShopCoupons.concat(appliedSystemCoupons);
    const sellerCoupons = allCoupons.filter(c => resolveCouponSlot(c) === 'SELLER_MERCHANDISE');
    const platformCoupons = allCoupons.filter(c => resolveCouponSlot(c) === 'PLATFORM_MERCHANDISE');
    const shippingCoupons = allCoupons.filter(c => resolveCouponSlot(c) === 'FREE_SHIPPING');
    const paymentCoupons = allCoupons.filter(c => resolveCouponSlot(c) === 'PAYMENT_METHOD');

    for (const coupon of sellerCoupons) {
        const scope = normalizeCouponScope(coupon.discountScope || 'SHOP');
        const data = await validateCouponAPIWithSubtotal(coupon.code, scope, merchandiseBase);
        if (data.valid) {
            coupon.discountAmount = data.discountAmount || 0;
            sellerTotal += coupon.discountAmount;
            merchandiseBase = Math.max(0, merchandiseBase - coupon.discountAmount);
        } else {
            coupon.discountAmount = 0;
        }
    }

    for (const coupon of platformCoupons) {
        const scope = normalizeCouponScope(coupon.discountScope || 'SYSTEM');
        const data = await validateCouponAPIWithSubtotal(coupon.code, scope, merchandiseBase);
        if (data.valid) {
            coupon.discountAmount = data.discountAmount || 0;
            platformTotal += coupon.discountAmount;
            merchandiseBase = Math.max(0, merchandiseBase - coupon.discountAmount);
        } else {
            coupon.discountAmount = 0;
        }
    }

    for (const coupon of shippingCoupons) {
        const scope = normalizeCouponScope(coupon.discountScope || 'SYSTEM');
        const data = await validateCouponAPIWithSubtotal(coupon.code, scope, shippingBase);
        if (data.valid) {
            coupon.discountAmount = data.discountAmount || 0;
            shippingTotal += coupon.discountAmount;
            shippingBase = Math.max(0, shippingBase - coupon.discountAmount);
        } else {
            coupon.discountAmount = 0;
        }
    }

    let paymentBase = Math.max(0, merchandiseBase + shippingBase);
    for (const coupon of paymentCoupons) {
        const scope = normalizeCouponScope(coupon.discountScope || 'SYSTEM');
        const data = await validateCouponAPIWithSubtotal(coupon.code, scope, paymentBase);
        if (data.valid) {
            coupon.discountAmount = data.discountAmount || 0;
            paymentTotal += coupon.discountAmount;
            paymentBase = Math.max(0, paymentBase - coupon.discountAmount);
        } else {
            coupon.discountAmount = 0;
        }
    }

    shopDiscount = sellerTotal;
    shopCouponCode = appliedShopCoupons.map(c => c.code).join(',');
    const shopInput = document.getElementById('shopCouponCode');
    if (shopInput) {
        shopInput.value = shopCouponCode;
    }

    systemDiscount = platformTotal;
    systemCouponCode = appliedSystemCoupons.map(c => c.code).join(',');
    const systemInput = document.getElementById('systemCouponCode');
    if (systemInput) {
        systemInput.value = systemCouponCode;
    }

    shippingDiscount = shippingTotal;
    paymentDiscount = paymentTotal;
}

function validateCouponAPI(code, scope) {
    const currentSubtotal = scope === 'SYSTEM' ? Math.max(0, SUBTOTAL - shopDiscount) : SUBTOTAL;
    return validateCouponAPIWithSubtotal(code, scope, currentSubtotal);
}

function validateCouponAPIWithSubtotal(code, scope, subtotalAmt) {
    const url = CTX + '/api/coupon/validate?code=' + encodeURIComponent(code) +
                '&subtotal=' + subtotalAmt +
                '&ownerId=' + OWNER_ID +
                '&scope=' + scope;
    return fetch(url, {
        headers: {
            'X-Requested-With': 'XMLHttpRequest',
            'X-CSRF-Token': CSRF_TOKEN
        }
    })
        .then(r => {
            if (!r.ok) throw new Error('HTTP ' + r.status);
            return r.json();
        })
        .then(normalizeCouponResponse);
}

function normalizeCouponResponse(resp) {
    if (!resp || typeof resp !== 'object') {
        return { valid: false, discountAmount: 0, message: 'Phản hồi mã giảm giá không hợp lệ.' };
    }
    if (typeof resp.success === 'boolean') {
        if (!resp.success) {
            return { valid: false, discountAmount: 0, message: resp.error || 'Không hợp lệ.' };
        }
        const payload = resp.data || {};
        return {
            valid: true,
            discountAmount: Number(payload.discountAmount ?? 0) || 0,
            promoId: payload.promoId,
            discountType: payload.discountType,
            discountScope: payload.discountScope,
            benefitTarget: payload.benefitTarget,
            ownerId: payload.ownerId,
            canStack: payload.canStack ?? true,
            message: payload.message || 'Áp dụng thành công!'
        };
    }
    return {
        valid: resp.valid ?? false,
        discountAmount: Number(resp.discountAmount ?? 0) || 0,
        promoId: resp.promoId,
        discountType: resp.discountType,
        discountScope: resp.discountScope,
        benefitTarget: resp.benefitTarget,
        ownerId: resp.ownerId,
        canStack: resp.canStack ?? true,
        message: resp.message || resp.error || ''
    };
}

function describeCouponSlotConflict(newCoupon, existingCoupons) {
    if (!newCoupon || !Array.isArray(existingCoupons) || existingCoupons.length === 0) {
        return '';
    }

    const newSlot = resolveCouponSlot(newCoupon);
    const blockingCoupon = existingCoupons.find(c => c && resolveCouponSlot(c) === newSlot);
    if (!blockingCoupon) {
        return '';
    }

    const slotLabel = getCouponSlotLabel(newSlot).toLowerCase();
    const blockingCode = (blockingCoupon.code || '').toString().trim();
    if (blockingCode) {
        return 'Mỗi checkout chỉ được tối đa 1 ' + slotLabel + '. Mã ' + blockingCode + ' đã chiếm slot này.';
    }
    return 'Mỗi checkout chỉ được tối đa 1 ' + slotLabel + '.';
}

function describeCouponStackConflict(newCoupon, existingCoupons) {
    if (!newCoupon || !Array.isArray(existingCoupons) || existingCoupons.length === 0) {
        return '';
    }

    const newSlot = resolveCouponSlot(newCoupon);
    const couponCode = (newCoupon.code || '').toString().trim();
    if (newSlot === 'PAYMENT_METHOD') {
        const blockingCoupon = existingCoupons.find(c => c && resolveCouponSlot(c) === 'PLATFORM_MERCHANDISE');
        if (blockingCoupon && (newCoupon.canStack === false || blockingCoupon.canStack === false)) {
            return 'Voucher sàn ' + (blockingCoupon.code || '') + ' và voucher phương thức thanh toán ' + couponCode + ' không thể cộng dồn.';
        }
    }

    if (newSlot === 'PLATFORM_MERCHANDISE') {
        const blockingCoupon = existingCoupons.find(c => c && resolveCouponSlot(c) === 'PAYMENT_METHOD');
        if (blockingCoupon && (newCoupon.canStack === false || blockingCoupon.canStack === false)) {
            return 'Voucher sàn ' + couponCode + ' và voucher phương thức thanh toán ' + (blockingCoupon.code || '') + ' không thể cộng dồn.';
        }
    }

    return '';
}

function normalizeCouponScope(scope) {
    const value = (scope || '').toString().trim().toUpperCase();
    if (value === 'ALL') {
        return 'SYSTEM';
    }
    if (value === 'SYSTEM' || value === 'SHOP') {
        return value;
    }
    return 'SHOP';
}

function removeCoupon(scope, code) {
    scope = normalizeCouponScope(scope);
    const removedCoupon = scope === 'SHOP'
        ? appliedShopCoupons.find(c => c.code === code)
        : appliedSystemCoupons.find(c => c.code === code);
    const removedLabel = removedCoupon ? getCouponSlotLabel(resolveCouponSlot(removedCoupon)) : (scope === 'SYSTEM' ? 'Voucher sàn' : 'Voucher shop');
    if (scope === 'SHOP') {
        appliedShopCoupons = appliedShopCoupons.filter(c => c.code !== code);
        showCouponMsg('Đã xóa ' + removedLabel.toLowerCase() + '.', 'text-on-surface-variant');
    } else if (scope === 'SYSTEM') {
        appliedSystemCoupons = appliedSystemCoupons.filter(c => c.code !== code);
        showCouponMsg('Đã xóa ' + removedLabel.toLowerCase() + '.', 'text-on-surface-variant');
    }
    
    refreshQuotePreview({ silent: true });
}

function showCouponMsg(text, className) {
    const msgEl = document.getElementById('couponMsg');
    msgEl.textContent = text;
    msgEl.className = 'text-xs mt-2 ' + className;
    msgEl.classList.remove('hidden');
}

function renderAppliedCoupons() {
    const container = document.getElementById('appliedCouponsContainer');
    const listEl = document.getElementById('appliedCouponsList');
    listEl.innerHTML = '';
    
    let hasCoupon = false;
    const fmt = (n) => new Intl.NumberFormat('vi-VN', {style:'currency', currency:'VND'}).format(n);
    if (quoteState && Array.isArray(quoteState.appliedCoupons) && quoteState.appliedCoupons.length > 0) {
        quoteState.appliedCoupons.forEach(c => {
            hasCoupon = true;
            const couponScope = normalizeCouponScope(c.discountScope || 'SHOP');
            const couponSlot = resolveCouponSlot(c);
            const scopeLabel = getCouponSlotLabel(couponSlot);
            const targetLabel = getCouponTargetLabel(c);
            const ownerLabel = c.ownerId ? 'Cửa hàng #' + c.ownerId : '';
            const couponCode = c.code || '';
            const badgeClass = couponSlot === 'FREE_SHIPPING'
                ? 'text-teal-800 bg-teal-200'
                : 'text-emerald-800 bg-emerald-200';
            const item = document.createElement('div');
            item.className = 'flex justify-between items-center bg-emerald-50 border border-emerald-200 rounded-lg px-3 py-2 text-xs';
            item.innerHTML = '<div>' +
                '<span class="font-bold ' + badgeClass + ' px-1.5 py-0.5 rounded mr-1">' + scopeLabel + '</span>' +
                '<span class="font-bold text-on-surface">' + c.code + '</span>' +
                '<span class="text-on-surface-variant ml-1">(Giảm ' + fmt(c.discountAmount) + (ownerLabel ? ', ' + ownerLabel : '') + ', ' + targetLabel + ')</span>' +
                '</div>' +
                '<button type="button" onclick="removeCoupon(\'' + couponScope + '\', \'' + couponCode + '\')" class="text-red-600 hover:text-red-800 font-bold ml-2 focus:outline-none">Xóa</button>';
            listEl.appendChild(item);
        });
    } else {
        appliedShopCoupons.forEach(c => {
            hasCoupon = true;
            const couponSlot = resolveCouponSlot(c);
            const slotLabel = getCouponSlotLabel(couponSlot);
            const targetLabel = getCouponTargetLabel(c);
            const badgeClass = couponSlot === 'FREE_SHIPPING'
                ? 'text-teal-800 bg-teal-200'
                : 'text-emerald-800 bg-emerald-200';
            const item = document.createElement('div');
            item.className = 'flex justify-between items-center bg-emerald-50 border border-emerald-200 rounded-lg px-3 py-2 text-xs';
            item.innerHTML = '<div>' +
                '<span class="font-bold ' + badgeClass + ' px-1.5 py-0.5 rounded mr-1">' + slotLabel + '</span>' +
                '<span class="font-bold text-on-surface">' + c.code + '</span>' +
                '<span class="text-on-surface-variant ml-1">(Đang tính..., ' + targetLabel + ')</span>' +
                '</div>' +
                '<button type="button" onclick="removeCoupon(\'SHOP\', \'' + (c.code || '') + '\')" class="text-red-600 hover:text-red-800 font-bold ml-2 focus:outline-none">Xóa</button>';
            listEl.appendChild(item);
        });
    
        appliedSystemCoupons.forEach(c => {
            hasCoupon = true;
            const couponSlot = resolveCouponSlot(c);
            const slotLabel = getCouponSlotLabel(couponSlot);
            const targetLabel = getCouponTargetLabel(c);
            const badgeClass = couponSlot === 'FREE_SHIPPING'
                ? 'text-teal-800 bg-teal-200'
                : 'text-emerald-800 bg-emerald-200';
            const item = document.createElement('div');
            item.className = 'flex justify-between items-center bg-teal-50 border border-teal-200 rounded-lg px-3 py-2 text-xs';
            item.innerHTML = '<div>' +
                '<span class="font-bold ' + badgeClass + ' px-1.5 py-0.5 rounded mr-1">' + slotLabel + '</span>' +
                '<span class="font-bold text-on-surface">' + c.code + '</span>' +
                '<span class="text-on-surface-variant ml-1">(Đang tính..., ' + targetLabel + ')</span>' +
                '</div>' +
                '<button type="button" onclick="removeCoupon(\'SYSTEM\', \'' + (c.code || '') + '\')" class="text-red-600 hover:text-red-800 font-bold ml-2 focus:outline-none">Xóa</button>';
            listEl.appendChild(item);
        });
    }
    
    if (hasCoupon) {
        container.classList.remove('hidden');
    } else {
        container.classList.add('hidden');
    }
}

function updateSummary() {
    if (quoteState) {
        renderQuoteSummary(quoteState);
        return;
    }

    const total = Math.max(0, SUBTOTAL - shopDiscount - systemDiscount - paymentDiscount - shippingDiscount + DELIVERY);
    const fmt = (n) => new Intl.NumberFormat('vi-VN', {style:'currency', currency:'VND'}).format(n);

    const shopRow   = document.getElementById('shop-discount-row');
    const systemRow = document.getElementById('system-discount-row');
    const paymentRow = document.getElementById('payment-discount-row');
    const shippingRow = document.getElementById('shipping-discount-row');

    if (shopDiscount > 0) {
        shopRow.style.removeProperty('display');
        document.getElementById('summary-shop-discount').textContent = '- ' + fmt(shopDiscount);
    } else {
        shopRow.style.setProperty('display', 'none', 'important');
    }

    if (systemDiscount > 0) {
        systemRow.style.removeProperty('display');
        document.getElementById('summary-system-discount').textContent = '- ' + fmt(systemDiscount);
    } else {
        systemRow.style.setProperty('display', 'none', 'important');
    }

    if (paymentDiscount > 0) {
        paymentRow.style.removeProperty('display');
        document.getElementById('summary-payment-discount').textContent = '- ' + fmt(paymentDiscount);
    } else {
        paymentRow.style.setProperty('display', 'none', 'important');
    }

    if (shippingDiscount > 0) {
        shippingRow.style.removeProperty('display');
        document.getElementById('summary-shipping-discount').textContent = '- ' + fmt(shippingDiscount);
    } else {
        shippingRow.style.setProperty('display', 'none', 'important');
    }

    document.getElementById('summary-total').textContent = fmt(total);
}

// Enter key apply coupon
const couponInputEl = document.getElementById('couponInput');
if (couponInputEl) {
    couponInputEl.addEventListener('keydown', e => {
        if (e.key === 'Enter') {
            e.preventDefault();
            applyCoupon();
        }
    });
}

// ─── Shopee/TikTok Style Address Widget Logic ──────────────────────
let userAddresses = Array.from(document.querySelectorAll('.js-user-address-data')).map(el => ({
    addressId: parseInt(el.getAttribute('data-address-id')),
    recipientName: el.getAttribute('data-recipient-name'),
    recipientPhone: el.getAttribute('data-recipient-phone'),
    addressDetail: el.getAttribute('data-address-detail'),
    isDefault: el.getAttribute('data-is-default') === 'true'
}));

let selectedAddressId = null;

// Populate initial address
function initAddressWidget() {
    // If no addresses, show the inline form immediately (in 'add' mode, permanently expanded)
    if (userAddresses.length === 0) {
        document.getElementById('selectedAddressCard').style.display = 'none';
        showInlineAddressForm('add');
        document.getElementById('btnCancelInlineAddress').style.display = 'none'; // No cancel since they must add an address
        document.getElementById('mIsDefault').checked = true;
        document.getElementById('mIsDefault').disabled = true; // Must be default since it's the first one
        return;
    }

    // Find default or first address
    let activeAddr = userAddresses.find(a => a.isDefault);
    if (!activeAddr) activeAddr = userAddresses[0];

    selectAddress(activeAddr.addressId);
    renderAddressList();
}

function selectAddress(addressId) {
    selectedAddressId = addressId;
    const addr = userAddresses.find(a => a.addressId === addressId);
    if (!addr) return;

    // Update display card
    document.getElementById('displayRecipientName').textContent = addr.recipientName;
    document.getElementById('displayRecipientPhone').textContent = addr.recipientPhone;
    document.getElementById('displayAddressDetail').textContent = addr.addressDetail;
    
    const defaultBadge = document.getElementById('defaultBadge');
    if (addr.isDefault) {
        defaultBadge.classList.remove('hidden');
    } else {
        defaultBadge.classList.add('hidden');
    }

    // Set form hidden inputs for submit
    document.getElementById('fullName').value = addr.recipientName;
    document.getElementById('phone').value = addr.recipientPhone;
    document.getElementById('deliveryAddress').value = addr.addressDetail;

    // Re-render list to show checked radio
    renderAddressList();
    scheduleQuoteRefresh();
}

function renderAddressList() {
    const container = document.getElementById('addressOptionsContainer');
    if (!container) return;
    container.innerHTML = '';

    userAddresses.forEach(addr => {
        const isSelected = (addr.addressId === selectedAddressId);
        
        const card = document.createElement('div');
        card.className = `p-3 rounded-lg border text-xs flex items-start justify-between gap-3 cursor-pointer transition-all duration-150 \${isSelected ? 'bg-emerald-50/75 border-[#14532D]/40 shadow-sm' : 'bg-white border-slate-100 hover:border-slate-300'}`;
        card.onclick = () => selectAddress(addr.addressId);

        card.innerHTML = `
            <div class="flex items-start gap-2.5 flex-grow">
                <input type="radio" name="addrSelect" value="\${addr.addressId}" \${isSelected ? 'checked' : ''} class="mt-0.5 text-primary focus:ring-primary h-3.5 w-3.5 cursor-pointer">
                <div class="space-y-0.5 flex-grow">
                    <div class="flex items-center gap-1.5 flex-wrap">
                        <span class="font-bold text-slate-800">\${addr.recipientName}</span>
                        <span class="text-slate-300">|</span>
                        <span class="text-slate-600 font-semibold">\${addr.recipientPhone}</span>
                        \${addr.isDefault ? '<span class="px-1.5 py-0.2 bg-red-100 text-red-700 text-[8px] font-bold rounded border border-red-200">Mặc định</span>' : ''}
                    </div>
                    <p class="text-[11px] text-slate-500 leading-relaxed">\${addr.addressDetail}</p>
                </div>
            </div>
            <button type="button" onclick="event.stopPropagation(); showInlineAddressForm('edit', \${addr.addressId})" class="text-[#14532D] hover:underline font-bold shrink-0 text-[11px] cursor-pointer">Sửa</button>
        `;
        
        container.appendChild(card);
    });
}

function toggleAddressSelectionList() {
    const list = document.getElementById('addressSelectionList');
    const icon = document.getElementById('expandIcon');
    if (list.classList.contains('hidden')) {
        list.classList.remove('hidden');
        if (icon) icon.classList.add('rotate-180');
    } else {
        list.classList.add('hidden');
        if (icon) icon.classList.remove('rotate-180');
    }
}

function showInlineAddressForm(mode, addressId = null) {
    const form = document.getElementById('inlineAddressForm');
    const title = document.getElementById('inlineFormTitle');
    const actionInput = document.getElementById('inlineAction');
    const addressIdInput = document.getElementById('inlineAddressId');
    
    const nameInput = document.getElementById('mRecipientName');
    const phoneInput = document.getElementById('mRecipientPhone');
    const detailInput = document.getElementById('mAddressDetail');
    const defaultInput = document.getElementById('mIsDefault');

    actionInput.value = mode;

    if (mode === 'add') {
        title.textContent = 'Thêm địa chỉ nhận hàng mới';
        addressIdInput.value = '';
        nameInput.value = '';
        phoneInput.value = '';
        detailInput.value = '';
        defaultInput.checked = (userAddresses.length === 0);
        defaultInput.disabled = (userAddresses.length === 0);
    } else {
        title.textContent = 'Cập nhật địa chỉ giao hàng';
        const addr = userAddresses.find(a => a.addressId === addressId);
        if (!addr) return;
        
        addressIdInput.value = addr.addressId;
        nameInput.value = addr.recipientName;
        phoneInput.value = addr.recipientPhone;
        detailInput.value = addr.addressDetail;
        defaultInput.checked = addr.isDefault;
        defaultInput.disabled = addr.isDefault; // If it's already default, cannot uncheck it
    }

    form.classList.remove('hidden');
    form.style.maxHeight = '500px';
    nameInput.focus();
}

function hideInlineAddressForm() {
    const form = document.getElementById('inlineAddressForm');
    form.style.maxHeight = '0px';
    setTimeout(() => {
        form.classList.add('hidden');
    }, 300);
}

function handleInlineAddressSubmit() {
    const mode = document.getElementById('inlineAction').value;
    const addressId = document.getElementById('inlineAddressId').value;
    const name = document.getElementById('mRecipientName').value.trim();
    const phone = document.getElementById('mRecipientPhone').value.trim();
    const detail = document.getElementById('mAddressDetail').value.trim();
    const isDefault = document.getElementById('mIsDefault').checked;

    if (name.length < 3) {
        showCheckoutAlert('Họ và tên người nhận phải từ 3 ký tự trở lên.', 'Thông tin không hợp lệ', 'warning');
        document.getElementById('mRecipientName').focus();
        return;
    }
    const phoneRegex = /^(0|\+84)[3|5|7|8|9][0-9]{8}$/;
    if (!phoneRegex.test(phone)) {
        showCheckoutAlert('Số điện thoại không hợp lệ (phải là số điện thoại Việt Nam gồm 10 chữ số).', 'Thông tin không hợp lệ', 'warning');
        document.getElementById('mRecipientPhone').focus();
        return;
    }
    if (detail.length < 5) {
        showCheckoutAlert('Địa chỉ chi tiết phải từ 5 ký tự trở lên.', 'Thông tin không hợp lệ', 'warning');
        document.getElementById('mAddressDetail').focus();
        return;
    }

    const btn = document.getElementById('btnSaveCheckoutAddress');
    btn.disabled = true;
    btn.classList.add('opacity-50');
    btn.textContent = 'Đang lưu...';

    const params = new URLSearchParams({
        action: mode === 'edit' ? 'update' : mode,
        addressId: addressId,
        recipientName: name,
        recipientPhone: phone,
        addressDetail: detail,
        isDefault: isDefault ? 'true' : 'false',
        _csrf: CSRF_TOKEN
    });

    fetch(CTX + '/api/address', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'X-CSRF-Token': CSRF_TOKEN,
            'X-Requested-With': 'XMLHttpRequest'
        },
        body: params.toString()
    })
    .then(r => r.json())
    .then(data => {
        btn.disabled = false;
        btn.classList.remove('opacity-50');
        btn.textContent = 'Lưu địa chỉ';

        if (data.success) {
            const updatedAddr = {
                addressId: data.data.address.addressId,
                recipientName: data.data.address.recipientName,
                recipientPhone: data.data.address.recipientPhone,
                addressDetail: data.data.address.addressDetail,
                isDefault: data.data.address.isDefault
            };

            if (updatedAddr.isDefault) {
                // Set all other addresses isDefault to false
                userAddresses.forEach(a => a.isDefault = false);
            }

            if (mode === 'add') {
                userAddresses.push(updatedAddr);
            } else {
                const idx = userAddresses.findIndex(a => a.addressId === updatedAddr.addressId);
                if (idx !== -1) {
                    userAddresses[idx] = updatedAddr;
                }
            }

            // Restore elements in case it was the first address
            document.getElementById('selectedAddressCard').style.display = 'flex';
            document.getElementById('btnCancelInlineAddress').style.display = 'inline-block';
            document.getElementById('mIsDefault').disabled = false;

            selectAddress(updatedAddr.addressId);
            hideInlineAddressForm();
            scheduleQuoteRefresh();
        } else {
            showCheckoutAlert(data.error || 'Không thể lưu địa chỉ.', 'Lưu địa chỉ thất bại', 'error');
        }
    })
    .catch(err => {
        btn.disabled = false;
        btn.classList.remove('opacity-50');
        btn.textContent = 'Lưu địa chỉ';
        console.error(err);
        showCheckoutAlert('Đã xảy ra lỗi kết nối.', 'Lỗi kết nối', 'error');
    });
}

let currentStep = 1;

function goToStep(step) {
    if (step === 2) {
        if (hasBlockingStockIssue()) {
            showCheckoutAlert('Có sản phẩm đã hết số lượng hoặc vượt số lượng còn lại. Vui lòng quay lại giỏ hàng để đổi phân loại còn hàng hoặc giảm số lượng trước khi thanh toán.', 'Không thể thanh toán', 'warning');
            return;
        }
        // Validate shipping address
        const fullName = document.getElementById('fullName').value.trim();
        const phone = document.getElementById('phone').value.trim();
        const deliveryAddress = document.getElementById('deliveryAddress').value.trim();
        if (userAddresses.length === 0 || !fullName || !phone || !deliveryAddress) {
            showCheckoutAlert('Vui lòng chọn hoặc thêm địa chỉ nhận hàng trước khi tiếp tục.', 'Thiếu địa chỉ', 'warning');
            const list = document.getElementById('addressSelectionList');
            if (list && list.classList.contains('hidden')) {
                toggleAddressSelectionList();
            }
            return;
        }
    }
    
    currentStep = step;
    updateStepUI();
}

function updateStepUI() {
    // Hide all step containers
    document.getElementById('step-1-container').classList.add('hidden');
    document.getElementById('step-2-container').classList.add('hidden');
    
    // Show current step container with transition
    const currentContainer = document.getElementById('step-' + currentStep + '-container');
    currentContainer.classList.remove('hidden');
    currentContainer.classList.add('animate-fade-in-up');
    
    // Update step progress indicator
    const progressLine = document.getElementById('stepLineProgress');
    if (progressLine) {
        progressLine.style.width = ((currentStep - 1) * 100) + '%';
    }
    
    for (let i = 1; i <= 2; i++) {
        const circle = document.getElementById('stepCircle-' + i);
        const title = document.getElementById('stepTitle-' + i);
        if (i < currentStep) {
            circle.className = 'w-8 h-8 rounded-full bg-emerald-600 text-white flex items-center justify-center font-bold text-xs transition-all shadow-sm';
            circle.innerHTML = '<span class="material-symbols-outlined text-sm font-bold">check</span>';
            title.className = 'text-[11px] font-bold text-emerald-600';
        } else if (i === currentStep) {
            circle.className = 'w-8 h-8 rounded-full bg-primary text-white flex items-center justify-center font-bold text-xs transition-all shadow-sm ring-4 ring-emerald-50';
            circle.innerHTML = i;
            title.className = 'text-[11px] font-bold text-primary';
        } else {
            circle.className = 'w-8 h-8 rounded-full bg-slate-100 text-slate-500 flex items-center justify-center font-bold text-xs transition-all';
            circle.innerHTML = i;
            title.className = 'text-[11px] font-semibold text-slate-400';
        }
    }
    
    // Update sidebar summary button text
    const submitBtn = document.getElementById('submitBtn');
    if (submitBtn) {
        if (currentStep === 1) {
            submitBtn.innerHTML = 'Tiếp tục xác nhận <span class="material-symbols-outlined">arrow_forward</span>';
        } else {
            submitBtn.innerHTML = 'Đặt hàng ngay <span class="material-symbols-outlined">arrow_forward</span>';
        }
    }

    syncCheckoutSubmitButtons();

    // Populate confirmation info card when going to step 2
    if (currentStep === 2) {
        populateConfirmationCard();
    }
}

function populateConfirmationCard() {
    const name = document.getElementById('fullName').value;
    const phone = document.getElementById('phone').value;
    const address = document.getElementById('deliveryAddress').value;
    const timeslot = document.getElementById('deliveryTimeSlot')?.value || '';
    const paymentEl = document.querySelector('input[name="paymentMethod"]:checked');
    const paymentLabel = paymentEl?.value === 'COD' ? 'Thanh toán khi nhận hàng (COD)' : 'Chuyển khoản QR ngân hàng';

    const setEl = (id, text) => { const el = document.getElementById(id); if (el) el.textContent = text; };
    setEl('confirm-name', name);
    setEl('confirm-phone', phone);
    setEl('confirm-address', address);
    setEl('confirm-timeslot', '🕐 ' + (timeslot || 'Giao hỏa tốc'));
    setEl('confirm-payment-method', paymentLabel);

    // Coupon info
    const couponContainer = document.getElementById('confirm-coupon-info');
    if (couponContainer) {
        let html = '';
        if (quoteState && Array.isArray(quoteState.appliedCoupons) && quoteState.appliedCoupons.length > 0) {
            const fmtCurrency = (value) => new Intl.NumberFormat('vi-VN', {style:'currency', currency:'VND'}).format(parseMoneyValue(value));
            quoteState.appliedCoupons.forEach(c => {
                const scopeLabel = getCouponSlotLabel(resolveCouponSlot(c));
                const targetLabel = getCouponTargetLabel(c).toLowerCase();
                html += '<p class="text-emerald-700 font-semibold">' + scopeLabel + ': ' + c.code + ' (' + targetLabel + ', -' + fmtCurrency(c.discountAmount) + ')</p>';
            });
        } else {
            if (shopCouponCode) html += '<p class="text-emerald-700 font-semibold">🏷️ Voucher Shop: ' + shopCouponCode + '</p>';
            if (systemCouponCode) html += '<p class="text-emerald-700 font-semibold">🎟️ Voucher Sàn: ' + systemCouponCode + '</p>';
        }
        if (quoteState && Array.isArray(quoteState.errors) && quoteState.errors.length > 0) {
            html += '<p class="text-red-600 font-semibold">' + quoteState.errors[0] + '</p>';
        }
        couponContainer.innerHTML = html;
        couponContainer.classList.toggle('hidden', !html);
    }
}

function showCheckoutAlert(message, title = 'Thông báo', icon = 'warning') {
    if (typeof Swal !== 'undefined') {
        return Swal.fire({
            icon,
            title,
            text: message,
            confirmButtonText: 'Đã hiểu',
            confirmButtonColor: 'var(--color-primary)',
            background: '#ffffff',
            customClass: {
                popup: 'premium-swal-popup',
                title: 'premium-swal-title',
                confirmButton: 'premium-swal-button'
            }
        });
    }
    alert(message);
}

function syncCheckoutSubmitButtons() {
    const blockingStockIssue = document.querySelectorAll('[data-stock-blocked="true"]').length > 0;
    const submitButtons = document.querySelectorAll('#checkoutForm button[type="submit"], #checkoutForm input[type="submit"], button[onclick="goToStep(2)"], button[form="checkoutForm"][type="submit"]');
    submitButtons.forEach((button) => {
        const shouldDisable = blockingStockIssue;
        button.disabled = shouldDisable;
        button.classList.toggle('opacity-50', shouldDisable);
        button.classList.toggle('cursor-not-allowed', shouldDisable);
    });
}

function hasBlockingStockIssue() {
    return document.querySelectorAll('[data-stock-blocked="true"]').length > 0;
}

function validateCheckoutForm() {
    if (hasBlockingStockIssue()) {
        showCheckoutAlert('Có sản phẩm đã hết số lượng hoặc vượt số lượng còn lại. Vui lòng quay lại giỏ hàng để đổi phân loại còn hàng hoặc giảm số lượng trước khi thanh toán.', 'Không thể thanh toán', 'warning');
        return false;
    }

    if (currentStep < 2) {
        goToStep(2);
        return false;
    }

    const fullName = document.getElementById('fullName').value.trim();
    const phone = document.getElementById('phone').value.trim();
    const deliveryAddress = document.getElementById('deliveryAddress').value.trim();

    if (userAddresses.length === 0) {
        showCheckoutAlert('Vui lòng thêm địa chỉ nhận hàng trước khi thanh toán.', 'Thiếu địa chỉ', 'warning');
        showInlineAddressForm('add');
        return false;
    }

    if (!fullName || !phone || !deliveryAddress) {
        showCheckoutAlert('Vui lòng chọn hoặc điền thông tin địa chỉ giao hàng hợp lệ.', 'Thiếu thông tin', 'warning');
        return false;
    }

    if (quoteState && quoteState.valid === false) {
        const firstError = Array.isArray(quoteState.errors) && quoteState.errors.length > 0
            ? quoteState.errors[0]
            : 'Vui lòng kiểm tra lại mã giảm giá hoặc thông tin thanh toán.';
        showCheckoutAlert(firstError, 'Không thể thanh toán', 'error');
        return false;
    }

    if (quoteState && quoteState.valid === false) {
        const firstError = Array.isArray(quoteState.errors) && quoteState.errors.length > 0
            ? quoteState.errors[0]
            : 'Vui lòng kiểm tra lại mã giảm giá hoặc thông tin checkout.';
        alert(firstError);
        return false;
    }

    const submitBtn = document.getElementById('submitBtn');
    if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.classList.add('opacity-50');
        submitBtn.innerHTML = 'Đang xử lý đặt đơn... <span class="material-symbols-outlined animate-spin text-sm">sync</span>';
    }
    return true;
}

// Prefill default address on load if available
document.addEventListener('DOMContentLoaded', () => {
    initAddressWidget();
    const timeSlotEl = document.getElementById('deliveryTimeSlot');
    if (timeSlotEl) {
        timeSlotEl.addEventListener('change', () => {
            scheduleQuoteRefresh();
            populateConfirmationCard();
        });
    }
    document.querySelectorAll('input[name="paymentMethod"]').forEach(el => {
        el.addEventListener('change', () => {
            scheduleQuoteRefresh();
            populateConfirmationCard();
        });
    });
    scheduleQuoteRefresh();
    syncCheckoutSubmitButtons();
    updateStepUI(); // Initialize wizard step indicators on load
});
</script>

<jsp:include page="/WEB-INF/jsp/common/footer.jsp"/>
