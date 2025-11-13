# duan_kmessapp

Mobile Flutter app (Android dùng Kotlin).

## Yêu cầu
- Flutter 3.38+
- Android SDK 36+
- Java 21 (JBR của Android Studio OK)

## Thiết lập
```bash
flutter doctor
flutter doctor --android-licenses
```

## Chạy
```bash
flutter run -d windows   # chạy desktop (dev nhanh)
flutter run -d chrome    # chạy web (tùy chọn)
flutter run -d emulator  # chạy Android emulator
```

## Deploy & Cấu hình

- **[docs/deploy_guide.md](docs/deploy_guide.md)**: Hướng dẫn chi tiết deploy Firestore Rules và Cloud Functions, kiểm tra bảo mật.
- **firebase/firestore.rules**: Security rules cho posts, likes, comments (yêu cầu `request.auth`, giới hạn field, quyền sở hữu).
- **functions/**: Cloud Functions TypeScript (thông báo like/comment, đồng bộ `postsCount`).

## Tài liệu kiến trúc
- [docs/firestore_schema.md](docs/firestore_schema.md): mô tả cấu trúc dữ liệu Firestore cho chat, follow, posts.
- `lib/features/chat/repositories/chat_repository.dart`: lớp thao tác Firestore cho hội thoại và tin nhắn, sử dụng schema ở tài liệu trên.
- `lib/features/chat/services/conversation_service.dart`: dịch vụ chuyển đổi dữ liệu hội thoại (đính kèm thông tin người dùng).
- `lib/features/chat/pages/conversations_page.dart`: màn danh sách hội thoại (tạm thời).
- `lib/features/chat/pages/chat_detail_page.dart`: màn chat chi tiết (tối giản, gửi/nhận tin theo thời gian thực).
- `lib/features/follow/repositories/follow_repository.dart`: thao tác follow/follower và yêu cầu theo dõi.
- `lib/features/follow/services/follow_service.dart`: dịch vụ cung cấp API mức cao (follow/unfollow, theo dõi trạng thái, đếm số).
- `lib/features/contacts/pages/contacts_page.dart`: màn quản lý kết nối (đang theo dõi, người theo dõi, yêu cầu follow).
- `lib/features/contacts/widgets/contact_search_delegate.dart`: SearchDelegate tìm kiếm người dùng và gửi yêu cầu theo dõi.
- `lib/features/profile/public_profile_page.dart`: trang hồ sơ công khai với nút Follow/Message.
- `lib/features/profile/profile_screen.dart`: trang chỉnh sửa hồ sơ (bio, private, xử lý yêu cầu theo dõi).
- `lib/features/posts/`: nghiệp vụ bảng tin (đăng nhiều ảnh/video + caption, feed phân trang, like/bình luận realtime).
- `firebase/firestore.rules`: rule mẫu áp dụng cho posts/likes/comments.
- `docs/cloud_functions.md`: skeleton Cloud Functions cho thông báo và xử lý media.

> 💡 **Firestore Index cần thiết**  
> - Truy vấn hội thoại (`participantIds` + `orderBy updatedAt`) yêu cầu composite index.  
> - Truy vấn collection group `follow_requests` (lọc theo `fromUid`) cũng cần index.  
> - Bảng tin sử dụng `posts` (orderBy `createdAt`) và có thể yêu cầu index khi kết hợp bộ lọc nâng cao.  
> Khi gặp lỗi `FAILED_PRECONDITION`, sử dụng liên kết được hiển thị trong ứng dụng để tạo index trên Firebase Console, đợi vài phút rồi thử lại.
