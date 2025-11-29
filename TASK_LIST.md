# Danh Sách Task - Chức Năng Cần Hoàn Thành

## ✅ Đã Hoàn Thành
1. ✅ Follow system (follow/unfollow, private profiles, follow requests)
2. ✅ Post feed (tạo bài đăng, hiển thị feed với infinite scroll)
3. ✅ Like & comment (realtime)
4. ✅ Upload ảnh/video lên Cloudinary
5. ✅ Chat cơ bản (gửi text, xem messages)
6. ✅ Chat permissions (contacts → tạo hội thoại, block/permission guard)

---

## 📋 Chức Năng Còn Thiếu (Ưu Tiên)

### 1. Chat - Gửi Hình Ảnh
**Mô tả:** Cho phép gửi hình ảnh trong chat
- [x] UI: Nút chọn ảnh trong chat input
- [x] Upload ảnh lên Cloudinary (folder: `chat/{conversationId}`)
- [x] Hiển thị ảnh trong message bubble
- [ ] Preview ảnh trước khi gửi
- [x] Tap để xem ảnh fullscreen

**Files cần tạo/sửa:**
- `lib/features/chat/pages/chat_detail_page.dart` - Thêm UI chọn ảnh
- `lib/features/chat/repositories/chat_repository.dart` - Method `sendImageMessage`
- `lib/services/cloudinary_service.dart` - Đã có sẵn

---

### 2. Chat - Typing Indicator
**Mô tả:** Hiển thị "Đang gõ..." khi đối phương đang nhập
- [x] Logic: Gọi `setTyping(true)` khi user bắt đầu gõ
- [x] Logic: Gọi `setTyping(false)` khi user dừng gõ (debounce 2s)
- [x] UI: Hiển thị "Đang gõ..." trong chat bubble
- [x] Realtime: Listen `typingIn` field trong `user_profiles`

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
- [x] Model: Thêm `reactions` field vào `ChatMessage` (Map<String, List<String>>)
- [x] UI: Long press message để hiển thị reaction picker
- [x] UI: Hiển thị reactions dưới message
- [x] Logic: Toggle reaction (thêm/xóa)

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
- [x] Logic: Xóa media trên Cloudinary (optional - skip để tối ưu)

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
- [x] Logic: Cập nhật `isOnline` khi app mở/đóng
- [x] Logic: Cập nhật `lastSeen` khi user offline
- [ ] UI: Hiển thị green dot cho online users
- [x] UI: Hiển thị "Hoạt động X phút trước" cho offline users

**Files cần sửa:**
- `lib/features/profile/user_profile_repository.dart` - Methods `setOnline`, `setOffline`
- `lib/features/chat/pages/conversations_page.dart` - Hiển thị online status
- `lib/features/profile/public_profile_page.dart` - Hiển thị online status

---

### 11. Stories (Tin nổi bật 24h)
**Mô tả:** Người dùng đăng ảnh/video dạng story, tự xoá sau 24h
- [ ] Model: `Story` (authorUid, mediaUrl, type, createdAt, viewers)
- [ ] UI: Vòng avatar có viền story trên home, list story trên đầu feed
- [ ] Logic: Tạo/xem/xoá story (auto expire sau 24h bằng field `expiresAt`)
- [ ] UI: Story viewer (swipe qua lại, hiển thị danh sách đã xem)
- [ ] Logic: Trả lời story bằng tin nhắn (mở direct chat kèm context)

**Files dự kiến:**
- `lib/features/stories/models/story.dart`
- `lib/features/stories/repositories/story_repository.dart`
- `lib/features/stories/pages/story_viewer_page.dart`
- `lib/features/stories/widgets/story_avatar_ring.dart`

---

### 12. Group Chat Nâng Cao
**Mô tả:** Hỗ trợ chat nhóm với quản lý thành viên và quyền admin
- [x] Model: Mở rộng `conversations` với type `group`, name, avatarUrl, description, admins, membersCount
- [ ] Model: Bổ sung phân biệt message trong group (ví dụ: hiển thị authorName, system messages: user joined/left, changed name,…)
- [x] Service: Thêm API trong `group_chat_service` / `chat_repository` để tạo group, thêm/xoá thành viên, rời nhóm, chuyển quyền admin
- [x] Service: Thêm API đổi tên nhóm, đổi avatar nhóm, cập nhật description
- [ ] Service: Logic pin/unpin tin nhắn quan trọng (field `pinnedMessageId` hoặc `pinnedMessages`)
- [x] UI: Màn hình tạo nhóm mới (chọn nhiều thành viên, nhập tên nhóm, chọn avatar nhóm)
- [ ] UI: Hiển thị conversation group trong `ConversationsPage` (tên nhóm, avatar nhóm, số thành viên)
- [ ] UI: Màn hình "Thông tin nhóm" (danh sách thành viên, role admin/member, nút thêm/xoá thành viên, rời nhóm, chuyển quyền admin)
- [ ] UI: Hiển thị badge/section cho tin nhắn được pin trong `ChatDetailPage` (tap để scroll tới message)
- [x] Logic: Phân quyền – chỉ admin mới được đổi tên nhóm, đổi avatar, thêm/xoá thành viên, pin/unpin, chuyển quyền admin
- [x] Firestore: Thiết kế structure và rules cho group (group conversations, participants với role, các thao tác admin)
- [ ] Migration: Xử lý tương thích để conversation 1-1 cũ vẫn hoạt động bình thường bên cạnh group
- [ ] UX: Thêm confirm dialog cho các action nhạy cảm (rời nhóm, xoá thành viên, chuyển quyền admin)

**Files dự kiến:**
- `lib/features/chat/pages/create_group_page.dart`
- `lib/features/chat/pages/group_info_page.dart`
- `lib/features/chat/services/group_chat_service.dart`

---

### 13. Voice & Video Messages ✅
**Mô tả:** Gửi voice message và video message ngắn trong chat
- [x] Model: Mở rộng `MessageAttachment` hỗ trợ type `voice` & `video_message` (duration, thumbnail,…)
- [x] Firestore: Chuẩn hoá cách lưu message voice/video (type, urls, duration, fileSize, createdAt,…)
- [x] Service: Hàm gửi voice message (ghi âm → upload Cloudinary → tạo message type `voice`)
- [x] Service: Hàm gửi video message (chọn/quay → upload → tạo message type `video_message`)
- [x] UI: Nút ghi âm trong `ChatDetailPage`, hiển thị trạng thái đang ghi
- [x] UI: Bubble voice với nút play/stop, thanh progress, thời lượng
- [x] UI: Bubble video message (thumbnail, tap mở `PostVideoPage`)
- [x] Tích hợp Cloudinary cho upload audio/video
- [x] Logic: Giới hạn thời lượng & xử lý lỗi upload (SnackBar báo lỗi, retry thủ công)

**Files dự kiến:**
- `lib/features/chat/models/message_attachment.dart` (mở rộng)
- `lib/features/chat/pages/chat_detail_page.dart` (UI ghi âm, gửi, hiển thị voice/video)
- `lib/services/cloudinary_service.dart` (nếu tái sử dụng upload cho audio/video)

---

### 14. Blocking & Reporting
**Mô tả:** Cho phép block user và report post/user

**Phase 1 – Thiết kế dữ liệu & rules**
- [x] Model blocks: `blocks/{blockerUid}/items/{blockedUid}` (createdAt, reason?)
- [x] Model reports: `reports/{autoId}` (reporterUid, targetType, targetId, reason, createdAt, status)
- [x] Firestore rules: chỉ chủ sở hữu đọc block của mình, mọi user có thể tạo report nhưng chỉ admin đọc

**Phase 2 – Repository & service layer**
- [x] `BlockRepository` (create/delete block, check isBlocked)
- [x] `ReportRepository` (create report, optional mark status)
- [x] Tích hợp vào luồng follow/chat/feed để kiểm tra block trước khi gửi follow/chat

**Phase 3 – UI & UX**
- [x] Profile menu: thêm "Chặn" và "Báo cáo" (confirm dialog, trạng thái block)
- [x] Post menu: thêm "Báo cáo bài viết" (modal chọn lý do)
- [x] Khi đã block: ẩn post, disable chat/follow button, hiển thị banner “Bạn đã chặn người này”

**Phase 4 – Hậu cần & admin**
- [ ] Trang quản trị đơn giản (tạm thời: collection viewer) hoặc export Cloud Function (optional)
- [x] Quy trình gỡ block (unblock) ngay tại profile/feed
- [x] Thông báo nhẹ khi report gửi thành công (SnackBar / dialog)

**Files dự kiến:**
- `lib/features/safety/models/block.dart`, `report.dart`
- `lib/features/safety/repositories/block_repository.dart`, `report_repository.dart`
- `lib/features/posts/pages/post_feed_page.dart` (thêm menu báo cáo/chặn)
- `lib/features/profile/public_profile_page.dart` (thêm menu chặn)

---

### 15. Saved Posts / Bookmarks
**Mô tả:** Lưu bài viết để xem lại sau

#### Phase 1 – Data & Rules
- [x] Thiết kế collection `saved_posts/{uid}/items/{postId}` (postId, savedAt, postOwnerUid)
- [x] Cập nhật `firebase/firestore.rules` để chỉ owner đọc/ghi saved posts của mình
- [ ] (Optional) Index `saved_posts` theo `savedAt DESC` cho màn list

#### Phase 2 – Repository & Service
- [x] Tạo `SavedPostsRepository` (watch, toggleSave, isSaved, fetchSavedPosts)
- [x] Tạo `SavedPostsService` (wrap repository, handle optimistic UI/logging)
- [ ] Viết unit/widget test tối thiểu cho toggle save

#### Phase 3 – UI Integration
- [x] Thêm icon bookmark (stateful) vào `PostCard/PostFeed` (+ SnackBar khi save/un-save)
- [x] Disable/ẩn icon với bài viết của chính mình (nếu không cần lưu)
- [ ] Đồng bộ badge/bộ đếm saved trong `UserProfile` (nếu có)

#### Phase 4 – Saved Posts Page
- [x] Tạo `SavedPostsPage` (list, preview)
- [x] Hiển thị trạng thái trống + CTA trở lại feed khi chưa có bài lưu
- [x] Cho phép mở chi tiết post từ danh sách saved (preview bottom sheet)

#### Phase 5 – QA & Polish
- [ ] Viết checklist test (save/un-save, offline retry, quyền truy cập chéo user)
- [ ] Đảm bảo analytics/logging ghi lại hành động save (nếu có)
- [ ] Cập nhật dokument/FAQ cho người dùng cuối

**Files đã tạo/sửa:**
- `lib/features/saved_posts/repositories/saved_posts_repository.dart`
- `lib/features/saved_posts/services/saved_posts_service.dart`
- `lib/features/saved_posts/models/saved_post.dart`
- `lib/features/saved_posts/pages/saved_posts_page.dart`
- `lib/features/posts/pages/post_feed_page.dart` (thêm icon save)
- `lib/features/profile/profile_screen.dart` (nút mở Saved Posts)
- `firebase/firestore.rules` (rule saved_posts)

---

### 16. Mute Conversation / Notification Controls
**Mô tả:** Cho phép người dùng tắt thông báo cho từng hội thoại (vĩnh viễn hoặc tạm thời).

#### Phase 1 – Data & Rules
- [x] Thêm trường `notificationsEnabled` (bool) và `mutedUntil` (timestamp, optional) vào participant document.
- [ ] Cập nhật Firestore rules để chính participant có thể cập nhật 2 trường này, admin vẫn được cập nhật cho người khác.

#### Phase 2 – Repository & Services
- [x] `ChatRepository.updateParticipantNotificationSettings(conversationId, uid, {notificationsEnabled, mutedUntil})`.
- [x] `NotificationService` kiểm tra trạng thái mute trước khi gửi push/in-app notification (bỏ qua nếu mutedUntil > now hoặc notificationsEnabled == false).

#### Phase 3 – UI & UX
- [x] Thêm action "Thông báo" trong `ChatDetailPage` (ví dụ trong menu 3 chấm) với lựa chọn:
  - Bật thông báo trở lại.
  - Tắt thông báo vô thời hạn.
  - Tắt thông báo 1 giờ / 8 giờ / 24 giờ.
- [x] Hiển thị trạng thái mute trong `ChatDetailPage` (badge hoặc text dưới tên hội thoại) và icon mute trong danh sách `ConversationsPage`.
- [x] SnackBar hoặc toast xác nhận sau khi bật/tắt.

#### Phase 4 – QA
- [x] Test các trường hợp: mute tự động hết hạn, vào lại chat vẫn giữ trạng thái, mute group vs 1-1.
- [x] Đảm bảo block/report không ảnh hưởng logic mute.

**Files dự kiến:**
- `lib/features/chat/repositories/chat_repository.dart`
- `lib/features/chat/pages/chat_detail_page.dart`
- `lib/features/chat/pages/conversations_page.dart`
- `lib/features/notifications/services/notification_service.dart`
- `firebase/firestore.rules`

---

### 17. Advanced Search (Users & Posts)
**Mô tả:** Tìm kiếm nâng cao người dùng và bài viết

#### Phase 1 – Data & Indexing
- [x] Bổ sung field phục vụ search cho user: `displayNameLower`, `emailLower` (ghi xuống khi update profile).
- [x] Bổ sung field phục vụ search cho post: `captionLower` (ghi xuống khi tạo/cập nhật bài viết).
- [x] Thiết kế query đơn giản (chưa cần full-text search): dùng `where` + `orderBy` theo trường lower + `startAt`/`endAt` nếu cần.
- [ ] (Optional) Tạo index cần thiết cho các truy vấn search phổ biến (user, post).

#### Phase 2 – Repository & Services
- [x] Tạo `SearchService` để gom logic tìm kiếm users & posts.
- [x] Mở rộng `UserProfileRepository` với hàm search users theo từ khóa (displayName/email/phone đơn giản).
- [x] Mở rộng `PostRepository` với hàm search posts theo `captionLower` (có phân trang giới hạn kết quả).
- [x] Xử lý chuẩn hoá input search (trim, lowercase, bỏ dấu nếu cần).

#### Phase 3 – UI & UX
- [x] Tạo màn hình `SearchPage` với search bar và tab "Người dùng" / "Bài viết".
- [x] Tab Người dùng: list kết quả với avatar, tên, email, nút follow/unfollow, tap mở `PublicProfilePage`.
- [x] Tab Bài viết: list hoặc grid các post match caption (sử dụng `PostCard`/preview sẵn có).
- [x] Loading & empty state rõ ràng (spinner, “Không tìm thấy kết quả”, gợi ý từ khóa).
- [x] Debounce nhập từ khóa để tránh spam query (ví dụ 300–500ms).

#### Phase 4 – QA
- [x] Test tìm kiếm với nhiều loại input: hoa/thường, có dấu/không dấu (nếu hỗ trợ), chuỗi ngắn/dài.
- [x] Đảm bảo quyền riêng tư: không hiển thị user private ngoài phạm vi cho phép, post bị chặn/bị report nặng thì không gợi ý.
- [x] Kiểm tra performance với nhiều kết quả (giới hạn page size hợp lý).

**Files dự kiến:**
- `lib/features/search/pages/search_page.dart`
- `lib/features/search/services/search_service.dart`
- `lib/features/profile/user_profile_repository.dart` (bổ sung field search)
- `lib/features/posts/repositories/post_repository.dart` (query theo captionLower)

---

### 18. Profile Customization
**Mô tả:** Tùy biến profile người dùng với theme color và links ngoài (website, social media)

#### Phase 1 – Data & Rules
- [x] Model: Thêm `themeColor` (string, hex color code) và `links` (list<map> với `url` và `label`) vào `UserProfile` class.
- [x] Cập nhật `toMap()` và `fromDoc()` để serialize/deserialize các field mới.
- [x] Cập nhật Firestore rules để cho phép owner update `themeColor` và `links` trong `user_profiles`.
- [x] (Optional) Validation: `themeColor` phải là hex color hợp lệ (ví dụ: `#FF5733`), `links` mỗi item phải có `url` (valid URL) và `label` (string).

#### Phase 2 – Repository & Service
- [x] Mở rộng `UserProfileRepository.updateProfile()` để nhận tham số `themeColor` và `links`.
- [x] Thêm method `updateThemeColor(uid, themeColor)` và `updateLinks(uid, links)` nếu cần (hoặc gộp vào `updateProfile`).
- [x] Đảm bảo backward compatibility: các profile cũ không có `themeColor`/`links` vẫn hoạt động bình thường (default values).

#### Phase 3 – UI: Profile Screen (Chỉnh sửa)
- [x] Thêm section "Tùy biến" trong `ProfileScreen` với:
  - Color picker hoặc palette để chọn `themeColor` (hiển thị preview màu).
  - Form để thêm/sửa/xóa links (tối đa 5 links, mỗi link có label và URL).
  - Validation URL format trước khi lưu.
- [x] Hiển thị preview theme color trên avatar ring hoặc accent color trong UI.
- [ ] SnackBar xác nhận sau khi lưu theme/links.

#### Phase 4 – UI: Public Profile Page (Hiển thị)
- [x] Áp dụng `themeColor` vào UI elements:
  - Avatar ring/border (nếu có).
  - Follow button background/accent.
  - AppBar hoặc header accent (optional).
- [x] Hiển thị section "Links" dưới bio với:
  - List các links dạng button/card (icon + label).
  - Tap để mở URL trong browser (sử dụng `url_launcher` hoặc `launchUrl`).
  - Icon phù hợp theo loại link (website, Instagram, Facebook, Twitter, etc.) nếu có thể detect.
- [x] Fallback: Nếu không có `themeColor`, dùng màu mặc định của app.

#### Phase 5 – QA & Polish
- [x] Test các trường hợp: profile cũ không có theme/links, profile mới có đầy đủ, update từng phần.
- [x] Đảm bảo validation URL hoạt động đúng (http/https, invalid URL).
- [x] Kiểm tra UI responsive trên các kích thước màn hình.
- [x] (Optional) Thêm preset colors cho user chọn nhanh thay vì color picker tự do.

**Files dự kiến:**
- `lib/features/profile/user_profile_repository.dart` (thêm fields và methods)
- `lib/features/profile/profile_screen.dart` (UI chỉnh sửa theme/links)
- `lib/features/profile/public_profile_page.dart` (hiển thị theme/links)
- `firebase/firestore.rules` (cho phép update themeColor và links)

---

### 19. Hashtag & Topic System ✅
**Mô tả:** Cho phép gắn hashtag vào bài viết và duyệt nội dung theo chủ đề.

#### Phase 1 – Data & Rules
- [x] Tạo utility function `extractHashtags(String caption)` sử dụng regex để tìm tất cả hashtag (pattern: `#[\w]+`).
- [x] Bổ sung field `hashtags` (list<string>, normalized lowercase) vào model `Post` và document `posts`.
- [x] Cập nhật `toMap()` và `fromDoc()` trong model `Post` để serialize/deserialize field `hashtags`.
- [ ] (Optional) Tạo collection `hashtags/{tag}` lưu metadata:
  - `totalPosts` (int): số bài viết sử dụng hashtag này
  - `lastUpdated` (timestamp): thời gian cập nhật gần nhất
  - `createdAt` (timestamp): thời gian hashtag được tạo lần đầu
- [x] Cập nhật Firestore rules để cho phép read/write `hashtags` field trong posts (đã có sẵn trong rule posts).
- [ ] (Optional) Tạo composite index cho query `posts` theo `hashtags` array-contains và `createdAt` DESC.

#### Phase 2 – Repository & Service
- [x] Mở rộng `PostRepository`:
  - Thêm method `extractHashtagsFromCaption(String caption)` → `List<String>` (normalize lowercase, loại bỏ trùng lặp).
  - Cập nhật `createPost()` để tự động trích xuất và lưu `hashtags` khi tạo bài viết.
  - Thêm method `watchPostsByHashtag(String tag, {int limit = 20})` → `Stream<List<Post>>` (query `where('hashtags', arrayContains: tag)`).
  - Thêm method `fetchPostsByHashtag(String tag, {int limit = 20, DocumentSnapshot? lastDoc})` → `Future<List<Post>>` (pagination).
  - Thêm method `fetchTrendingHashtags({int limit = 10})` → `Future<List<String>>` (dựa trên `hashtags` collection hoặc aggregate từ posts).
- [ ] Tạo `HashtagService` (optional) để:
  - Cập nhật metadata trong `hashtags` collection khi có post mới/xóa post.
  - Cache trending hashtags để tối ưu performance.

#### Phase 3 – UI: Hashtag Display & Interaction
- [x] Tạo widget `PostCaptionWithHashtags`:
  - Parse caption và highlight hashtag (màu xanh, font weight bold).
  - Mỗi hashtag là `TextSpan` tap-able, khi tap → navigate đến `HashtagPage`.
  - Xử lý trường hợp caption có nhiều hashtag, hashtag ở giữa câu.
- [x] Cập nhật `PostFeedPage` và `PostPermalinkPage`:
  - Thay thế `Text` caption bằng `PostCaptionWithHashtags`.
  - Đảm bảo hiển thị đúng format khi có hashtag.

#### Phase 4 – UI: Hashtag Page & Search
- [x] Tạo `HashtagPage`:
  - AppBar hiển thị hashtag (ví dụ: "#travel").
  - TabBar với 2 tabs: "Mới nhất" (sort `createdAt DESC`) và "Nổi bật" (sort theo `likeCount + commentCount DESC`).
  - List posts sử dụng `PostCard` widget sẵn có.
  - Infinite scroll với pagination.
  - Empty state khi không có bài viết.
- [ ] Tích hợp vào `SearchPage`:
  - Thêm tab "Hashtag" (hoặc filter trong tab "Bài viết").
  - Hiển thị gợi ý hashtag khi user nhập từ khóa bắt đầu bằng `#`.
  - Tap hashtag → navigate đến `HashtagPage`.

#### Phase 5 – UI: Hashtag Autocomplete
- [x] Trong màn hình tạo bài viết (`CreatePostPage`):
  - Khi user nhập caption, detect khi gõ `#` → hiển thị dropdown gợi ý hashtag.
  - Gợi ý dựa trên trending hashtags hoặc hashtags phổ biến (query `hashtags` collection).
  - User có thể chọn từ dropdown hoặc tiếp tục gõ tự do.
  - Debounce input để tránh query quá nhiều.

#### Phase 6 – QA & Polish
- [x] Test các trường hợp:
  - Caption không có hashtag → `hashtags` = `[]`.
  - Caption có nhiều hashtag → parse đúng tất cả.
  - Hashtag trùng lặp → normalize và loại bỏ duplicate.
  - Hashtag có ký tự đặc biệt → sanitize (chỉ cho phép chữ, số, underscore).
  - Hashtag dài quá → giới hạn độ dài (ví dụ: tối đa 50 ký tự).
- [x] Đảm bảo XSS/sanitization:
  - Không cho hashtag chứa HTML tags hoặc script.
  - Validate format hashtag trước khi lưu.
- [x] Performance:
  - Giới hạn số lượng hashtag mỗi post (ví dụ: tối đa 10 hashtags).
  - Cache trending hashtags để giảm query Firestore.
- [x] UX improvements:
  - Hiển thị số lượng bài viết cho mỗi hashtag trong `HashtagPage`.
  - (Optional) Hiển thị hashtag suggestions dựa trên caption đang gõ (AI/ML nếu có).

**Files đã tạo/sửa:**
- `lib/features/posts/models/post.dart` (thêm field `hashtags`)
- `lib/features/posts/repositories/post_repository.dart` (parse & lưu hashtags, query theo hashtag)
- `lib/features/posts/pages/hashtag_page.dart` (màn hình hiển thị posts theo hashtag)
- `lib/features/posts/widgets/post_caption_with_hashtags.dart` (widget hiển thị caption với hashtag tap-able)
- `lib/features/posts/widgets/hashtag_autocomplete_field.dart` (autocomplete widget)
- `lib/features/posts/pages/create_post_page.dart` (thêm autocomplete hashtag)
- `lib/features/posts/pages/post_feed_page.dart` (sử dụng `PostCaptionWithHashtags`)
- `lib/features/posts/pages/post_permalink_page.dart` (sử dụng `PostCaptionWithHashtags`)
- `firebase/firestore.rules` (validate field `hashtags`)

---

### 20. Pinned Posts & Profile Highlights
**Mô tả:** Cho phép người dùng ghim bài viết lên đầu profile và lưu stories thành highlights.

**Lưu ý:** Task này chia làm 2 phần chính:
- **Pinned Posts** (ưu tiên): Cho phép ghim tối đa 3 bài viết lên đầu profile
- **Profile Highlights** (tùy chọn, phụ thuộc vào Stories feature): Lưu stories thành highlights (sẽ implement sau khi có Stories)

---

## Phần A: Pinned Posts ✅

#### Phase 1 – Data & Rules
- [x] Thêm field `pinnedPostIds` (list<string>, tối đa 3) vào model `UserProfile` và document `user_profiles`.
- [x] Cập nhật `toMap()` và `fromDoc()` trong `UserProfile` để serialize/deserialize field `pinnedPostIds`.
- [x] Cập nhật Firestore rules để chỉ owner được update `pinnedPostIds` trong `user_profiles`.
- [x] Validation: Đảm bảo `pinnedPostIds` không vượt quá 3 items, không có duplicate.

#### Phase 2 – Repository & Service
- [x] Mở rộng `UserProfileRepository`:
  - Thêm method `updatePinnedPosts(String uid, List<String> postIds)` → `Future<void>` (validate tối đa 3, update field `pinnedPostIds`).
  - Thêm method `addPinnedPost(String uid, String postId)` → `Future<void>` (thêm vào list nếu chưa đủ 3).
  - Thêm method `removePinnedPost(String uid, String postId)` → `Future<void>` (xóa khỏi list).
  - Thêm method `reorderPinnedPosts(String uid, List<String> newOrder)` → `Future<void>` (sắp xếp lại thứ tự).
- [x] Tích hợp vào `PostRepository.deletePost()`:
  - Khi xóa post, tự động gỡ khỏi `pinnedPostIds` của tất cả user profiles (query `where('pinnedPostIds', arrayContains: postId)`).
- [x] Thêm method `fetchPostsByAuthor` vào `PostRepository` để query posts theo authorUid.

#### Phase 3 – UI: Profile Screen (Quản lý Pinned Posts)
- [x] Trên `ProfileScreen` (màn hình profile của chính mình):
  - Thêm nút "Quản lý bài viết ghim" trong AppBar.
  - Tạo màn hình `ManagePinnedPostsPage`:
    - Hiển thị danh sách bài viết đã ghim hiện tại (tối đa 3).
    - Nút "Thêm bài viết" → mở bottom sheet chọn từ danh sách posts của user.
    - Nút "Gỡ ghim" cho mỗi bài viết đã ghim.
    - Drag & drop để sắp xếp lại thứ tự (ReorderableListView).
    - Hiển thị preview thumbnail của mỗi post.
    - Validation: Hiển thị warning khi đã đủ 3 bài, disable nút "Thêm".

#### Phase 4 – UI: Public Profile Page (Hiển thị Pinned Posts)
- [x] Cập nhật `PublicProfilePage`:
  - Thêm section hiển thị posts của user:
    - Query posts theo `authorUid`, sắp xếp `createdAt DESC`.
    - Hiển thị dạng grid 3 cột.
    - Tap vào post → navigate đến `PostPermalinkPage`.
  - Thêm section "Bài viết đã ghim" phía trên grid posts:
    - Chỉ hiển thị nếu `pinnedPostIds` không rỗng.
    - Hiển thị horizontal scrollable list.
    - Mỗi item hiển thị thumbnail của post (media đầu tiên).
    - Icon "Ghim" trên mỗi pinned post để phân biệt.
    - Tap vào pinned post → navigate đến `PostPermalinkPage`.

#### Phase 5 – UI: Post Feed Integration
- [x] Trong `PostFeedPage`:
  - Thêm nút "Ghim/Gỡ ghim" trong menu của post (chỉ hiện cho chủ bài viết).
  - Khi tap "Ghim":
    - Kiểm tra đã đủ 3 bài chưa → hiển thị error nếu đủ.
    - Nếu chưa đủ → thêm vào `pinnedPostIds`, hiển thị SnackBar xác nhận.
    - Nếu đã ghim rồi → hiển thị option "Gỡ ghim".
  - Hiển thị trạng thái pinned/unpinned realtime trong menu.

#### Phase 6 – QA & Polish
- [x] Test các trường hợp:
  - Pin 0, 1, 2, 3 bài viết → hiển thị đúng trên profile.
  - Thử pin bài viết thứ 4 → hiển thị error, không cho phép.
  - Xóa post đã ghim → tự động gỡ khỏi `pinnedPostIds`.
  - Sắp xếp lại thứ tự pinned posts → hiển thị đúng thứ tự trên profile.
  - Pin/unpin từ nhiều nơi (profile screen, post menu) → đồng bộ realtime.
- [x] Performance:
  - Query pinned posts hiệu quả (fetch posts theo list `pinnedPostIds`).
  - Thêm Firestore index cho `posts` collection (authorUid + createdAt).
- [x] UX improvements:
  - Loading state khi đang pin/unpin.
  - SnackBar feedback sau mỗi action.

---

## Phần B: Profile Highlights (Tùy chọn - Phụ thuộc Stories)

**Lưu ý:** Phần này chỉ implement sau khi có Stories feature (Task 11). Tạm thời để trống.

#### Phase 1 – Data & Rules (Stories Highlights)
- [x] Thêm collection `story_highlights/{uid}/albums/{albumId}` với structure:
  - `name` (string): Tên highlight album
  - `coverStoryId` (string): ID của story dùng làm cover
  - `storyIds` (list<string>): Danh sách story IDs trong album
  - `createdAt` (timestamp): Thời gian tạo album
  - `updatedAt` (timestamp): Thời gian cập nhật gần nhất
- [x] Firestore rules: chỉ owner được đọc/ghi albums highlights của mình.

#### Phase 2 – Repository & Service (Stories Highlights)
- [x] Tạo `StoryHighlightRepository`:
  - `createHighlightAlbum(String uid, String name, String coverStoryId, List<String> storyIds)` → `Future<String>` (albumId).
  - `updateHighlightAlbum(String uid, String albumId, {String? name, String? coverStoryId, List<String>? storyIds})` → `Future<void>`.
  - `deleteHighlightAlbum(String uid, String albumId)` → `Future<void>`.
  - `watchHighlightAlbums(String uid)` → `Stream<List<HighlightAlbum>>`.
  - `addStoryToAlbum(String uid, String albumId, String storyId)` → `Future<void>`.
  - `removeStoryFromAlbum(String uid, String albumId, String storyId)` → `Future<void>`.

#### Phase 3 – UI (Stories Highlights)
- [x] Tạo widget `StoryHighlightRow`:
  - Hiển thị horizontal scrollable list các highlight albums.
  - Mỗi album hiển thị avatar nhỏ (cover story), tên album bên dưới.
  - Tap vào album → mở story viewer với stories trong album.
- [x] Tích hợp vào `PublicProfilePage`:
  - Hiển thị `StoryHighlightRow` phía trên pinned posts (nếu có highlights).
- [x] Tạo màn hình quản lý highlights (từ stories đã hết hạn):
  - Chọn stories để tạo album mới.
  - Chọn tên album, cover story.
  - Quản lý albums: sửa tên, xóa album, thêm/bớt stories.

---

**Files dự kiến (Pinned Posts):**
- `lib/features/profile/user_profile_repository.dart` (thêm methods update pinned posts)
- `lib/features/profile/models/user_profile.dart` (thêm field `pinnedPostIds`)
- `lib/features/profile/pages/manage_pinned_posts_page.dart` (màn hình quản lý pinned posts)
- `lib/features/profile/pages/profile_screen.dart` (thêm nút quản lý pinned posts)
- `lib/features/profile/pages/public_profile_page.dart` (hiển thị pinned posts + posts grid)
- `lib/features/posts/repositories/post_repository.dart` (tự động gỡ pinned khi xóa post)
- `lib/features/posts/pages/post_feed_page.dart` (nút ghim trong post menu)
- `lib/features/posts/widgets/pinned_post_card.dart` (widget hiển thị pinned post, optional)
- `firebase/firestore.rules` (rules cho `pinnedPostIds`)

**Files dự kiến (Profile Highlights - sau này):**
- `lib/features/stories/models/story_highlight.dart`
- `lib/features/stories/repositories/story_highlight_repository.dart`
- `lib/features/stories/widgets/story_highlight_row.dart`
- `lib/features/stories/pages/manage_highlights_page.dart`
- `firebase/firestore.rules` (rules cho `story_highlights`)

---

### 21. Advanced Notifications & Digest
**Mô tả:** Nâng cấp hệ thống thông báo với tính năng gom nhóm notifications và tạo báo cáo tổng hợp ngày/tuần.

**Lưu ý:** Task này chia làm 2 phần chính:
- **Notification Grouping** (ưu tiên): Gom nhóm notifications cùng loại để giảm spam (ví dụ: "5 người đã thích bài viết X")
- **Notification Digest** (tùy chọn): Tổng hợp thống kê tương tác theo ngày/tuần

---

## Phần A: Notification Grouping

#### Phase 1 – Data & Rules
- [x] Bổ sung fields vào model `Notification`:
  - `groupKey` (string, optional): Key để group notifications (format: `{type}_{postId}_{toUid}` hoặc `{type}_{toUid}`)
  - `count` (int, default: 1): Số lượng notifications được group
  - `fromUids` (list<string>, optional): Danh sách UIDs của những người đã thực hiện action (thay vì chỉ `fromUid`)
- [x] Cập nhật `toMap()` và `fromDoc()` trong `Notification` để serialize/deserialize các fields mới.
- [x] Cập nhật Firestore rules: cho phép update `count` và `fromUids` khi group notifications (cần validate logic).

#### Phase 2 – Grouping Logic
- [x] Tạo utility function `generateGroupKey(NotificationType type, String? postId, String toUid)` → `String`:
  - Like: `like_{postId}_{toUid}`
  - Comment: `comment_{postId}_{toUid}` (hoặc không group comments vì mỗi comment là unique)
  - Follow: `follow_{toUid}` (group tất cả follow notifications cho cùng một user)
  - Message: Không group (mỗi message là unique)
- [x] Cập nhật `NotificationService`:
  - Thêm method `_findExistingGroupedNotification(String groupKey, String toUid, {Duration? timeWindow})` → `Future<Notification?>`:
    - Query notifications với `groupKey` và `toUid` trong time window (ví dụ: 1 giờ gần đây).
    - Trả về notification đã tồn tại nếu có.
  - Cập nhật `createLikeNotification()`:
    - Generate `groupKey` cho like.
    - Kiểm tra có notification cùng `groupKey` trong 1 giờ gần đây không.
    - Nếu có: Update `count++`, thêm `fromUid` vào `fromUids` (nếu chưa có), update `createdAt` = now.
    - Nếu không: Tạo notification mới với `groupKey`, `count = 1`, `fromUids = [fromUid]`.
  - Cập nhật `createFollowNotification()`:
    - Tương tự như like, nhưng groupKey không có postId.
    - Group tất cả follow notifications trong 1 giờ.
  - Giữ nguyên `createCommentNotification()` và `createMessageNotification()` (không group).

#### Phase 3 – Repository Updates
- [x] Cập nhật `NotificationRepository`:
  - Thêm method `updateGroupedNotification(String notificationId, {int? count, List<String>? fromUids})` → `Future<void>`:
    - Update `count` và `fromUids` của notification đã tồn tại.
    - Update `createdAt` để notification hiển thị ở đầu list.
  - Thêm method `findGroupedNotification(String groupKey, String toUid, {Duration? timeWindow})` → `Future<Notification?>`:
    - Query notification với `groupKey` và `toUid` trong time window.

#### Phase 4 – UI: Grouped Notifications Display
- [x] Cập nhật `NotificationCenterPage`:
  - Tạo helper method `_formatGroupedNotificationTitle(Notification notification)` → `String`:
    - Nếu `count > 1`: "5 người đã thích bài viết của bạn"
    - Nếu `count == 1`: "Nguyễn Văn A đã thích bài viết của bạn"
    - Xử lý các loại notification khác nhau (like, follow, comment).
  - Cập nhật `_getNotificationTitle()` để sử dụng helper mới.
  - Hiển thị avatars của những người đã thực hiện action (nếu `fromUids.length <= 3`, hiển thị tất cả; nếu > 3, hiển thị 3 + "và X người khác").
  - Tap vào grouped notification → navigate đến post/profile tương ứng.

#### Phase 5 – QA & Polish
- [x] Test các trường hợp:
  - Spam like nhiều lần (10 likes trong 1 giờ) → chỉ tạo 1 notification với count = 10.
  - Like từ nhiều người khác nhau → group đúng, hiển thị đúng số lượng.
  - Like sau 1 giờ → tạo notification mới (không group với cái cũ).
  - Follow notifications → group đúng theo toUid.
  - Comment và message → không group (giữ nguyên behavior cũ).
- [x] Performance:
  - Query grouped notification hiệu quả (index trên `groupKey` và `toUid`).
  - Giới hạn số lượng `fromUids` trong một notification (ví dụ: tối đa 50 UIDs, sau đó chỉ hiển thị "và X người khác").

---

## Phần B: Notification Digest

#### Phase 1 – Data & Rules
- [x] Tạo model `NotificationDigest`:
  - `id` (string): Digest ID
  - `uid` (string): User ID
  - `period` (string): 'daily' hoặc 'weekly'
  - `startDate` (DateTime): Ngày bắt đầu period
  - `endDate` (DateTime): Ngày kết thúc period
  - `stats` (map): Thống kê:
    - `likesCount` (int): Tổng số lượt like
    - `commentsCount` (int): Tổng số comment
    - `followsCount` (int): Tổng số người follow mới
    - `messagesCount` (int): Tổng số tin nhắn
  - `topPosts` (list<string>): Danh sách post IDs có nhiều tương tác nhất
  - `createdAt` (DateTime): Thời gian tạo digest
- [x] Tạo collection `notification_digests/{uid}/items/{digestId}` trong Firestore.
- [x] Firestore rules: chỉ owner được đọc/ghi digests của mình.

#### Phase 2 – Digest Service
- [x] Tạo `NotificationDigestService`:
  - Method `generateDailyDigest(String uid, DateTime date)` → `Future<NotificationDigest>`:
    - Query tất cả notifications của user trong ngày.
    - Aggregate: đếm likes, comments, follows, messages.
    - Tìm top 5 posts có nhiều tương tác nhất.
    - Tạo digest document.
  - Method `generateWeeklyDigest(String uid, DateTime weekStart)` → `Future<NotificationDigest>`:
    - Tương tự daily nhưng cho cả tuần.
  - Method `watchDigests(String uid, {String? period})` → `Stream<List<NotificationDigest>>`:
    - Watch digests của user, filter theo period nếu có.
  - Method `fetchDigests(String uid, {String? period, int limit = 10})` → `Future<List<NotificationDigest>>`:
    - Fetch digests với pagination.

#### Phase 3 – Auto-Generate Digest
- [x] Tích hợp vào app lifecycle:
  - Khi user mở app lần đầu trong ngày/tuần, tự động generate digest (nếu chưa có).
  - Hoặc generate digest khi user mở Notification Center (lazy generation).
- [x] Tối ưu: Chỉ generate digest khi có notifications mới trong period.

#### Phase 4 – UI: Digest Page
- [x] Tạo `NotificationDigestPage`:
  - TabBar với 2 tabs: "Hôm nay" và "Tuần này".
  - Hiển thị digest với:
    - Header: "Hôm nay bạn có X lượt thích, Y bình luận..."
    - Cards cho từng loại thống kê (likes, comments, follows, messages).
    - Section "Bài viết nổi bật" hiển thị top posts với preview.
    - Empty state khi chưa có digest hoặc không có tương tác.
  - Tap vào post trong "Bài viết nổi bật" → navigate đến `PostPermalinkPage`.
- [x] Tích hợp vào `NotificationCenterPage`:
  - Thêm tab "Tổng kết" hoặc nút "Xem tổng kết" trong AppBar.
  - Navigate đến `NotificationDigestPage`.

#### Phase 5 – QA & Polish
- [x] Test các trường hợp:
  - Generate digest với ít tương tác (0-5) → hiển thị đúng.
  - Generate digest với nhiều tương tác (100+) → hiển thị đúng, performance tốt.
  - Generate digest cho period không có notifications → empty state.
  - Multiple digests cho cùng period → chỉ giữ 1 digest mới nhất.
- [x] UX improvements:
  - Loading state khi đang generate digest.
  - Refresh button để regenerate digest.
  - Share digest (optional).

---

**Files dự kiến (Notification Grouping):**
- `lib/features/notifications/models/notification.dart` (thêm fields `groupKey`, `count`, `fromUids`)
- `lib/features/notifications/repositories/notification_repository.dart` (thêm methods update grouped notification)
- `lib/features/notifications/services/notification_service.dart` (logic grouping khi tạo notification)
- `lib/features/notifications/pages/notification_center_page.dart` (hiển thị grouped notifications)
- `firebase/firestore.rules` (rules cho update grouped notifications)
- `firebase/firestore.indexes.json` (index cho query `groupKey` và `toUid`)

**Files dự kiến (Notification Digest):**
- `lib/features/notifications/models/notification_digest.dart` (model mới)
- `lib/features/notifications/repositories/notification_digest_repository.dart` (CRUD digests)
- `lib/features/notifications/services/notification_digest_service.dart` (logic generate digest)
- `lib/features/notifications/pages/notification_digest_page.dart` (UI hiển thị digest)
- `firebase/firestore.rules` (rules cho `notification_digests`)


---

### 22. Privacy Nâng Cao ✅
**Mô tả:** Cài đặt riêng tư chi tiết để người dùng kiểm soát thông tin hiển thị và quyền tương tác.

#### Phase 1 – Data & Model
- [x] Thêm các fields privacy vào model `UserProfile`:
  - `showOnlineStatus` (bool, default: true): Hiển thị trạng thái online/offline
  - `lastSeenVisibility` (enum: `everyone`, `followers`, `nobody`, default: `everyone`): Ai được xem last seen
  - `messagePermission` (enum: `everyone`, `followers`, `nobody`, default: `everyone`): Ai được phép nhắn tin
- [x] Cập nhật `toMap()` và `fromDoc()` trong `UserProfile` để serialize/deserialize các fields mới
- [x] Tạo enum `LastSeenVisibility` và `MessagePermission` nếu cần
- [x] Cập nhật Firestore rules để cho phép owner update các fields privacy trong `user_profiles`

#### Phase 2 – Repository & Service
- [x] Mở rộng `UserProfileRepository`:
  - Thêm method `updatePrivacySettings(String uid, {bool? showOnlineStatus, LastSeenVisibility? lastSeenVisibility, MessagePermission? messagePermission})` → `Future<void>`
  - Đảm bảo backward compatibility: profiles cũ không có fields này vẫn hoạt động (default values)
- [x] Tạo helper methods để check quyền:
  - `canViewLastSeen(String viewerUid, String profileUid, bool isFollowing)` → `bool`
  - `canSendMessage(String senderUid, String receiverUid, bool isFollowing, MessagePermission messagePermission)` → `bool`

#### Phase 3 – UI: Privacy Settings Page
- [x] Tạo màn hình `PrivacySettingsPage`:
  - Section "Trạng thái hoạt động":
    - Switch "Hiển thị trạng thái online" (`showOnlineStatus`)
    - Radio buttons cho "Ai có thể xem last seen":
      - Mọi người
      - Chỉ người theo dõi
      - Không ai
  - Section "Tin nhắn":
    - Radio buttons cho "Ai có thể nhắn tin cho bạn":
      - Mọi người
      - Chỉ người theo dõi
      - Không ai
  - Section "Giải thích":
    - Hiển thị mô tả ngắn gọn về từng cài đặt
  - Nút "Lưu" để cập nhật settings
  - SnackBar xác nhận sau khi lưu
- [x] Tích hợp vào `ProfileScreen`:
  - Thêm nút "Quyền riêng tư" trong AppBar
  - Navigate đến `PrivacySettingsPage`

#### Phase 4 – UI: Hiển thị Trạng thái Online/Last Seen
- [x] Cập nhật `PublicProfilePage`:
  - Kiểm tra `showOnlineStatus` trước khi hiển thị "Đang hoạt động"
  - Kiểm tra `lastSeenVisibility` với follow status check (nested StreamBuilder)
  - Logic:
    - Nếu `showOnlineStatus == false`: Không hiển thị "Đang hoạt động"
    - Nếu `lastSeenVisibility == 'nobody'`: Không hiển thị last seen
    - Nếu `lastSeenVisibility == 'followers'`: Chỉ hiển thị nếu viewer đang follow profile owner
- [ ] Cập nhật `ConversationsPage`:
  - Kiểm tra `showOnlineStatus` trước khi hiển thị green dot
  - Kiểm tra `lastSeenVisibility` trước khi hiển thị "Hoạt động X phút trước"
  - Logic tương tự PublicProfilePage
- [ ] Cập nhật `ChatDetailPage`:
  - Hiển thị trạng thái online/offline trong AppBar theo settings

#### Phase 5 – Logic: Kiểm tra Quyền Nhắn Tin
- [x] Cập nhật `ChatRepository`:
  - Thêm method `canCreateConversation(String senderUid, String receiverUid, bool isFollowing)` → `Future<bool>`
  - Kiểm tra `messagePermission` của receiver:
    - `everyone`: Cho phép
    - `followers`: Chỉ cho phép nếu sender đang follow receiver
    - `nobody`: Không cho phép
- [x] Cập nhật `PublicProfilePage`:
  - Disable nút "Nhắn tin" nếu không có quyền (kiểm tra `messagePermission` với follow status)
  - Hiển thị message button theo quyền
- [ ] Cập nhật `ConversationsPage`:
  - Khi tap vào user để tạo conversation mới, kiểm tra quyền trước
  - Nếu không có quyền: Hiển thị dialog/alert giải thích lý do
- [ ] Cập nhật `SearchPage`:
  - Disable nút "Nhắn tin" nếu không có quyền
  - Hiển thị tooltip/badge giải thích lý do

#### Phase 6 – Integration với Follow System
- [x] Đảm bảo logic kiểm tra follow status chính xác:
  - Sử dụng `FollowService` để check follow status trong `PublicProfilePage`
  - Tích hợp follow status check vào privacy logic
- [x] Cập nhật logic khi follow/unfollow:
  - UI tự động refresh khi follow status thay đổi (StreamBuilder realtime)

#### Phase 7 – QA & Polish
- [x] Test các trường hợp:
  - User A set `lastSeenVisibility = 'followers'`, user B không follow → không thấy last seen
  - User A set `lastSeenVisibility = 'followers'`, user B follow → thấy last seen
  - User A set `messagePermission = 'followers'`, user B không follow → không thể nhắn tin
  - User A set `messagePermission = 'followers'`, user B follow → có thể nhắn tin
  - User A set `showOnlineStatus = false` → không ai thấy "Đang hoạt động"
  - Profile cũ không có privacy settings → hoạt động với default values
- [x] UX improvements:
  - Loading state khi đang cập nhật settings
  - SnackBar xác nhận sau khi lưu settings
  - Tooltip/help text giải thích từng cài đặt trong PrivacySettingsPage
- [x] Performance:
  - Sử dụng StreamBuilder để check follow status realtime
  - Optimize queries khi check quyền

**Files cần tạo/sửa:**
- `lib/features/profile/models/user_profile.dart` - Thêm fields privacy
- `lib/features/profile/user_profile_repository.dart` - Thêm methods update privacy settings
- `lib/features/settings/pages/privacy_settings_page.dart` - UI cài đặt privacy (mới)
- `lib/features/profile/profile_screen.dart` - Thêm nút navigate đến PrivacySettingsPage
- `lib/features/chat/pages/conversations_page.dart` - Kiểm tra privacy settings khi hiển thị online/last seen
- `lib/features/chat/pages/chat_detail_page.dart` - Kiểm tra privacy settings
- `lib/features/chat/repositories/chat_repository.dart` - Thêm method check quyền nhắn tin
- `lib/features/search/pages/search_page.dart` - Disable message button theo quyền
- `lib/features/profile/public_profile_page.dart` - Kiểm tra privacy settings và quyền nhắn tin
- `firebase/firestore.rules` - Rules cho update privacy fields

---

### 23. Post Scheduling & Drafts ✅
**Mô tả:** Lưu bài viết dạng nháp và hẹn giờ đăng trong tương lai.

#### Phase 1 – Data & Rules
- [x] Tạo collection `post_drafts/{uid}/items/{draftId}` với structure:
  - `media` (list<map>): Danh sách media (url, type, thumbnailUrl, durationMs)
  - `caption` (string, optional): Caption của bài viết
  - `hashtags` (list<string>, optional): Hashtags đã extract
  - `createdAt` (timestamp): Thời gian tạo draft
  - `updatedAt` (timestamp): Thời gian cập nhật gần nhất
- [x] Bổ sung fields vào model `Post`:  
  - `scheduledAt` (DateTime?, optional): Thời gian hẹn đăng (nếu có)
  - `status` (enum: `draft`, `scheduled`, `published`, `cancelled`, default: `published`): Trạng thái bài viết
- [x] Cập nhật `toMap()` và `fromDoc()` trong `Post` để serialize/deserialize các fields mới
- [x] Tạo enum `PostStatus` (draft, scheduled, published, cancelled)
- [x] Firestore rules:
  - Chỉ owner đọc/ghi `post_drafts` của mình
  - Chỉ owner tạo/update post với `scheduledAt` và `status`
  - Post với `status = 'scheduled'` chỉ hiển thị cho owner cho đến khi `published`

#### Phase 2 – Repository & Service
- [x] Tạo `DraftPostRepository`:
  - `saveDraft(String uid, {List<PostMedia>? media, String? caption, List<String>? hashtags})` → `Future<String>` (draftId)
  - `updateDraft(String uid, String draftId, {List<PostMedia>? media, String? caption, List<String>? hashtags})` → `Future<void>`
  - `deleteDraft(String uid, String draftId)` → `Future<void>`
  - `fetchDraft(String uid, String draftId)` → `Future<DraftPost?>`
  - `watchDrafts(String uid)` → `Stream<List<DraftPost>>`
  - `fetchDrafts(String uid, {int limit = 20})` → `Future<List<DraftPost>>`
- [x] Tạo model `DraftPost`:
  - `id` (string): Draft ID
  - `uid` (string): User ID
  - `media` (List<PostMedia>): Danh sách media
  - `caption` (String?): Caption
  - `hashtags` (List<String>): Hashtags
  - `createdAt` (DateTime): Thời gian tạo
  - `updatedAt` (DateTime): Thời gian cập nhật
- [x] Mở rộng `PostRepository`:
  - Cập nhật `createPost()` để hỗ trợ `scheduledAt` và `status`:
    - Nếu `scheduledAt != null` và `scheduledAt > now`: Set `status = 'scheduled'`
    - Nếu `scheduledAt == null`: Set `status = 'published'`
  - Thêm method `fetchScheduledPosts(String uid)` → `Future<List<Post>>`:
    - Query posts với `status = 'scheduled'` và `authorUid = uid`
  - Thêm method `publishScheduledPost(String postId)` → `Future<void>`:
    - Update `status = 'published'`, xóa `scheduledAt` (hoặc giữ lại để log)
  - Thêm method `cancelScheduledPost(String postId)` → `Future<void>`:
    - Update `status = 'cancelled'`
  - Thêm method `updateScheduledTime(String postId, DateTime newScheduledAt)` → `Future<void>`
- [x] Tạo `PostSchedulingService`:
  - Method `checkAndPublishScheduledPosts(String uid)` → `Future<void>`:
    - Query scheduled posts của user có `scheduledAt <= now` và `status = 'scheduled'`
    - Tự động publish các posts này
  - Tích hợp vào app lifecycle (khi user mở app, check scheduled posts mỗi phút)

#### Phase 3 – UI: Create Post Page (Draft & Schedule)
- [x] Cập nhật `CreatePostPage`:
  - Thêm nút "Lưu nháp" trong AppBar hoặc bottom bar:
    - Khi tap: Lưu media và caption vào `post_drafts`
    - Hiển thị SnackBar xác nhận "Đã lưu nháp"
    - Không cần validate (có thể lưu draft không có caption/media)
  - Thêm toggle/switch "Hẹn giờ đăng" hoặc nút "Đăng ngay / Hẹn giờ":
    - Khi bật "Hẹn giờ đăng": Hiển thị DateTime picker để chọn ngày/giờ
    - Validate: `scheduledAt` phải trong tương lai
    - Hiển thị preview: "Sẽ đăng vào: [ngày/giờ]"
  - Cập nhật nút "Đăng":
    - Nếu có `scheduledAt`: Tạo post với `status = 'scheduled'`
    - Nếu không có: Tạo post với `status = 'published'` (như hiện tại)
    - Hiển thị SnackBar: "Đã lên lịch đăng bài" hoặc "Đã đăng bài"
  - Khi load draft:
    - Thêm nút "Tiếp tục chỉnh sửa" hoặc tự động load draft khi mở CreatePostPage
    - Hiển thị media và caption từ draft
  - Thêm chức năng chỉnh giờ đăng bài (giữ nguyên ngày)

#### Phase 4 – UI: Drafts & Scheduled Posts Page
- [x] Tạo `DraftsAndScheduledPage`:
  - TabBar với 2 tabs: "Bài nháp" và "Bài hẹn giờ"
  - Tab "Bài nháp":
    - List các draft posts với preview (thumbnail, caption truncated)
    - Mỗi item có:
      - Thumbnail (media đầu tiên hoặc icon placeholder)
      - Caption preview (nếu có)
      - Timestamp "Lưu lúc: [createdAt]"
      - Actions: "Tiếp tục chỉnh sửa", "Xóa"
    - Tap vào draft → mở `CreatePostPage` với data từ draft
    - Empty state: "Chưa có bài nháp nào"
  - Tab "Bài hẹn giờ":
    - List các scheduled posts với:
      - Post preview (thumbnail, caption)
      - Badge "Đã lên lịch"
      - Thời gian hẹn đăng: "Sẽ đăng vào: [scheduledAt]"
      - Countdown timer (optional): "Còn X giờ Y phút"
      - Actions: "Chỉnh sửa giờ", "Hủy lên lịch", "Đăng ngay"
    - Tap vào scheduled post → mở preview hoặc `PostPermalinkPage` (nếu đã publish)
    - Empty state: "Chưa có bài viết nào được lên lịch"
  - AppBar:
    - Title: "Bài nháp & Bài hẹn giờ"
    - Action: Refresh button (để check và publish scheduled posts)
  - Actions cho scheduled posts: "Chỉnh giờ", "Chỉnh ngày và giờ", "Đăng ngay", "Hủy lên lịch"

#### Phase 5 – UI: Integration
- [x] Tích hợp vào `ProfileScreen`:
  - Thêm nút "Bài nháp & Bài hẹn giờ" trong AppBar hoặc menu
  - Navigate đến `DraftsAndScheduledPage`
- [x] Cập nhật `PostFeedPage`:
  - Filter posts với `status = 'published'` (không hiển thị scheduled/draft posts)
  - Xử lý backward compatibility cho posts cũ không có status
  - Thêm stream listener để tự động refresh khi có posts mới được publish
- [x] Cập nhật `CreatePostPage`:
  - Khi mở trang, check xem có draft chưa hoàn thành không:
    - Hiển thị dialog: "Bạn có bài nháp chưa hoàn thành. Tiếp tục chỉnh sửa?"
    - Options: "Tiếp tục", "Bỏ qua", "Xóa nháp"
  - Xử lý lỗi context deactivated khi đăng bài

#### Phase 6 – Auto-Publish Logic
- [x] Tạo background task hoặc check khi app mở:
  - Method `checkScheduledPosts()` trong app lifecycle hoặc `initState` của main app
  - Query scheduled posts có `scheduledAt <= now` và `status = 'scheduled'`
  - Tự động publish các posts này
  - Hiển thị notification (optional): "Đã đăng X bài viết đã lên lịch"
- [x] Tối ưu:
  - Chỉ check scheduled posts của current user
  - Check định kỳ mỗi phút bằng Timer.periodic
  - Stream listener để tự động refresh feed khi có posts mới được publish

#### Phase 7 – QA & Polish
- [x] Test các trường hợp:
  - Lưu draft không có caption → load lại đúng
  - Lưu draft không có media → load lại đúng
  - Lưu draft có cả media và caption → load lại đúng
  - Tạo scheduled post với thời gian trong tương lai → hiển thị trong tab "Bài hẹn giờ"
  - Tạo scheduled post với thời gian trong quá khứ → hiển thị error, không cho phép
  - Đến giờ scheduled → tự động publish (hoặc khi mở app)
  - Hủy scheduled post → chuyển sang `status = 'cancelled'`
  - Chỉnh sửa giờ scheduled post → update `scheduledAt`
  - Chỉnh giờ đăng bài (giữ nguyên ngày) → hoạt động đúng
  - Xóa draft → confirm dialog, xóa khỏi Firestore
  - Posts cũ không có status → vẫn hiển thị bình thường
  - Auto-publish realtime → feed tự động cập nhật
- [x] UX improvements:
  - Loading state khi lưu draft/publish scheduled post
  - SnackBar feedback sau mỗi action
  - Confirmation dialog khi xóa draft hoặc hủy scheduled post
  - DateTime picker với timezone support (hiển thị timezone local)
  - Preview scheduled time với format dễ đọc (ví dụ: "Ngày 15/12/2024 lúc 14:30")
  - 2 nút riêng: "Chọn ngày" và "Chọn giờ" trong CreatePostPage
- [x] Performance:
  - Lazy load drafts và scheduled posts (pagination nếu có nhiều)
  - Optimize queries với Firestore indexes
  - Cache draft data locally (optional) để tránh mất data khi offline

**Files cần tạo/sửa:**
- `lib/features/posts/models/draft_post.dart` - Model cho draft post
- `lib/features/posts/models/post.dart` - Thêm fields `scheduledAt` và `status`
- `lib/features/posts/repositories/draft_post_repository.dart` - CRUD operations cho drafts
- `lib/features/posts/repositories/post_repository.dart` - Thêm methods cho scheduled posts
- `lib/features/posts/services/post_scheduling_service.dart` - Service để check và publish scheduled posts (optional)
- `lib/features/posts/pages/drafts_and_scheduled_page.dart` - UI hiển thị drafts và scheduled posts
- `lib/features/posts/pages/create_post_page.dart` - Thêm chức năng lưu draft và schedule
- `lib/features/profile/profile_screen.dart` - Thêm nút navigate đến drafts page
- `firebase/firestore.rules` - Rules cho `post_drafts` và scheduled posts
- `firebase/firestore.indexes.json` - Indexes cho query scheduled posts (authorUid + status + scheduledAt)

---

### 24. Share & Deep-linking Nâng Cao ✅
**Mô tả:** Chia sẻ bài viết/profiles ra ngoài app và hỗ trợ deep link vào trong app.

#### Phase 1 – Deep Link Design & Configuration ✅
- [x] Chuẩn hoá format deep link:
  - Bài viết: `kmessapp://posts/{postId}` hoặc `https://kmessapp.com/posts/{postId}` (universal link)
  - Profile: `kmessapp://user/{uid}` hoặc `https://kmessapp.com/user/{uid}` (universal link)
  - Hashtag: `kmessapp://hashtag/{tag}` hoặc `https://kmessapp.com/hashtag/{tag}`
- [x] Cấu hình deep link trên Android:
  - Thêm intent filters vào `android/app/src/main/AndroidManifest.xml`
  - Cấu hình scheme `kmessapp://` và host `kmessapp.com`
  - Xử lý `android.intent.action.VIEW` với data URI
- [x] Cấu hình deep link trên iOS:
  - Thêm URL schemes vào `ios/Runner/Info.plist`
  - Cấu hình Associated Domains cho universal links (nếu dùng)
  - Xử lý `UIApplicationDelegate` methods
- [ ] (Optional) Cấu hình universal links (App Links/Universal Links):
  - Tạo `.well-known/apple-app-site-association` và `assetlinks.json`
  - Host trên domain `kmessapp.com` (nếu có)

#### Phase 2 – Deep Link Service Implementation ✅
- [x] Tạo model `DeepLink`:
  - `type` (enum: `post`, `profile`, `hashtag`, `unknown`): Loại deep link
  - `postId` (String?): ID bài viết (nếu type = post)
  - `uid` (String?): User ID (nếu type = profile)
  - `hashtag` (String?): Hashtag (nếu type = hashtag)
  - `rawUrl` (String): URL gốc
- [x] Tạo `DeepLinkService`:
  - Method `parseDeepLink(String url)` → `DeepLink?`:
    - Parse URL và extract type, postId, uid, hashtag
    - Validate format và return `DeepLink` object
    - Return `null` nếu URL không hợp lệ
  - Method `handleDeepLink(DeepLink link)` → `Future<void>`:
    - Navigate đến `PostPermalinkPage` nếu type = post
    - Navigate đến `PublicProfilePage` nếu type = profile
    - Navigate đến `HashtagPage` nếu type = hashtag
    - Hiển thị error nếu type = unknown hoặc data không hợp lệ
  - Method `generatePostLink(String postId)` → `String`:
    - Generate deep link URL cho bài viết
  - Method `generateProfileLink(String uid)` → `String`:
    - Generate deep link URL cho profile
  - Method `generateHashtagLink(String hashtag)` → `String`:
    - Generate deep link URL cho hashtag
- [x] Tích hợp vào app lifecycle:
  - Listen deep link khi app mở từ external link
  - Handle deep link khi app đang chạy (background/foreground)
  - Xử lý deep link khi app khởi động từ terminated state

#### Phase 3 – Share Functionality ✅
- [x] Thêm package `share_plus` vào `pubspec.yaml`
- [x] Tạo `ShareService`:
  - Method `sharePost(String postId, {String? caption})` → `Future<void>`:
    - Generate deep link cho post
    - Share text với format: "[Caption]\n\nXem bài viết: [deep link]"
    - Sử dụng `Share.share()` từ `share_plus`
  - Method `shareProfile(String uid, {String? displayName})` → `Future<void>`:
    - Generate deep link cho profile
    - Share text với format: "Xem profile của [displayName]: [deep link]"
  - Method `shareHashtag(String hashtag)` → `Future<void>`:
    - Generate deep link cho hashtag
    - Share text với format: "Khám phá #hashtag: [deep link]"
  - Method `copyPostLink(String postId)` → `Future<void>`:
    - Copy post link vào clipboard
  - Method `copyProfileLink(String uid)` → `Future<void>`:
    - Copy profile link vào clipboard
  - Method `copyHashtagLink(String hashtag)` → `Future<void>`:
    - Copy hashtag link vào clipboard
- [x] Cập nhật UI:
  - Thêm nút "Chia sẻ" trong `PostFeedPage` post menu:
    - PopupMenuButton với options: "Chia sẻ link", "Sao chép link"
    - Tap → share hoặc copy post link
  - Thêm nút "Chia sẻ" trong `PublicProfilePage`:
    - Icon share trong AppBar
    - Tap → share profile link
  - Thêm nút "Chia sẻ" trong `HashtagPage`:
    - PopupMenuButton với options: "Chia sẻ link", "Sao chép link"
    - Tap → share hoặc copy hashtag link
  - Thêm nút "Chia sẻ" trong `PostPermalinkPage`:
    - PopupMenuButton với options: "Chia sẻ link", "Sao chép link"
  - `SavedPostsPage` đã có chức năng copy link sẵn

#### Phase 4 – Link Preview & Metadata
- [ ] (Optional) Tạo link preview khi share:
  - Generate preview card với:
    - Post: thumbnail, caption preview, author name, like/comment count
    - Profile: avatar, display name, bio preview, follower count
    - Hashtag: hashtag name, post count
  - Sử dụng `flutter_link_preview` hoặc custom widget
- [ ] (Optional) Open Graph meta tags cho web:
  - Nếu có web version, thêm OG tags cho posts/profiles
  - Enable rich preview khi share lên social media

#### Phase 5 – Integration & Error Handling ✅
- [x] Cập nhật `PostPermalinkPage`:
  - Nhận `postId` từ deep link (đã có sẵn)
  - Validate post tồn tại, hiển thị error nếu không tìm thấy
  - Handle case post đã bị xóa hoặc private
- [x] Cập nhật `PublicProfilePage`:
  - Nhận `uid` từ deep link (đã có sẵn)
  - Validate user tồn tại, hiển thị error nếu không tìm thấy
  - Handle case profile private hoặc user đã bị block
- [x] Cập nhật `HashtagPage`:
  - Nhận `hashtag` từ deep link (đã có sẵn)
  - Validate hashtag hợp lệ
- [x] Error handling:
  - Hiển thị SnackBar khi deep link không hợp lệ
  - Hiển thị message khi post/profile không tồn tại
  - Hiển thị message khi không có quyền truy cập (private profile, blocked user)

#### Phase 6 – Clipboard & Quick Actions ✅
- [x] Thêm chức năng "Sao chép link":
  - Sử dụng `Clipboard.setData()` từ `flutter/services.dart`
  - SnackBar xác nhận "Đã sao chép link vào clipboard"
- [ ] (Optional) Quick actions:
  - Long press trên post → show menu với "Chia sẻ", "Sao chép link"
  - Long press trên profile avatar → show menu với "Chia sẻ profile"

#### Phase 7 – QA & Polish ✅
- [x] Test các trường hợp:
  - Mở deep link khi app chưa mở → navigate đúng sau khi login (MethodChannel)
  - Mở deep link khi app đang nền → navigate đúng khi resume (MethodChannel)
  - Mở deep link khi app đang mở → navigate đúng không duplicate
  - Share post → link hoạt động đúng khi mở
  - Share profile → link hoạt động đúng khi mở
  - Share hashtag → link hoạt động đúng khi mở
  - Copy link → paste vào app khác và mở đúng
  - Deep link với postId không tồn tại → hiển thị error
  - Deep link với uid không tồn tại → hiển thị error
  - Deep link với post private → hiển thị error hoặc yêu cầu follow
- [x] UX improvements:
  - Loading state khi đang parse và navigate deep link (context.mounted check)
  - Smooth transition khi navigate từ deep link
  - Toast/SnackBar feedback khi share thành công
  - Confirmation dialog khi share sensitive content (optional)
- [x] Performance:
  - Parse deep link nhanh (không block UI)
  - Lazy load data khi navigate từ deep link
  - Cache parsed deep links để tránh parse lại (optional)

**Files cần tạo/sửa:**
- `lib/features/share/models/deep_link.dart` - Model cho deep link
- `lib/features/share/services/deep_link_service.dart` - Service parse và handle deep links
- `lib/features/share/services/share_service.dart` - Service share content
- `lib/features/posts/pages/post_feed_page.dart` - Thêm nút share trong post menu
- `lib/features/posts/pages/post_permalink_page.dart` - Nhận postId từ deep link, thêm nút share
- `lib/features/profile/public_profile_page.dart` - Nhận uid từ deep link, thêm nút share
- `lib/features/posts/pages/hashtag_page.dart` - Nhận hashtag từ deep link, thêm nút share
- `lib/features/saved_posts/pages/saved_posts_page.dart` - Thêm nút copy link
- `lib/features/auth/auth_gate.dart` - Listen và handle deep links khi app mở
- `android/app/src/main/AndroidManifest.xml` - Cấu hình intent filters
- `ios/Runner/Info.plist` - Cấu hình URL schemes
- `pubspec.yaml` - Thêm dependency `share_plus`

---

### 25. Bộ lọc & Sort nâng cao cho Feed/Search
**Mô tả:** Cho phép người dùng lọc và sắp xếp nội dung linh hoạt hơn.

#### Phase 1 – Data & Model Design
- [ ] Tạo enum `PostMediaFilter` (all, images, videos):
  - `all`: Hiển thị tất cả posts
  - `images`: Chỉ hiển thị posts có ít nhất 1 ảnh
  - `videos`: Chỉ hiển thị posts có ít nhất 1 video
- [ ] Tạo enum `TimeFilter` (all, today, thisWeek, thisMonth):
  - `all`: Tất cả thời gian
  - `today`: Chỉ posts trong ngày hôm nay
  - `thisWeek`: Chỉ posts trong tuần này
  - `thisMonth`: Chỉ posts trong tháng này
- [ ] Tạo enum `PostSortOption` (newest, mostLiked, mostCommented):
  - `newest`: Sắp xếp theo `createdAt DESC` (mặc định)
  - `mostLiked`: Sắp xếp theo `likeCount DESC`
  - `mostCommented`: Sắp xếp theo `commentCount DESC`
- [ ] Tạo model `FeedFilters`:
  - `mediaFilter` (PostMediaFilter, default: all)
  - `timeFilter` (TimeFilter, default: all)
  - `sortOption` (PostSortOption, default: newest)
- [ ] Tạo enum `UserSearchFilter` (all, following, notFollowing, followRequest):
  - `all`: Tất cả users
  - `following`: Chỉ users đang follow
  - `notFollowing`: Chỉ users chưa follow
  - `followRequest`: Chỉ users có follow request pending
- [ ] Tạo enum `PrivacyFilter` (all, public, private):
  - `all`: Tất cả (public + private nếu có quyền)
  - `public`: Chỉ public profiles
  - `private`: Chỉ private profiles (nếu có quyền)
- [ ] Tạo model `UserSearchFilters`:
  - `followStatus` (UserSearchFilter, default: all)
  - `privacyFilter` (PrivacyFilter, default: all)

#### Phase 2 – Repository & Service Layer
- [ ] Mở rộng `PostRepository`:
  - Thêm method `fetchPostsWithFilters({FeedFilters? filters, int limit = 20, DocumentSnapshot? startAfter})` → `Future<PageResult<Post>>`:
    - Apply media filter: Query posts có media type tương ứng (client-side filter nếu cần)
    - Apply time filter: Query posts trong khoảng thời gian (từ `startDate` đến `endDate`)
    - Apply sort option: OrderBy theo field tương ứng
    - Pagination với `startAfter`
  - Thêm method `watchPostsWithFilters(FeedFilters filters)` → `Stream<List<Post>>`:
    - Stream posts với filters đã áp dụng
    - Realtime updates khi có posts mới
  - Tối ưu query:
    - Sử dụng composite indexes cho các query phức tạp
    - Client-side filter cho media type nếu Firestore không hỗ trợ tốt
- [ ] Mở rộng `UserProfileRepository`:
  - Thêm method `searchUsersWithFilters(String query, {UserSearchFilters? filters, int limit = 20})` → `Future<List<UserProfile>>`:
    - Apply follow status filter: Query users theo follow state
    - Apply privacy filter: Query users theo `isPrivate`
    - Combine với search query (displayName, email)
- [ ] Tạo `FeedFilterService` (optional):
  - Method `applyMediaFilter(List<Post> posts, PostMediaFilter filter)` → `List<Post>`:
    - Filter posts theo media type (client-side)
  - Method `applyTimeFilter(List<Post> posts, TimeFilter filter)` → `List<Post>`:
    - Filter posts theo time range (client-side)
  - Method `applySort(List<Post> posts, PostSortOption sort)` → `List<Post>`:
    - Sort posts theo option (client-side fallback)

#### Phase 3 – UI: Feed Filters
- [ ] Cập nhật `PostFeedPage`:
  - Thêm AppBar action: Icon filter (hoặc nút "Lọc")
  - Tap → show bottom sheet `FeedFilterBottomSheet`:
    - Section "Loại media":
      - Radio buttons: "Tất cả", "Chỉ ảnh", "Chỉ video"
    - Section "Thời gian":
      - Radio buttons: "Tất cả", "Hôm nay", "Tuần này", "Tháng này"
    - Section "Sắp xếp":
      - Radio buttons: "Mới nhất", "Nhiều like nhất", "Nhiều comment nhất"
    - Nút "Áp dụng" và "Đặt lại"
    - Nút "Đóng"
  - Hiển thị active filters:
    - Chips hiển thị filters đang áp dụng (ví dụ: "Chỉ ảnh", "Tuần này", "Nhiều like nhất")
    - Tap chip → mở filter sheet để chỉnh sửa
    - Nút "Xóa tất cả" để reset filters
  - Cập nhật query khi filters thay đổi:
    - Gọi `fetchPostsWithFilters()` với filters mới
    - Reset pagination khi filters thay đổi
    - Loading state khi đang apply filters
- [ ] Tạo widget `FeedFilterChips`:
  - Hiển thị chips cho các filters đang active
  - Tap chip → remove filter hoặc mở filter sheet
  - Empty state khi không có filters

#### Phase 4 – UI: Search Filters
- [ ] Cập nhật `SearchPage`:
  - Tab "Người dùng":
    - Thêm filter bar phía trên search results:
      - Dropdown "Trạng thái follow": "Tất cả", "Đang follow", "Chưa follow", "Follow request"
      - Dropdown "Quyền riêng tư": "Tất cả", "Công khai", "Riêng tư"
    - Apply filters khi user chọn:
      - Gọi `searchUsersWithFilters()` với filters
      - Reset results khi filters thay đổi
    - Hiển thị active filters dạng chips
  - Tab "Bài viết":
    - Thêm filter bar:
      - Dropdown "Loại media": "Tất cả", "Chỉ ảnh", "Chỉ video"
      - Dropdown "Sắp xếp": "Mới nhất", "Nhiều like nhất", "Nhiều comment nhất"
    - Apply filters khi user chọn:
      - Gọi `fetchPostsWithFilters()` với filters
      - Reset results khi filters thay đổi
    - Hiển thị active filters dạng chips
  - (Optional) Tab "Hashtag":
    - Thêm filter "Sắp xếp": "Mới nhất", "Nổi bật nhất"
    - Apply filter khi user chọn

#### Phase 5 – UI: Filter Bottom Sheet
- [ ] Tạo `FeedFilterBottomSheet`:
  - DraggableScrollableSheet với 3 sections:
    - Section 1: Media Filter (Radio buttons)
    - Section 2: Time Filter (Radio buttons)
    - Section 3: Sort Option (Radio buttons)
  - Bottom actions:
    - Nút "Đặt lại" (reset về defaults)
    - Nút "Áp dụng" (apply filters và đóng sheet)
  - State management:
    - Lưu selected filters trong state
    - Preview filters trước khi apply
- [ ] Tạo `UserSearchFilterBottomSheet`:
  - Tương tự `FeedFilterBottomSheet` nhưng cho user search filters
  - Sections:
    - Follow Status Filter
    - Privacy Filter

#### Phase 6 – State Management & Persistence
- [ ] Lưu filters vào local state:
  - Sử dụng `StatefulWidget` state hoặc `Provider`/`Riverpod` nếu có
  - Persist filters trong session (không mất khi navigate)
- [ ] (Optional) Lưu filters vào SharedPreferences:
  - Lưu last used filters để restore khi mở lại app
  - Clear filters khi user logout
- [ ] Reset filters:
  - Nút "Xóa tất cả" trong filter UI
  - Reset về defaults khi navigate away (optional)

#### Phase 7 – Firestore Indexes & Performance
- [ ] Tạo composite indexes cho queries phức tạp:
  - Index cho `posts` collection:
    - `createdAt` + `likeCount` (cho sort mostLiked)
    - `createdAt` + `commentCount` (cho sort mostCommented)
    - `createdAt` + `authorUid` (cho filter theo time + author)
  - Index cho `user_profiles` collection:
    - `displayNameLower` + `isPrivate` (cho search + privacy filter)
  - Thêm vào `firebase/firestore.indexes.json`
- [ ] Tối ưu queries:
  - Giới hạn số lượng filters kết hợp (tránh query quá phức tạp)
  - Client-side filter cho media type nếu Firestore query không hiệu quả
  - Debounce filter changes để tránh spam queries
  - Cache filter results nếu có thể

#### Phase 8 – QA & Polish
- [ ] Test các trường hợp:
  - Apply single filter → kết quả đúng
  - Apply multiple filters → kết quả đúng
  - Combine filters với search query → kết quả đúng
  - Reset filters → về trạng thái mặc định
  - Pagination với filters → load more đúng
  - Realtime updates với filters → cập nhật đúng
  - Filter với empty results → hiển thị empty state
  - Filter với private posts/users → không lộ nội dung private
- [ ] UX improvements:
  - Loading state khi đang apply filters
  - Smooth transition khi filters thay đổi
  - SnackBar feedback khi apply/reset filters
  - Tooltip giải thích từng filter option
  - Preview số lượng kết quả trước khi apply (optional)
- [ ] Performance:
  - Debounce filter changes (300-500ms)
  - Lazy load filter options
  - Optimize queries với indexes
  - Cache filter results nếu có thể

**Files cần tạo/sửa:**
- `lib/features/posts/models/feed_filters.dart` - Models cho feed filters
- `lib/features/search/models/user_search_filters.dart` - Models cho user search filters
- `lib/features/posts/repositories/post_repository.dart` - Thêm methods query với filters
- `lib/features/profile/user_profile_repository.dart` - Thêm methods search với filters
- `lib/features/posts/services/feed_filter_service.dart` - Service xử lý filters (optional)
- `lib/features/posts/pages/post_feed_page.dart` - UI filter & sort cho feed
- `lib/features/posts/widgets/feed_filter_bottom_sheet.dart` - Bottom sheet chọn filters
- `lib/features/posts/widgets/feed_filter_chips.dart` - Widget hiển thị active filters
- `lib/features/search/pages/search_page.dart` - UI filter cho search
- `lib/features/search/widgets/user_search_filter_bottom_sheet.dart` - Bottom sheet cho user filters
- `firebase/firestore.indexes.json` - Indexes cho queries với filters

---

### 26. Voice/Video Call (Real-time)
**Mô tả:** Cuộc gọi thoại / video 1-1 trực tiếp giữa người dùng.

#### Phase 1 – Tech & Data Design
- [ ] Chọn giải pháp: WebRTC thuần hoặc tích hợp dịch vụ bên thứ ba (Agora, Twilio,…).
- [ ] Thiết kế collection `calls/{callId}` (callerUid, calleeUid, type, status, startedAt, endedAt).
- [ ] Firestore rules: chỉ caller/callee được đọc call của mình.

#### Phase 2 – Signaling & Call Flow
- [ ] Tạo `CallService`:
  - Tạo cuộc gọi mới, gửi “ringing” tới callee (notification + realtime).
  - Cập nhật trạng thái: ringing → accepted/rejected/missed/ended.
- [ ] Tích hợp signaling (qua Firestore hoặc RTDB) cho WebRTC/SDK.

#### Phase 3 – UI & UX
- [ ] Trong `ChatDetailPage`: thêm icon gọi thoại & video.
- [ ] Màn hình “Đang gọi” với nút accept/reject.
- [ ] Màn hình trong cuộc gọi: hiển thị video (nếu video call), mute mic, tắt camera, kết thúc.
- [ ] Log lịch sử cuộc gọi hiển thị trong chat (message type `call_log`).

#### Phase 4 – QA & Network
- [ ] Test trên mạng yếu, chuyển mạng, mất kết nối tạm thời.
- [ ] Test các edge case: callee không online, reject call, missed call.

**Files dự kiến:**
- `lib/features/call/models/call.dart`
- `lib/features/call/services/call_service.dart`
- `lib/features/call/pages/voice_call_page.dart`
- `lib/features/call/pages/video_call_page.dart`
- `lib/features/chat/pages/chat_detail_page.dart` (thêm nút call)
- `firebase/firestore.rules`

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

