<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%@ taglib prefix="fmt" uri="jakarta.tags.fmt" %>
<%@ taglib prefix="ft" uri="/WEB-INF/tld/fruitmkt.tld" %>
<jsp:include page="/WEB-INF/jsp/common/header.jsp">
    <jsp:param name="pageTitle" value="Đánh giá sản phẩm đơn hàng #${order.orderId}" />
</jsp:include>

<div class="container my-5">
    <div class="d-flex justify-content-between align-items-center mb-4">
        <h2>Đánh giá sản phẩm - Đơn #${order.orderId}</h2>
        <a href="${pageContext.request.contextPath}/profile?tab=orders" class="btn btn-outline-secondary">Quay lại lịch sử</a>
    </div>



    <div class="row">
        <c:forEach var="item" items="${items}">
            <c:set var="review" value="${reviewMap[item.orderItemId]}" />
            
            <div class="col-12 mb-3">
                <div class="card shadow-sm">
                    <div class="card-body d-flex justify-content-between align-items-center">
                        <div class="d-flex align-items-center">
                            <div class="ms-3">
                                <h5 class="mb-1">${item.productNameSnapshot}</h5>
                                <c:if test="${not empty item.variantLabelSnapshot}">
                                    <small class="text-muted">Phân loại: ${item.variantLabelSnapshot}</small><br/>
                                </c:if>
                                <small class="text-muted">Số lượng: ${item.quantity}</small>
                            </div>
                        </div>
                        
                        <div>
                            <c:choose>
                                <c:when test="${not empty review}">
                                    <div class="text-end mb-2">
                                        <ft:stars rating="${review.rating}" />
                                    </div>
                                    <div class="d-flex gap-2">
                                        <a href="${pageContext.request.contextPath}/reviews?action=edit&orderId=${order.orderId}&orderItemId=${item.orderItemId}" class="btn btn-outline-primary btn-sm">Sửa đánh giá</a>
                                        <form action="${pageContext.request.contextPath}/reviews" method="POST" class="d-inline" onsubmit="return confirmDeleteReview(event)">
                                             <input type="hidden" name="_csrf" value="${sessionScope._csrfToken}">
                                             <input type="hidden" name="action" value="delete">
                                             <input type="hidden" name="orderId" value="${order.orderId}">
                                             <input type="hidden" name="orderItemId" value="${item.orderItemId}">
                                             <button type="submit" class="btn btn-outline-danger btn-sm">Xóa</button>
                                         </form>
                                    </div>
                                </c:when>
                                <c:otherwise>
                                    <a href="${pageContext.request.contextPath}/reviews?orderItemId=${item.orderItemId}" class="btn btn-primary">Viết đánh giá</a>
                                </c:otherwise>
                            </c:choose>
                        </div>
                    </div>
                </div>
            </div>
        </c:forEach>
    </div>
</div>

<script>
function confirmDeleteReview(event) {
    event.preventDefault();
    Swal.fire({
        title: 'Xóa đánh giá này?',
        text: 'Bạn có chắc chắn muốn xóa đánh giá này không?',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#ba1a1a',
        cancelButtonColor: '#e5e7eb',
        confirmButtonText: 'Đồng ý xóa',
        cancelButtonText: 'Hủy'
    }).then(r => { if (r.isConfirmed) event.target.submit(); });
    return false;
}
</script>
<jsp:include page="/WEB-INF/jsp/common/footer.jsp" />
