# 🛠️ Hướng dẫn cấu hình IDE (NetBeans, IntelliJ, VS Code) - Ban Hoa Qua Online

Tài liệu này hướng dẫn chi tiết cách thiết lập dự án trên các IDE phổ biến nhất để đảm bảo dự án chạy ổn định trên mọi môi trường phát triển của bạn.

---

## ☕ Yêu cầu hệ thống tối thiểu
- **Java SDK**: JDK 17 (Khuyến nghị sử dụng OpenJDK 17 hoặc Oracle JDK 17)
- **Tomcat**: Apache Tomcat 10.1.x (Jakarta EE 10 / Servlet 6.0)
- **Hệ điều hành**: Windows 10/11, macOS, Linux

---

## 🟦 1. Cấu hình trên Apache NetBeans (Hỗ trợ tốt nhất từ NetBeans 17 đến 22+)

Dự án được cấu hình sẵn dưới dạng dự án chuẩn của **NetBeans Web Project**. Khi bạn import vào NetBeans mới, lỗi thường gặp là thiếu cấu hình Server hoặc JDK. Hãy làm theo các bước sau:

### Bước 1: Import dự án vào NetBeans
1. Mở NetBeans -> Chọn **File** -> **Open Project**.
2. Chọn thư mục root của dự án `Ban_Hoa_Qua_Online`.
3. Nhấn **Open Project**.

### Bước 2: Khắc phục lỗi "Resolve Missing Server Problem" (Nếu có)
Nếu NetBeans hiển thị biểu tượng dự án bị lỗi (dấu chấm than đỏ hoặc tam giác vàng):
1. **Thêm Server Tomcat 10 vào IDE**:
   - Vào menu **Tools** -> **Servers**.
   - Nhấn **Add Server** -> Chọn **Apache Tomcat or TomEE** -> Nhấn **Next**.
   - Tại dòng **Server Location**, trỏ đường dẫn tới thư mục cài đặt Tomcat 10 của bạn (ví dụ: `C:\apache-tomcat-10.1.55`).
   - Đặt Username/Password cho Tomcat manager (hoặc để trống) -> Nhấn **Finish**.
2. **Liên kết dự án với Server vừa thêm**:
   - Click chuột phải vào dự án `Ban_Hoa_Qua_Online` -> Chọn **Properties**.
   - Chọn mục **Run** ở danh sách bên trái.
   - Ở mục **Server**, chọn server **Apache Tomcat** bạn vừa thêm.
   - Ở mục **Java Platform**, chọn **JDK 17**.
   - Nhấn **OK**.

### Bước 3: Khắc phục lỗi thiếu thư viện / CopyLibs
Nếu gặp thông báo lỗi liên quan đến task `CopyLibs`:
- Dự án đã đính kèm sẵn file Jar hỗ trợ tại thư mục `lib/CopyLibs/`. NetBeans sẽ tự động nhận diện thông qua file cấu hình `nbproject/project.properties`.
- Nếu vẫn báo lỗi, click chuột phải vào dự án -> chọn **Clean & Build** để IDE tự động làm mới cache.

---

## 🟪 2. Cấu hình trên IntelliJ IDEA (Ultimate Edition)

IntelliJ Ultimate hỗ trợ cực tốt cho Java EE/Jakarta EE và Tomcat Server:

### Bước 1: Import dự án
1. Mở IntelliJ IDEA -> Chọn **Open**.
2. Chọn thư mục root của dự án `Ban_Hoa_Qua_Online`.
3. IntelliJ sẽ tự động nhận diện cấu hình Ant và cấu trúc dự án.

### Bước 2: Thiết lập Project SDK & Language Level
1. Vào **File** -> **Project Structure** (hoặc nhấn `Ctrl + Alt + Shift + S`).
2. Chọn mục **Project**:
   - **SDK**: Chọn JDK 17.
   - **Language level**: Chọn **17 - Sáng kiến cục bộ, switch pattern matching...**
3. Chọn mục **Modules**:
   - Đảm bảo source root được trỏ đúng vào thư mục `src/java`.
   - Web Resource Directory trỏ đúng vào thư mục `web`.

### Bước 3: Cấu hình Run/Debug Configuration với Tomcat
1. Nhấp vào nút **Add Configuration** (góc trên bên phải) -> Chọn **Add New...** -> Chọn **Tomcat Server** -> **Local**.
2. Tại tab **Server**:
   - Nhấn **Configure...** bên cạnh Application Server và chọn thư mục Tomcat 10.
3. Tại tab **Deployment**:
   - Nhấp vào dấu **+** -> Chọn **Artifact** -> Chọn `Ban_Hoa_Qua_Online:war exploded` hoặc thư mục `build/web`.
   - Thiết lập **Application context** thành `/Ban_Hoa_Qua_Online`.
4. Nhấn **Apply** -> **OK** và nhấn nút **Run** (mũi tên xanh) để bắt đầu.

---

## 🟩 3. Cấu hình trên Visual Studio Code (VS Code)

Dự án được tối ưu hóa tối đa cho các lập trình viên sử dụng VS Code thông qua kịch bản tự động hóa mạnh mẽ.

### Bước 1: Cài đặt Extension cần thiết
Hãy cài đặt các tiện ích mở rộng sau từ Marketplace:
1. **Extension Pack for Java** (của Microsoft)
2. **Community Server Connector** hoặc **Tomcat for Java** (để quản lý Tomcat trực tiếp)

### Bước 2: Sử dụng bộ công cụ tự động hóa `build-tools` (Khuyên dùng)
Chúng tôi đã xây dựng file kịch bản điều khiển cực kỳ mạnh mẽ bằng PowerShell để bạn build/run mà không cần cài đặt phức tạp:

1. **Khởi chạy ứng dụng (Clean, Build, Deploy, Run & Hot-Reload)**:
   - Mở Terminal trong VS Code và gõ:
     ```powershell
     .\build-tools.bat
     ```
   - Nhập lựa chọn `0` để chạy toàn bộ quy trình. Hệ thống sẽ tự động cấu hình Tomcat, recompile mã nguồn Java và mở trình duyệt tại địa chỉ: `http://localhost:8080/Ban_Hoa_Qua_Online/`.
   - Giữ terminal này mở để sử dụng tính năng **Watch Mode (Hot-Reload)**: Mọi thay đổi trong file `.java` hoặc `.jsp` sẽ lập tức được recompile và đưa lên server trong 1-2 giây mà không mất session đăng nhập!

2. **Cách cấu hình đường dẫn Tomcat cho script**:
   - Lần đầu chạy, nếu script không tự tìm thấy Tomcat của bạn, hãy chọn mục `7` (**Cấu hình Tomcat/Java**) để thiết lập đường dẫn đến JDK 17 và Tomcat 10. Thông tin cấu hình sẽ lưu tại file `tomcat_config.ini`.

---

## 🛠️ Công cụ xử lý sự cố nhanh (Troubleshooting Commands)
Nếu gặp bất kỳ xung đột nào về Port hoặc Cache giữa các IDE, hãy chạy script:
- `.\build-tools.bat` -> Nhập `4` để giải phóng Port 8080 (Kill Tomcat bị treo).
- `.\build-tools.bat` -> Nhập `2` để xóa toàn bộ cache build của cả NetBeans và Tomcat.
