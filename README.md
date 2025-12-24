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
- `registerWithEmail(email, password)`: Đăng ký tài khoản mới với email/password
  ```dart
  Future<void> registerWithEmail(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);
  ```
- `signInWithEmail(email, password)`: Đăng nhập với email/password
  ```dart
  Future<void> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);
  ```
- `signInWithGoogle()`: Đăng nhập bằng Google (OAuth), tự động tạo/update profile
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
- `signInWithFacebook()`: Đăng nhập bằng Facebook (OAuth), tự động tạo/update profile
  ```dart
  Future<void> signInWithFacebook() async {
    final result = await FacebookAuth.instance.login();
    final credential = FacebookAuthProvider.credential(result.accessToken.tokenString);
    await _auth.signInWithCredential(credential);
    // Auto-create/update profile với thông tin từ Facebook
    await userProfileRepository.ensureProfile(...);
  }
  ```
- `startPhoneVerification(phoneNumber, callbacks)`: Bắt đầu xác thực số điện thoại (SMS)
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
- `confirmSmsCode(verificationId, smsCode)`: Xác nhận mã SMS và đăng nhập
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
- `authState()`: Stream trạng thái đăng nhập (User?)
  ```dart
  Stream<User?> authState() => _auth.authStateChanges();
  ```
- `currentUser()`: Lấy user hiện tại (User?)
  ```dart
  User? currentUser() => _auth.currentUser;
  ```

**Update (5):**
- `changePassword(currentPassword, newPassword)`: Đổi mật khẩu (cần re-authenticate)
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
- `sendPasswordResetEmail(email)`: Gửi email reset mật khẩu
  ```dart
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
  ```
- `confirmPasswordReset(code, newPassword)`: Xác nhận reset mật khẩu với code
  ```dart
  Future<void> confirmPasswordReset(String code, String newPassword) async {
    await _auth.confirmPasswordReset(code: code, newPassword: newPassword);
  }
  ```
- `sendEmailVerification()`: Gửi email xác thực tài khoản
  ```dart
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }
  ```
- `reloadCurrentUser()`: Reload thông tin user từ server
  ```dart
  Future<void> reloadCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
    }
  }
  ```

**Delete (1):**
- `signOut()`: Đăng xuất (sign out cả Google Sign-In và Firebase Auth)
  ```dart
  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }
  ```

### 2. PostRepository
**File:** [`lib/features/posts/repositories/post_repository.dart`](lib/features/posts/repositories/post_repository.dart)

**Create (4):**
- `createPost(authorUid, media, caption, scheduledAt)`: Tạo post mới (hỗ trợ scheduled), tự động extract hashtags, increment postsCount
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
- `addComment(postId, authorUid, text, parentCommentId, replyToUid)`: Thêm comment (transaction, increment commentCount)
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
- `likePost(postId, uid)`: Like post (transaction, increment likeCount, retry logic)
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
- `setCommentReaction(postId, commentId, uid, reaction)`: Thêm/xóa reaction cho comment (emoji)
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
- `fetchPosts(startAfter, limit, includeScheduled)`: Lấy danh sách posts (pagination, filter published)
- `fetchPostsWithFilters(filters, startAfter, limit)`: Lấy posts với filters (media type, time range, sort option)
- `watchPost(postId)`: Stream một post cụ thể (realtime)
- `watchPublishedPosts(limit)`: Stream posts đã publish (realtime)
- `watchComments(postId)`: Stream comments của post (realtime, limit 100)
- `fetchPostsByAuthor(authorUid, startAfter, limit)`: Lấy posts theo tác giả (pagination)
- `searchPosts(query, limit, startAfter)`: Tìm kiếm posts theo caption (prefix matching trên captionLower)
- `watchPostsByHashtag(tag, limit, sortBy)`: Stream posts theo hashtag (realtime, sort by createdAt hoặc hot)
- `fetchPostsByHashtag(tag, limit, startAfter, sortBy)`: Lấy posts theo hashtag (pagination)
- `fetchTrendingHashtags(limit)`: Lấy trending hashtags (aggregate từ 100 posts gần nhất)
- `fetchScheduledPosts(authorUid, limit)`: Lấy scheduled posts của user
- `hasUserLikedPost(postId, uid)`: Kiểm tra user đã like chưa
- `watchUserLike(postId, uid)`: Stream trạng thái like của user (realtime)
- `getComment(postId, commentId)`: Lấy một comment cụ thể
- `getCommentEditHistory(postId, commentId)`: Stream lịch sử chỉnh sửa comment
- `watchPostReactionCount(postId)`: Stream tổng số reactions trên tất cả comments của post

**Update (4):**
- `editComment(postId, commentId, newText, currentUid)`: Chỉnh sửa comment (lưu edit history, chỉ tác giả)
- `publishScheduledPost(postId, authorUid)`: Publish scheduled post (transaction, chuyển status, increment postsCount)
- `cancelScheduledPost(postId)`: Hủy scheduled post (chuyển status sang cancelled)
- `updateScheduledTime(postId, newScheduledAt)`: Cập nhật thời gian scheduled

**Delete (3):**
- `deletePost(postId, authorUid)`: Xóa post (batch delete likes, comments, post, decrement postsCount, tự động gỡ khỏi pinnedPostIds)
- `deleteComment(postId, commentId, currentUid)`: Xóa comment (transaction, chỉ tác giả hoặc chủ post, decrement commentCount)
- `unlikePost(postId, uid)`: Bỏ like (transaction, decrement likeCount, retry logic)

### 3. ChatRepository
**File:** [`lib/features/chat/repositories/chat_repository.dart`](lib/features/chat/repositories/chat_repository.dart)

**Create (8):**
- `createOrGetDirectConversation(currentUid, otherUid)`: Tạo hoặc lấy conversation 1-1 (tự động tìm existing, tạo participant entry)
- `createGroupConversation(ownerUid, memberIds, name, avatarUrl, description)`: Tạo group chat (batch tạo participants, set owner làm admin)
- `sendTextMessage(conversationId, senderId, text, attachments)`: Gửi tin nhắn text/media (batch update lastMessage, unreadCount)
- `sendImageMessage(conversationId, senderId, attachments, text)`: Gửi tin nhắn hình ảnh (wrapper của sendTextMessage)
- `sendVoiceMessage(conversationId, senderId, attachments, text)`: Gửi voice message (wrapper của sendTextMessage)
- `sendVideoMessage(conversationId, senderId, attachments, text)`: Gửi video message (wrapper của sendTextMessage)
- `addMembersToGroup(conversationId, requesterId, newMemberIds)`: Thêm thành viên vào group (transaction, chỉ admin, update participantIds và membersCount)
- `ensureParticipantEntry(conversationId, uid, role)`: Đảm bảo participant entry tồn tại (tạo nếu chưa có)

**Read (7):**
- `watchConversations(uid)`: Stream danh sách conversations (realtime, orderBy updatedAt)
- `watchMessages(conversationId, limit)`: Stream tin nhắn (realtime, limit 50, reverse order)
- `watchUnreadCount(uid)`: Stream tổng số conversations có tin chưa đọc
- `fetchParticipantIds(conversationId)`: Lấy danh sách participantIds
- `searchMessages(conversationId, searchTerm, limit)`: Tìm kiếm tin nhắn trong conversation (client-side filter)
- `watchParticipantNotificationSettings(conversationId, uid)`: Stream notification settings của participant
- `fetchParticipantNotificationSettings(conversationId, uid)`: Lấy notification settings (one-time)

**Update (7):**
- `editMessage(conversationId, messageId, newText)`: Chỉnh sửa tin nhắn (update text và editedAt trong systemPayload)
- `toggleReaction(conversationId, messageId, uid, emoji)`: Thêm/xóa reaction cho tin nhắn (transaction, update reactions map)
- `markConversationAsRead(conversationId, uid, limit)`: Đánh dấu đã đọc (batch update lastReadAt, unreadCount, seenBy)
- `updateGroupInfo(conversationId, requesterId, name, avatarUrl, description)`: Cập nhật thông tin group (transaction, chỉ admin)
- `setAdminForMember(conversationId, requesterId, targetUid, isAdmin)`: Thêm/gỡ quyền admin (transaction, đảm bảo luôn có ít nhất 1 admin)
- `updateParticipantNotificationSettings(conversationId, uid, notificationsEnabled, mutedUntil)`: Cập nhật notification settings
- `setTyping(uid, conversationId, isTyping)`: Đặt trạng thái đang gõ (update typingIn array trong user_profiles)

**Delete (3):**
- `recallMessage(conversationId, messageId)`: Thu hồi tin nhắn (xóa nội dung, attachments, đánh dấu recalled)
- `removeMemberFromGroup(conversationId, requesterId, targetUid)`: Xóa thành viên khỏi group (transaction, chỉ admin, không dùng cho chính mình)
- `leaveGroup(conversationId, uid)`: Thành viên rời group (transaction, tự động chuyển quyền admin nếu là admin cuối cùng)

### 4. FollowRepository
**File:** [`lib/features/follow/repositories/follow_repository.dart`](lib/features/follow/repositories/follow_repository.dart)

**Create (2):**
- `followUser(followerUid, targetUid)`: Follow user (transaction, tạo entries trong followers/following, increment counters)
- `sendFollowRequest(followerUid, targetUid)`: Gửi yêu cầu follow (tạo trong follow_requests subcollection)

**Read (7):**
- `watchFollowers(uid)`: Stream danh sách followers (realtime, orderBy followedAt)
- `watchFollowing(uid)`: Stream danh sách following (realtime, orderBy followedAt)
- `watchIncomingRequests(uid)`: Stream yêu cầu follow đến (realtime, orderBy createdAt)
- `watchSentRequests(uid)`: Stream yêu cầu follow đã gửi (realtime, collection group query)
- `isFollowing(currentUid, targetUid)`: Kiểm tra đang follow chưa
- `hasPendingRequest(currentUid, targetUid)`: Kiểm tra có yêu cầu follow đang chờ chưa
- `fetchFollowingIds(uid)`: Lấy Set UIDs đang follow

**Update (1):**
- `acceptFollowRequest(targetUid, followerUid)`: Chấp nhận yêu cầu follow (transaction, xóa request, tạo follow relationship, increment counters)

**Delete (3):**
- `unfollowUser(followerUid, targetUid)`: Unfollow (transaction, xóa entries, decrement counters)
- `cancelFollowRequest(followerUid, targetUid)`: Hủy yêu cầu follow đã gửi
- `declineFollowRequest(targetUid, followerUid)`: Từ chối yêu cầu follow

### 5. UserProfileRepository
**File:** [`lib/features/profile/user_profile_repository.dart`](lib/features/profile/user_profile_repository.dart)

**Create (1):**
- `ensureProfile(uid, email, phoneNumber, displayName, photoUrl, bio, isPrivate)`: Tạo hoặc update profile (merge, không overwrite displayName/photoUrl nếu đã có)

**Read (4):**
- `watchProfile(uid)`: Stream profile (realtime)
- `fetchProfile(uid)`: Lấy profile (one-time)
- `searchUsers(query, limit)`: Tìm kiếm users (prefix matching trên displayNameLower, emailLower, phoneNumber)
- `searchUsersWithFilters(query, limit, isFollowing, isPrivate)`: Tìm kiếm với filters (privacy, follow status)

**Update (10):**
- `updateProfile(uid, displayName, photoUrl, phoneNumber, removePhoto, bio, note, isPrivate, themeColor, links, showOnlineStatus, lastSeenVisibility, messagePermission)`: Cập nhật profile (merge, xóa field nếu cần)
- `updatePrivacySettings(uid, showOnlineStatus, lastSeenVisibility, messagePermission)`: Cập nhật privacy settings
- `setPresence(uid, isOnline)`: Cập nhật trạng thái online/offline và lastSeen
- `updatePinnedPosts(uid, postIds)`: Cập nhật pinned posts (validate max 3, loại bỏ duplicate)
- `updatePinnedStories(uid, storyIds)`: Cập nhật pinned stories (validate max 3)
- `addPinnedPost(uid, postId)`: Thêm pinned post (validate limit 3)
- `removePinnedPost(uid, postId)`: Xóa pinned post
- `reorderPinnedPosts(uid, newOrder)`: Sắp xếp lại thứ tự pinned posts
- `updateHighlightedStories(uid, highlightedStories)`: Cập nhật highlighted stories
- `updateBanStatus(uid, banStatus, banExpiresAt, activeBanId)`: Cập nhật ban status (admin only)

**Delete (2):**
- `removePinnedPost(uid, postId)`: Xóa pinned post
- `removePinnedStory(uid, storyId)`: Xóa pinned story

### 6. StoryRepository
**File:** [`lib/features/stories/repositories/story_repository.dart`](lib/features/stories/repositories/story_repository.dart)

**Create (5):**
- `createStory(authorUid, mediaUrl, type, thumbnailUrl, text)`: Tạo story mới (expires sau 24h, validate auth)
- `uploadAndCreateStoryImage(authorUid, file, text)`: Upload ảnh lên Cloudinary và tạo story
- `uploadAndCreateStoryVideo(authorUid, file, text)`: Upload video lên Cloudinary và tạo story
- `repostStory(authorUid, story)`: Đăng lại story từ archive (tạo story mới với media cũ)
- `addViewer(authorUid, storyId, viewerUid)`: Ghi nhận viewer (best effort, merge)

**Read (6):**
- `watchUserStories(uid)`: Stream stories còn hiệu lực của user (realtime, filter expired)
- `fetchStoryRingStatus(ownerUid, viewerUid)`: Lấy trạng thái vòng story (none/unseen/allSeen)
- `watchUserStoryArchive(uid, limit)`: Stream toàn bộ stories (kể cả expired, limit 200)
- `fetchStoriesByAuthor(uid, limit)`: Stream stories theo author (kể cả expired)
- `fetchViewerEntries(authorUid, storyId)`: Lấy danh sách viewers kèm trạng thái liked
- `isStoryLikedByUser(authorUid, storyId, viewerUid)`: Kiểm tra user đã like story chưa

**Update (1):**
- `toggleStoryLike(authorUid, storyId, likerUid)`: Toggle like story (update liked flag trong viewer doc)

**Delete (1):**
- `deleteStory(authorUid, storyId)`: Xóa story

### 7. NotificationRepository
**File:** [`lib/features/notifications/repositories/notification_repository.dart`](lib/features/notifications/repositories/notification_repository.dart)

**Create (1):**
- `createNotification(notification, maxRetries)`: Tạo notification mới (retry logic với exponential backoff)

**Read (4):**
- `watchNotifications(uid, limit)`: Stream notifications của user (realtime, orderBy createdAt, limit 50)
- `watchUnreadCount(uid)`: Stream số lượng notifications chưa đọc
- `fetchNotificationsInRange(uid, startDate, endDate)`: Lấy notifications trong khoảng thời gian (để generate digest)
- `findGroupedNotification(groupKey, toUid, timeWindow)`: Tìm grouped notification trong time window (1h mặc định)

**Update (3):**
- `markAsRead(notificationId)`: Đánh dấu một notification đã đọc
- `markAllAsRead(uid)`: Đánh dấu tất cả notifications đã đọc (batch update)
- `updateGroupedNotification(notificationId, fromUid)`: Update grouped notification (tăng count, thêm fromUid vào list, max 50)

### 8. CallRepository
**File:** [`lib/features/call/repositories/call_repository.dart`](lib/features/call/repositories/call_repository.dart)

**Create (2):**
- `createCall(callerUid, calleeUid, type, conversationId)`: Tạo cuộc gọi mới (status: ringing)
- `addIceCandidate(callId, candidate, isCaller)`: Thêm ICE candidate (lưu vào subcollection)

**Read (5):**
- `watchCall(callId)`: Stream call document (realtime)
- `fetchCall(callId)`: Lấy call document (one-time)
- `fetchCallHistory(uid, limit, startAfter)`: Lấy lịch sử cuộc gọi (pagination, filter callerUid hoặc calleeUid)
- `watchActiveCalls(uid)`: Stream các cuộc gọi đang active (ringing hoặc accepted)
- `watchIceCandidates(callId, listenForCaller)`: Stream ICE candidates từ remote peer (realtime)

**Update (3):**
- `updateCallStatus(callId, status, startedAt, endedAt, duration)`: Cập nhật trạng thái cuộc gọi
- `updateCallSignaling(callId, offer, answer)`: Cập nhật signaling data (offer, answer)
- `endCall(callId, status, endedAt, duration)`: Kết thúc cuộc gọi

**Delete (1):**
- `clearSignalingData(callId)`: Dọn dẹp signaling data sau khi kết thúc (xóa offer/answer/candidates)

### 9. AdminRepository
**File:** [`lib/features/admin/repositories/admin_repository.dart`](lib/features/admin/repositories/admin_repository.dart)

**Read (5):**
- `isAdmin(uid)`: Kiểm tra user có phải admin không
- `watchAdminStatus(uid)`: Stream admin status (realtime)
- `getAllAdmins()`: Lấy danh sách admin UIDs
- `getAdmin(uid)`: Lấy admin document
- `watchAllAdmins()`: Stream tất cả admins (để gửi notification)

### 10. BanRepository
**File:** [`lib/features/admin/repositories/ban_repository.dart`](lib/features/admin/repositories/ban_repository.dart)

**Create (1):**
- `createBan(uid, banType, banLevel, reason, reportId, adminUid, expiresAt)`: Tạo ban mới (isActive: true)

**Read (6):**
- `getActiveBan(uid)`: Lấy ban đang active của user
- `watchActiveBan(uid)`: Stream ban status (realtime)
- `getBan(banId)`: Lấy ban theo ID
- `getAllBans(banType, banLevel, isActive)`: Lấy danh sách bans với filter (admin view)
- `watchAllBans(banType, banLevel, isActive)`: Stream tất cả bans (admin view)
- `checkIfBanned(uid)`: Kiểm tra user có bị ban không (auto unban nếu expired)

**Update (2):**
- `unbanUser(banId, adminUid, reason)`: Mở khóa tài khoản (set isActive: false)
- `updateBanAppealId(banId, appealId)`: Cập nhật appealId vào ban

### 11. AppealRepository
**File:** [`lib/features/admin/repositories/appeal_repository.dart`](lib/features/admin/repositories/appeal_repository.dart)

**Create (1):**
- `createAppeal(uid, banId, reason, evidence)`: Tạo đơn kháng cáo (status: pending)

**Read (6):**
- `watchPendingAppeals()`: Stream appeals chưa xử lý (admin view, realtime)
- `getAppeal(appealId)`: Lấy chi tiết appeal
- `getAppealsByUser(uid)`: Lấy appeals của một user
- `watchAppealsByUser(uid)`: Stream appeals của user (realtime)
- `getAllAppeals(status)`: Lấy tất cả appeals với filter (admin view)
- `watchAllAppeals(status)`: Stream tất cả appeals (admin view, realtime)

**Update (1):**
- `updateAppealStatus(appealId, status, adminUid, adminNotes)`: Cập nhật status appeal (pending/approved/rejected)

### 12. ReportRepository
**File:** [`lib/features/safety/repositories/report_repository.dart`](lib/features/safety/repositories/report_repository.dart)

**Create (1):**
- `submitReport(reporterUid, targetType, targetId, targetOwnerUid, reason)`: Gửi báo cáo (status: pending)

**Read (5):**
- `watchPendingReports()`: Stream reports chưa xử lý (admin view, realtime)
- `watchReports(status)`: Stream reports với filter (admin view, realtime)
- `getReport(reportId)`: Lấy chi tiết report
- `getReportsByTarget(targetUid)`: Lấy tất cả reports về một user (admin view)
- `getAllReports(status)`: Lấy tất cả reports với filter (admin view)

**Update (1):**
- `updateReportStatus(reportId, status, adminNotes, adminUid, banId, actionTaken)`: Cập nhật status report (pending/resolved/dismissed)

### 13. BlockRepository
**File:** [`lib/features/safety/repositories/block_repository.dart`](lib/features/safety/repositories/block_repository.dart)

**Create (1):**
- `blockUser(blockerUid, blockedUid, reason)`: Chặn user (lưu vào blocks/{blockerUid}/items/{blockedUid})

**Read (5):**
- `watchBlock(blockerUid, blockedUid)`: Stream block status (realtime)
- `isBlocked(blockerUid, blockedUid)`: Kiểm tra đã chặn chưa
- `isEitherBlocked(uidA, uidB)`: Kiểm tra một trong hai đã chặn nhau chưa
- `watchBlockedIds(blockerUid)`: Stream danh sách blocked UIDs (realtime)
- `fetchBlockedIds(blockerUid)`: Lấy danh sách blocked UIDs (one-time)

**Delete (1):**
- `unblockUser(blockerUid, blockedUid)`: Bỏ chặn user

### 14. SavedPostsRepository
**File:** [`lib/features/saved_posts/repositories/saved_posts_repository.dart`](lib/features/saved_posts/repositories/saved_posts_repository.dart)

**Create (1):**
- `savePost(uid, postId, postOwnerUid, postUrl)`: Lưu post (lưu vào saved_posts/{uid}/items/{postId})

**Read (5):**
- `watchSavedPosts(uid, limit)`: Stream saved posts (realtime, orderBy savedAt, limit 50)
- `watchIsSaved(uid, postId)`: Stream trạng thái đã lưu (realtime)
- `isSaved(uid, postId)`: Kiểm tra đã lưu chưa (one-time)
- `fetchSavedPosts(uid, limit)`: Lấy saved posts (one-time, pagination)
- `fetchSavedPostsPage(uid, startAfter, limit)`: Lấy saved posts với pagination

**Delete (1):**
- `unsavePost(uid, postId)`: Bỏ lưu post

### 15. DraftPostRepository
**File:** [`lib/features/posts/repositories/draft_post_repository.dart`](lib/features/posts/repositories/draft_post_repository.dart)

**Create (1):**
- `saveDraft(uid, media, caption, hashtags)`: Lưu draft mới (tự động extract hashtags từ caption)

**Read (3):**
- `fetchDraft(uid, draftId)`: Lấy một draft
- `watchDrafts(uid)`: Stream tất cả drafts (realtime, orderBy updatedAt)
- `fetchDrafts(uid, limit, startAfter)`: Lấy drafts với pagination

**Update (1):**
- `updateDraft(uid, draftId, media, caption, hashtags)`: Cập nhật draft (merge)

**Delete (1):**
- `deleteDraft(uid, draftId)`: Xóa draft

### 16. SearchHistoryRepository
**File:** [`lib/features/search/repositories/search_history_repository.dart`](lib/features/search/repositories/search_history_repository.dart)

**Create (1):**
- `saveSearchHistory(uid, query, searchType)`: Lưu lịch sử tìm kiếm (normalize query, update createdAt nếu đã có, giới hạn 50 mục)

**Read (2):**
- `getSearchHistory(uid, searchType, limit)`: Lấy lịch sử tìm kiếm (one-time, orderBy createdAt)
- `watchSearchHistory(uid, searchType, limit)`: Stream lịch sử tìm kiếm (realtime)

**Delete (2):**
- `deleteSearchHistory(uid, historyId)`: Xóa một lịch sử tìm kiếm
- `clearSearchHistory(uid, searchType)`: Xóa tất cả lịch sử (batch delete)

### 17. SavedAccountsRepository
**File:** [`lib/features/auth/saved_accounts_repository.dart`](lib/features/auth/saved_accounts_repository.dart)

**Create (2):**
- `saveAccountFromUser(user)`: Lưu account từ Firebase User (lấy avatar từ profile nếu có)
- `upsertAccount(account)`: Thêm hoặc cập nhật account (lưu vào SharedPreferences)

**Read (1):**
- `getAccounts()`: Lấy danh sách saved accounts (sắp xếp theo lastUsedAt)

**Delete (2):**
- `removeAccount(uid)`: Xóa một account
- `clear()`: Xóa tất cả accounts

### 18. SavedCredentialsRepository
**File:** [`lib/features/auth/saved_credentials_repository.dart`](lib/features/auth/saved_credentials_repository.dart)

**Create (1):**
- `savePassword(uid, password)`: Lưu mật khẩu (FlutterSecureStorage, key: cred_{uid})

**Read (1):**
- `getPassword(uid)`: Lấy mật khẩu đã lưu

**Delete (2):**
- `removePassword(uid)`: Xóa mật khẩu của một account
- `clearAll()`: Xóa tất cả credentials (filter theo prefix)

### 19. NotificationDigestRepository
**File:** [`lib/features/notifications/repositories/notification_digest_repository.dart`](lib/features/notifications/repositories/notification_digest_repository.dart)

**Create (1):**
- `createDigest(digest)`: Tạo digest mới (lưu vào notification_digests/{uid}/items/{digestId})

**Read (4):**
- `fetchDigest(uid, digestId)`: Lấy digest theo ID
- `fetchDigests(uid, period, limit, startAfter)`: Lấy digests với pagination
- `watchDigests(uid, period, limit)`: Stream digests (realtime, filter period client-side)
- `findDigestForPeriod(uid, period, startDate)`: Tìm digest cho một period cụ thể

**Delete (1):**
- `deleteDigest(uid, digestId)`: Xóa digest cũ (cleanup)

## Chức năng không phải CRUD

### Services (Business Logic Layer)

#### 1. PostService
**File:** [`lib/features/posts/services/post_service.dart`](lib/features/posts/services/post_service.dart)

**Non-CRUD Functions (15):**
- `fetchFeedPage(startAfter, limit)`: Lấy feed page với author info
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
- `fetchFeedPageWithFilters(filters, startAfter, limit)`: Lấy feed với filters và author info
- `createPost(media, caption, scheduledAt)`: Upload media lên Cloudinary/Firebase Storage và tạo post
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
- `saveDraft(media, caption)`: Lưu draft (không upload media)
- `updateDraft(draftId, media, caption)`: Cập nhật draft
- `fetchDraft(draftId)`: Lấy draft
- `deleteDraft(draftId)`: Xóa draft
- `toggleLike(postId, like)`: Toggle like và tạo notification
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
- `watchComments(postId)`: Stream comments với author info và reactions
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
- `addComment(postId, text, parentCommentId, replyToUid)`: Thêm comment và tạo notification
- `watchPost(postId)`: Stream post
- `watchPostReactionCount(postId)`: Stream tổng reactions
- `watchLikeStatus(postId)`: Stream like status của user
- `setCommentReaction(postId, commentId, reaction)`: Set reaction và tạo notification
- `deletePost(postId)`: Xóa post và media từ Cloudinary
- `editComment(postId, commentId, newText)`: Chỉnh sửa comment
- `getCommentEditHistory(postId, commentId)`: Stream edit history
- `deleteComment(postId, commentId)`: Xóa comment

#### 2. ConversationService
**File:** [`lib/features/chat/services/conversation_service.dart`](lib/features/chat/services/conversation_service.dart)

**Non-CRUD Functions (7):**
- `watchConversationEntries(uid)`: Stream conversations với title, avatar, subtitle
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
- `_buildEntry(currentUid, summary)`: Build conversation entry với profile info
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
- `createGroup(ownerUid, memberIds, name, avatarUrl, description)`: Tạo group (wrapper)
- `addMembers(conversationId, requesterId, newMemberIds)`: Thêm members (wrapper)
- `removeMember(conversationId, requesterId, targetUid)`: Xóa member (wrapper)
- `leaveGroup(conversationId, uid)`: Rời group (wrapper)
- `updateGroupInfo(conversationId, requesterId, name, avatarUrl, description)`: Update group info (wrapper)
- `setAdmin(conversationId, requesterId, targetUid, isAdmin)`: Set admin (wrapper)

#### 3. FollowService
**File:** [`lib/features/follow/services/follow_service.dart`](lib/features/follow/services/follow_service.dart)

**Non-CRUD Functions (10):**
- `searchUsers(keyword, limit)`: Tìm kiếm users với normalize và backfill lowercase fields
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
- `followUser(targetUid)`: Follow user với logic private/public, tạo notification
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
- `cancelRequest(targetUid)`: Hủy follow request
- `unfollow(targetUid)`: Unfollow user
- `acceptRequest(followerUid)`: Chấp nhận request và tạo notification
- `declineRequest(followerUid)`: Từ chối request
- `watchFollowState(currentUid, targetUid)`: Stream follow state với profile info
  ```dart
  Stream<FollowState> watchFollowState(String currentUid, String targetUid) {
    return _profiles.watchProfile(targetUid).asyncMap((profile) async {
      final isFollowing = await _repository.isFollowing(currentUid: currentUid, targetUid: targetUid);
      final hasRequest = await _repository.hasPendingRequest(currentUid: currentUid, targetUid: targetUid);
      return FollowState(status: isFollowing ? FollowStatus.following : (hasRequest ? FollowStatus.requested : FollowStatus.none), ...);
    });
  }
  ```
- `fetchFollowStatus(currentUid, targetUid)`: Lấy follow status (one-time)
- `watchFollowingEntries(uid)`: Stream following với mutual follow check
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
- `watchFollowersEntries(uid)`: Stream followers với mutual follow check
- `watchIncomingRequestEntries(uid)`: Stream incoming requests với profile info
- `watchSentRequestEntries(uid)`: Stream sent requests với profile info

#### 4. NotificationService
**File:** [`lib/features/notifications/services/notification_service.dart`](lib/features/notifications/services/notification_service.dart)

**Non-CRUD Functions (12):**
- `_generateGroupKey(type, toUid, postId)`: Generate group key cho notification grouping
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
- `createLikeNotification(postId, likerUid, postAuthorUid)`: Tạo like notification với grouping
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
- `createCommentNotification(...)`: Tạo comment notification với commenter name
- `createFollowNotification(followerUid, followedUid)`: Tạo follow notification với grouping
- `createMessageNotification(...)`: Tạo message notification
- `createStoryLikeNotification(...)`: Tạo story like notification
- `createCommentReactionNotification(...)`: Tạo comment reaction notification
- `createCallNotification(...)`: Tạo call notification
- `createReportNotification(reportId, reporterUid, targetUid)`: Tạo notification cho tất cả admins
  ```dart
  Future<void> createReportNotification({required String reportId, required String reporterUid, required String targetUid}) async {
    final adminUids = await _adminRepository.getAllAdmins();
    for (final adminUid in adminUids) {
      await _repository.createNotification(Notification(type: NotificationType.report, fromUid: reporterUid, toUid: adminUid, reportId: reportId, ...));
    }
  }
  ```
- `createAppealNotification(appealId, uid, banId)`: Tạo notification cho tất cả admins
- `markAsRead(notificationId)`: Đánh dấu đã đọc (wrapper)
- `markAllAsRead(uid)`: Đánh dấu tất cả đã đọc (wrapper)
- `watchNotifications(uid)`: Stream notifications (wrapper)
- `watchUnreadCount(uid)`: Stream unread count (wrapper)

#### 5. CloudinaryService
**File:** [`lib/services/cloudinary_service.dart`](lib/services/cloudinary_service.dart)

**Non-CRUD Functions (5):**
- `uploadImage(file, folder, publicId)`: Upload ảnh lên Cloudinary với signature
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
- `uploadVideo(file, folder, publicId)`: Upload video lên Cloudinary với thumbnail
  ```dart
  static Future<Map<String, dynamic>> uploadVideo({required XFile file, String? folder, String? publicId}) async {
    // Similar to uploadImage but with resource_type: 'video'
    // Returns: url, thumbnailUrl, durationMs, publicId
  }
  ```
- `uploadAudio(file, folder, publicId)`: Upload audio/voice lên Cloudinary
- `_generateSignature(params)`: Tạo signature cho Cloudinary API (SHA1)
  ```dart
  static String _generateSignature(Map<String, String> params) {
    final sortedKeys = params.keys.toList()..sort();
    final signString = sortedKeys.map((key) => '$key=${params[key]}').join('&');
    final stringToSign = '$signString${CloudinaryConfig.apiSecret}';
    final hash = sha1.convert(utf8.encode(stringToSign));
    return hash.toString();
  }
  ```
- `deleteFile(publicId, resourceType)`: Xóa file từ Cloudinary

#### 6. CallService
**File:** [`lib/features/call/services/call_service.dart`](lib/features/call/services/call_service.dart)

**Non-CRUD Functions (8):**
- `initiateCall(calleeUid, type, conversationId)`: Khởi tạo cuộc gọi với validation
  ```dart
  Future<String> initiateCall({required String calleeUid, required CallType type, String? conversationId}) async {
    final calleeProfile = await _profileRepository.fetchProfile(calleeUid);
    if (calleeProfile == null) throw StateError('Không tìm thấy người dùng');
    final callId = await _repository.createCall(callerUid: currentUid, calleeUid: calleeUid, type: type, conversationId: conversationId);
    return callId;
  }
  ```
- `answerCall(callId)`: Chấp nhận cuộc gọi với validation
- `rejectCall(callId)`: Từ chối cuộc gọi
- `endCall(callId)`: Kết thúc cuộc gọi và tính duration
  ```dart
  Future<void> endCall(String callId) async {
    final call = await _repository.fetchCall(callId);
    final duration = call.startedAt != null ? DateTime.now().difference(call.startedAt!).inSeconds : null;
    await _repository.endCall(callId, status: CallStatus.ended, endedAt: DateTime.now(), duration: duration);
    unawaited(_repository.clearSignalingData(callId));
  }
  ```
- `cancelCall(callId)`: Hủy cuộc gọi (chỉ caller)
- `handleMissedCall(callId)`: Xử lý missed call (timeout)
- `watchCall(callId)`: Stream call (wrapper)
- `watchActiveCalls(uid)`: Stream active calls (wrapper)
- `fetchCallHistory(uid, limit)`: Lấy call history (wrapper)

#### 7. WebRTCService
**File:** [`lib/features/call/services/webrtc_service.dart`](lib/features/call/services/webrtc_service.dart)

**Non-CRUD Functions (15):**
- `initializeCaller(callId, callType, localRenderer, remoteRenderer)`: Khởi tạo WebRTC cho caller
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
- `initializeCallee(callId, callType, localRenderer, remoteRenderer)`: Khởi tạo WebRTC cho callee
- `_watchForOffer(callId)`: Lắng nghe offer và tạo answer
- `_handleOffer(callId, offer)`: Xử lý offer từ caller
- `_watchForAnswer(callId)`: Lắng nghe answer từ callee
- `_handleAnswer(answer)`: Xử lý answer
- `_handleIceCandidate(callId, candidate)`: Xử lý ICE candidate local
- `_watchForIceCandidates(callId)`: Lắng nghe ICE candidates từ remote
- `_handleIceCandidateFromRemote(candidateData)`: Xử lý ICE candidate từ remote
- `_createPeerConnection()`: Tạo RTCPeerConnection với STUN servers
  ```dart
  Future<RTCPeerConnection> _createPeerConnection() async {
    final configuration = {
      'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}],
    };
    return await createPeerConnection(configuration, constraints);
  }
  ```
- `_getUserMedia(callType)`: Lấy camera/microphone stream
  ```dart
  Future<MediaStream> _getUserMedia(CallType callType) async {
    final constraints = {
      'audio': true,
      'video': callType == CallType.video ? {'facingMode': 'user', 'width': {'ideal': 1280}, 'height': {'ideal': 720}} : false,
    };
    return await navigator.mediaDevices.getUserMedia(constraints);
  }
  ```
- `toggleMicrophone()`: Toggle microphone on/off
- `toggleCamera()`: Toggle camera on/off
- `switchCamera()`: Switch front/back camera
- `dispose()`: Giải phóng resources (streams, connections, renderers)
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
- `normalizeQuery(query)`: Chuẩn hóa search query (trim, lowercase)
  ```dart
  String normalizeQuery(String query) {
    return query.trim().toLowerCase();
  }
  ```
- `searchUsers(query, limit)`: Tìm kiếm users với normalize
- `searchUsersWithFilters(query, filters, limit, checkFollowing)`: Tìm kiếm với filters (privacy, follow status)
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
- `searchPosts(query, limit)`: Tìm kiếm posts với normalize

#### 9. ShareService
**File:** [`lib/features/share/services/share_service.dart`](lib/features/share/services/share_service.dart)

**Non-CRUD Functions (6):**
- `sharePost(postId, caption)`: Share post với deep link
  ```dart
  static Future<void> sharePost({required String postId, String? caption}) async {
    final link = DeepLink.generatePostLink(postId);
    final text = caption != null ? '$caption\n\nXem bài viết: $link' : 'Xem bài viết: $link';
    await Share.share(text);
  }
  ```
- `shareProfile(uid, displayName)`: Share profile với deep link
- `shareHashtag(hashtag)`: Share hashtag với deep link
- `copyLink(link)`: Copy link vào clipboard
  ```dart
  static Future<void> copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
  }
  ```
- `copyPostLink(postId)`: Copy post link
- `copyProfileLink(uid)`: Copy profile link
- `copyHashtagLink(hashtag)`: Copy hashtag link

#### 10. BlockService
**File:** [`lib/features/safety/services/block_service.dart`](lib/features/safety/services/block_service.dart)

**Non-CRUD Functions (5):**
- `watchIsBlocked(blockerUid, blockedUid)`: Stream block status
- `isBlockedByMe(targetUid)`: Kiểm tra đã chặn chưa (wrapper với current user)
- `isEitherBlocked(uidA, uidB)`: Kiểm tra một trong hai đã chặn nhau (wrapper)
- `blockUser(targetUid, reason, onCompleted)`: Chặn user với validation
- `unblockUser(targetUid)`: Bỏ chặn user (wrapper)
- `watchMyBlockedIds()`: Stream blocked IDs của current user
- `fetchMyBlockedIds()`: Lấy blocked IDs của current user (one-time)

#### 11. AdminService
**File:** [`lib/features/admin/services/admin_service.dart`](lib/features/admin/services/admin_service.dart)

**Non-CRUD Functions (5):**
- `isAdmin(uid)`: Kiểm tra admin (wrapper)
- `watchAdminStatus(uid)`: Stream admin status (wrapper)
- `banUser(uid, banType, banLevel, reason, adminUid, reportId, expiresAt)`: Ban user và update profile
  ```dart
  Future<void> banUser({required String uid, required BanType banType, required BanLevel banLevel, required String reason, required String adminUid, String? reportId, DateTime? expiresAt}) async {
    final banId = await _banRepository.createBan(uid: uid, banType: banType, banLevel: banLevel, reason: reason, adminUid: adminUid, expiresAt: expiresAt);
    await _profileRepository.updateBanStatus(uid, banStatus: banType == BanType.permanent ? BanStatus.permanent : BanStatus.temporary, banExpiresAt: expiresAt, activeBanId: banId);
    if (reportId != null) {
      await _reportRepository.updateReportStatus(reportId, ReportStatus.resolved, adminUid: adminUid, banId: banId, actionTaken: ReportAction.banned);
    }
  }
  ```
- `unbanUser(banId, adminUid, reason)`: Unban user và update profile
  ```dart
  Future<void> unbanUser(String banId, {required String adminUid, String? reason}) async {
    final ban = await _banRepository.getBan(banId);
    await _banRepository.unbanUser(banId, adminUid, reason: reason);
    await _profileRepository.updateBanStatus(ban.uid, banStatus: BanStatus.none, banExpiresAt: null, activeBanId: null);
  }
  ```
- `resolveReport(reportId, action, adminUid, adminNotes, banId)`: Xử lý report
- `processAppeal(appealId, decision, adminUid, adminNotes)`: Xử lý appeal và unban nếu approve
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
- `reportUser(targetUid, reason)`: Báo cáo user và tạo notification cho admins
  ```dart
  Future<void> reportUser({required String targetUid, required String reason}) async {
    final reportId = await _repository.submitReport(reporterUid: reporterUid, targetType: ReportTargetType.user, targetId: targetUid, targetOwnerUid: targetUid, reason: reason);
    await _notificationService.createReportNotification(reportId: reportId, reporterUid: reporterUid, targetUid: targetUid);
  }
  ```
- `reportPost(postId, ownerUid, reason)`: Báo cáo post

#### 13. SavedPostsService
**File:** [`lib/features/saved_posts/services/saved_posts_service.dart`](lib/features/saved_posts/services/saved_posts_service.dart)

**Non-CRUD Functions (6):**
- `watchMySavedPosts(limit)`: Stream saved posts của current user
- `watchIsPostSaved(postId)`: Stream saved status của current user
- `isPostSaved(postId)`: Kiểm tra đã lưu (one-time)
- `buildPostLink(postId)`: Build deep link cho post
  ```dart
  static String buildPostLink(String postId) {
    return 'kmessapp://posts/$postId';
  }
  ```
- `savePost(postId, postOwnerUid, postUrl)`: Lưu post với deep link
- `unsavePost(postId)`: Bỏ lưu post
- `toggleSaved(postId, postOwnerUid, postUrl)`: Toggle saved status
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
- `fetchMySavedPosts(limit)`: Lấy saved posts (one-time)

#### 14. PostSchedulingService
**File:** [`lib/features/posts/services/post_scheduling_service.dart`](lib/features/posts/services/post_scheduling_service.dart)

**Non-CRUD Functions (1):**
- `checkAndPublishScheduledPosts()`: Kiểm tra và publish scheduled posts đã đến giờ
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
- `normalizePhone(raw)`: Chuẩn hóa số điện thoại về E.164 format
  ```dart
  String normalizePhone(String raw) {
    var phone = raw.replaceAll(RegExp(r'[\s\-]'), '');
    if (phone.startsWith('+')) return phone;
    if (phone.startsWith('0')) return '+84${phone.substring(1)}';
    throw FormatException('Số điện thoại phải ở dạng +[mã quốc gia][số] hoặc bắt đầu bằng 0');
  }
  ```
- `sendCode(phoneNumber)`: Gửi mã SMS với error handling
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
- `signInWithCode(verificationId, smsCode)`: Đăng nhập với mã SMS
- `linkPhoneWithCode(user, verificationId, smsCode)`: Link số điện thoại với account

#### 16. NotificationDigestService
**File:** [`lib/features/notifications/services/notification_digest_service.dart`](lib/features/notifications/services/notification_digest_service.dart)

**Non-CRUD Functions (6):**
- `generateDailyDigest(uid, date)`: Generate daily digest với stats và top posts
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
- `generateWeeklyDigest(uid, weekStart)`: Generate weekly digest
- `_aggregateStats(notifications)`: Aggregate stats từ notifications
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
- `aggregateCommentsByPost(notifications)`: Nhóm comments theo postId
- `_findTopPosts(notifications)`: Tìm top 5 posts có nhiều tương tác nhất
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
- `_getStartOfWeek(date)`: Lấy start of week (Monday)
- `watchDigests(uid, period, limit)`: Stream digests (wrapper)
- `fetchDigests(uid, period, limit)`: Lấy digests (wrapper)

#### 17. DeepLinkService
**File:** [`lib/features/share/services/deep_link_service.dart`](lib/features/share/services/deep_link_service.dart)

**Non-CRUD Functions (2):**
- `handleDeepLink(context, link)`: Handle deep link và navigate đến page tương ứng
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
- `_showError(context, message)`: Hiển thị error message

### Helper Methods trong Repositories

#### 1. PostRepository
- `extractHashtagsFromCaption(caption)`: Extract hashtags từ caption (static method)
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
- `canCreateConversation(senderUid, receiverUid, isFollowing)`: Kiểm tra có thể tạo conversation không
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
- `canViewLastSeen(viewerUid, profileUid, isFollowing)`: Kiểm tra có thể xem last seen không
  ```dart
  bool canViewLastSeen({required String viewerUid, required String profileUid, required bool isFollowing}) {
    if (viewerUid == profileUid) return true;
    // Logic sẽ được xử lý trong UI layer với profile data
    return true;
  }
  ```
- `canSendMessage(senderUid, receiverUid, isFollowing, messagePermission)`: Kiểm tra có thể nhắn tin không
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
- `fetchStoryRingStatus(ownerUid, viewerUid)`: Lấy trạng thái vòng story (none/unseen/allSeen)
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

----Models (Mô hình dữ liệu)----
Mục đích: Định nghĩa cấu trúc dữ liệu (data classes) cho các entity trong ứng dụng
Ví dụ: Post, Message, Story, Notification
Chức năng:
Chứa các class Dart đại diện cho dữ liệu
Chuyển đổi dữ liệu từ Firestore/API sang object Dart (factory methods như fromDoc, fromMap)
Định nghĩa các thuộc tính và kiểu dữ liệu

----Pages (Giao diện màn hình)----
Mục đích: Chứa các màn hình UI (StatefulWidget/StatelessWidget)
Ví dụ: PostFeedPage, ChatDetailPage, StoryViewerPage
Chức năng:
Xây dựng giao diện người dùng
Xử lý tương tác (tap, scroll, input)
Quản lý state của màn hình
Gọi services/repositories để lấy dữ liệu

----Repositories (Tầng truy cập dữ liệu)----
Mục đích: Lớp trung gian giữa UI và nguồn dữ liệu (Firestore, API)
Ví dụ: PostRepository, ChatRepository, StoryRepository
Chức năng:
Thực hiện các thao tác CRUD với database
Đọc/ghi dữ liệu từ Firestore
Xử lý query, filter, pagination
Trả về dữ liệu dạng raw (DocumentSnapshot, QuerySnapshot)

---Services (Tầng xử lý nghiệp vụ)---
Mục đích: Xử lý logic nghiệp vụ phức tạp, kết hợp nhiều repositories
Ví dụ: PostService, ConversationService, NotificationService
Chức năng:
Kết hợp nhiều repositories để thực hiện một tác vụ
Xử lý upload file (ảnh, video) lên Cloudinary/Firebase Storage
Xử lý business logic (ví dụ: tạo post → upload media → lưu vào Firestore → gửi notification)
Chuyển đổi dữ liệu từ repository sang model để UI sử dụng