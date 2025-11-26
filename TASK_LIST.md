# Danh Sách Task - Chức Năng Cần Hoàn Thành

## ✅ Đã Hoàn Thành
1. ✅ Follow system (follow/unfollow, private profiles, follow requests)
2. ✅ Post feed (tạo bài đăng, hiển thị feed với infinite scroll)
3. ✅ Like & comment (realtime)
4. ✅ Upload ảnh/video lên Cloudinary
5. ✅ Chat cơ bản (gửi text, xem messages)

---

## 📋 Chức Năng Còn Thiếu (Ưu Tiên)

### 1. Chat - Gửi Hình Ảnh
**Mô tả:** Cho phép gửi hình ảnh trong chat
- [ ] UI: Nút chọn ảnh trong chat input
- [ ] Upload ảnh lên Cloudinary (folder: `chat/{conversationId}`)
- [ ] Hiển thị ảnh trong message bubble
- [ ] Preview ảnh trước khi gửi
- [ ] Tap để xem ảnh fullscreen

**Files cần tạo/sửa:**
- `lib/features/chat/pages/chat_detail_page.dart` - Thêm UI chọn ảnh
- `lib/features/chat/repositories/chat_repository.dart` - Method `sendImageMessage`
- `lib/services/cloudinary_service.dart` - Đã có sẵn

---

### 2. Chat - Typing Indicator
**Mô tả:** Hiển thị "Đang gõ..." khi đối phương đang nhập
- [ ] Logic: Gọi `setTyping(true)` khi user bắt đầu gõ
- [ ] Logic: Gọi `setTyping(false)` khi user dừng gõ (debounce 2s)
- [ ] UI: Hiển thị "Đang gõ..." trong chat bubble
- [ ] Realtime: Listen `typingIn` field trong `user_profiles`

**Files cần sửa:**
- `lib/features/chat/pages/chat_detail_page.dart` - Thêm typing indicator UI và logic

---

### 3. Chat - Seen Status ✅
**Mô tả:** Hiển thị "Đã xem" cho tin nhắn đã được đọc
- [x] UI: Hiển thị icon "Đã xem" (checkmark) cho tin nhắn đã seen
- [x] Logic: Tự động mark as read khi mở conversation
- [x] Logic: Cập nhật `seenBy` khi user xem tin nhắn

**Files đã sửa:**
- `lib/features/chat/pages/chat_detail_page.dart` - Hiển thị seen status, mark as read khi mở
- `lib/features/chat/repositories/chat_repository.dart` - Đã có `markConversationAsRead`
- `firebase/firestore.rules` - Cho phép participant update `seenBy`

---

### 4. Chat - Tìm Kiếm Tin Nhắn ✅
**Mô tả:** Tìm kiếm tin nhắn trong hội thoại
- [x] UI: Search bar trong chat detail page (AppBar với TextField)
- [x] Logic: Query messages by text (Firestore query với client-side filter)
- [x] UI: Highlight kết quả tìm kiếm (yellow background, bold)
- [x] UI: Scroll đến tin nhắn được tìm thấy (jumpTo đầu list)

**Files đã sửa:**
- `lib/features/chat/pages/chat_detail_page.dart` - Thêm search bar, search results view, highlight text
- `lib/features/chat/repositories/chat_repository.dart` - Method `searchMessages` với filter

---

### 5. Chat - Quick Reactions
**Mô tả:** Thêm emoji reactions cho tin nhắn (like, love, haha, etc.)
- [ ] Model: Thêm `reactions` field vào `ChatMessage` (Map<String, List<String>>)
- [ ] UI: Long press message để hiển thị reaction picker
- [ ] UI: Hiển thị reactions dưới message
- [ ] Logic: Toggle reaction (thêm/xóa)

**Files cần sửa:**
- `lib/features/chat/models/message.dart` - Thêm `reactions` field
- `lib/features/chat/pages/chat_detail_page.dart` - UI reactions
- `lib/features/chat/repositories/chat_repository.dart` - Method `toggleReaction`

---

### 6. Post - Xóa Bài Đăng ✅
**Mô tả:** Cho phép chủ bài đăng xóa bài đăng
- [x] UI: Nút delete trong post feed (chỉ hiện cho chủ bài đăng)
- [x] Logic: Xóa post document
- [x] Logic: Xóa likes và comments subcollections
- [x] Logic: Cập nhật `postsCount` (decrement)
- [ ] Logic: Xóa media trên Cloudinary (optional - skip để tối ưu)

**Files đã sửa:**
- `lib/features/posts/pages/post_feed_page.dart` - Thêm PopupMenuButton với option delete
- `lib/features/posts/repositories/post_repository.dart` - Method `deletePost` với batch delete
- `lib/features/posts/services/post_service.dart` - Method `deletePost` wrapper

---

### 7. Comment - Xóa Comment ✅
**Mô tả:** Cho phép tác giả comment hoặc chủ bài đăng xóa comment
- [x] UI: Nút delete trong comment list (chỉ hiện cho tác giả/chủ post)
- [x] Logic: Xóa comment document
- [x] Logic: Kiểm tra quyền (tác giả comment hoặc chủ bài đăng)
- [x] Logic: Cập nhật `commentCount` (decrement)

**Files đã sửa:**
- `lib/features/posts/pages/post_comments_sheet.dart` - Thêm PopupMenuButton với option delete
- `lib/features/posts/repositories/post_repository.dart` - Method `deleteComment` với kiểm tra quyền
- `lib/features/posts/services/post_service.dart` - Method `deleteComment` wrapper

---

### 8. Notification Center ✅
**Mô tả:** In-app notifications cho follow, like, comment, message
- [x] Model: `Notification` model (type, fromUid, toUid, postId?, read, createdAt)
- [x] Repository: `NotificationRepository` (create, markAsRead, watchNotifications)
- [x] Service: Tạo notification khi có like/comment/follow/message
- [x] UI: Notification center page (list notifications)
- [x] UI: Badge số lượng notifications chưa đọc (trong AppBar)
- [x] UI: Navigate đến post/conversation khi tap notification
- [x] Firestore rules cho notifications collection

**Files đã tạo:**
- `lib/features/notifications/models/notification.dart` - Notification model với enum type
- `lib/features/notifications/repositories/notification_repository.dart` - CRUD operations
- `lib/features/notifications/services/notification_service.dart` - Business logic
- `lib/features/notifications/pages/notification_center_page.dart` - UI với list và navigation

**Files đã sửa:**
- `lib/features/posts/services/post_service.dart` - Tạo notification khi like/comment
- `lib/features/follow/services/follow_service.dart` - Tạo notification khi follow/accept request
- `lib/features/chat/repositories/chat_repository.dart` - Tạo notification khi message
- `lib/features/auth/auth_gate.dart` - Thêm notification icon với badge
- `firebase/firestore.rules` - Rules cho notifications collection

---

### 9. Discover/Explore Page
**Mô tả:** Trang Explore gợi ý bài viết/tài khoản trending
- [ ] UI: Discover page với tabs (Posts, Users)
- [ ] Logic: Trending posts (sắp xếp theo likeCount, commentCount, createdAt)
- [ ] Logic: Suggested users (mutual connections, not following)
- [ ] UI: Post grid view
- [ ] UI: User list với follow button

**Files cần tạo:**
- `lib/features/discover/pages/discover_page.dart`
- `lib/features/discover/services/discover_service.dart`

---

### 10. Realtime Presence (Online/Offline)
**Mô tả:** Hiển thị online/offline status
- [ ] Logic: Cập nhật `isOnline` khi app mở/đóng
- [ ] Logic: Cập nhật `lastSeen` khi user offline
- [ ] UI: Hiển thị green dot cho online users
- [ ] UI: Hiển thị "Hoạt động X phút trước" cho offline users

**Files cần sửa:**
- `lib/features/profile/user_profile_repository.dart` - Methods `setOnline`, `setOffline`
- `lib/features/chat/pages/conversations_page.dart` - Hiển thị online status
- `lib/features/profile/public_profile_page.dart` - Hiển thị online status

---

## 📝 Lưu Ý

1. **Firestore Rules:** Cần cập nhật rules cho notifications và reactions
2. **Cloudinary:** Đã có sẵn service, chỉ cần gọi khi upload
3. **Realtime:** Sử dụng `StreamBuilder` và `snapshots()` cho realtime updates
4. **Security:** Đảm bảo chỉ chủ sở hữu mới có thể xóa post/comment

---

## 🎯 Thứ Tự Ưu Tiên Đề Xuất

1. **Chat - Gửi Hình Ảnh** (quan trọng nhất, nhiều người dùng cần)
2. **Chat - Typing Indicator** (cải thiện UX)
3. **Chat - Seen Status** (cải thiện UX)
4. **Post - Xóa Bài Đăng** (chức năng cơ bản)
5. **Comment - Xóa Comment** (chức năng cơ bản)
6. **Notification Center** (tăng engagement)
7. **Chat - Tìm Kiếm Tin Nhắn** (nice to have)
8. **Chat - Quick Reactions** (nice to have)
9. **Discover/Explore Page** (tăng discovery)
10. **Realtime Presence** (nice to have)

