# Mô tả mở rộng cho GitHub

## 📱 KMessApp - Nền tảng Mạng xã hội & Nhắn tin

Ứng dụng mạng xã hội và nhắn tin toàn diện được xây dựng bằng Flutter với các mẫu kiến trúc hiện đại, bao gồm giao tiếp thời gian thực, chia sẻ nội dung và khả năng quản lý người dùng nâng cao.

### 🎯 Tổng quan

KMessApp là nền tảng mạng xã hội di động đầy đủ tính năng kết hợp các khía cạnh tốt nhất của mạng xã hội và nhắn tin tức thời. Được xây dựng với Flutter 3.38+ và tận dụng các dịch vụ Firebase, ứng dụng cung cấp trải nghiệm có thể mở rộng, thời gian thực để người dùng kết nối, chia sẻ nội dung và giao tiếp liền mạch.

### ✨ Tính năng chính

**🔐 Xác thực & Bảo mật**
- Nhiều phương thức xác thực: Email/Mật khẩu, Google OAuth, Facebook OAuth, Số điện thoại (SMS)
- Lưu trữ thông tin đăng nhập an toàn với FlutterSecureStorage
- Quản lý tài khoản với hỗ trợ tài khoản đã lưu
- Đặt lại mật khẩu và xác thực email

**📝 Quản lý Nội dung**
- Tạo bài viết phong phú với hỗ trợ nhiều phương tiện (ảnh, video)
- Chức năng lên lịch bài viết
- Quản lý bản nháp bài viết
- Hỗ trợ hashtag với hashtag đang thịnh hành
- Phản ứng bài viết (thích, bình luận với cảm xúc emoji)
- Chỉnh sửa bình luận với theo dõi lịch sử

**💬 Nhắn tin Thời gian thực**
- Cuộc trò chuyện trực tiếp 1-1
- Nhóm chat với quản lý quản trị viên
- Nhiều loại tin nhắn: văn bản, ảnh, giọng nói, video
- Phản ứng và chỉnh sửa tin nhắn
- Chỉ báo đang gõ
- Xác nhận đã đọc và theo dõi số tin chưa đọc
- Chức năng tìm kiếm tin nhắn

**👥 Tính năng Xã hội**
- Hệ thống theo dõi/bỏ theo dõi với hỗ trợ tài khoản riêng tư
- Quản lý yêu cầu theo dõi
- Hồ sơ người dùng với cài đặt quyền riêng tư
- Bài viết và story đã ghim
- Tạo và xem story (hết hạn sau 24 giờ)
- Thích story và theo dõi người xem

**📞 Cuộc gọi Thoại & Video**
- Cuộc gọi video và thoại dựa trên WebRTC
- Tín hiệu cuộc gọi thời gian thực qua Firestore
- Theo dõi lịch sử cuộc gọi
- Quản lý ICE candidate cho kết nối peer

**🔔 Thông báo**
- Hệ thống thông báo thời gian thực
- Nhóm thông báo (thông báo thích, theo dõi)
- Theo dõi số lượng chưa đọc
- Tóm tắt thông báo hàng ngày và hàng tuần
- Tùy chọn thông báo cho từng cuộc trò chuyện

**🛡️ An toàn & Kiểm duyệt**
- Chức năng chặn người dùng
- Hệ thống báo cáo cho người dùng và bài viết
- Bảng quản trị cho kiểm duyệt nội dung
- Hệ thống cấm với cấm tạm thời và vĩnh viễn
- Hệ thống kháng cáo cho người dùng bị cấm

**🔍 Tìm kiếm & Khám phá**
- Tìm kiếm người dùng với bộ lọc (quyền riêng tư, trạng thái theo dõi)
- Tìm kiếm bài viết theo chú thích
- Quản lý lịch sử tìm kiếm
- Khám phá hashtag đang thịnh hành

**💾 Quản lý Dữ liệu**
- Bộ sưu tập bài viết đã lưu
- Bản nháp bài viết với tự động lưu
- Lịch sử tìm kiếm
- Quản lý thông tin đăng nhập tài khoản

### 🏗️ Kiến trúc

Dự án tuân theo mẫu **kiến trúc phân lớp** với sự phân tách rõ ràng về trách nhiệm:

- **📦 Models**: Các lớp dữ liệu đại diện cho các thực thể (Post, Message, Story, Notification)
- **🖼️ Pages**: Lớp UI với StatefulWidget/StatelessWidget
- **💾 Repositories**: Lớp truy cập dữ liệu (19 repositories) xử lý các thao tác CRUD
- **⚙️ Services**: Lớp logic nghiệp vụ (17 services) điều phối các quy trình phức tạp

### 📊 Thống kê Dự án

**Thao tác CRUD: 196**
- Create: 39 thao tác
- Read: 94 thao tác
- Update: 39 thao tác
- Delete: 24 thao tác

**Thao tác không phải CRUD: ~80+**
- Services: ~60 thao tác (logic nghiệp vụ, chuyển đổi dữ liệu, xác thực)
- Helper Methods: ~10 thao tác (tiện ích trong repositories)
- Utilities: ~10 thao tác (định dạng, chuẩn hóa, liên kết sâu)

**Repositories: 19**
- AuthRepository, PostRepository, ChatRepository, FollowRepository
- UserProfileRepository, StoryRepository, NotificationRepository
- CallRepository, AdminRepository, BanRepository, AppealRepository
- ReportRepository, BlockRepository, SavedPostsRepository
- DraftPostRepository, SearchHistoryRepository, SavedAccountsRepository
- SavedCredentialsRepository, NotificationDigestRepository

**Services: 17**
- PostService, ConversationService, FollowService, NotificationService
- CloudinaryService, CallService, WebRTCService, SearchService
- ShareService, BlockService, AdminService, ReportService
- SavedPostsService, PostSchedulingService, PhoneAuthService
- NotificationDigestService, DeepLinkService

### 🛠️ Công nghệ Sử dụng

**Frontend:**
- Flutter 3.38+
- Dart
- StatefulWidget/StatelessWidget cho UI

**Dịch vụ Backend:**
- Firebase Authentication (Email, Google, Facebook, Phone)
- Cloud Firestore (Cơ sở dữ liệu NoSQL)
- Firebase Cloud Functions (TypeScript)
- Cloudinary (Lưu trữ phương tiện - khuyến nghị gói miễn phí 25GB)
- Firebase Storage (Tùy chọn thay thế)

**Gói Quan trọng:**
- Luồng dữ liệu thời gian thực với Firestore
- WebRTC cho cuộc gọi video/thoại
- Xử lý Ảnh/Video
- Hỗ trợ liên kết sâu
- Lưu trữ an toàn cho thông tin đăng nhập

### 🎨 Điểm Nổi bật

✅ **Cập nhật Thời gian thực**: Tất cả luồng dữ liệu sử dụng trình nghe Firestore thời gian thực để cập nhật tức thì

✅ **Kiến trúc Có thể Mở rộng**: Phân tách rõ ràng giữa UI, logic nghiệp vụ và các lớp truy cập dữ liệu

✅ **CRUD Toàn diện**: 196 thao tác CRUD được tài liệu hóa tốt trên 19 repositories

✅ **Tính năng Nâng cao**: Lên lịch bài viết, tóm tắt thông báo, quản lý story, chức năng cuộc gọi

✅ **Bảo mật Ưu tiên**: Hệ thống kiểm duyệt quản trị viên, chặn người dùng, xử lý báo cáo, quản lý cấm

✅ **Thân thiện với Nhà phát triển**: Tài liệu phong phú, ví dụ mã và các mẫu kiến trúc rõ ràng

### 📚 Tài liệu

Dự án bao gồm tài liệu toàn diện:
- Hướng dẫn thiết lập chi tiết cho Firebase và Cloudinary
- Tài liệu kiến trúc
- Tài liệu schema Firestore
- Hướng dẫn triển khai
- So sánh các giải pháp lưu trữ thay thế

### 🚀 Bắt đầu

**Yêu cầu:**
- Flutter 3.38+
- Android SDK 36+
- Java 21

**Khởi động Nhanh:**
```bash
flutter doctor
flutter doctor --android-licenses
flutter run -d windows   # Desktop (phát triển nhanh)
flutter run -d chrome    # Web (tùy chọn)
flutter run -d emulator  # Android emulator
```

### 📄 Giấy phép

[Thêm thông tin giấy phép của bạn tại đây]

---

**Được xây dựng với ❤️ bằng Flutter & Firebase**

