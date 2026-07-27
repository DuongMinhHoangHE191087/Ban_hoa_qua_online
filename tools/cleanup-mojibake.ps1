$files = @(
    'D:\DMHoang\Project_GitHub\Ban_hoa_qua_online\web\WEB-INF\jsp\admin\user-view.jsp',
    'D:\DMHoang\Project_GitHub\Ban_hoa_qua_online\web\WEB-INF\jsp\customer\shop-apply.jsp',
    'D:\DMHoang\Project_GitHub\Ban_hoa_qua_online\web\WEB-INF\jsp\shop\status.jsp'
)

foreach ($file in $files) {
    $text = [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8)
    $text = $text.Replace('HOáº T Äá»˜NG', 'HOẠT ĐỘNG')
    $text = $text.Replace('ÄÃƒ KHÃ“A', 'ĐÃ KHÓA')
    $text = $text.Replace('Há» vÃ  tÃªn', 'Họ và tên')
    $text = $text.Replace('Äá»‹a chá»‰ Email', 'Địa chỉ Email')
    $text = $text.Replace('ÄÃ£ xÃ¡c thá»±c', 'Đã xác thực')
    $text = $text.Replace('Sá»‘ Ä‘iá»‡n thoáº¡i', 'Số điện thoại')
    $text = $text.Replace('ChÆ°a cáº­p nháº­t', 'Chưa cập nhật')
    $text = $text.Replace('Vai trÃ² (Role)', 'Vai trò (Role)')
    $text = $text.Replace('ÄÄƒng kÃ½ má»Ÿ gian hÃ ng', 'Đăng ký mở gian hàng')
    $text = $text.Replace('Äiá»n thÃ´ng tin Ä‘á»ƒ gá»­i Ä‘Æ¡n Ä‘Äƒng kÃ½. Admin sáº½ xÃ©t duyá»‡t trong 1-3 ngÃ y lÃ m viá»‡c.', 'Điền thông tin để gửi đơn đăng ký. Admin sẽ xét duyệt trong 1-3 ngày làm việc.')
    $text = $text.Replace('TRáº NG THÃI ÄÃƒ Ná»˜P ÄÆ N', 'TRẠNG THÁI ĐÃ NỘP ĐƠN')
    $text = $text.Replace('Tráº¡ng thÃ¡i Ä‘Æ¡n Ä‘Äƒng kÃ½ hiá»‡n táº¡i', 'Trạng thái đơn đăng ký hiện tại')
    $text = $text.Replace('â³ Äang chá» duyá»‡t', '⏳ Đang chờ duyệt')
    $text = $text.Replace('âœ… ÄÃ£ Ä‘Æ°á»£c duyá»‡t', '✅ Đã được duyệt')
    $text = $text.Replace('âŒ Bá»‹ tá»« chá»‘i', '❌ Bị từ chối')
    $text = $text.Replace('â¸ Táº¡m ngá»«ng hoáº¡t Ä‘á»™ng', '⏸ Tạm ngừng hoạt động')
    $text = $text.Replace('ÄÄƒng kÃ½', 'Đăng ký')
    $text = $text.Replace('ÄÆ¡n hÃ ng', 'Đơn hàng')
    $text = $text.Replace('Tráº¡ng thÃ¡i', 'Trạng thái')
    $text = $text.Replace('ÄÃ£ phÃª duyá»‡t', 'Đã phê duyệt')
    $text = $text.Replace('Äang chá» phÃª duyá»‡t', 'Đang chờ phê duyệt')
    [IO.File]::WriteAllText($file, $text, (New-Object Text.UTF8Encoding($false)))
}
