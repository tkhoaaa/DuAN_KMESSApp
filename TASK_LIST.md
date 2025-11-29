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

### 19. Hashtag & Topic System
**Mô tả:** Cho phép gắn hashtag vào bài viết và duyệt nội dung theo chủ đề.

#### Phase 1 – Data & Rules
- [ ] Tạo utility function `extractHashtags(String caption)` sử dụng regex để tìm tất cả hashtag (pattern: `#[\w]+`).
- [ ] Bổ sung field `hashtags` (list<string>, normalized lowercase) vào model `Post` và document `posts`.
- [ ] Cập nhật `toMap()` và `fromDoc()` trong model `Post` để serialize/deserialize field `hashtags`.
- [ ] (Optional) Tạo collection `hashtags/{tag}` lưu metadata:
  - `totalPosts` (int): số bài viết sử dụng hashtag này
  - `lastUpdated` (timestamp): thời gian cập nhật gần nhất
  - `createdAt` (timestamp): thời gian hashtag được tạo lần đầu
- [ ] Cập nhật Firestore rules để cho phép read/write `hashtags` field trong posts (đã có sẵn trong rule posts).
- [ ] (Optional) Tạo composite index cho query `posts` theo `hashtags` array-contains và `createdAt` DESC.

#### Phase 2 – Repository & Service
- [ ] Mở rộng `PostRepository`:
  - Thêm method `extractHashtagsFromCaption(String caption)` → `List<String>` (normalize lowercase, loại bỏ trùng lặp).
  - Cập nhật `createPost()` để tự động trích xuất và lưu `hashtags` khi tạo bài viết.
  - Thêm method `watchPostsByHashtag(String tag, {int limit = 20})` → `Stream<List<Post>>` (query `where('hashtags', arrayContains: tag)`).
  - Thêm method `fetchPostsByHashtag(String tag, {int limit = 20, DocumentSnapshot? lastDoc})` → `Future<List<Post>>` (pagination).
  - Thêm method `fetchTrendingHashtags({int limit = 10})` → `Future<List<String>>` (dựa trên `hashtags` collection hoặc aggregate từ posts).
- [ ] Tạo `HashtagService` (optional) để:
  - Cập nhật metadata trong `hashtags` collection khi có post mới/xóa post.
  - Cache trending hashtags để tối ưu performance.

#### Phase 3 – UI: Hashtag Display & Interaction
- [ ] Tạo widget `PostCaptionWithHashtags`:
  - Parse caption và highlight hashtag (màu xanh, font weight bold).
  - Mỗi hashtag là `TextSpan` tap-able, khi tap → navigate đến `HashtagPage`.
  - Xử lý trường hợp caption có nhiều hashtag, hashtag ở giữa câu.
- [ ] Cập nhật `PostFeedPage` và `PostPermalinkPage`:
  - Thay thế `Text` caption bằng `PostCaptionWithHashtags`.
  - Đảm bảo hiển thị đúng format khi có hashtag.

#### Phase 4 – UI: Hashtag Page & Search
- [ ] Tạo `HashtagPage`:
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
- [ ] Trong màn hình tạo bài viết (`CreatePostPage`):
  - Khi user nhập caption, detect khi gõ `#` → hiển thị dropdown gợi ý hashtag.
  - Gợi ý dựa trên trending hashtags hoặc hashtags phổ biến (query `hashtags` collection).
  - User có thể chọn từ dropdown hoặc tiếp tục gõ tự do.
  - Debounce input để tránh query quá nhiều.

#### Phase 6 – QA & Polish
- [ ] Test các trường hợp:
  - Caption không có hashtag → `hashtags` = `[]`.
  - Caption có nhiều hashtag → parse đúng tất cả.
  - Hashtag trùng lặp → normalize và loại bỏ duplicate.
  - Hashtag có ký tự đặc biệt → sanitize (chỉ cho phép chữ, số, underscore).
  - Hashtag dài quá → giới hạn độ dài (ví dụ: tối đa 50 ký tự).
- [ ] Đảm bảo XSS/sanitization:
  - Không cho hashtag chứa HTML tags hoặc script.
  - Validate format hashtag trước khi lưu.
- [ ] Performance:
  - Giới hạn số lượng hashtag mỗi post (ví dụ: tối đa 10 hashtags).
  - Cache trending hashtags để giảm query Firestore.
- [ ] UX improvements:
  - Hiển thị số lượng bài viết cho mỗi hashtag trong `HashtagPage`.
  - (Optional) Hiển thị hashtag suggestions dựa trên caption đang gõ (AI/ML nếu có).

**Files dự kiến:**
- `lib/features/posts/models/post.dart` (thêm field `hashtags`)
- `lib/features/posts/repositories/post_repository.dart` (parse & lưu hashtags, query theo hashtag)
- `lib/features/posts/services/hashtag_service.dart` (optional - metadata management)
- `lib/features/posts/pages/hashtag_page.dart` (màn hình hiển thị posts theo hashtag)
- `lib/features/posts/widgets/post_caption_with_hashtags.dart` (widget hiển thị caption với hashtag tap-able)
- `lib/features/posts/pages/create_post_page.dart` (thêm autocomplete hashtag)
- `lib/features/search/pages/search_page.dart` (tích hợp tìm kiếm hashtag)
- `lib/features/posts/pages/post_feed_page.dart` (sử dụng `PostCaptionWithHashtags`)
- `lib/features/posts/pages/post_permalink_page.dart` (sử dụng `PostCaptionWithHashtags`)
- `firebase/firestore.rules` (nếu cần validate thêm cho field `hashtags`)

---

### 20. Pinned Posts & Profile Highlights
**Mô tả:** Cho phép người dùng ghim bài viết lên đầu profile và lưu stories thành highlights.

#### Phase 1 – Data & Rules
- [ ] Thêm field `pinnedPostIds` (list<string>, tối đa 3) vào `user_profiles`.
- [ ] Thêm collection `story_highlights/{uid}/albums/{albumId}` (name, coverStoryId, createdAt).
- [ ] Firestore rules: chỉ owner được update `pinnedPostIds` và albums highlights của mình.

#### Phase 2 – Repository & Service
- [ ] Mở rộng `UserProfileRepository` với hàm update pinned posts.
- [ ] Tạo `StoryHighlightRepository` để quản lý albums: tạo/sửa/xóa album, gắn story vào album.

#### Phase 3 – UI & UX
- [ ] Trên `ProfileScreen`: UI chọn bài viết để ghim (tối đa 3), hiển thị preview.
- [ ] Trên `PublicProfilePage`: hiển thị pinned posts phía trên grid bài viết.
- [ ] Trên phần stories: UI tạo highlight album từ stories đã hết hạn (chọn tên, cover).
- [ ] Trên profile: hiển thị hàng “Highlights” (avatar nhỏ từng album, tap mở story viewer).

#### Phase 4 – QA
- [ ] Đảm bảo khi xóa post thì tự động gỡ khỏi `pinnedPostIds`.
- [ ] Test giới hạn 3 bài ghim, hành vi khi thêm/bớt/đổi thứ tự.

**Files dự kiến:**
- `lib/features/profile/user_profile_repository.dart`
- `lib/features/profile/profile_screen.dart`
- `lib/features/profile/public_profile_page.dart`
- `lib/features/stories/repositories/story_highlight_repository.dart`
- `lib/features/stories/widgets/story_highlight_row.dart`
- `firebase/firestore.rules`

---

### 21. Advanced Notifications & Digest
**Mô tả:** Nâng cấp hệ thống thông báo, gom nhóm và tạo báo cáo tổng hợp ngày/tuần.

#### Phase 1 – Data & Rules
- [ ] Bổ sung field `groupKey` và `count` vào notification (để group “N người đã thích bài viết…”).
- [ ] Bổ sung collection `notification_digests/{uid}/items/{digestId}` lưu tổng hợp hằng ngày/tuần.
- [ ] Firestore rules: chỉ owner được đọc/ghi digests của mình.

#### Phase 2 – Service Logic
- [ ] Cập nhật `NotificationService`:
  - Khi tạo notification mới, kiểm tra có notification cùng `groupKey` trong khoảng thời gian gần đây để group.
  - Tăng `count` thay vì tạo document mới nếu phù hợp.
- [ ] Tạo `NotificationDigestService`:
  - Gom dữ liệu like/follow/comment/message theo ngày/tuần.
  - Tạo digest document định kỳ (initial version có thể chạy khi user mở app).

#### Phase 3 – UI & UX
- [ ] Trong Notification Center: hiển thị dạng group (“5 người đã thích bài viết X”).
- [ ] Tạo tab hoặc màn mới “Tổng kết” hiển thị digest (ví dụ: “Tuần này bạn có 30 lượt thích, 5 người theo dõi mới…”).

#### Phase 4 – QA
- [ ] Test logic group: spam like nhiều lần vẫn gom gọn, không tạo quá nhiều row.
- [ ] Test hiển thị digest với nhiều trường hợp: ít tương tác, nhiều tương tác.

**Files dự kiến:**
- `lib/features/notifications/models/notification.dart` (bổ sung group fields)
- `lib/features/notifications/services/notification_service.dart`
- `lib/features/notifications/services/notification_digest_service.dart`
- `lib/features/notifications/pages/notification_center_page.dart`
- `lib/features/notifications/pages/notification_digest_page.dart`
- `firebase/firestore.rules`

---

### 22. In-App Security & Privacy Nâng Cao
**Mô tả:** Bảo mật nâng cao và cài đặt riêng tư chi tiết.

#### Phase 1 – 2FA (Two-Factor Authentication)
- [ ] Thiết kế luồng 2FA qua email/OTP (khi đăng nhập mới, thiết bị mới).
- [ ] Tạo collection `two_factor_tokens/{uid}/items/{tokenId}` (code, expiresAt, used).
- [ ] UI: màn nhập OTP sau khi đăng nhập thành công bước 1.

#### Phase 2 – Device Management
- [ ] Tạo collection `devices/{uid}/sessions/{sessionId}` (deviceInfo, lastActiveAt, ip nếu có).
- [ ] UI: trang “Thiết bị & Phiên đăng nhập” cho phép:
  - Xem danh sách thiết bị.
  - Đăng xuất từng thiết bị.
  - Đăng xuất tất cả thiết bị khác.

#### Phase 3 – Privacy Settings
- [ ] Thêm các cài đặt:
  - Ẩn trạng thái online (`showOnlineStatus`).
  - Ẩn `lastSeen` với người lạ hoặc tất cả (`lastSeenVisibility`).
  - Quyền nhắn tin: mọi người / chỉ người theo dõi (`messagePermission`).
- [ ] UI: trang “Quyền riêng tư” trong settings/profile.
- [ ] Tích hợp vào logic chat/search: chặn send message / hiển thị trạng thái theo cài đặt.

#### Phase 4 – QA
- [ ] Test đăng nhập từ nhiều thiết bị, đăng xuất từ xa.
- [ ] Test quyền nhắn tin giữa các loại tài khoản khác nhau (public/private, follow/not follow).

**Files dự kiến:**
- `lib/features/auth/pages/two_factor_page.dart`
- `lib/features/auth/services/two_factor_service.dart`
- `lib/features/auth/device_session_repository.dart`
- `lib/features/settings/pages/privacy_settings_page.dart`
- `lib/features/profile/user_profile_repository.dart` (thêm fields privacy)
- `lib/features/chat/repositories/chat_repository.dart` (check messagePermission)
- `firebase/firestore.rules`

---

### 23. Post Scheduling & Drafts
**Mô tả:** Lưu bài viết dạng nháp và hẹn giờ đăng trong tương lai.

#### Phase 1 – Data & Rules
- [ ] Thêm collection `post_drafts/{uid}/items/{draftId}` (media, caption, createdAt, updatedAt).
- [ ] Bổ sung field `scheduledAt` và `status` (scheduled/published/cancelled) trong `posts`.
- [ ] Firestore rules: chỉ owner đọc/ghi draft & scheduled posts của mình.

#### Phase 2 – Repository & Service
- [ ] Tạo `DraftPostRepository` để CRUD draft.
- [ ] Mở rộng `PostRepository`:
  - Tạo post với `scheduledAt` trong tương lai (status `scheduled`).
  - Cập nhật status sang `published` khi đến giờ (tạm thời: xử lý client-side khi app mở).

#### Phase 3 – UI & UX
- [ ] Trên màn tạo bài viết:
  - Nút “Lưu nháp”.
  - Tùy chọn “Đăng ngay” hoặc “Hẹn giờ đăng”.
- [ ] Màn “Bài nháp & Bài hẹn giờ”:
  - Danh sách draft có thể sửa/xóa.
  - Danh sách bài đã schedule, cho phép đổi giờ hoặc huỷ schedule.

#### Phase 4 – QA
- [ ] Test các trường hợp: thoát app giữa chừng, mở lại draft, chỉnh sửa rồi đăng.
- [ ] Test timezone và hiển thị thời gian chính xác.

**Files dự kiến:**
- `lib/features/posts/repositories/draft_post_repository.dart`
- `lib/features/posts/pages/draft_posts_page.dart`
- `lib/features/posts/pages/create_post_page.dart` (bổ sung lựa chọn schedule/draft)
- `lib/features/posts/repositories/post_repository.dart`
- `firebase/firestore.rules`

---

### 24. Share & Deep-linking Nâng Cao
**Mô tả:** Chia sẻ bài viết/profiles ra ngoài app và hỗ trợ deep link vào trong app.

#### Phase 1 – Deep Link Design
- [ ] Chuẩn hoá format deep link:
  - Bài viết: `kmessapp://posts/{postId}`
  - Profile: `kmessapp://user/{uid}`
- [ ] Cấu hình deep link trên Android/iOS (intent filters, universal links nếu cần).

#### Phase 2 – Implementation
- [ ] Tạo `DeepLinkService` để phân tích URL và điều hướng tới `PostPermalinkPage` hoặc `PublicProfilePage`.
- [ ] Cập nhật nơi hiển thị link (Saved Posts, share menu) sử dụng format đã chuẩn hóa.

#### Phase 3 – Share Out
- [ ] Tích hợp package share (vd: `share_plus`) để share link bài viết/profile ra ngoài (Messenger, Zalo,…).
- [ ] UI: nút “Chia sẻ” trong post menu và profile menu.

#### Phase 4 – QA
- [ ] Test mở deep link từ trạng thái app khác nhau: app chưa mở / đang nền / đang mở.
- [ ] Test link lỗi, bài viết/profile đã bị xóa → hiển thị màn thông báo phù hợp.

**Files dự kiến:**
- `lib/features/deeplink/deep_link_service.dart`
- `lib/features/posts/pages/post_permalink_page.dart` (mở rộng)
- `lib/features/profile/public_profile_page.dart` (mở rộng nhận từ deep link)
- Android/iOS native config cho deep links

---

### 25. Bộ lọc & Sort nâng cao cho Feed/Search
**Mô tả:** Cho phép người dùng lọc và sắp xếp nội dung linh hoạt hơn.

#### Phase 1 – Feed Filters
- [ ] Trong post feed: bộ lọc theo loại media (tất cả / chỉ ảnh / chỉ video).
- [ ] Bộ lọc theo khoảng thời gian (hôm nay / tuần này / tháng này).
- [ ] Sort theo: mới nhất, nhiều like nhất, nhiều comment nhất.

#### Phase 2 – Search Filters
- [ ] Trong `SearchPage`, tab Users:
  - Filter theo trạng thái follow: đang follow / chưa follow / follow request.
  - Filter theo quyền riêng tư: public / private.
- [ ] Trong tab Posts:
  - Filter theo loại media (image/video).
  - (Optional) Filter theo hashtag nếu đã có hệ thống hashtag.

#### Phase 3 – UX
- [ ] Thiết kế bottom sheet/filter bar để chọn filter & sort.
- [ ] Hiển thị chip/label các filter đang áp dụng.

#### Phase 4 – QA
- [ ] Test kết hợp nhiều filter và sort, tránh query quá nặng (giới hạn page size).
- [ ] Đảm bảo tôn trọng Firestore rules (không lộ nội dung private).

**Files dự kiến:**
- `lib/features/posts/repositories/post_repository.dart` (bổ sung query theo filter)
- `lib/features/posts/pages/post_feed_page.dart` (UI filter & sort)
- `lib/features/search/pages/search_page.dart` (bổ sung filter UI & logic)

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

