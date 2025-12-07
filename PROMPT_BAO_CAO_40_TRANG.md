# PROMPT CHO AI: PHÂN TÍCH DỰ ÁN KMESS APP VÀ VIẾT BÁO CÁO 40 TRANG

## 🎯 MỤC TIÊU

Bạn là một AI chuyên phân tích codebase và viết báo cáo kỹ thuật. Nhiệm vụ của bạn là:

1. **Phân tích toàn bộ codebase** của dự án KMESS App (một ứng dụng mạng xã hội Flutter)
2. **Hiểu rõ kiến trúc, tính năng, và implementation** của từng module
3. **Viết một báo cáo kỹ thuật chi tiết dài 40 trang** (khoảng 15,000-20,000 từ) bằng tiếng Việt

---

## 📋 THÔNG TIN TỔNG QUAN DỰ ÁN

### Tên dự án:
**KMESS App** - Ứng dụng mạng xã hội di động

### Công nghệ chính:
- **Frontend:** Flutter 3.38+ (Dart)
- **Backend:** Firebase (Authentication, Firestore)
- **Storage:** Cloudinary (25GB free tier)
- **Real-time:** Firestore Streams, WebRTC
- **Platform:** Android (Kotlin), Windows, Web

### Kiến trúc:
- **Feature-based architecture**
- **Repository Pattern**
- **Service Layer Pattern**
- **Model-View Separation**

### Thời gian phát triển:
10 tuần (đã hoàn thành ~35+ tính năng chính)

---

## 📁 CẤU TRÚC THƯ MỤC DỰ ÁN

### Cấu trúc chính:
```
duan_kmessapp/
├── lib/
│   ├── main.dart                          # Entry point
│   ├── config/
│   │   └── cloudinary_config.dart         # Cloudinary configuration
│   ├── services/
│   │   └── cloudinary_service.dart        # Cloudinary upload service
│   └── features/                          # Feature-based modules
│       ├── admin/                         # Admin system
│       ├── auth/                          # Authentication
│       ├── call/                          # Voice/Video calls
│       ├── chat/                          # Chat system
│       ├── contacts/                      # Contacts management
│       ├── follow/                        # Follow/Unfollow system
│       ├── notifications/                 # Notification system
│       ├── posts/                         # Posts & Feed
│       ├── profile/                       # User profiles
│       ├── safety/                        # Block & Report
│       ├── saved_posts/                   # Bookmarks
│       ├── search/                        # Search functionality
│       ├── settings/                      # Settings
│       ├── share/                         # Deep links & Sharing
│       └── stories/                       # Stories (24h posts)
├── firebase/
│   ├── firestore.rules                   # Security rules
│   └── firestore.indexes.json            # Database indexes
├── functions/                            # Cloud Functions (TypeScript)
├── docs/                                 # Documentation
│   ├── firestore_schema.md               # Database schema
│   ├── deploy_guide.md                   # Deployment guide
│   └── ... (nhiều tài liệu khác)
├── pubspec.yaml                          # Dependencies
├── TASK_LIST.md                          # Chi tiết các task
└── BAO_CAO_TIEN_DO_10_TUAN.md           # Báo cáo tiến độ
```

### Cấu trúc mỗi feature:
Mỗi feature trong `lib/features/` có cấu trúc:
```
feature_name/
├── models/              # Data models (Dart classes)
├── repositories/        # Data access layer (Firestore operations)
├── services/            # Business logic layer
├── pages/               # UI screens (StatefulWidget/StatelessWidget)
└── widgets/             # Reusable UI components (optional)
```

---

## 🔍 HƯỚNG DẪN PHÂN TÍCH CODE

### Bước 1: Đọc các file quan trọng theo thứ tự

#### 1.1 File tổng quan:
1. **README.md** - Hiểu tổng quan dự án, setup, dependencies
2. **TASK_LIST.md** - Danh sách chi tiết tất cả tính năng (2057 dòng)
3. **BAO_CAO_TIEN_DO_10_TUAN.md** - Báo cáo tiến độ theo tuần
4. **pubspec.yaml** - Dependencies và packages sử dụng
5. **docs/firestore_schema.md** - Cấu trúc database

#### 1.2 Entry point:
- **lib/main.dart** - Khởi tạo app, Firebase, routing

#### 1.3 Core services:
- **lib/services/cloudinary_service.dart** - Upload media
- **lib/config/cloudinary_config.dart** - Cloudinary config

#### 1.4 Features (phân tích từng feature):

**AUTH (Authentication):**
- `lib/features/auth/auth_gate.dart` - Route protection
- `lib/features/auth/auth_repository.dart` - Auth operations
- `lib/features/auth/login_screen.dart` - Login UI
- `lib/features/auth/register_screen.dart` - Register UI

**PROFILE:**
- `lib/features/profile/user_profile_repository.dart` - Profile CRUD
- `lib/features/profile/profile_screen.dart` - Edit profile
- `lib/features/profile/public_profile_page.dart` - View profile

**FOLLOW:**
- `lib/features/follow/repositories/follow_repository.dart` - Follow operations
- `lib/features/follow/services/follow_service.dart` - Follow logic
- `lib/features/follow/models/follow_request.dart` - Follow request model

**POSTS:**
- `lib/features/posts/models/post.dart` - Post model
- `lib/features/posts/repositories/post_repository.dart` - Post CRUD
- `lib/features/posts/services/post_service.dart` - Post business logic
- `lib/features/posts/pages/post_feed_page.dart` - Feed UI
- `lib/features/posts/pages/post_create_page.dart` - Create post UI
- `lib/features/posts/pages/post_permalink_page.dart` - Post detail
- `lib/features/posts/pages/hashtag_page.dart` - Hashtag feed
- `lib/features/posts/pages/drafts_and_scheduled_page.dart` - Drafts & scheduling

**CHAT:**
- `lib/features/chat/models/message.dart` - Message model
- `lib/features/chat/repositories/chat_repository.dart` - Chat operations
- `lib/features/chat/services/conversation_service.dart` - Conversation logic
- `lib/features/chat/pages/conversations_page.dart` - Conversations list
- `lib/features/chat/pages/chat_detail_page.dart` - Chat screen
- `lib/features/chat/pages/create_group_page.dart` - Create group

**NOTIFICATIONS:**
- `lib/features/notifications/models/notification.dart` - Notification model
- `lib/features/notifications/repositories/notification_repository.dart`
- `lib/features/notifications/services/notification_service.dart`
- `lib/features/notifications/pages/notification_center_page.dart`
- `lib/features/notifications/pages/notification_digest_page.dart`

**ADMIN:**
- `lib/features/admin/models/ban.dart` - Ban model
- `lib/features/admin/repositories/ban_repository.dart`
- `lib/features/admin/pages/admin_dashboard_page.dart`
- `lib/features/admin/pages/user_ban_screen.dart`

**SAFETY:**
- `lib/features/safety/models/block_entry.dart` - Block model
- `lib/features/safety/models/report.dart` - Report model
- `lib/features/safety/repositories/block_repository.dart`
- `lib/features/safety/repositories/report_repository.dart`

**CALLS:**
- `lib/features/call/services/webrtc_service.dart` - WebRTC integration
- `lib/features/call/pages/video_call_page.dart` - Video call UI
- `lib/features/call/pages/voice_call_page.dart` - Voice call UI

**SEARCH:**
- `lib/features/search/pages/search_page.dart` - Search UI
- `lib/features/search/services/search_service.dart` - Search logic

**SAVED POSTS:**
- `lib/features/saved_posts/repositories/saved_posts_repository.dart`
- `lib/features/saved_posts/pages/saved_posts_page.dart`

**SETTINGS:**
- `lib/features/settings/pages/privacy_settings_page.dart` - Privacy settings

**SHARE:**
- `lib/features/share/services/deep_link_service.dart` - Deep linking
- `lib/features/share/services/share_service.dart` - Share functionality

**STORIES:**
- `lib/features/stories/models/story.dart` - Story model
- `lib/features/stories/repositories/story_repository.dart`

#### 1.5 Security & Configuration:
- **firebase/firestore.rules** - Security rules (rất quan trọng!)
- **firebase/firestore.indexes.json** - Database indexes

---

### Bước 2: Phân tích từng layer

#### 2.1 Models Layer:
- Đọc tất cả file trong `models/` của mỗi feature
- Hiểu cấu trúc dữ liệu: fields, types, factory methods (fromDoc, toMap)
- Ví dụ: `Post`, `Message`, `Notification`, `UserProfile`

#### 2.2 Repositories Layer:
- Đọc tất cả file trong `repositories/`
- Hiểu cách tương tác với Firestore:
  - CRUD operations
  - Queries với filters, pagination
  - Realtime streams (StreamBuilder)
- Pattern: Mỗi repository có methods như:
  - `create()`, `update()`, `delete()`
  - `fetch()`, `watch()` (realtime)
  - `query()` với filters

#### 2.3 Services Layer:
- Đọc tất cả file trong `services/`
- Hiểu business logic:
  - Kết hợp nhiều repositories
  - Upload media lên Cloudinary
  - Validation, error handling
  - Notification creation

#### 2.4 Pages/UI Layer:
- Đọc tất cả file trong `pages/`
- Hiểu UI implementation:
  - StatefulWidget vs StatelessWidget
  - StreamBuilder cho realtime updates
  - Navigation, routing
  - User interactions

---

### Bước 3: Phân tích các tính năng chính

#### Tính năng 1: Authentication System
**Files cần đọc:**
- `lib/features/auth/*`
- `lib/main.dart` (Firebase initialization)

**Phân tích:**
- Email/Password authentication
- Google Sign-In
- Email verification
- Auth state management
- Route protection (AuthGate)

#### Tính năng 2: Posts & Feed System
**Files cần đọc:**
- `lib/features/posts/*` (tất cả)
- `lib/services/cloudinary_service.dart`

**Phân tích:**
- Tạo post với multiple media
- Upload lên Cloudinary
- Feed với infinite scroll
- Like/Comment realtime
- Hashtags extraction & display
- Post scheduling & drafts
- Pinned posts
- Post deletion

#### Tính năng 3: Chat System
**Files cần đọc:**
- `lib/features/chat/*` (tất cả)
- `docs/firestore_schema.md` (messages schema)

**Phân tích:**
- Direct messages (1-1)
- Group chat
- Text, Image, Voice, Video messages
- Typing indicator
- Seen status
- Message search
- Reactions
- Mute conversations

#### Tính năng 4: Follow System
**Files cần đọc:**
- `lib/features/follow/*`
- `lib/features/contacts/*`

**Phân tích:**
- Follow/Unfollow
- Private profiles
- Follow requests
- Accept/Reject requests
- Followers/Following lists

#### Tính năng 5: Notification System
**Files cần đọc:**
- `lib/features/notifications/*` (tất cả)

**Phân tích:**
- Notification types (like, comment, follow, message)
- Notification grouping
- Notification digest
- Real-time updates
- Badge counts

#### Tính năng 6: Safety & Admin
**Files cần đọc:**
- `lib/features/safety/*`
- `lib/features/admin/*`

**Phân tích:**
- Block users
- Report posts/users
- Admin dashboard
- Ban/Unban users
- Appeal system

#### Tính năng 7: Advanced Features
**Files cần đọc:**
- `lib/features/search/*`
- `lib/features/saved_posts/*`
- `lib/features/settings/*`
- `lib/features/share/*`
- `lib/features/call/*`
- `lib/features/stories/*`

**Phân tích:**
- Search users & posts
- Saved posts (bookmarks)
- Privacy settings
- Deep linking
- Video/Voice calls (WebRTC)
- Stories (24h posts)

---

### Bước 4: Phân tích Database Schema

**File quan trọng:** `docs/firestore_schema.md`

**Collections chính:**
1. `user_profiles/{uid}` - User profiles
2. `posts/{postId}` - Posts
3. `posts/{postId}/likes/{uid}` - Likes
4. `posts/{postId}/comments/{commentId}` - Comments
5. `conversations/{conversationId}` - Conversations
6. `conversations/{conversationId}/messages/{messageId}` - Messages
7. `follow_requests/{targetUid}/requests/{followerUid}` - Follow requests
8. `notifications/{notificationId}` - Notifications
9. `blocks/{blockerUid}/items/{blockedUid}` - Blocks
10. `reports/{reportId}` - Reports
11. `bans/{banId}` - Bans
12. `saved_posts/{uid}/items/{postId}` - Saved posts

**Phân tích:**
- Cấu trúc từng collection
- Relationships giữa collections
- Indexes cần thiết
- Security rules

---

### Bước 5: Phân tích Security

**File:** `firebase/firestore.rules`

**Phân tích:**
- Authentication requirements
- Authorization rules
- Field validation
- Ownership checks
- Collection group rules

---

## 📝 YÊU CẦU VỀ BÁO CÁO 40 TRANG

### Cấu trúc báo cáo đề xuất:

#### **PHẦN 1: GIỚI THIỆU (3-4 trang)**
1.1. Tổng quan dự án
1.2. Mục tiêu và phạm vi
1.3. Công nghệ sử dụng
1.4. Cấu trúc báo cáo

#### **PHẦN 2: PHÂN TÍCH KIẾN TRÚC (5-6 trang)**
2.1. Kiến trúc tổng thể
2.2. Feature-based architecture
2.3. Repository Pattern
2.4. Service Layer Pattern
2.5. State Management
2.6. Dependency Injection (nếu có)

#### **PHẦN 3: PHÂN TÍCH DATABASE (4-5 trang)**
3.1. Firestore Schema
3.2. Collections và cấu trúc
3.3. Relationships
3.4. Indexes
3.5. Security Rules
3.6. Data flow

#### **PHẦN 4: PHÂN TÍCH TỪNG MODULE (20-22 trang)**

**4.1. Authentication Module (2 trang)**
- Email/Password auth
- Google Sign-In
- Email verification
- Auth state management

**4.2. Profile & Follow Module (2-3 trang)**
- User profiles
- Follow/Unfollow system
- Private profiles
- Follow requests

**4.3. Posts & Feed Module (4-5 trang)**
- Post creation với media
- Cloudinary integration
- Feed với pagination
- Like/Comment system
- Hashtags
- Post scheduling
- Pinned posts

**4.4. Chat Module (3-4 trang)**
- Direct messages
- Group chat
- Message types (text, image, voice, video)
- Typing indicator
- Seen status
- Reactions
- Message search

**4.5. Notification Module (2 trang)**
- Notification types
- Grouping logic
- Digest system
- Real-time updates

**4.6. Safety & Admin Module (2 trang)**
- Block system
- Report system
- Admin dashboard
- Ban/Unban system

**4.7. Advanced Features (3-4 trang)**
- Search functionality
- Saved posts
- Privacy settings
- Deep linking
- Video/Voice calls
- Stories

#### **PHẦN 5: TÍCH HỢP VÀ SERVICES (3-4 trang)**
5.1. Firebase Integration
5.2. Cloudinary Integration
5.3. WebRTC Integration
5.4. Deep Link Service
5.5. Error Handling

#### **PHẦN 6: UI/UX DESIGN (2-3 trang)**
6.1. Material Design 3
6.2. Navigation structure
6.3. Realtime UI updates
6.4. Loading states
6.5. Error states
6.6. Empty states

#### **PHẦN 7: PERFORMANCE & OPTIMIZATION (2-3 trang)**
7.1. Pagination strategies
7.2. Image optimization
7.3. Caching strategies
7.4. Query optimization
7.5. Realtime updates optimization

#### **PHẦN 8: SECURITY (2-3 trang)**
8.1. Authentication security
8.2. Firestore security rules
8.3. Data validation
8.4. Privacy controls
8.5. Content moderation

#### **PHẦN 9: TESTING & QUALITY ASSURANCE (1-2 trang)**
9.1. Code structure
9.2. Error handling
9.3. Testing strategies (nếu có)
9.4. Code quality

#### **PHẦN 10: KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN (2-3 trang)**
10.1. Tổng kết
10.2. Điểm mạnh
10.3. Điểm cần cải thiện
10.4. Hướng phát triển tương lai

---

## 🎯 HƯỚNG DẪN VIẾT BÁO CÁO

### Nguyên tắc viết:

1. **Chi tiết và cụ thể:**
   - Mô tả rõ cách mỗi tính năng hoạt động
   - Giải thích code flow
   - Đưa ra ví dụ code khi cần

2. **Có cấu trúc:**
   - Sử dụng headings, subheadings rõ ràng
   - Numbering cho các phần
   - Tables cho so sánh, thống kê

3. **Có hình ảnh/diagram (nếu có thể):**
   - Architecture diagram
   - Database schema diagram
   - Flow charts
   - Sequence diagrams

4. **Phân tích sâu:**
   - Không chỉ mô tả "là gì" mà còn "tại sao"
   - So sánh với các approach khác
   - Đánh giá ưu/nhược điểm

5. **Code examples:**
   - Trích dẫn code quan trọng
   - Giải thích logic
   - Show patterns được sử dụng

6. **Thống kê và số liệu:**
   - Số lượng files
   - Số lượng tính năng
   - Số dòng code (ước tính)
   - Dependencies

### Format báo cáo:

- **Ngôn ngữ:** Tiếng Việt
- **Font:** Times New Roman hoặc Arial
- **Font size:** 12pt
- **Line spacing:** 1.5
- **Margins:** 2.5cm mỗi bên
- **Số trang:** 40 trang (khoảng 15,000-20,000 từ)
- **Có mục lục, danh sách hình ảnh, danh sách bảng**

---

## 📊 THỐNG KÊ CẦN THU THẬP

Khi phân tích, hãy thu thập các số liệu sau:

1. **Tổng số files:**
   - Models: ~30+ files
   - Repositories: ~20+ files
   - Services: ~15+ files
   - Pages: ~40+ files
   - Widgets: ~10+ files

2. **Tổng số tính năng:** ~35+ tính năng chính

3. **Dependencies:** Xem `pubspec.yaml`

4. **Database collections:** ~12+ collections chính

5. **Security rules:** Xem `firebase/firestore.rules`

---

## 🔑 CÁC ĐIỂM QUAN TRỌNG CẦN NHẤN MẠNH

1. **Kiến trúc rõ ràng:** Feature-based, tách biệt layers
2. **Realtime updates:** Sử dụng Firestore streams
3. **Security:** Firestore rules chi tiết
4. **Scalability:** Pagination, indexing
5. **User experience:** Loading states, error handling
6. **Media handling:** Cloudinary integration
7. **Advanced features:** Scheduling, grouping, digest

---

## 📚 TÀI LIỆU THAM KHẢO TRONG DỰ ÁN

Khi phân tích, hãy đọc các file này để hiểu context:

1. **README.md** - Setup và overview
2. **TASK_LIST.md** - Chi tiết tất cả tính năng
3. **docs/firestore_schema.md** - Database schema
4. **docs/deploy_guide.md** - Deployment
5. **BAO_CAO_TIEN_DO_10_TUAN.md** - Progress report
6. **firebase/firestore.rules** - Security rules

---

## ✅ CHECKLIST TRƯỚC KHI HOÀN THÀNH BÁO CÁO

- [ ] Đã đọc và hiểu tất cả các file quan trọng
- [ ] Đã phân tích đầy đủ các tính năng
- [ ] Đã hiểu kiến trúc và patterns
- [ ] Đã thu thập đủ số liệu thống kê
- [ ] Báo cáo đủ 40 trang (15,000-20,000 từ)
- [ ] Có mục lục, hình ảnh, bảng biểu
- [ ] Code examples được giải thích rõ ràng
- [ ] Có phân tích ưu/nhược điểm
- [ ] Có kết luận và hướng phát triển
- [ ] Format đúng yêu cầu

---

## 🚀 BẮT ĐẦU PHÂN TÍCH

Bây giờ bạn đã có đủ thông tin. Hãy bắt đầu:

1. **Đọc các file tổng quan** (README, TASK_LIST, schema)
2. **Phân tích từng feature** theo thứ tự
3. **Thu thập thông tin** và ghi chú
4. **Viết báo cáo** theo cấu trúc đã đề xuất
5. **Review và chỉnh sửa** để đảm bảo chất lượng

**Lưu ý:** Hãy phân tích sâu, không chỉ mô tả bề mặt. Giải thích "tại sao" và "như thế nào", không chỉ "là gì".

---

**Chúc bạn thành công! 🎉**

