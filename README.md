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
firebase deploy --only firestore:rules

- **[docs/deploy_guide.md](docs/deploy_guide.md)**: Hướng dẫn chi tiết deploy Firestore Rules và Cloud Functions, kiểm tra bảo mật.
- **[docs/setup_storage.md](docs/setup_storage.md)**: Hướng dẫn setup Firebase Storage (bắt buộc cho tính năng upload ảnh/video).
- **[docs/storage_alternatives.md](docs/storage_alternatives.md)**: So sánh các giải pháp storage miễn phí (Base64, Cloudinary, Firebase Storage).
- **[docs/cloudinary_setup_guide.md](docs/cloudinary_setup_guide.md)**: Hướng dẫn setup Cloudinary (25GB free tier) - **Khuyến nghị cho dự án nhỏ**.
- **[docs/FIREBASE_VS_CLOUDINARY.md](docs/FIREBASE_VS_CLOUDINARY.md)**: So sánh Firebase vs Cloudinary - **Đọc để hiểu rõ vai trò từng dịch vụ**.
- **[docs/base64_storage_guide.md](docs/base64_storage_guide.md)**: Hướng dẫn lưu ảnh dạng Base64 trong Firestore (miễn phí, có giới hạn).
- **[docs/NO_STORAGE_GUIDE.md](docs/NO_STORAGE_GUIDE.md)**: Hướng dẫn chạy app không cần Storage (tạm thời bỏ upload).
- **firebase/firestore.rules**: Security rules cho posts, likes, comments (yêu cầu `request.auth`, giới hạn field, quyền sở hữu).
- **functions/**: Cloud Functions TypeScript (thông báo like/comment, đồng bộ `postsCount`).

> 💡 **Lưu ý về Storage:** App có tính năng upload ảnh/video nên cần storage. 
> - **Cloudinary (Khuyến nghị):** 25GB free tier, không cần upgrade plan. **Chỉ thay thế Firebase Storage**, vẫn cần Firebase cho Auth + Firestore. Xem [docs/cloudinary_setup_guide.md](docs/cloudinary_setup_guide.md).
> - **Firebase Storage:** 5GB free tier, cần Blaze plan. Xem [docs/storage_alternatives.md](docs/storage_alternatives.md).
> **Hiểu rõ:** Cloudinary chỉ thay Firebase Storage, Firebase vẫn cần cho Authentication và Firestore. Xem [docs/FIREBASE_VS_CLOUDINARY.md](docs/FIREBASE_VS_CLOUDINARY.md).

## Thống kê chức năng

### Tổng số chức năng CRUD: **196 operations**
- **Create**: 39 operations
- **Read**: 94 operations
- **Update**: 39 operations
- **Delete**: 24 operations

### Tổng số chức năng không phải CRUD: **~80+ operations**
- **Services**: ~60 operations (business logic, data transformation, validation)
- **Helper Methods**: ~10 operations (utilities trong repositories)
- **Utilities**: ~10 operations (format, normalization, deep linking)

## Chức năng CRUD

Dự án có **19 repositories** với tổng cộng **196 CRUD operations**. Dưới đây là danh sách đầy đủ với code logic:

### 1. AuthRepository
**File:** [`lib/features/auth/auth_repository.dart`](lib/features/auth/auth_repository.dart)

**Create (6):**
- **Đăng ký bằng email** - `registerWithEmail(email, password)`: Đăng ký tài khoản mới với email/password
  ```dart
  Future<void> registerWithEmail(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);
  ```
- **Đăng nhập bằng email** - `signInWithEmail(email, password)`: Đăng nhập với email/password
  ```dart
  Future<void> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);
  ```
- **Đăng nhập bằng Google** - `signInWithGoogle()`: Đăng nhập bằng Google (OAuth), tự động tạo/update profile
  ```dart
  Future<void> signInWithGoogle() async {
    final user = await _google.signIn();
    final auth = await user.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    await _auth.signInWithCredential(credential);
    // Auto-create/update profile
    await userProfileRepository.ensureProfile(...);
  }
  ```
- **Đăng nhập bằng Facebook** - `signInWithFacebook()`: Đăng nhập bằng Facebook (OAuth), tự động tạo/update profile
  ```dart
  Future<void> signInWithFacebook() async {
    final result = await FacebookAuth.instance.login();
    final credential = FacebookAuthProvider.credential(result.accessToken.tokenString);
    await _auth.signInWithCredential(credential);
    // Auto-create/update profile với thông tin từ Facebook
    await userProfileRepository.ensureProfile(...);
  }
  ```
- **Bắt đầu xác thực số điện thoại** - `startPhoneVerification(phoneNumber, callbacks)`: Bắt đầu xác thực số điện thoại (SMS)
  ```dart
  Future<void> startPhoneVerification({required String phoneNumber, ...}) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onCompleted,
      verificationFailed: onError,
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (verificationId) => onTimeout(verificationId),
    );
  }
  ```
- **Xác nhận mã SMS** - `confirmSmsCode(verificationId, smsCode)`: Xác nhận mã SMS và đăng nhập
  ```dart
  Future<void> confirmSmsCode({required String verificationId, required String smsCode}) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _auth.signInWithCredential(credential);
  }
  ```

**Read (2):**
- **Theo dõi trạng thái đăng nhập** - `authState()`: Stream trạng thái đăng nhập (User?)
  ```dart
  Stream<User?> authState() => _auth.authStateChanges();
  ```
- **Lấy người dùng hiện tại** - `currentUser()`: Lấy user hiện tại (User?)
  ```dart
  User? currentUser() => _auth.currentUser;
  ```

**Update (5):**
- **Đổi mật khẩu** - `changePassword(currentPassword, newPassword)`: Đổi mật khẩu (cần re-authenticate)
  ```dart
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }
  ```
- **Gửi email đặt lại mật khẩu** - `sendPasswordResetEmail(email)`: Gửi email reset mật khẩu
  ```dart
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
  ```
- **Xác nhận đặt lại mật khẩu** - `confirmPasswordReset(code, newPassword)`: Xác nhận reset mật khẩu với code
  ```dart
  Future<void> confirmPasswordReset(String code, String newPassword) async {
    await _auth.confirmPasswordReset(code: code, newPassword: newPassword);
  }
  ```
- **Gửi email xác thực** - `sendEmailVerification()`: Gửi email xác thực tài khoản
  ```dart
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }
  ```
- **Tải lại thông tin người dùng** - `reloadCurrentUser()`: Reload thông tin user từ server
  ```dart
  Future<void> reloadCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
    }
  }
  ```

**Delete (1):**
- **Đăng xuất** - `signOut()`: Đăng xuất (sign out cả Google Sign-In và Firebase Auth)
  ```dart
  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }
  ```

### 2. PostRepository
**File:** [`lib/features/posts/repositories/post_repository.dart`](lib/features/posts/repositories/post_repository.dart)

**Create (4):**
- **Tạo bài viết** - `createPost(authorUid, media, caption, scheduledAt)`: Tạo post mới (hỗ trợ scheduled), tự động extract hashtags, increment postsCount
  ```dart
  Future<String> createPost({required String authorUid, required List<Map<String, dynamic>> media, String? caption, DateTime? scheduledAt}) async {
    final doc = _posts.doc();
    final hashtags = extractHashtagsFromCaption(caption ?? '');
    final isScheduled = scheduledAt != null && scheduledAt.isAfter(DateTime.now());
    final status = isScheduled ? PostStatus.scheduled : PostStatus.published;
    
    await doc.set({
      'authorUid': authorUid,
      'media': media,
      'caption': caption ?? '',
      'hashtags': hashtags,
      'status': status.name,
      'createdAt': FieldValue.serverTimestamp(),
      'likeCount': 0,
      'commentCount': 0,
    });
    
    if (status == PostStatus.published) {
      await _firestore.collection('user_profiles').doc(authorUid).set({
        'postsCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    }
    return doc.id;
  }
  ```
- **Thêm bình luận** - `addComment(postId, authorUid, text, parentCommentId, replyToUid)`: Thêm comment (transaction, increment commentCount)
  ```dart
  Future<String> addComment({required String postId, required String authorUid, required String text, String? parentCommentId, String? replyToUid, int maxRetries = 3}) async {
    await _firestore.runTransaction((txn) async {
      final newCommentRef = commentsRef.doc();
      txn.set(newCommentRef, {
        'authorUid': authorUid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        if (parentCommentId != null) 'parentId': parentCommentId,
      });
      txn.update(postRef, {
        'commentCount': FieldValue.increment(1),
      });
    });
  }
  ```
- **Thích bài viết** - `likePost(postId, uid)`: Like post (transaction, increment likeCount, retry logic)
  ```dart
  Future<void> likePost({required String postId, required String uid, int maxRetries = 3}) async {
    await _firestore.runTransaction((txn) async {
      final likeSnap = await txn.get(likeRef);
      if (likeSnap.exists) return;
      txn.set(likeRef, {'likedAt': FieldValue.serverTimestamp()});
      txn.update(postRef, {'likeCount': FieldValue.increment(1)});
    });
  }
  ```
- **Thêm/xóa cảm xúc cho bình luận** - `setCommentReaction(postId, commentId, uid, reaction)`: Thêm/xóa reaction cho comment (emoji)
  ```dart
  Future<void> setCommentReaction({required String postId, required String commentId, required String uid, String? reaction}) async {
    await _firestore.runTransaction((txn) async {
      final currentReactionCounts = Map<String, int>.from(...);
      if (previousReaction != null) {
        currentReactionCounts[previousReaction] = (currentReactionCounts[previousReaction] ?? 1) - 1;
      }
      if (reaction != null) {
        currentReactionCounts[reaction] = (currentReactionCounts[reaction] ?? 0) + 1;
      }
      txn.update(commentRef, {'reactionCounts': currentReactionCounts});
    });
  }
  ```

**Read (16):**
- **Lấy danh sách bài viết** - `fetchPosts(startAfter, limit, includeScheduled)`: Lấy danh sách posts (pagination, filter published)
- **Lấy bài viết với bộ lọc** - `fetchPostsWithFilters(filters, startAfter, limit)`: Lấy posts với filters (media type, time range, sort option)
- **Theo dõi một bài viết** - `watchPost(postId)`: Stream một post cụ thể (realtime)
- **Theo dõi bài viết đã xuất bản** - `watchPublishedPosts(limit)`: Stream posts đã publish (realtime)
- **Theo dõi bình luận** - `watchComments(postId)`: Stream comments của post (realtime, limit 100)
- **Lấy bài viết theo tác giả** - `fetchPostsByAuthor(authorUid, startAfter, limit)`: Lấy posts theo tác giả (pagination)
- **Tìm kiếm bài viết** - `searchPosts(query, limit, startAfter)`: Tìm kiếm posts theo caption (prefix matching trên captionLower)
- **Theo dõi bài viết theo hashtag** - `watchPostsByHashtag(tag, limit, sortBy)`: Stream posts theo hashtag (realtime, sort by createdAt hoặc hot)
- **Lấy bài viết theo hashtag** - `fetchPostsByHashtag(tag, limit, startAfter, sortBy)`: Lấy posts theo hashtag (pagination)
- **Lấy hashtag đang thịnh hành** - `fetchTrendingHashtags(limit)`: Lấy trending hashtags (aggregate từ 100 posts gần nhất)
- **Lấy bài viết đã lên lịch** - `fetchScheduledPosts(authorUid, limit)`: Lấy scheduled posts của user
- **Kiểm tra đã thích** - `hasUserLikedPost(postId, uid)`: Kiểm tra user đã like chưa
- **Theo dõi trạng thái thích** - `watchUserLike(postId, uid)`: Stream trạng thái like của user (realtime)
- **Lấy một bình luận** - `getComment(postId, commentId)`: Lấy một comment cụ thể
- **Lấy lịch sử chỉnh sửa bình luận** - `getCommentEditHistory(postId, commentId)`: Stream lịch sử chỉnh sửa comment
- **Theo dõi tổng số cảm xúc** - `watchPostReactionCount(postId)`: Stream tổng số reactions trên tất cả comments của post

**Update (4):**
- **Chỉnh sửa bình luận** - `editComment(postId, commentId, newText, currentUid)`: Chỉnh sửa comment (lưu edit history, chỉ tác giả)
- **Xuất bản bài viết đã lên lịch** - `publishScheduledPost(postId, authorUid)`: Publish scheduled post (transaction, chuyển status, increment postsCount)
- **Hủy bài viết đã lên lịch** - `cancelScheduledPost(postId)`: Hủy scheduled post (chuyển status sang cancelled)
- **Cập nhật thời gian lên lịch** - `updateScheduledTime(postId, newScheduledAt)`: Cập nhật thời gian scheduled

**Delete (3):**
- **Xóa bài viết** - `deletePost(postId, authorUid)`: Xóa post (batch delete likes, comments, post, decrement postsCount, tự động gỡ khỏi pinnedPostIds)
- **Xóa bình luận** - `deleteComment(postId, commentId, currentUid)`: Xóa comment (transaction, chỉ tác giả hoặc chủ post, decrement commentCount)
- **Bỏ thích bài viết** - `unlikePost(postId, uid)`: Bỏ like (transaction, decrement likeCount, retry logic)

### 3. ChatRepository
**File:** [`lib/features/chat/repositories/chat_repository.dart`](lib/features/chat/repositories/chat_repository.dart)

**Create (8):**
- **Tạo hoặc lấy cuộc trò chuyện trực tiếp** - `createOrGetDirectConversation(currentUid, otherUid)`: Tạo hoặc lấy conversation 1-1 (tự động tìm existing, tạo participant entry)
- **Tạo nhóm trò chuyện** - `createGroupConversation(ownerUid, memberIds, name, avatarUrl, description)`: Tạo group chat (batch tạo participants, set owner làm admin)
- **Gửi tin nhắn văn bản** - `sendTextMessage(conversationId, senderId, text, attachments)`: Gửi tin nhắn text/media (batch update lastMessage, unreadCount)
- **Gửi tin nhắn hình ảnh** - `sendImageMessage(conversationId, senderId, attachments, text)`: Gửi tin nhắn hình ảnh (wrapper của sendTextMessage)
- **Gửi tin nhắn thoại** - `sendVoiceMessage(conversationId, senderId, attachments, text)`: Gửi voice message (wrapper của sendTextMessage)
- **Gửi tin nhắn video** - `sendVideoMessage(conversationId, senderId, attachments, text)`: Gửi video message (wrapper của sendTextMessage)
- **Thêm thành viên vào nhóm** - `addMembersToGroup(conversationId, requesterId, newMemberIds)`: Thêm thành viên vào group (transaction, chỉ admin, update participantIds và membersCount)
- **Đảm bảo entry người tham gia** - `ensureParticipantEntry(conversationId, uid, role)`: Đảm bảo participant entry tồn tại (tạo nếu chưa có)

**Read (7):**
- **Theo dõi danh sách cuộc trò chuyện** - `watchConversations(uid)`: Stream danh sách conversations (realtime, orderBy updatedAt)
- **Theo dõi tin nhắn** - `watchMessages(conversationId, limit)`: Stream tin nhắn (realtime, limit 50, reverse order)
- **Theo dõi số tin chưa đọc** - `watchUnreadCount(uid)`: Stream tổng số conversations có tin chưa đọc
- **Lấy danh sách ID người tham gia** - `fetchParticipantIds(conversationId)`: Lấy danh sách participantIds
- **Tìm kiếm tin nhắn** - `searchMessages(conversationId, searchTerm, limit)`: Tìm kiếm tin nhắn trong conversation (client-side filter)
- **Theo dõi cài đặt thông báo người tham gia** - `watchParticipantNotificationSettings(conversationId, uid)`: Stream notification settings của participant
- **Lấy cài đặt thông báo người tham gia** - `fetchParticipantNotificationSettings(conversationId, uid)`: Lấy notification settings (one-time)

**Update (7):**
- **Chỉnh sửa tin nhắn** - `editMessage(conversationId, messageId, newText)`: Chỉnh sửa tin nhắn (update text và editedAt trong systemPayload)
- **Thêm/xóa cảm xúc cho tin nhắn** - `toggleReaction(conversationId, messageId, uid, emoji)`: Thêm/xóa reaction cho tin nhắn (transaction, update reactions map)
- **Đánh dấu đã đọc** - `markConversationAsRead(conversationId, uid, limit)`: Đánh dấu đã đọc (batch update lastReadAt, unreadCount, seenBy)
- **Cập nhật thông tin nhóm** - `updateGroupInfo(conversationId, requesterId, name, avatarUrl, description)`: Cập nhật thông tin group (transaction, chỉ admin)
- **Thêm/gỡ quyền quản trị viên** - `setAdminForMember(conversationId, requesterId, targetUid, isAdmin)`: Thêm/gỡ quyền admin (transaction, đảm bảo luôn có ít nhất 1 admin)
- **Cập nhật cài đặt thông báo người tham gia** - `updateParticipantNotificationSettings(conversationId, uid, notificationsEnabled, mutedUntil)`: Cập nhật notification settings
- **Đặt trạng thái đang gõ** - `setTyping(uid, conversationId, isTyping)`: Đặt trạng thái đang gõ (update typingIn array trong user_profiles)

**Delete (3):**
- **Thu hồi tin nhắn** - `recallMessage(conversationId, messageId)`: Thu hồi tin nhắn (xóa nội dung, attachments, đánh dấu recalled)
- **Xóa thành viên khỏi nhóm** - `removeMemberFromGroup(conversationId, requesterId, targetUid)`: Xóa thành viên khỏi group (transaction, chỉ admin, không dùng cho chính mình)
- **Rời nhóm** - `leaveGroup(conversationId, uid)`: Thành viên rời group (transaction, tự động chuyển quyền admin nếu là admin cuối cùng)

### 4. FollowRepository
**File:** [`lib/features/follow/repositories/follow_repository.dart`](lib/features/follow/repositories/follow_repository.dart)

**Create (2):**
- **Theo dõi người dùng** - `followUser(followerUid, targetUid)`: Follow user (transaction, tạo entries trong followers/following, increment counters)
- **Gửi yêu cầu theo dõi** - `sendFollowRequest(followerUid, targetUid)`: Gửi yêu cầu follow (tạo trong follow_requests subcollection)

**Read (7):**
- **Theo dõi danh sách người theo dõi** - `watchFollowers(uid)`: Stream danh sách followers (realtime, orderBy followedAt)
- **Theo dõi danh sách đang theo dõi** - `watchFollowing(uid)`: Stream danh sách following (realtime, orderBy followedAt)
- **Theo dõi yêu cầu theo dõi đến** - `watchIncomingRequests(uid)`: Stream yêu cầu follow đến (realtime, orderBy createdAt)
- **Theo dõi yêu cầu theo dõi đã gửi** - `watchSentRequests(uid)`: Stream yêu cầu follow đã gửi (realtime, collection group query)
- **Kiểm tra đang theo dõi** - `isFollowing(currentUid, targetUid)`: Kiểm tra đang follow chưa
- **Kiểm tra có yêu cầu đang chờ** - `hasPendingRequest(currentUid, targetUid)`: Kiểm tra có yêu cầu follow đang chờ chưa
- **Lấy danh sách ID đang theo dõi** - `fetchFollowingIds(uid)`: Lấy Set UIDs đang follow

**Update (1):**
- **Chấp nhận yêu cầu theo dõi** - `acceptFollowRequest(targetUid, followerUid)`: Chấp nhận yêu cầu follow (transaction, xóa request, tạo follow relationship, increment counters)

**Delete (3):**
- **Bỏ theo dõi người dùng** - `unfollowUser(followerUid, targetUid)`: Unfollow (transaction, xóa entries, decrement counters)
- **Hủy yêu cầu theo dõi** - `cancelFollowRequest(followerUid, targetUid)`: Hủy yêu cầu follow đã gửi
- **Từ chối yêu cầu theo dõi** - `declineFollowRequest(targetUid, followerUid)`: Từ chối yêu cầu follow

### 5. UserProfileRepository
**File:** [`lib/features/profile/user_profile_repository.dart`](lib/features/profile/user_profile_repository.dart)

**Create (1):**
- **Đảm bảo hồ sơ tồn tại** - `ensureProfile(uid, email, phoneNumber, displayName, photoUrl, bio, isPrivate)`: Tạo hoặc update profile (merge, không overwrite displayName/photoUrl nếu đã có)

**Read (4):**
- **Theo dõi hồ sơ** - `watchProfile(uid)`: Stream profile (realtime)
- **Lấy hồ sơ** - `fetchProfile(uid)`: Lấy profile (one-time)
- **Tìm kiếm người dùng** - `searchUsers(query, limit)`: Tìm kiếm users (prefix matching trên displayNameLower, emailLower, phoneNumber)
- **Tìm kiếm người dùng với bộ lọc** - `searchUsersWithFilters(query, limit, isFollowing, isPrivate)`: Tìm kiếm với filters (privacy, follow status)

**Update (10):**
- **Cập nhật hồ sơ** - `updateProfile(uid, displayName, photoUrl, phoneNumber, removePhoto, bio, note, isPrivate, themeColor, links, showOnlineStatus, lastSeenVisibility, messagePermission)`: Cập nhật profile (merge, xóa field nếu cần)
- **Cập nhật cài đặt quyền riêng tư** - `updatePrivacySettings(uid, showOnlineStatus, lastSeenVisibility, messagePermission)`: Cập nhật privacy settings
- **Cập nhật trạng thái hiện diện** - `setPresence(uid, isOnline)`: Cập nhật trạng thái online/offline và lastSeen
- **Cập nhật bài viết đã ghim** - `updatePinnedPosts(uid, postIds)`: Cập nhật pinned posts (validate max 3, loại bỏ duplicate)
- **Cập nhật story đã ghim** - `updatePinnedStories(uid, storyIds)`: Cập nhật pinned stories (validate max 3)
- **Thêm bài viết đã ghim** - `addPinnedPost(uid, postId)`: Thêm pinned post (validate limit 3)
- **Xóa bài viết đã ghim** - `removePinnedPost(uid, postId)`: Xóa pinned post
- **Sắp xếp lại bài viết đã ghim** - `reorderPinnedPosts(uid, newOrder)`: Sắp xếp lại thứ tự pinned posts
- **Cập nhật story nổi bật** - `updateHighlightedStories(uid, highlightedStories)`: Cập nhật highlighted stories
- **Cập nhật trạng thái cấm** - `updateBanStatus(uid, banStatus, banExpiresAt, activeBanId)`: Cập nhật ban status (admin only)

**Delete (2):**
- **Xóa bài viết đã ghim** - `removePinnedPost(uid, postId)`: Xóa pinned post
- **Xóa story đã ghim** - `removePinnedStory(uid, storyId)`: Xóa pinned story

### 6. StoryRepository
**File:** [`lib/features/stories/repositories/story_repository.dart`](lib/features/stories/repositories/story_repository.dart)

**Create (5):**
- **Tạo story** - `createStory(authorUid, mediaUrl, type, thumbnailUrl, text)`: Tạo story mới (expires sau 24h, validate auth)
- **Upload và tạo story ảnh** - `uploadAndCreateStoryImage(authorUid, file, text)`: Upload ảnh lên Cloudinary và tạo story
- **Upload và tạo story video** - `uploadAndCreateStoryVideo(authorUid, file, text)`: Upload video lên Cloudinary và tạo story
- **Đăng lại story** - `repostStory(authorUid, story)`: Đăng lại story từ archive (tạo story mới với media cũ)
- **Ghi nhận người xem** - `addViewer(authorUid, storyId, viewerUid)`: Ghi nhận viewer (best effort, merge)

**Read (6):**
- **Theo dõi story của người dùng** - `watchUserStories(uid)`: Stream stories còn hiệu lực của user (realtime, filter expired)
- **Lấy trạng thái vòng story** - `fetchStoryRingStatus(ownerUid, viewerUid)`: Lấy trạng thái vòng story (none/unseen/allSeen)
- **Theo dõi kho lưu trữ story** - `watchUserStoryArchive(uid, limit)`: Stream toàn bộ stories (kể cả expired, limit 200)
- **Lấy story theo tác giả** - `fetchStoriesByAuthor(uid, limit)`: Stream stories theo author (kể cả expired)
- **Lấy danh sách người xem** - `fetchViewerEntries(authorUid, storyId)`: Lấy danh sách viewers kèm trạng thái liked
- **Kiểm tra đã thích story** - `isStoryLikedByUser(authorUid, storyId, viewerUid)`: Kiểm tra user đã like story chưa

**Update (1):**
- **Thích/bỏ thích story** - `toggleStoryLike(authorUid, storyId, likerUid)`: Toggle like story (update liked flag trong viewer doc)

**Delete (1):**
- **Xóa story** - `deleteStory(authorUid, storyId)`: Xóa story

### 7. NotificationRepository
**File:** [`lib/features/notifications/repositories/notification_repository.dart`](lib/features/notifications/repositories/notification_repository.dart)

**Create (1):**
- **Tạo thông báo** - `createNotification(notification, maxRetries)`: Tạo notification mới (retry logic với exponential backoff)

**Read (4):**
- **Theo dõi thông báo** - `watchNotifications(uid, limit)`: Stream notifications của user (realtime, orderBy createdAt, limit 50)
- **Theo dõi số thông báo chưa đọc** - `watchUnreadCount(uid)`: Stream số lượng notifications chưa đọc
- **Lấy thông báo trong khoảng thời gian** - `fetchNotificationsInRange(uid, startDate, endDate)`: Lấy notifications trong khoảng thời gian (để generate digest)
- **Tìm thông báo nhóm** - `findGroupedNotification(groupKey, toUid, timeWindow)`: Tìm grouped notification trong time window (1h mặc định)

**Update (3):**
- **Đánh dấu đã đọc** - `markAsRead(notificationId)`: Đánh dấu một notification đã đọc
- **Đánh dấu tất cả đã đọc** - `markAllAsRead(uid)`: Đánh dấu tất cả notifications đã đọc (batch update)
- **Cập nhật thông báo nhóm** - `updateGroupedNotification(notificationId, fromUid)`: Update grouped notification (tăng count, thêm fromUid vào list, max 50)

### 8. CallRepository
**File:** [`lib/features/call/repositories/call_repository.dart`](lib/features/call/repositories/call_repository.dart)

**Create (2):**
- **Tạo cuộc gọi** - `createCall(callerUid, calleeUid, type, conversationId)`: Tạo cuộc gọi mới (status: ringing)
- **Thêm ICE candidate** - `addIceCandidate(callId, candidate, isCaller)`: Thêm ICE candidate (lưu vào subcollection)

**Read (5):**
- **Theo dõi cuộc gọi** - `watchCall(callId)`: Stream call document (realtime)
- **Lấy cuộc gọi** - `fetchCall(callId)`: Lấy call document (one-time)
- **Lấy lịch sử cuộc gọi** - `fetchCallHistory(uid, limit, startAfter)`: Lấy lịch sử cuộc gọi (pagination, filter callerUid hoặc calleeUid)
- **Theo dõi cuộc gọi đang hoạt động** - `watchActiveCalls(uid)`: Stream các cuộc gọi đang active (ringing hoặc accepted)
- **Theo dõi ICE candidates** - `watchIceCandidates(callId, listenForCaller)`: Stream ICE candidates từ remote peer (realtime)

**Update (3):**
- **Cập nhật trạng thái cuộc gọi** - `updateCallStatus(callId, status, startedAt, endedAt, duration)`: Cập nhật trạng thái cuộc gọi
- **Cập nhật dữ liệu signaling** - `updateCallSignaling(callId, offer, answer)`: Cập nhật signaling data (offer, answer)
- **Kết thúc cuộc gọi** - `endCall(callId, status, endedAt, duration)`: Kết thúc cuộc gọi

**Delete (1):**
- **Dọn dẹp dữ liệu signaling** - `clearSignalingData(callId)`: Dọn dẹp signaling data sau khi kết thúc (xóa offer/answer/candidates)

### 9. AdminRepository
**File:** [`lib/features/admin/repositories/admin_repository.dart`](lib/features/admin/repositories/admin_repository.dart)

**Read (5):**
- **Kiểm tra quyền quản trị viên** - `isAdmin(uid)`: Kiểm tra user có phải admin không
- **Theo dõi trạng thái quản trị viên** - `watchAdminStatus(uid)`: Stream admin status (realtime)
- **Lấy danh sách quản trị viên** - `getAllAdmins()`: Lấy danh sách admin UIDs
- **Lấy thông tin quản trị viên** - `getAdmin(uid)`: Lấy admin document
- **Theo dõi tất cả quản trị viên** - `watchAllAdmins()`: Stream tất cả admins (để gửi notification)

### 10. BanRepository
**File:** [`lib/features/admin/repositories/ban_repository.dart`](lib/features/admin/repositories/ban_repository.dart)

**Create (1):**
- **Tạo lệnh cấm** - `createBan(uid, banType, banLevel, reason, reportId, adminUid, expiresAt)`: Tạo ban mới (isActive: true)

**Read (6):**
- **Lấy lệnh cấm đang hoạt động** - `getActiveBan(uid)`: Lấy ban đang active của user
- **Theo dõi trạng thái cấm** - `watchActiveBan(uid)`: Stream ban status (realtime)
- **Lấy lệnh cấm** - `getBan(banId)`: Lấy ban theo ID
- **Lấy danh sách lệnh cấm** - `getAllBans(banType, banLevel, isActive)`: Lấy danh sách bans với filter (admin view)
- **Theo dõi tất cả lệnh cấm** - `watchAllBans(banType, banLevel, isActive)`: Stream tất cả bans (admin view)
- **Kiểm tra bị cấm** - `checkIfBanned(uid)`: Kiểm tra user có bị ban không (auto unban nếu expired)

**Update (2):**
- **Mở khóa tài khoản** - `unbanUser(banId, adminUid, reason)`: Mở khóa tài khoản (set isActive: false)
- **Cập nhật ID kháng cáo** - `updateBanAppealId(banId, appealId)`: Cập nhật appealId vào ban

### 11. AppealRepository
**File:** [`lib/features/admin/repositories/appeal_repository.dart`](lib/features/admin/repositories/appeal_repository.dart)

**Create (1):**
- **Tạo đơn kháng cáo** - `createAppeal(uid, banId, reason, evidence)`: Tạo đơn kháng cáo (status: pending)

**Read (6):**
- **Theo dõi đơn kháng cáo chờ xử lý** - `watchPendingAppeals()`: Stream appeals chưa xử lý (admin view, realtime)
- **Lấy chi tiết đơn kháng cáo** - `getAppeal(appealId)`: Lấy chi tiết appeal
- **Lấy đơn kháng cáo theo người dùng** - `getAppealsByUser(uid)`: Lấy appeals của một user
- **Theo dõi đơn kháng cáo theo người dùng** - `watchAppealsByUser(uid)`: Stream appeals của user (realtime)
- **Lấy tất cả đơn kháng cáo** - `getAllAppeals(status)`: Lấy tất cả appeals với filter (admin view)
- **Theo dõi tất cả đơn kháng cáo** - `watchAllAppeals(status)`: Stream tất cả appeals (admin view, realtime)

**Update (1):**
- **Cập nhật trạng thái đơn kháng cáo** - `updateAppealStatus(appealId, status, adminUid, adminNotes)`: Cập nhật status appeal (pending/approved/rejected)

### 12. ReportRepository
**File:** [`lib/features/safety/repositories/report_repository.dart`](lib/features/safety/repositories/report_repository.dart)

**Create (1):**
- **Gửi báo cáo** - `submitReport(reporterUid, targetType, targetId, targetOwnerUid, reason)`: Gửi báo cáo (status: pending)

**Read (5):**
- **Theo dõi báo cáo chờ xử lý** - `watchPendingReports()`: Stream reports chưa xử lý (admin view, realtime)
- **Theo dõi báo cáo** - `watchReports(status)`: Stream reports với filter (admin view, realtime)
- **Lấy chi tiết báo cáo** - `getReport(reportId)`: Lấy chi tiết report
- **Lấy báo cáo theo đối tượng** - `getReportsByTarget(targetUid)`: Lấy tất cả reports về một user (admin view)
- **Lấy tất cả báo cáo** - `getAllReports(status)`: Lấy tất cả reports với filter (admin view)

**Update (1):**
- **Cập nhật trạng thái báo cáo** - `updateReportStatus(reportId, status, adminNotes, adminUid, banId, actionTaken)`: Cập nhật status report (pending/resolved/dismissed)

### 13. BlockRepository
**File:** [`lib/features/safety/repositories/block_repository.dart`](lib/features/safety/repositories/block_repository.dart)

**Create (1):**
- **Chặn người dùng** - `blockUser(blockerUid, blockedUid, reason)`: Chặn user (lưu vào blocks/{blockerUid}/items/{blockedUid})

**Read (5):**
- **Theo dõi trạng thái chặn** - `watchBlock(blockerUid, blockedUid)`: Stream block status (realtime)
- **Kiểm tra đã chặn** - `isBlocked(blockerUid, blockedUid)`: Kiểm tra đã chặn chưa
- **Kiểm tra một trong hai đã chặn** - `isEitherBlocked(uidA, uidB)`: Kiểm tra một trong hai đã chặn nhau chưa
- **Theo dõi danh sách ID bị chặn** - `watchBlockedIds(blockerUid)`: Stream danh sách blocked UIDs (realtime)
- **Lấy danh sách ID bị chặn** - `fetchBlockedIds(blockerUid)`: Lấy danh sách blocked UIDs (one-time)

**Delete (1):**
- **Bỏ chặn người dùng** - `unblockUser(blockerUid, blockedUid)`: Bỏ chặn user

### 14. SavedPostsRepository
**File:** [`lib/features/saved_posts/repositories/saved_posts_repository.dart`](lib/features/saved_posts/repositories/saved_posts_repository.dart)

**Create (1):**
- **Lưu bài viết** - `savePost(uid, postId, postOwnerUid, postUrl)`: Lưu post (lưu vào saved_posts/{uid}/items/{postId})

**Read (5):**
- **Theo dõi bài viết đã lưu** - `watchSavedPosts(uid, limit)`: Stream saved posts (realtime, orderBy savedAt, limit 50)
- **Theo dõi trạng thái đã lưu** - `watchIsSaved(uid, postId)`: Stream trạng thái đã lưu (realtime)
- **Kiểm tra đã lưu** - `isSaved(uid, postId)`: Kiểm tra đã lưu chưa (one-time)
- **Lấy bài viết đã lưu** - `fetchSavedPosts(uid, limit)`: Lấy saved posts (one-time, pagination)
- **Lấy trang bài viết đã lưu** - `fetchSavedPostsPage(uid, startAfter, limit)`: Lấy saved posts với pagination

**Delete (1):**
- **Bỏ lưu bài viết** - `unsavePost(uid, postId)`: Bỏ lưu post

### 15. DraftPostRepository
**File:** [`lib/features/posts/repositories/draft_post_repository.dart`](lib/features/posts/repositories/draft_post_repository.dart)

**Create (1):**
- **Lưu bản nháp** - `saveDraft(uid, media, caption, hashtags)`: Lưu draft mới (tự động extract hashtags từ caption)

**Read (3):**
- **Lấy bản nháp** - `fetchDraft(uid, draftId)`: Lấy một draft
- **Theo dõi tất cả bản nháp** - `watchDrafts(uid)`: Stream tất cả drafts (realtime, orderBy updatedAt)
- **Lấy bản nháp với phân trang** - `fetchDrafts(uid, limit, startAfter)`: Lấy drafts với pagination

**Update (1):**
- **Cập nhật bản nháp** - `updateDraft(uid, draftId, media, caption, hashtags)`: Cập nhật draft (merge)

**Delete (1):**
- **Xóa bản nháp** - `deleteDraft(uid, draftId)`: Xóa draft

### 16. SearchHistoryRepository
**File:** [`lib/features/search/repositories/search_history_repository.dart`](lib/features/search/repositories/search_history_repository.dart)

**Create (1):**
- **Lưu lịch sử tìm kiếm** - `saveSearchHistory(uid, query, searchType)`: Lưu lịch sử tìm kiếm (normalize query, update createdAt nếu đã có, giới hạn 50 mục)

**Read (2):**
- **Lấy lịch sử tìm kiếm** - `getSearchHistory(uid, searchType, limit)`: Lấy lịch sử tìm kiếm (one-time, orderBy createdAt)
- **Theo dõi lịch sử tìm kiếm** - `watchSearchHistory(uid, searchType, limit)`: Stream lịch sử tìm kiếm (realtime)

**Delete (2):**
- **Xóa một lịch sử tìm kiếm** - `deleteSearchHistory(uid, historyId)`: Xóa một lịch sử tìm kiếm
- **Xóa tất cả lịch sử tìm kiếm** - `clearSearchHistory(uid, searchType)`: Xóa tất cả lịch sử (batch delete)

### 17. SavedAccountsRepository
**File:** [`lib/features/auth/saved_accounts_repository.dart`](lib/features/auth/saved_accounts_repository.dart)

**Create (2):**
- **Lưu tài khoản từ người dùng** - `saveAccountFromUser(user)`: Lưu account từ Firebase User (lấy avatar từ profile nếu có)
- **Thêm hoặc cập nhật tài khoản** - `upsertAccount(account)`: Thêm hoặc cập nhật account (lưu vào SharedPreferences)

**Read (1):**
- **Lấy danh sách tài khoản đã lưu** - `getAccounts()`: Lấy danh sách saved accounts (sắp xếp theo lastUsedAt)

**Delete (2):**
- **Xóa một tài khoản** - `removeAccount(uid)`: Xóa một account
- **Xóa tất cả tài khoản** - `clear()`: Xóa tất cả accounts

### 18. SavedCredentialsRepository
**File:** [`lib/features/auth/saved_credentials_repository.dart`](lib/features/auth/saved_credentials_repository.dart)

**Create (1):**
- **Lưu mật khẩu** - `savePassword(uid, password)`: Lưu mật khẩu (FlutterSecureStorage, key: cred_{uid})

**Read (1):**
- **Lấy mật khẩu đã lưu** - `getPassword(uid)`: Lấy mật khẩu đã lưu

**Delete (2):**
- **Xóa mật khẩu** - `removePassword(uid)`: Xóa mật khẩu của một account
- **Xóa tất cả mật khẩu** - `clearAll()`: Xóa tất cả credentials (filter theo prefix)

### 19. NotificationDigestRepository
**File:** [`lib/features/notifications/repositories/notification_digest_repository.dart`](lib/features/notifications/repositories/notification_digest_repository.dart)

**Create (1):**
- **Tạo tóm tắt thông báo** - `createDigest(digest)`: Tạo digest mới (lưu vào notification_digests/{uid}/items/{digestId})

**Read (4):**
- **Lấy tóm tắt thông báo** - `fetchDigest(uid, digestId)`: Lấy digest theo ID
- **Lấy danh sách tóm tắt thông báo** - `fetchDigests(uid, period, limit, startAfter)`: Lấy digests với pagination
- **Theo dõi tóm tắt thông báo** - `watchDigests(uid, period, limit)`: Stream digests (realtime, filter period client-side)
- **Tìm tóm tắt thông báo theo khoảng thời gian** - `findDigestForPeriod(uid, period, startDate)`: Tìm digest cho một period cụ thể

**Delete (1):**
- **Xóa tóm tắt thông báo** - `deleteDigest(uid, digestId)`: Xóa digest cũ (cleanup)

## Chức năng không phải CRUD

### Services (Business Logic Layer)

#### 1. PostService
**File:** [`lib/features/posts/services/post_service.dart`](lib/features/posts/services/post_service.dart)

**Non-CRUD Functions (15):**
- **Lấy trang bảng tin** - `fetchFeedPage(startAfter, limit)`: Lấy feed page với author info
  ```dart
  Future<PostFeedPageResult> fetchFeedPage({DocumentSnapshot? startAfter, int limit = 10}) async {
    final page = await _repository.fetchPosts(startAfter: startAfter, limit: limit);
    final entries = await Future.wait(page.docs.map((doc) async {
      final post = Post.fromDoc(doc);
      final author = await _profiles.fetchProfile(post.authorUid);
      return PostFeedEntry(doc: doc, author: author);
    }));
    return PostFeedPageResult(entries: entries, lastDoc: page.lastDoc, hasMore: page.hasMore);
  }
  ```
- **Lấy trang bảng tin với bộ lọc** - `fetchFeedPageWithFilters(filters, startAfter, limit)`: Lấy feed với filters và author info
- **Tạo bài viết** - `createPost(media, caption, scheduledAt)`: Upload media lên Cloudinary/Firebase Storage và tạo post
  ```dart
  Future<void> createPost({required List<PostMediaUpload> media, String? caption, DateTime? scheduledAt}) async {
    // Upload tất cả media song song (parallel)
    final uploadFutures = media.asMap().entries.map((entry) async {
      if (storageBackend == 'cloudinary') {
        final result = await CloudinaryService.uploadImage(file: entry.value.file, folder: 'posts/$currentUid');
        return {'url': result['url'], 'type': entry.value.type.name, ...};
      } else {
        // Firebase Storage upload logic
      }
    });
    final uploadResults = await Future.wait(uploadFutures);
    await _repository.createPost(authorUid: currentUid, media: uploadResults, caption: caption, scheduledAt: scheduledAt);
  }
  ```
- **Lưu bản nháp** - `saveDraft(media, caption)`: Lưu draft (không upload media)
- **Cập nhật bản nháp** - `updateDraft(draftId, media, caption)`: Cập nhật draft
- **Lấy bản nháp** - `fetchDraft(draftId)`: Lấy draft
- **Xóa bản nháp** - `deleteDraft(draftId)`: Xóa draft
- **Thích/bỏ thích bài viết** - `toggleLike(postId, like)`: Toggle like và tạo notification
  ```dart
  Future<void> toggleLike({required String postId, required bool like}) async {
    if (like) {
      await _repository.likePost(postId: postId, uid: currentUid);
      // Tạo notification async (không block)
      _notificationService.createLikeNotification(...).catchError((e) => debugPrint('Error: $e'));
    } else {
      await _repository.unlikePost(postId: postId, uid: currentUid);
    }
  }
  ```
- **Theo dõi bình luận** - `watchComments(postId)`: Stream comments với author info và reactions
  ```dart
  Stream<List<PostCommentEntry>> watchComments(String postId) {
    return _repository.watchComments(postId).asyncMap((comments) async {
      // Preload authors và reactions
      final authorsMap = Map.fromEntries(await Future.wait(comments.map((c) async {
        final author = await _profiles.fetchProfile(c.authorUid);
        return MapEntry(c.id, author);
      })));
      // Build entries với replies hierarchy
      return roots;
    });
  }
  ```
- **Thêm bình luận** - `addComment(postId, text, parentCommentId, replyToUid)`: Thêm comment và tạo notification
- **Theo dõi bài viết** - `watchPost(postId)`: Stream post
- **Theo dõi tổng số cảm xúc** - `watchPostReactionCount(postId)`: Stream tổng reactions
- **Theo dõi trạng thái thích** - `watchLikeStatus(postId)`: Stream like status của user
- **Đặt cảm xúc cho bình luận** - `setCommentReaction(postId, commentId, reaction)`: Set reaction và tạo notification
- **Xóa bài viết** - `deletePost(postId)`: Xóa post và media từ Cloudinary
- **Chỉnh sửa bình luận** - `editComment(postId, commentId, newText)`: Chỉnh sửa comment
- **Lấy lịch sử chỉnh sửa bình luận** - `getCommentEditHistory(postId, commentId)`: Stream edit history
- **Xóa bình luận** - `deleteComment(postId, commentId)`: Xóa comment

#### 2. ConversationService
**File:** [`lib/features/chat/services/conversation_service.dart`](lib/features/chat/services/conversation_service.dart)

**Non-CRUD Functions (7):**
- **Theo dõi mục cuộc trò chuyện** - `watchConversationEntries(uid)`: Stream conversations với title, avatar, subtitle
  ```dart
  Stream<List<ConversationEntry>> watchConversationEntries(String uid) {
    return _chatRepository.watchConversations(uid).asyncMap((summaries) async {
      final entries = <ConversationEntry>[];
      for (final summary in summaries) {
        entries.add(await _buildEntry(uid, summary));
      }
      return entries;
    });
  }
  ```
- **Xây dựng mục cuộc trò chuyện** - `_buildEntry(currentUid, summary)`: Build conversation entry với profile info
  ```dart
  Future<ConversationEntry> _buildEntry(String currentUid, ConversationSummary summary) async {
    String title = summary.name ?? 'Cuộc trò chuyện';
    if (summary.type == 'direct') {
      final otherUid = summary.participantIds.firstWhere((id) => id != currentUid);
      final profile = await _profileRepository.fetchProfile(otherUid);
      title = profile?.displayName ?? otherUid;
    }
    final settings = await _chatRepository.fetchParticipantNotificationSettings(...);
    return ConversationEntry(summary: summary, title: title, ...);
  }
  ```
- **Tạo nhóm** - `createGroup(ownerUid, memberIds, name, avatarUrl, description)`: Tạo group (wrapper)
- **Thêm thành viên** - `addMembers(conversationId, requesterId, newMemberIds)`: Thêm members (wrapper)
- **Xóa thành viên** - `removeMember(conversationId, requesterId, targetUid)`: Xóa member (wrapper)
- **Rời nhóm** - `leaveGroup(conversationId, uid)`: Rời group (wrapper)
- **Cập nhật thông tin nhóm** - `updateGroupInfo(conversationId, requesterId, name, avatarUrl, description)`: Update group info (wrapper)
- **Đặt quyền quản trị viên** - `setAdmin(conversationId, requesterId, targetUid, isAdmin)`: Set admin (wrapper)

#### 3. FollowService
**File:** [`lib/features/follow/services/follow_service.dart`](lib/features/follow/services/follow_service.dart)

**Non-CRUD Functions (10):**
- **Tìm kiếm người dùng** - `searchUsers(keyword, limit)`: Tìm kiếm users với normalize và backfill lowercase fields
  ```dart
  Future<List<UserProfile>> searchUsers({required String keyword, int limit = 20}) async {
    final keywordLower = keyword.trim().toLowerCase();
    final byDisplayName = await _firestore.collection('user_profiles')
        .where('displayNameLower', isGreaterThanOrEqualTo: keywordLower)
        .where('displayNameLower', isLessThanOrEqualTo: '$keywordLower\uf8ff')
        .limit(limit).get();
    // Normalize lowercase fields cho legacy docs
    for (final profile in results.values) {
      if (profile.displayNameLower == null && profile.displayName?.isNotEmpty == true) {
        await _firestore.collection('user_profiles').doc(profile.uid).set({
          'displayNameLower': profile.displayName!.toLowerCase(),
        }, SetOptions(merge: true));
      }
    }
    return results.values.toList();
  }
  ```
- **Theo dõi người dùng** - `followUser(targetUid)`: Follow user với logic private/public, tạo notification
  ```dart
  Future<FollowStatus> followUser(String targetUid) async {
    final targetProfile = await _profiles.fetchProfile(targetUid);
    if (targetProfile.isPrivate) {
      await _repository.sendFollowRequest(followerUid: currentUid, targetUid: targetUid);
      return FollowStatus.requested;
    }
    await _repository.followUser(followerUid: currentUid, targetUid: targetUid);
    _notificationService.createFollowNotification(...).catchError(...);
    return FollowStatus.following;
  }
  ```
- **Hủy yêu cầu theo dõi** - `cancelRequest(targetUid)`: Hủy follow request
- **Bỏ theo dõi** - `unfollow(targetUid)`: Unfollow user
- **Chấp nhận yêu cầu** - `acceptRequest(followerUid)`: Chấp nhận request và tạo notification
- **Từ chối yêu cầu** - `declineRequest(followerUid)`: Từ chối request
- **Theo dõi trạng thái theo dõi** - `watchFollowState(currentUid, targetUid)`: Stream follow state với profile info
  ```dart
  Stream<FollowState> watchFollowState(String currentUid, String targetUid) {
    return _profiles.watchProfile(targetUid).asyncMap((profile) async {
      final isFollowing = await _repository.isFollowing(currentUid: currentUid, targetUid: targetUid);
      final hasRequest = await _repository.hasPendingRequest(currentUid: currentUid, targetUid: targetUid);
      return FollowState(status: isFollowing ? FollowStatus.following : (hasRequest ? FollowStatus.requested : FollowStatus.none), ...);
    });
  }
  ```
- **Lấy trạng thái theo dõi** - `fetchFollowStatus(currentUid, targetUid)`: Lấy follow status (one-time)
- **Theo dõi mục đang theo dõi** - `watchFollowingEntries(uid)`: Stream following với mutual follow check
  ```dart
  Stream<List<FollowEntry>> watchFollowingEntries(String uid) {
    return _repository.watchFollowing(uid).asyncMap((snapshot) async {
      final futures = snapshot.docs.map((doc) async {
        final otherUid = doc.id;
        final profile = await _profiles.fetchProfile(otherUid);
        final isMutual = await _repository.isFollowing(currentUid: otherUid, targetUid: uid);
        return FollowEntry(uid: otherUid, profile: profile, isMutual: isMutual, ...);
      });
      return Future.wait(futures);
    });
  }
  ```
- **Theo dõi mục người theo dõi** - `watchFollowersEntries(uid)`: Stream followers với mutual follow check
- **Theo dõi mục yêu cầu đến** - `watchIncomingRequestEntries(uid)`: Stream incoming requests với profile info
- **Theo dõi mục yêu cầu đã gửi** - `watchSentRequestEntries(uid)`: Stream sent requests với profile info

#### 4. NotificationService
**File:** [`lib/features/notifications/services/notification_service.dart`](lib/features/notifications/services/notification_service.dart)

**Non-CRUD Functions (12):**
- **Tạo khóa nhóm** - `_generateGroupKey(type, toUid, postId)`: Generate group key cho notification grouping
  ```dart
  String _generateGroupKey({required NotificationType type, required String toUid, String? postId}) {
    switch (type) {
      case NotificationType.like:
        return 'like_${postId}_$toUid';
      case NotificationType.follow:
        return 'follow_$toUid';
      default:
        throw ArgumentError('This notification type should not be grouped');
    }
  }
  ```
- **Tạo thông báo thích** - `createLikeNotification(postId, likerUid, postAuthorUid)`: Tạo like notification với grouping
  ```dart
  Future<void> createLikeNotification({required String postId, required String likerUid, required String postAuthorUid}) async {
    final groupKey = _generateGroupKey(type: NotificationType.like, toUid: postAuthorUid, postId: postId);
    final existingNotification = await _repository.findGroupedNotification(groupKey: groupKey, toUid: postAuthorUid, timeWindow: Duration(hours: 1));
    if (existingNotification != null) {
      await _repository.updateGroupedNotification(notificationId: existingNotification.id, fromUid: likerUid);
    } else {
      final notification = Notification(type: NotificationType.like, fromUid: likerUid, toUid: postAuthorUid, postId: postId, groupKey: groupKey, count: 1, fromUids: [likerUid], ...);
      await _repository.createNotification(notification);
    }
  }
  ```
- **Tạo thông báo bình luận** - `createCommentNotification(...)`: Tạo comment notification với commenter name
- **Tạo thông báo theo dõi** - `createFollowNotification(followerUid, followedUid)`: Tạo follow notification với grouping
- **Tạo thông báo tin nhắn** - `createMessageNotification(...)`: Tạo message notification
- **Tạo thông báo thích story** - `createStoryLikeNotification(...)`: Tạo story like notification
- **Tạo thông báo cảm xúc bình luận** - `createCommentReactionNotification(...)`: Tạo comment reaction notification
- **Tạo thông báo cuộc gọi** - `createCallNotification(...)`: Tạo call notification
- **Tạo thông báo báo cáo** - `createReportNotification(reportId, reporterUid, targetUid)`: Tạo notification cho tất cả admins
  ```dart
  Future<void> createReportNotification({required String reportId, required String reporterUid, required String targetUid}) async {
    final adminUids = await _adminRepository.getAllAdmins();
    for (final adminUid in adminUids) {
      await _repository.createNotification(Notification(type: NotificationType.report, fromUid: reporterUid, toUid: adminUid, reportId: reportId, ...));
    }
  }
  ```
- **Tạo thông báo kháng cáo** - `createAppealNotification(appealId, uid, banId)`: Tạo notification cho tất cả admins
- **Đánh dấu đã đọc** - `markAsRead(notificationId)`: Đánh dấu đã đọc (wrapper)
- **Đánh dấu tất cả đã đọc** - `markAllAsRead(uid)`: Đánh dấu tất cả đã đọc (wrapper)
- **Theo dõi thông báo** - `watchNotifications(uid)`: Stream notifications (wrapper)
- **Theo dõi số chưa đọc** - `watchUnreadCount(uid)`: Stream unread count (wrapper)

#### 5. CloudinaryService
**File:** [`lib/services/cloudinary_service.dart`](lib/services/cloudinary_service.dart)

**Non-CRUD Functions (5):**
- **Upload ảnh** - `uploadImage(file, folder, publicId)`: Upload ảnh lên Cloudinary với signature
  ```dart
  static Future<Map<String, String>> uploadImage({required XFile file, String? folder, String? publicId}) async {
    final bytes = await file.readAsBytes();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final params = {'timestamp': timestamp.toString(), 'api_key': CloudinaryConfig.apiKey, ...};
    final signature = _generateSignature(params);
    params['signature'] = signature;
    
    final request = http.MultipartRequest('POST', Uri.parse(CloudinaryConfig.imageUploadUrl));
    params.forEach((key, value) => request.fields[key] = value);
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: file.name));
    
    final response = await request.send();
    final jsonResponse = json.decode(await response.stream.bytesToString());
    return {'url': jsonResponse['secure_url'], 'publicId': jsonResponse['public_id']};
  }
  ```
- **Upload video** - `uploadVideo(file, folder, publicId)`: Upload video lên Cloudinary với thumbnail
  ```dart
  static Future<Map<String, dynamic>> uploadVideo({required XFile file, String? folder, String? publicId}) async {
    // Similar to uploadImage but with resource_type: 'video'
    // Returns: url, thumbnailUrl, durationMs, publicId
  }
  ```
- **Upload âm thanh** - `uploadAudio(file, folder, publicId)`: Upload audio/voice lên Cloudinary
- **Tạo chữ ký** - `_generateSignature(params)`: Tạo signature cho Cloudinary API (SHA1)
  ```dart
  static String _generateSignature(Map<String, String> params) {
    final sortedKeys = params.keys.toList()..sort();
    final signString = sortedKeys.map((key) => '$key=${params[key]}').join('&');
    final stringToSign = '$signString${CloudinaryConfig.apiSecret}';
    final hash = sha1.convert(utf8.encode(stringToSign));
    return hash.toString();
  }
  ```
- **Xóa file** - `deleteFile(publicId, resourceType)`: Xóa file từ Cloudinary

#### 6. CallService
**File:** [`lib/features/call/services/call_service.dart`](lib/features/call/services/call_service.dart)

**Non-CRUD Functions (8):**
- **Khởi tạo cuộc gọi** - `initiateCall(calleeUid, type, conversationId)`: Khởi tạo cuộc gọi với validation
  ```dart
  Future<String> initiateCall({required String calleeUid, required CallType type, String? conversationId}) async {
    final calleeProfile = await _profileRepository.fetchProfile(calleeUid);
    if (calleeProfile == null) throw StateError('Không tìm thấy người dùng');
    final callId = await _repository.createCall(callerUid: currentUid, calleeUid: calleeUid, type: type, conversationId: conversationId);
    return callId;
  }
  ```
- **Chấp nhận cuộc gọi** - `answerCall(callId)`: Chấp nhận cuộc gọi với validation
- **Từ chối cuộc gọi** - `rejectCall(callId)`: Từ chối cuộc gọi
- **Kết thúc cuộc gọi** - `endCall(callId)`: Kết thúc cuộc gọi và tính duration
  ```dart
  Future<void> endCall(String callId) async {
    final call = await _repository.fetchCall(callId);
    final duration = call.startedAt != null ? DateTime.now().difference(call.startedAt!).inSeconds : null;
    await _repository.endCall(callId, status: CallStatus.ended, endedAt: DateTime.now(), duration: duration);
    unawaited(_repository.clearSignalingData(callId));
  }
  ```
- **Hủy cuộc gọi** - `cancelCall(callId)`: Hủy cuộc gọi (chỉ caller)
- **Xử lý cuộc gọi nhỡ** - `handleMissedCall(callId)`: Xử lý missed call (timeout)
- **Theo dõi cuộc gọi** - `watchCall(callId)`: Stream call (wrapper)
- **Theo dõi cuộc gọi đang hoạt động** - `watchActiveCalls(uid)`: Stream active calls (wrapper)
- **Lấy lịch sử cuộc gọi** - `fetchCallHistory(uid, limit)`: Lấy call history (wrapper)

#### 7. WebRTCService
**File:** [`lib/features/call/services/webrtc_service.dart`](lib/features/call/services/webrtc_service.dart)

**Non-CRUD Functions (15):**
- **Khởi tạo WebRTC cho người gọi** - `initializeCaller(callId, callType, localRenderer, remoteRenderer)`: Khởi tạo WebRTC cho caller
  ```dart
  Future<void> initializeCaller({required String callId, required CallType callType, RTCVideoRenderer? localRenderer, RTCVideoRenderer? remoteRenderer}) async {
    _peerConnection = await _createPeerConnection();
    _localStream = await _getUserMedia(callType);
    _localStream!.getTracks().forEach((track) => _peerConnection!.addTrack(track, _localStream!));
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    await _repository.updateCallSignaling(callId, offer: {'type': offer.type, 'sdp': offer.sdp});
    _watchForAnswer(callId);
    _watchForIceCandidates(callId);
  }
  ```
- **Khởi tạo WebRTC cho người nhận** - `initializeCallee(callId, callType, localRenderer, remoteRenderer)`: Khởi tạo WebRTC cho callee
- **Lắng nghe offer** - `_watchForOffer(callId)`: Lắng nghe offer và tạo answer
- **Xử lý offer** - `_handleOffer(callId, offer)`: Xử lý offer từ caller
- **Lắng nghe answer** - `_watchForAnswer(callId)`: Lắng nghe answer từ callee
- **Xử lý answer** - `_handleAnswer(answer)`: Xử lý answer
- **Xử lý ICE candidate local** - `_handleIceCandidate(callId, candidate)`: Xử lý ICE candidate local
- **Lắng nghe ICE candidates từ xa** - `_watchForIceCandidates(callId)`: Lắng nghe ICE candidates từ remote
- **Xử lý ICE candidate từ xa** - `_handleIceCandidateFromRemote(candidateData)`: Xử lý ICE candidate từ remote
- **Tạo kết nối peer** - `_createPeerConnection()`: Tạo RTCPeerConnection với STUN servers
  ```dart
  Future<RTCPeerConnection> _createPeerConnection() async {
    final configuration = {
      'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}],
    };
    return await createPeerConnection(configuration, constraints);
  }
  ```
- **Lấy stream camera/microphone** - `_getUserMedia(callType)`: Lấy camera/microphone stream
  ```dart
  Future<MediaStream> _getUserMedia(CallType callType) async {
    final constraints = {
      'audio': true,
      'video': callType == CallType.video ? {'facingMode': 'user', 'width': {'ideal': 1280}, 'height': {'ideal': 720}} : false,
    };
    return await navigator.mediaDevices.getUserMedia(constraints);
  }
  ```
- **Bật/tắt microphone** - `toggleMicrophone()`: Toggle microphone on/off
- **Bật/tắt camera** - `toggleCamera()`: Toggle camera on/off
- **Chuyển camera** - `switchCamera()`: Switch front/back camera
- **Giải phóng tài nguyên** - `dispose()`: Giải phóng resources (streams, connections, renderers)
  ```dart
  Future<void> dispose() async {
    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    await _peerConnection?.close();
    await _localRenderer?.dispose();
    await _remoteRenderer?.dispose();
  }
  ```

#### 8. SearchService
**File:** [`lib/features/search/services/search_service.dart`](lib/features/search/services/search_service.dart)

**Non-CRUD Functions (3):**
- **Chuẩn hóa truy vấn tìm kiếm** - `normalizeQuery(query)`: Chuẩn hóa search query (trim, lowercase)
  ```dart
  String normalizeQuery(String query) {
    return query.trim().toLowerCase();
  }
  ```
- **Tìm kiếm người dùng** - `searchUsers(query, limit)`: Tìm kiếm users với normalize
- **Tìm kiếm người dùng với bộ lọc** - `searchUsersWithFilters(query, filters, limit, checkFollowing)`: Tìm kiếm với filters (privacy, follow status)
  ```dart
  Future<List<UserProfile>> searchUsersWithFilters({required String query, UserSearchFilters? filters, int limit = 20, Future<bool> Function(String)? checkFollowing}) async {
    final normalized = normalizeQuery(query);
    final users = await _profileRepository.searchUsersWithFilters(query: normalized, limit: limit * 2, isPrivate: filters?.privacyFilter == PrivacyFilter.private ? true : (filters?.privacyFilter == PrivacyFilter.public ? false : null));
    // Apply follow status filter client-side
    if (filters?.followStatus != null && checkFollowing != null) {
      final followChecks = await Future.wait(users.map((user) => checkFollowing(user.uid)));
      return users.where((user) {
        final isFollowing = followChecks[users.indexOf(user)];
        switch (filters!.followStatus) {
          case UserSearchFilter.following: return isFollowing;
          case UserSearchFilter.notFollowing: return !isFollowing;
          default: return true;
        }
      }).take(limit).toList();
    }
    return users.take(limit).toList();
  }
  ```
- **Tìm kiếm bài viết** - `searchPosts(query, limit)`: Tìm kiếm posts với normalize

#### 9. ShareService
**File:** [`lib/features/share/services/share_service.dart`](lib/features/share/services/share_service.dart)

**Non-CRUD Functions (6):**
- **Chia sẻ bài viết** - `sharePost(postId, caption)`: Share post với deep link
  ```dart
  static Future<void> sharePost({required String postId, String? caption}) async {
    final link = DeepLink.generatePostLink(postId);
    final text = caption != null ? '$caption\n\nXem bài viết: $link' : 'Xem bài viết: $link';
    await Share.share(text);
  }
  ```
- **Chia sẻ hồ sơ** - `shareProfile(uid, displayName)`: Share profile với deep link
- **Chia sẻ hashtag** - `shareHashtag(hashtag)`: Share hashtag với deep link
- **Sao chép liên kết** - `copyLink(link)`: Copy link vào clipboard
  ```dart
  static Future<void> copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
  }
  ```
- **Sao chép liên kết bài viết** - `copyPostLink(postId)`: Copy post link
- **Sao chép liên kết hồ sơ** - `copyProfileLink(uid)`: Copy profile link
- **Sao chép liên kết hashtag** - `copyHashtagLink(hashtag)`: Copy hashtag link

#### 10. BlockService
**File:** [`lib/features/safety/services/block_service.dart`](lib/features/safety/services/block_service.dart)

**Non-CRUD Functions (5):**
- **Theo dõi trạng thái chặn** - `watchIsBlocked(blockerUid, blockedUid)`: Stream block status
- **Kiểm tra đã chặn** - `isBlockedByMe(targetUid)`: Kiểm tra đã chặn chưa (wrapper với current user)
- **Kiểm tra một trong hai đã chặn** - `isEitherBlocked(uidA, uidB)`: Kiểm tra một trong hai đã chặn nhau (wrapper)
- **Chặn người dùng** - `blockUser(targetUid, reason, onCompleted)`: Chặn user với validation
- **Bỏ chặn người dùng** - `unblockUser(targetUid)`: Bỏ chặn user (wrapper)
- **Theo dõi danh sách ID bị chặn** - `watchMyBlockedIds()`: Stream blocked IDs của current user
- **Lấy danh sách ID bị chặn** - `fetchMyBlockedIds()`: Lấy blocked IDs của current user (one-time)

#### 11. AdminService
**File:** [`lib/features/admin/services/admin_service.dart`](lib/features/admin/services/admin_service.dart)

**Non-CRUD Functions (5):**
- **Kiểm tra quyền quản trị viên** - `isAdmin(uid)`: Kiểm tra admin (wrapper)
- **Theo dõi trạng thái quản trị viên** - `watchAdminStatus(uid)`: Stream admin status (wrapper)
- **Cấm người dùng** - `banUser(uid, banType, banLevel, reason, adminUid, reportId, expiresAt)`: Ban user và update profile
  ```dart
  Future<void> banUser({required String uid, required BanType banType, required BanLevel banLevel, required String reason, required String adminUid, String? reportId, DateTime? expiresAt}) async {
    final banId = await _banRepository.createBan(uid: uid, banType: banType, banLevel: banLevel, reason: reason, adminUid: adminUid, expiresAt: expiresAt);
    await _profileRepository.updateBanStatus(uid, banStatus: banType == BanType.permanent ? BanStatus.permanent : BanStatus.temporary, banExpiresAt: expiresAt, activeBanId: banId);
    if (reportId != null) {
      await _reportRepository.updateReportStatus(reportId, ReportStatus.resolved, adminUid: adminUid, banId: banId, actionTaken: ReportAction.banned);
    }
  }
  ```
- **Mở khóa người dùng** - `unbanUser(banId, adminUid, reason)`: Unban user và update profile
  ```dart
  Future<void> unbanUser(String banId, {required String adminUid, String? reason}) async {
    final ban = await _banRepository.getBan(banId);
    await _banRepository.unbanUser(banId, adminUid, reason: reason);
    await _profileRepository.updateBanStatus(ban.uid, banStatus: BanStatus.none, banExpiresAt: null, activeBanId: null);
  }
  ```
- **Xử lý báo cáo** - `resolveReport(reportId, action, adminUid, adminNotes, banId)`: Xử lý report
- **Xử lý kháng cáo** - `processAppeal(appealId, decision, adminUid, adminNotes)`: Xử lý appeal và unban nếu approve
  ```dart
  Future<void> processAppeal(String appealId, {required AppealDecision decision, required String adminUid, String? adminNotes}) async {
    final appeal = await _appealRepository.getAppeal(appealId);
    final status = decision == AppealDecision.approve ? AppealStatus.approved : AppealStatus.rejected;
    await _appealRepository.updateAppealStatus(appealId, status, adminUid: adminUid, adminNotes: adminNotes);
    if (decision == AppealDecision.approve) {
      await unbanUser(appeal.banId, adminUid: adminUid, reason: 'Appeal approved');
    }
  }
  ```

#### 12. ReportService
**File:** [`lib/features/safety/services/report_service.dart`](lib/features/safety/services/report_service.dart)

**Non-CRUD Functions (2):**
- **Báo cáo người dùng** - `reportUser(targetUid, reason)`: Báo cáo user và tạo notification cho admins
  ```dart
  Future<void> reportUser({required String targetUid, required String reason}) async {
    final reportId = await _repository.submitReport(reporterUid: reporterUid, targetType: ReportTargetType.user, targetId: targetUid, targetOwnerUid: targetUid, reason: reason);
    await _notificationService.createReportNotification(reportId: reportId, reporterUid: reporterUid, targetUid: targetUid);
  }
  ```
- **Báo cáo bài viết** - `reportPost(postId, ownerUid, reason)`: Báo cáo post

#### 13. SavedPostsService
**File:** [`lib/features/saved_posts/services/saved_posts_service.dart`](lib/features/saved_posts/services/saved_posts_service.dart)

**Non-CRUD Functions (6):**
- **Theo dõi bài viết đã lưu** - `watchMySavedPosts(limit)`: Stream saved posts của current user
- **Theo dõi trạng thái đã lưu** - `watchIsPostSaved(postId)`: Stream saved status của current user
- **Kiểm tra đã lưu** - `isPostSaved(postId)`: Kiểm tra đã lưu (one-time)
- **Tạo liên kết bài viết** - `buildPostLink(postId)`: Build deep link cho post
  ```dart
  static String buildPostLink(String postId) {
    return 'kmessapp://posts/$postId';
  }
  ```
- **Lưu bài viết** - `savePost(postId, postOwnerUid, postUrl)`: Lưu post với deep link
- **Bỏ lưu bài viết** - `unsavePost(postId)`: Bỏ lưu post
- **Chuyển đổi trạng thái lưu** - `toggleSaved(postId, postOwnerUid, postUrl)`: Toggle saved status
  ```dart
  Future<bool> toggleSaved({required String postId, required String postOwnerUid, String? postUrl}) async {
    final isSaved = await _repository.isSaved(uid: uid, postId: postId);
    if (isSaved) {
      await _repository.unsavePost(uid: uid, postId: postId);
      return false;
    } else {
      await _repository.savePost(uid: uid, postId: postId, postOwnerUid: postOwnerUid, postUrl: postUrl ?? buildPostLink(postId));
      return true;
    }
  }
  ```
- **Lấy bài viết đã lưu** - `fetchMySavedPosts(limit)`: Lấy saved posts (one-time)

#### 14. PostSchedulingService
**File:** [`lib/features/posts/services/post_scheduling_service.dart`](lib/features/posts/services/post_scheduling_service.dart)

**Non-CRUD Functions (1):**
- **Kiểm tra và xuất bản bài viết đã lên lịch** - `checkAndPublishScheduledPosts()`: Kiểm tra và publish scheduled posts đã đến giờ
  ```dart
  Future<int> checkAndPublishScheduledPosts() async {
    final scheduledPosts = await _repository.fetchScheduledPosts(authorUid: currentUid, limit: 100);
    final now = DateTime.now();
    int publishedCount = 0;
    for (final post in scheduledPosts) {
      if (post.scheduledAt != null && post.scheduledAt!.isBefore(now)) {
        await _repository.publishScheduledPost(postId: post.id, authorUid: currentUid);
        publishedCount++;
      }
    }
    return publishedCount;
  }
  ```

#### 15. PhoneAuthService
**File:** [`lib/features/auth/services/phone_auth_service.dart`](lib/features/auth/services/phone_auth_service.dart)

**Non-CRUD Functions (4):**
- **Chuẩn hóa số điện thoại** - `normalizePhone(raw)`: Chuẩn hóa số điện thoại về E.164 format
  ```dart
  String normalizePhone(String raw) {
    var phone = raw.replaceAll(RegExp(r'[\s\-]'), '');
    if (phone.startsWith('+')) return phone;
    if (phone.startsWith('0')) return '+84${phone.substring(1)}';
    throw FormatException('Số điện thoại phải ở dạng +[mã quốc gia][số] hoặc bắt đầu bằng 0');
  }
  ```
- **Gửi mã SMS** - `sendCode(phoneNumber)`: Gửi mã SMS với error handling
  ```dart
  Future<String> sendCode(String phoneNumber) async {
    String verificationId = '';
    final completer = Completer<String>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        await _auth.signInWithCredential(credential);
        completer.complete('');
      },
      verificationFailed: (e) => completer.completeError(FirebaseAuthException(code: e.code, message: PhoneAuthErrorHelper.getErrorMessage(e))),
      codeSent: (vId, _) => completer.complete(vId),
      codeAutoRetrievalTimeout: (vId) => completer.complete(vId),
    );
    return completer.future;
  }
  ```
- **Đăng nhập bằng mã SMS** - `signInWithCode(verificationId, smsCode)`: Đăng nhập với mã SMS
- **Liên kết số điện thoại** - `linkPhoneWithCode(user, verificationId, smsCode)`: Link số điện thoại với account

#### 16. NotificationDigestService
**File:** [`lib/features/notifications/services/notification_digest_service.dart`](lib/features/notifications/services/notification_digest_service.dart)

**Non-CRUD Functions (6):**
- **Tạo tóm tắt hàng ngày** - `generateDailyDigest(uid, date)`: Generate daily digest với stats và top posts
  ```dart
  Future<NotificationDigest> generateDailyDigest({required String uid, required DateTime date}) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(Duration(days: 1)).subtract(Duration(milliseconds: 1));
    final notifications = await _notificationRepository.fetchNotificationsInRange(uid: uid, startDate: startOfDay, endDate: endOfDay);
    final stats = _aggregateStats(notifications);
    final topPosts = _findTopPosts(notifications);
    final digest = NotificationDigest(uid: uid, period: DigestPeriod.daily, startDate: startOfDay, endDate: endOfDay, stats: stats, topPosts: topPosts, ...);
    final digestId = await _digestRepository.createDigest(digest);
    return NotificationDigest(id: digestId, ...);
  }
  ```
- **Tạo tóm tắt hàng tuần** - `generateWeeklyDigest(uid, weekStart)`: Generate weekly digest
- **Tổng hợp thống kê** - `_aggregateStats(notifications)`: Aggregate stats từ notifications
  ```dart
  DigestStats _aggregateStats(List<Notification> notifications) {
    int likesCount = 0, commentsCount = 0, followsCount = 0;
    for (final notification in notifications) {
      final count = notification.count;
      switch (notification.type) {
        case NotificationType.like: likesCount += count; break;
        case NotificationType.comment: commentsCount += count; break;
        case NotificationType.follow: followsCount += count; break;
        default: break;
      }
    }
    return DigestStats(likesCount: likesCount, commentsCount: commentsCount, followsCount: followsCount, messagesCount: 0);
  }
  ```
- **Nhóm bình luận theo bài viết** - `aggregateCommentsByPost(notifications)`: Nhóm comments theo postId
- **Tìm bài viết hàng đầu** - `_findTopPosts(notifications)`: Tìm top 5 posts có nhiều tương tác nhất
  ```dart
  List<String> _findTopPosts(List<Notification> notifications) {
    final postInteractions = <String, int>{};
    for (final notification in notifications) {
      if (notification.postId == null) continue;
      if (notification.type == NotificationType.like || notification.type == NotificationType.comment) {
        postInteractions[notification.postId!] = (postInteractions[notification.postId!] ?? 0) + notification.count;
      }
    }
    return postInteractions.entries.toList()..sort((a, b) => b.value.compareTo(a.value)).take(5).map((e) => e.key).toList();
  }
  ```
- **Lấy đầu tuần** - `_getStartOfWeek(date)`: Lấy start of week (Monday)
- **Theo dõi tóm tắt thông báo** - `watchDigests(uid, period, limit)`: Stream digests (wrapper)
- **Lấy tóm tắt thông báo** - `fetchDigests(uid, period, limit)`: Lấy digests (wrapper)

#### 17. DeepLinkService
**File:** [`lib/features/share/services/deep_link_service.dart`](lib/features/share/services/deep_link_service.dart)

**Non-CRUD Functions (2):**
- **Xử lý liên kết sâu** - `handleDeepLink(context, link)`: Handle deep link và navigate đến page tương ứng
  ```dart
  static Future<void> handleDeepLink(BuildContext context, DeepLink link) async {
    switch (link.type) {
      case DeepLinkType.post:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostPermalinkPage(postId: link.postId!)));
        break;
      case DeepLinkType.profile:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => PublicProfilePage(uid: link.uid!)));
        break;
      case DeepLinkType.hashtag:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => HashtagPage(hashtag: link.hashtag!)));
        break;
      case DeepLinkType.resetPassword:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResetPasswordPage(actionCode: link.actionCode!)));
        break;
    }
  }
  ```
- **Hiển thị lỗi** - `_showError(context, message)`: Hiển thị error message

### Helper Methods trong Repositories

#### 1. PostRepository
- **Trích xuất hashtag từ chú thích** - `extractHashtagsFromCaption(caption)`: Extract hashtags từ caption (static method)
  ```dart
  static List<String> extractHashtagsFromCaption(String caption) {
    if (caption.trim().isEmpty) return [];
    final regex = RegExp(r'#[\w]{1,50}', caseSensitive: false);
    final matches = regex.allMatches(caption);
    final hashtags = matches.map((match) => match.group(0)?.substring(1).toLowerCase() ?? '').where((tag) => tag.isNotEmpty).toSet().toList();
    return hashtags.take(10).toList(); // Max 10 hashtags
  }
  ```

#### 2. ChatRepository
- **Kiểm tra có thể tạo cuộc trò chuyện** - `canCreateConversation(senderUid, receiverUid, isFollowing)`: Kiểm tra có thể tạo conversation không
  ```dart
  Future<bool> canCreateConversation({required String senderUid, required String receiverUid, required bool isFollowing}) async {
    if (senderUid == receiverUid) return false;
    final receiverProfile = await profileRepository.fetchProfile(receiverUid);
    switch (receiverProfile.messagePermission) {
      case MessagePermission.everyone: return true;
      case MessagePermission.followers: return isFollowing;
      case MessagePermission.nobody: return false;
    }
  }
  ```

#### 3. UserProfileRepository
- **Kiểm tra có thể xem lần truy cập cuối** - `canViewLastSeen(viewerUid, profileUid, isFollowing)`: Kiểm tra có thể xem last seen không
  ```dart
  bool canViewLastSeen({required String viewerUid, required String profileUid, required bool isFollowing}) {
    if (viewerUid == profileUid) return true;
    // Logic sẽ được xử lý trong UI layer với profile data
    return true;
  }
  ```
- **Kiểm tra có thể gửi tin nhắn** - `canSendMessage(senderUid, receiverUid, isFollowing, messagePermission)`: Kiểm tra có thể nhắn tin không
  ```dart
  bool canSendMessage({required String senderUid, required String receiverUid, required bool isFollowing, required MessagePermission messagePermission}) {
    if (senderUid == receiverUid) return false;
    switch (messagePermission) {
      case MessagePermission.everyone: return true;
      case MessagePermission.followers: return isFollowing;
      case MessagePermission.nobody: return false;
    }
  }
  ```

#### 4. StoryRepository
- **Lấy trạng thái vòng story** - `fetchStoryRingStatus(ownerUid, viewerUid)`: Lấy trạng thái vòng story (none/unseen/allSeen)
  ```dart
  Future<StoryRingStatus> fetchStoryRingStatus({required String ownerUid, required String viewerUid}) async {
    final activeStories = await watchUserStories(ownerUid).first;
    if (activeStories.isEmpty) return StoryRingStatus.none;
    for (final story in activeStories) {
      final viewerDoc = await _viewersCollection(ownerUid, story.id).doc(viewerUid).get();
      if (!viewerDoc.exists) return StoryRingStatus.unseen;
    }
    return StoryRingStatus.allSeen;
  }
  ```

## 📊 Tổng hợp chức năng dự án

### 🎯 Tổng quan

| Loại chức năng | Số lượng | Mô tả |
|----------------|---------|-------|
| **CRUD Operations** | **196** | Thao tác cơ bản với database |
| **Non-CRUD Operations** | **~80+** | Logic nghiệp vụ và tiện ích |

### 📈 Phân loại CRUD Operations

| Thao tác | Số lượng | Tỷ lệ |
|----------|----------|-------|
| **Create** | 39 | 19.9% |
| **Read** | 94 | 48.0% |
| **Update** | 39 | 19.9% |
| **Delete** | 24 | 12.2% |

---

## 📚 Chi tiết 19 Repositories
### 1. 🔐 AuthRepository (Xác thực) - **14 chức năng**

**📝 Tạo mới (6):**
- Đăng ký bằng email
- Đăng nhập bằng email
- Đăng nhập bằng Google
- Đăng nhập bằng Facebook
- Bắt đầu xác thực số điện thoại
- Xác nhận mã SMS

**👁️ Đọc (2):**
- Theo dõi trạng thái đăng nhập
- Lấy người dùng hiện tại

**✏️ Cập nhật (5):**
- Đổi mật khẩu
- Gửi email đặt lại mật khẩu
- Xác nhận đặt lại mật khẩu
- Gửi email xác thực
- Tải lại thông tin người dùng

**🗑️ Xóa (1):**
- Đăng xuất

### 2. 📝 PostRepository (Bài viết) - **27 chức năng**

**📝 Tạo mới (4):**
- Tạo bài viết (hỗ trợ lên lịch)
- Thêm bình luận
- Thích bài viết
- Thêm/xóa cảm xúc cho bình luận

**👁️ Đọc (16):**
- Lấy danh sách bài viết
- Lấy bài viết với bộ lọc
- Theo dõi một bài viết
- Theo dõi bài viết đã xuất bản
- Theo dõi bình luận
- Lấy bài viết theo tác giả
- Tìm kiếm bài viết
- Theo dõi bài viết theo hashtag
- Lấy bài viết theo hashtag
- Lấy hashtag đang thịnh hành
- Lấy bài viết đã lên lịch
- Kiểm tra đã thích
- Theo dõi trạng thái thích
- Lấy một bình luận
- Lấy lịch sử chỉnh sửa bình luận
- Theo dõi tổng số cảm xúc

**✏️ Cập nhật (4):**
- Chỉnh sửa bình luận
- Xuất bản bài viết đã lên lịch
- Hủy bài viết đã lên lịch
- Cập nhật thời gian lên lịch

**🗑️ Xóa (3):**
- Xóa bài viết
- Xóa bình luận
- Bỏ thích bài viết

### 3. 💬 ChatRepository (Trò chuyện) - **25 chức năng**

**📝 Tạo mới (8):**
- Tạo hoặc lấy cuộc trò chuyện trực tiếp
- Tạo nhóm trò chuyện
- Gửi tin nhắn văn bản
- Gửi tin nhắn hình ảnh
- Gửi tin nhắn thoại
- Gửi tin nhắn video
- Thêm thành viên vào nhóm
- Đảm bảo entry người tham gia

**👁️ Đọc (7):**
- Theo dõi danh sách cuộc trò chuyện
- Theo dõi tin nhắn
- Theo dõi số tin chưa đọc
- Lấy danh sách ID người tham gia
- Tìm kiếm tin nhắn
- Theo dõi cài đặt thông báo người tham gia
- Lấy cài đặt thông báo người tham gia

**✏️ Cập nhật (7):**
- Chỉnh sửa tin nhắn
- Thêm/xóa cảm xúc cho tin nhắn
- Đánh dấu đã đọc
- Cập nhật thông tin nhóm
- Thêm/gỡ quyền quản trị viên
- Cập nhật cài đặt thông báo người tham gia
- Đặt trạng thái đang gõ

**🗑️ Xóa (3):**
- Thu hồi tin nhắn
- Xóa thành viên khỏi nhóm
- Rời nhóm

### 4. 👥 FollowRepository (Theo dõi) - **13 chức năng**

**📝 Tạo mới (2):**
- Theo dõi người dùng
- Gửi yêu cầu theo dõi

**👁️ Đọc (7):**
- Theo dõi danh sách người theo dõi
- Theo dõi danh sách đang theo dõi
- Theo dõi yêu cầu theo dõi đến
- Theo dõi yêu cầu theo dõi đã gửi
- Kiểm tra đang theo dõi
- Kiểm tra có yêu cầu đang chờ
- Lấy danh sách ID đang theo dõi

**✏️ Cập nhật (1):**
- Chấp nhận yêu cầu theo dõi

**🗑️ Xóa (3):**
- Bỏ theo dõi người dùng
- Hủy yêu cầu theo dõi
- Từ chối yêu cầu theo dõi

### 5. 👤 UserProfileRepository (Hồ sơ người dùng) - **17 chức năng**

**📝 Tạo mới (1):**
- Đảm bảo hồ sơ tồn tại

**👁️ Đọc (4):**
- Theo dõi hồ sơ
- Lấy hồ sơ
- Tìm kiếm người dùng
- Tìm kiếm người dùng với bộ lọc

**✏️ Cập nhật (10):**
- Cập nhật hồ sơ
- Cập nhật cài đặt quyền riêng tư
- Cập nhật trạng thái hiện diện
- Cập nhật bài viết đã ghim
- Cập nhật story đã ghim
- Thêm bài viết đã ghim
- Sắp xếp lại bài viết đã ghim
- Cập nhật story nổi bật
- Cập nhật trạng thái cấm

**🗑️ Xóa (2):**
- Xóa bài viết đã ghim
- Xóa story đã ghim

### 6. 📸 StoryRepository (Câu chuyện) - **13 chức năng**

**📝 Tạo mới (5):**
- Tạo story
- Upload và tạo story ảnh
- Upload và tạo story video
- Đăng lại story
- Ghi nhận người xem

**👁️ Đọc (6):**
- Theo dõi story của người dùng
- Lấy trạng thái vòng story
- Theo dõi kho lưu trữ story
- Lấy story theo tác giả
- Lấy danh sách người xem
- Kiểm tra đã thích story

**✏️ Cập nhật (1):**
- Thích/bỏ thích story

**🗑️ Xóa (1):**
- Xóa story

### 7. 🔔 NotificationRepository (Thông báo) - **8 chức năng**

**📝 Tạo mới (1):**
- Tạo thông báo

**👁️ Đọc (4):**
- Theo dõi thông báo
- Theo dõi số thông báo chưa đọc
- Lấy thông báo trong khoảng thời gian
- Tìm thông báo nhóm

**✏️ Cập nhật (3):**
- Đánh dấu đã đọc
- Đánh dấu tất cả đã đọc
- Cập nhật thông báo nhóm

### 8. 📞 CallRepository (Cuộc gọi) - **11 chức năng**

**📝 Tạo mới (2):**
- Tạo cuộc gọi
- Thêm ICE candidate

**👁️ Đọc (5):**
- Theo dõi cuộc gọi
- Lấy cuộc gọi
- Lấy lịch sử cuộc gọi
- Theo dõi cuộc gọi đang hoạt động
- Theo dõi ICE candidates

**✏️ Cập nhật (3):**
- Cập nhật trạng thái cuộc gọi
- Cập nhật dữ liệu signaling
- Kết thúc cuộc gọi

**🗑️ Xóa (1):**
- Dọn dẹp dữ liệu signaling

### 9. 👨‍💼 AdminRepository (Quản trị viên) - **5 chức năng**

**👁️ Đọc (5):**
- Kiểm tra quyền quản trị viên
- Theo dõi trạng thái quản trị viên
- Lấy danh sách quản trị viên
- Lấy thông tin quản trị viên
- Theo dõi tất cả quản trị viên

### 10. 🚫 BanRepository (Cấm) - **9 chức năng**

**📝 Tạo mới (1):**
- Tạo lệnh cấm

**👁️ Đọc (6):**
- Lấy lệnh cấm đang hoạt động
- Theo dõi trạng thái cấm
- Lấy lệnh cấm
- Lấy danh sách lệnh cấm
- Theo dõi tất cả lệnh cấm
- Kiểm tra bị cấm

**✏️ Cập nhật (2):**
- Mở khóa tài khoản
- Cập nhật ID kháng cáo

### 11. 📋 AppealRepository (Kháng cáo) - **8 chức năng**

**📝 Tạo mới (1):**
- Tạo đơn kháng cáo

**👁️ Đọc (6):**
- Theo dõi đơn kháng cáo chờ xử lý
- Lấy chi tiết đơn kháng cáo
- Lấy đơn kháng cáo theo người dùng
- Theo dõi đơn kháng cáo theo người dùng
- Lấy tất cả đơn kháng cáo
- Theo dõi tất cả đơn kháng cáo

**✏️ Cập nhật (1):**
- Cập nhật trạng thái đơn kháng cáo

### 12. ⚠️ ReportRepository (Báo cáo) - **7 chức năng**

**📝 Tạo mới (1):**
- Gửi báo cáo

**👁️ Đọc (5):**
- Theo dõi báo cáo chờ xử lý
- Theo dõi báo cáo
- Lấy chi tiết báo cáo
- Lấy báo cáo theo đối tượng
- Lấy tất cả báo cáo

**✏️ Cập nhật (1):**
- Cập nhật trạng thái báo cáo

### 13. 🚧 BlockRepository (Chặn) - **7 chức năng**

**📝 Tạo mới (1):**
- Chặn người dùng

**👁️ Đọc (5):**
- Theo dõi trạng thái chặn
- Kiểm tra đã chặn
- Kiểm tra một trong hai đã chặn
- Theo dõi danh sách ID bị chặn
- Lấy danh sách ID bị chặn

**🗑️ Xóa (1):**
- Bỏ chặn người dùng

### 14. 💾 SavedPostsRepository (Bài viết đã lưu) - **7 chức năng**

**📝 Tạo mới (1):**
- Lưu bài viết

**👁️ Đọc (5):**
- Theo dõi bài viết đã lưu
- Theo dõi trạng thái đã lưu
- Kiểm tra đã lưu
- Lấy bài viết đã lưu
- Lấy trang bài viết đã lưu

**🗑️ Xóa (1):**
- Bỏ lưu bài viết

### 15. 📄 DraftPostRepository (Bản nháp) - **6 chức năng**

**📝 Tạo mới (1):**
- Lưu bản nháp

**👁️ Đọc (3):**
- Lấy bản nháp
- Theo dõi tất cả bản nháp
- Lấy bản nháp với phân trang

**✏️ Cập nhật (1):**
- Cập nhật bản nháp

**🗑️ Xóa (1):**
- Xóa bản nháp

### 16. 🔍 SearchHistoryRepository (Lịch sử tìm kiếm) - **5 chức năng**

**📝 Tạo mới (1):**
- Lưu lịch sử tìm kiếm

**👁️ Đọc (2):**
- Lấy lịch sử tìm kiếm
- Theo dõi lịch sử tìm kiếm

**🗑️ Xóa (2):**
- Xóa một lịch sử tìm kiếm
- Xóa tất cả lịch sử tìm kiếm

### 17. 👥 SavedAccountsRepository (Tài khoản đã lưu) - **5 chức năng**

**📝 Tạo mới (2):**
- Lưu tài khoản từ người dùng
- Thêm hoặc cập nhật tài khoản

**👁️ Đọc (1):**
- Lấy danh sách tài khoản đã lưu

**🗑️ Xóa (2):**
- Xóa một tài khoản
- Xóa tất cả tài khoản

### 18. 🔑 SavedCredentialsRepository (Thông tin đăng nhập đã lưu) - **4 chức năng**

**📝 Tạo mới (1):**
- Lưu mật khẩu

**👁️ Đọc (1):**
- Lấy mật khẩu đã lưu

**🗑️ Xóa (2):**
- Xóa mật khẩu
- Xóa tất cả mật khẩu

### 19. 📊 NotificationDigestRepository (Tóm tắt thông báo) - **6 chức năng**

**📝 Tạo mới (1):**
- Tạo tóm tắt thông báo

**👁️ Đọc (4):**
- Lấy tóm tắt thông báo
- Lấy danh sách tóm tắt thông báo
- Theo dõi tóm tắt thông báo
- Tìm tóm tắt thông báo theo khoảng thời gian

**🗑️ Xóa (1):**
- Xóa tóm tắt thông báo

---

## ⚙️ Chức năng không phải CRUD

### 📊 Tổng quan

| Loại | Số lượng | Mô tả |
|------|----------|-------|
| **Services** | ~60 | Logic nghiệp vụ, xử lý dữ liệu, validation |
| **Helper Methods** | ~10 | Tiện ích trong repositories |
| **Utilities** | ~10 | Format, normalization, deep linking |

### 🔧 17 Services (Dịch vụ xử lý nghiệp vụ)

#### 1. 📝 PostService - **15 chức năng**
- Lấy trang bảng tin
- Lấy trang bảng tin với bộ lọc
- Tạo bài viết (upload media)
- Lưu bản nháp
- Cập nhật bản nháp
- Lấy bản nháp
- Xóa bản nháp
- Thích/bỏ thích bài viết
- Theo dõi bình luận
- Thêm bình luận
- Theo dõi bài viết
- Theo dõi tổng số cảm xúc
- Theo dõi trạng thái thích
- Đặt cảm xúc cho bình luận
- Xóa bài viết

#### 2. 💬 ConversationService - **7 chức năng**
- Theo dõi mục cuộc trò chuyện
- Xây dựng mục cuộc trò chuyện
- Tạo nhóm
- Thêm thành viên
- Xóa thành viên
- Rời nhóm
- Cập nhật thông tin nhóm

#### 3. 👥 FollowService - **10 chức năng**
- Tìm kiếm người dùng
- Theo dõi người dùng
- Hủy yêu cầu theo dõi
- Bỏ theo dõi
- Chấp nhận yêu cầu
- Từ chối yêu cầu
- Theo dõi trạng thái theo dõi
- Lấy trạng thái theo dõi
- Theo dõi mục đang theo dõi
- Theo dõi mục người theo dõi

#### 4. 🔔 NotificationService - **12 chức năng**
- Tạo khóa nhóm
- Tạo thông báo thích
- Tạo thông báo bình luận
- Tạo thông báo theo dõi
- Tạo thông báo tin nhắn
- Tạo thông báo thích story
- Tạo thông báo cảm xúc bình luận
- Tạo thông báo cuộc gọi
- Tạo thông báo báo cáo
- Tạo thông báo kháng cáo
- Theo dõi thông báo
- Theo dõi số chưa đọc

#### 5. ☁️ CloudinaryService - **5 chức năng**
- Upload ảnh
- Upload video
- Upload âm thanh
- Tạo chữ ký
- Xóa file

#### 6. 📞 CallService - **8 chức năng**
- Khởi tạo cuộc gọi
- Chấp nhận cuộc gọi
- Từ chối cuộc gọi
- Kết thúc cuộc gọi
- Hủy cuộc gọi
- Xử lý cuộc gọi nhỡ
- Theo dõi cuộc gọi
- Lấy lịch sử cuộc gọi

#### 7. 🎥 WebRTCService - **15 chức năng**
- Khởi tạo WebRTC cho người gọi
- Khởi tạo WebRTC cho người nhận
- Lắng nghe offer
- Xử lý offer
- Lắng nghe answer
- Xử lý answer
- Xử lý ICE candidate local
- Lắng nghe ICE candidates từ xa
- Xử lý ICE candidate từ xa
- Tạo kết nối peer
- Lấy stream camera/microphone
- Bật/tắt microphone
- Bật/tắt camera
- Chuyển camera
- Giải phóng tài nguyên

#### 8. 🔍 SearchService - **3 chức năng**
- Chuẩn hóa truy vấn tìm kiếm
- Tìm kiếm người dùng
- Tìm kiếm người dùng với bộ lọc

#### 9. 🔗 ShareService - **6 chức năng**
- Chia sẻ bài viết
- Chia sẻ hồ sơ
- Chia sẻ hashtag
- Sao chép liên kết
- Sao chép liên kết bài viết
- Sao chép liên kết hồ sơ

#### 10. 🚧 BlockService - **5 chức năng**
- Theo dõi trạng thái chặn
- Kiểm tra đã chặn
- Kiểm tra một trong hai đã chặn
- Chặn người dùng
- Bỏ chặn người dùng

#### 11. 👨‍💼 AdminService - **5 chức năng**
- Kiểm tra quyền quản trị viên
- Theo dõi trạng thái quản trị viên
- Cấm người dùng
- Mở khóa người dùng
- Xử lý báo cáo

#### 12. ⚠️ ReportService - **2 chức năng**
- Báo cáo người dùng
- Báo cáo bài viết

#### 13. 💾 SavedPostsService - **6 chức năng**
- Theo dõi bài viết đã lưu
- Theo dõi trạng thái đã lưu
- Kiểm tra đã lưu
- Tạo liên kết bài viết
- Lưu bài viết
- Chuyển đổi trạng thái lưu

#### 14. ⏰ PostSchedulingService - **1 chức năng**
- Kiểm tra và xuất bản bài viết đã lên lịch

#### 15. 📱 PhoneAuthService - **4 chức năng**
- Chuẩn hóa số điện thoại
- Gửi mã SMS
- Đăng nhập bằng mã SMS
- Liên kết số điện thoại

#### 16. 📊 NotificationDigestService - **6 chức năng**
- Tạo tóm tắt hàng ngày
- Tạo tóm tắt hàng tuần
- Tổng hợp thống kê
- Nhóm bình luận theo bài viết
- Tìm bài viết hàng đầu
- Theo dõi tóm tắt thông báo

#### 17. 🔗 DeepLinkService - **2 chức năng**
- Xử lý liên kết sâu
- Hiển thị lỗi

### 🛠️ Helper Methods (Phương thức hỗ trợ)

#### PostRepository - **1 helper**
- Trích xuất hashtag từ chú thích

#### ChatRepository - **1 helper**
- Kiểm tra có thể tạo cuộc trò chuyện

#### UserProfileRepository - **2 helpers**
- Kiểm tra có thể xem lần truy cập cuối
- Kiểm tra có thể gửi tin nhắn

#### StoryRepository - **1 helper**
- Lấy trạng thái vòng story

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

## 🏗️ Kiến trúc ứng dụng

Dự án sử dụng kiến trúc phân lớp (layered architecture) với 4 tầng chính:

### 📦 Models (Mô hình dữ liệu)

**Mục đích:** Định nghĩa cấu trúc dữ liệu (data classes) cho các entity trong ứng dụng

**Ví dụ:** `Post`, `Message`, `Story`, `Notification`

**Chức năng:**
- Chứa các class Dart đại diện cho dữ liệu
- Chuyển đổi dữ liệu từ Firestore/API sang object Dart (factory methods như `fromDoc`, `fromMap`)
- Định nghĩa các thuộc tính và kiểu dữ liệu

---

### 🖼️ Pages (Giao diện màn hình)

**Mục đích:** Chứa các màn hình UI (`StatefulWidget`/`StatelessWidget`)

**Ví dụ:** `PostFeedPage`, `ChatDetailPage`, `StoryViewerPage`

**Chức năng:**
- Xây dựng giao diện người dùng
- Xử lý tương tác (tap, scroll, input)
- Quản lý state của màn hình
- Gọi services/repositories để lấy dữ liệu

---

### 💾 Repositories (Tầng truy cập dữ liệu)

**Mục đích:** Lớp trung gian giữa UI và nguồn dữ liệu (Firestore, API)

**Ví dụ:** `PostRepository`, `ChatRepository`, `StoryRepository`

**Chức năng:**
- Thực hiện các thao tác CRUD với database
- Đọc/ghi dữ liệu từ Firestore
- Xử lý query, filter, pagination
- Trả về dữ liệu dạng raw (`DocumentSnapshot`, `QuerySnapshot`)

---

### ⚙️ Services (Tầng xử lý nghiệp vụ)

**Mục đích:** Xử lý logic nghiệp vụ phức tạp, kết hợp nhiều repositories

**Ví dụ:** `PostService`, `ConversationService`, `NotificationService`

**Chức năng:**
- Kết hợp nhiều repositories để thực hiện một tác vụ
- Xử lý upload file (ảnh, video) lên Cloudinary/Firebase Storage
- Xử lý business logic (ví dụ: tạo post → upload media → lưu vào Firestore → gửi notification)
- Chuyển đổi dữ liệu từ repository sang model để UI sử dụng

---

### 🔄 Luồng dữ liệu

```
Pages (UI Layer)
    ↓
Services (Business Logic Layer)
    ↓
Repositories (Data Access Layer)
    ↓
Firestore / APIs (Data Source)
```

**Models** được sử dụng ở tất cả các tầng để đảm bảo tính nhất quán của dữ liệu.
