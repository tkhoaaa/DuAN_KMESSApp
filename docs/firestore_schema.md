# Firestore Schema Overview

Tài liệu này mô tả cấu trúc dữ liệu sẽ được sử dụng trong Firestore cho ứng dụng KMESS. Mục tiêu là chuẩn hoá cách lưu trữ để tránh nhầm lẫn trong quá trình phát triển các tính năng chat, bạn bè, trạng thái online/offline.

## 1. `user_profiles` (collection)

**Path:** `user_profiles/{uid}`

| Trường            | Kiểu dữ liệu          | Ghi chú                                                     |
|-------------------|-----------------------|--------------------------------------------------------------|
| `displayName`     | `string`              | Tên hiển thị; có thể rỗng                                    |
| `displayNameLower`| `string`              | Tên hiển thị viết thường (phục vụ tìm kiếm)                 |
| `photoUrl`        | `string`              | URL ảnh đại diện (Firebase Storage)                          |
| `phoneNumber`     | `string`              | Số điện thoại; để trống nếu chưa có                          |
| `email`           | `string`              | Email đã đăng ký                                             |
| `emailLower`      | `string`              | Email viết thường (phục vụ tìm kiếm)                         |
| `bio`             | `string`              | Tiểu sử ngắn của người dùng                                  |
| `isPrivate`       | `boolean`             | Tài khoản riêng tư (cần chấp nhận yêu cầu theo dõi)          |
| `followersCount`  | `number`              | Tổng số người theo dõi                                        |
| `followingCount`  | `number`              | Tổng số đang theo dõi                                         |
| `postsCount`      | `number`              | Tổng số bài đăng (mặc định 0)                                |
| `isOnline`        | `boolean`             | Đánh dấu trạng thái hiện tại                                 |
| `lastSeen`        | `timestamp`           | Lưu thời điểm offline gần nhất (cập nhật khi setOffline)     |
| `typingIn`        | `array<string>`       | Danh sách conversationId mà user đang gõ (dùng optional)     |
| `createdAt`       | `timestamp`           | Server timestamp lúc tạo                                     |
| `updatedAt`       | `timestamp`           | Server timestamp khi cập nhật hồ sơ                          |

**Ghi chú:**
- Trạng thái `isOnline`/`lastSeen` cập nhật mỗi lần user login/logout.
- Khi user bắt đầu gõ trong conversation, thêm conversationId vào `typingIn`; khi dừng gõ thì xoá.

## 2. Follow system

### 2.1 `followers`

**Path:** `user_profiles/{uid}/followers/{followerUid}`

| Trường      | Kiểu dữ liệu | Ghi chú                                |
|-------------|--------------|-----------------------------------------|
| `followedAt`| `timestamp`  | Thời điểm follower bắt đầu theo dõi     |

### 2.2 `following`

**Path:** `user_profiles/{uid}/following/{targetUid}`

| Trường      | Kiểu dữ liệu | Ghi chú                                |
|-------------|--------------|-----------------------------------------|
| `followedAt`| `timestamp`  | Thời điểm bắt đầu theo dõi người khác   |

### 2.3 `follow_requests`

**Path:** `follow_requests/{targetUid}/requests/{followerUid}`

| Trường      | Kiểu dữ liệu | Ghi chú                                  |
|-------------|--------------|-------------------------------------------|
| `fromUid`   | `string`     | UID người gửi yêu cầu                     |
| `createdAt` | `timestamp`  | Thời điểm gửi yêu cầu                     |

- Các tài khoản private nhận yêu cầu ở subcollection này. Khi chấp nhận: xoá request, thêm record vào `followers`/`following`, đồng thời cập nhật `followersCount`/`followingCount`.
- Có thể sử dụng `collectionGroup('requests')` để truy vấn các yêu cầu đã gửi theo `fromUid`.

## 3. `posts` (collection)

**Path:** `posts/{postId}`

| Trường          | Kiểu dữ liệu | Ghi chú                                         |
|-----------------|--------------|-------------------------------------------------|
| `authorUid`     | `string`     | UID người đăng                                  |
| `media`         | `array<map>` | Danh sách media `{ url, type, thumbnailUrl?, durationMs? }` (`type`: `image`/`video`) |
| `caption`       | `string`     | Chú thích bài đăng (có thể rỗng)                |
| `createdAt`     | `timestamp`  | Thời điểm đăng bài                              |
| `likeCount`     | `number`     | Tổng số lượt thích                              |
| `commentCount`  | `number`     | Tổng số bình luận                               |

### 3.1 `likes`

**Path:** `posts/{postId}/likes/{uid}`

| Trường      | Kiểu dữ liệu | Ghi chú                               |
|-------------|--------------|----------------------------------------|
| `likedAt`   | `timestamp`  | Thời điểm người dùng nhấn thích       |

### 3.2 `comments`

**Path:** `posts/{postId}/comments/{commentId}`

| Trường      | Kiểu dữ liệu | Ghi chú                               |
|-------------|--------------|----------------------------------------|
| `authorUid` | `string`     | UID người bình luận                    |
| `text`      | `string`     | Nội dung bình luận                     |
| `createdAt` | `timestamp`  | Thời điểm bình luận                    |

## 4. `conversations` (collection)

**Path:** `conversations/{conversationId}`

| Trường            | Kiểu dữ liệu            | Ghi chú                                                                     |
|-------------------|-------------------------|------------------------------------------------------------------------------|
| `type`            | `string`               | `direct` (1-1) hoặc `group`                                                 |
| `participantIds`  | `array<string>`        | Danh sách UID của các thành viên (dùng để query direct với 2 thành viên)    |
| `createdBy`       | `string`               | UID người tạo conversation                                                  |
| `createdAt`       | `timestamp`            | Thời điểm tạo                                                               |
| `lastMessage`     | `map`                  | `{ text, senderId, createdAt }` phục vụ danh sách hội thoại                 |
| `name`            | `string`               | Tên nhóm (nếu type = group)                                                 |
| `avatarUrl`       | `string`               | Ảnh nhóm (nếu type = group)                                                 |
| `updatedAt`       | `timestamp`            | Cập nhật mỗi lần có tin nhắn mới                                             |

### 4.1 `participants` (subcollection)

**Path:** `conversations/{conversationId}/participants/{uid}`

| Trường         | Kiểu dữ liệu | Ghi chú                                                  |
|----------------|--------------|-----------------------------------------------------------|
| `role`         | `string`     | `member`, `admin`, ...                                    |
| `joinedAt`     | `timestamp`  | Khi tham gia conversation                                |
| `lastReadAt`   | `timestamp`  | Thời điểm đọc tin nhắn cuối                              |
| `notificationsEnabled` | `boolean` | Bật/tắt notifications cho conversation            |

## 5. `messages` (subcollection)

**Path:** `conversations/{conversationId}/messages/{messageId}`

| Trường           | Kiểu dữ liệu            | Ghi chú                                                                 |
|------------------|-------------------------|-------------------------------------------------------------------------|
| `senderId`       | `string`                | UID người gửi                                                          |
| `type`           | `string`                | `text`, `image`, `file`, `system`…                                      |
| `text`           | `string` (nullable)     | Nội dung text nếu type=text                                             |
| `attachments`    | `array<map>`            | `{ url, name, size, mimeType }` cho ảnh/file                            |
| `createdAt`      | `timestamp`             | Server timestamp                                                       |
| `status`         | `string`                | `sent`, `delivered`, `seen` (có thể mở rộng)                            |
| `seenBy`         | `array<string>`         | UID đã xem tin nhắn (phục vụ read receipts)                             |
| `replyTo`        | `string`                | `messageId` được reply (optional)                                       |
| `systemPayload`  | `map`                   | Dữ liệu phụ cho type=system                                             |

**Index đề xuất:**
- Composite index: `messages` orderBy `createdAt` + filter `type` (nếu cần).
- For conversations list: index `conversations` orderBy `updatedAt` desc.

## 6. `typing_status` (collection) – tuỳ chọn

Nếu không muốn lưu `typingIn` trong `user_profiles`, có thể dùng collection riêng:

**Path:** `typing_status/{conversationId}_{uid}`

| Trường       | Kiểu dữ liệu | Ghi chú                               |
|--------------|--------------|----------------------------------------|
| `conversationId` | `string` |                                         |
| `uid`         | `string`    |                                         |
| `expiresAt`   | `timestamp` | Firestore TTL cho biết khi nào hết typing |

+ Cần thiết lập TTL index để tự xóa document khi hết hạn.

## 7. Quy tắc bảo mật cơ bản (định hướng)

- `user_profiles/{uid}`: chỉ chủ sở hữu (request.auth.uid == uid) hoặc người được cấp quyền đọc mới được truy cập. Cho phép tất cả người dùng đã đăng nhập đọc tên/avatar, nhưng chỉ chủ sở hữu được ghi.
- `conversations/{conversationId}`: chỉ participant được đọc/ghi. Việc thêm thành viên mới cần kiểm tra quyền admin.
- `messages` subcollection: chỉ participant được đọc; chỉ sender hoặc server logic được sửa/xoá.
- `followers`/`following` subcollections: chỉ chủ sở hữu hoặc người được theo dõi được cập nhật; `follow_requests` chỉ owner đọc/ghi.
- `posts` collection: chỉ author được sửa/xoá bài đăng của mình. Likes/comments được tạo bởi người dùng đã đăng nhập.

### 7.1 Gợi ý rules chi tiết cho posts/likes/comments

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(resource) {
      return isSignedIn() && resource.data.authorUid == request.auth.uid;
    }

    match /posts/{postId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.resource.data.keys().hasOnly([
        'authorUid', 'media', 'caption', 'createdAt', 'likeCount', 'commentCount'
      ]) && request.resource.data.authorUid == request.auth.uid;
      allow update, delete: if isOwner(resource);

      match /likes/{uid} {
        allow read: if isSignedIn();
        allow create: if isSignedIn() && request.auth.uid == uid;
        allow delete: if isSignedIn() && request.auth.uid == uid;
      }

      match /comments/{commentId} {
        allow read: if isSignedIn();
        allow create: if isSignedIn()
          && request.resource.data.authorUid == request.auth.uid
          && request.resource.data.text is string
          && request.resource.data.createdAt == request.time;
        allow delete: if isSignedIn() &&
          (request.auth.uid == resource.data.authorUid || isOwner(get(/databases/$(database)/documents/posts/$(postId))));
        allow update: if false; // không cho sửa comment để tránh giả mạo
      }
    }
  }
}
```

> 📄 **Lưu ý**: Repo đã kèm file mẫu `firebase/firestore.rules` để có thể copy sang Firebase Console.

**Giải thích nhanh:**
- Bài đăng (`posts`) chỉ cho phép tác giả tạo/sửa/xoá. Khi tạo, bắt buộc trường `authorUid` khớp `request.auth.uid` và giới hạn danh sách field nhằm chống ghi tuỳ ý.
- `likes` chỉ cho phép chủ like tạo/xoá document cùng UID (tránh double-like).
- `comments` yêu cầu người gửi đăng nhập, không cho sửa, chỉ cho phép xoá bởi tác giả comment hoặc chủ bài đăng.
- Tất cả route yêu cầu `request.auth != null` để tránh truy cập ẩn danh.

### 7.2 Cloud Functions & thông báo đẩy

- **Bình luận mới / lượt thích mới:** Trigger Cloud Functions `onCreate` trên `posts/{postId}/comments/{commentId}` và `likes` để gửi thông báo FCM/Push tới tác giả bài đăng.
- **Cập nhật bảng tin:** Có thể tạo function xử lý tạo thumbnail video, giới hạn kích thước, hoặc scan nội dung.
- **Dọn dẹp dữ liệu:** Hàm định kỳ để xoá comment/like spam hoặc resets `postsCount` nếu lệch.

## 8. Seed và migration

- Khi người dùng mới đăng ký: gọi `userProfileRepository.ensureProfile` để tạo document `user_profiles/{uid}`.
- Khi tạo conversation direct: tìm conversation với `participantIds` chứa đúng 2 uid. Nếu chưa có, tạo mới với `type=direct`.
- Tin nhắn: dùng `add` vào subcollection `messages`; cập nhật `conversations/{conversationId}` với `lastMessage`, `updatedAt`.
- Presence: khi user online, set `isOnline=true`, clear `lastSeen`. Khi offline (app background/đăng xuất), set `isOnline=false`, `lastSeen=now`.

## 9. Các index cần cấu hình

| Collection / Subcollection                 | Điều kiện                                         |
|-------------------------------------------|---------------------------------------------------|
| `conversations`                           | `orderBy updatedAt DESC`                          |
| `conversations`                           | `where participantIds array-contains UID` + `orderBy updatedAt DESC` |
| `messages` (per conversation)             | `orderBy createdAt ASC`                           |
| `messages` (per conversation)             | `where type == 'text'` + `orderBy createdAt DESC` (tuỳ nhu cầu) |
| `user_profiles`                           | `orderBy displayName` (cho chức năng tìm kiếm đơn giản) |

> Lưu ý: với subcollection `messages`, Firestore sẽ cần index riêng cho từng combination. Tạo index khi gặp thông báo lỗi từ Firestore console.

## 10. Lộ trình phát triển liên quan

1. Cài đặt `ChatRepository` sử dụng cấu trúc trên (tạo conversation, gửi/nhận message).
2. Thiết kế UI danh sách hội thoại và màn chat chi tiết.
3. Hoàn thiện follow/follower (danh sách, đề xuất, xử lý yêu cầu).
4. Xây dựng post feed (upload media, like/comment).
5. Bổ sung Cloud Functions:
   - Push notification khi có message/bình luận mới.
   - Cleanup dữ liệu (TTL typing, lastSeen).
6. Viết Security Rules dựa trên mô tả ở mục 6.

---

Tài liệu sẽ tiếp tục được cập nhật khi mô hình dữ liệu thay đổi trong quá trình phát triển.

