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
- [ ] Bổ sung field phục vụ search cho user: `displayNameLower`, `emailLower` (ghi xuống khi update profile).
- [ ] Bổ sung field phục vụ search cho post: `captionLower` (ghi xuống khi tạo/cập nhật bài viết).
- [ ] Thiết kế query đơn giản (chưa cần full-text search): dùng `where` + `orderBy` theo trường lower + `startAt`/`endAt` nếu cần.
- [ ] (Optional) Tạo index cần thiết cho các truy vấn search phổ biến (user, post).

#### Phase 2 – Repository & Services
- [ ] Tạo `SearchService` để gom logic tìm kiếm users & posts.
- [ ] Mở rộng `UserProfileRepository` với hàm search users theo từ khóa (displayName/email/phone đơn giản).
- [ ] Mở rộng `PostRepository` với hàm search posts theo `captionLower` (có phân trang giới hạn kết quả).
- [ ] Xử lý chuẩn hoá input search (trim, lowercase, bỏ dấu nếu cần).

#### Phase 3 – UI & UX
- [ ] Tạo màn hình `SearchPage` với search bar và tab "Người dùng" / "Bài viết".
- [ ] Tab Người dùng: list kết quả với avatar, tên, email, nút follow/unfollow, tap mở `PublicProfilePage`.
- [ ] Tab Bài viết: list hoặc grid các post match caption (sử dụng `PostCard`/preview sẵn có).
- [ ] Loading & empty state rõ ràng (spinner, “Không tìm thấy kết quả”, gợi ý từ khóa).
- [ ] Debounce nhập từ khóa để tránh spam query (ví dụ 300–500ms).

#### Phase 4 – QA
- [ ] Test tìm kiếm với nhiều loại input: hoa/thường, có dấu/không dấu (nếu hỗ trợ), chuỗi ngắn/dài.
- [ ] Đảm bảo quyền riêng tư: không hiển thị user private ngoài phạm vi cho phép, post bị chặn/bị report nặng thì không gợi ý.
- [ ] Kiểm tra performance với nhiều kết quả (giới hạn page size hợp lý).

**Files dự kiến:**
- `lib/features/search/pages/search_page.dart`
- `lib/features/search/services/search_service.dart`
- `lib/features/profile/user_profile_repository.dart` (bổ sung field search)
- `lib/features/posts/repositories/post_repository.dart` (query theo captionLower)

---

### 18. Profile Customization
**Mô tả:** Tùy biến profile người dùng
- [ ] Model: Thêm `themeColor`, `links` (list URL + label) vào `user_profiles`
- [ ] UI: Chọn màu chủ đạo cho profile (áp dụng cho avatar ring, nút follow,…)
- [ ] UI: Thêm/hiển thị các link ngoài (website, social)
- [ ] Logic: Lưu và hiển thị trên PublicProfilePage

**Files dự kiến:**
- `lib/features/profile/user_profile_repository.dart`
- `lib/features/profile/profile_screen.dart` (UI chọn màu, link)
- `lib/features/profile/public_profile_page.dart` (hiển thị theme/link)

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

