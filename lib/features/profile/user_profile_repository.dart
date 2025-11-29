import 'package:cloud_firestore/cloud_firestore.dart';

enum LastSeenVisibility {
  everyone,
  followers,
  nobody,
}

enum MessagePermission {
  everyone,
  followers,
  nobody,
}

class ProfileLink {
  ProfileLink({
    required this.url,
    required this.label,
  });

  final String url;
  final String label;

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'label': label,
    };
  }

  factory ProfileLink.fromMap(Map<String, dynamic> map) {
    return ProfileLink(
      url: map['url'] as String? ?? '',
      label: map['label'] as String? ?? '',
    );
  }
}

class UserProfile {
  UserProfile({
    required this.uid,
    this.displayName,
    this.displayNameLower,
    this.bio,
    this.photoUrl,
    this.phoneNumber,
    this.email,
    this.emailLower,
    this.isOnline = false,
    this.isPrivate = false,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    this.updatedAt,
    this.lastSeen,
    this.themeColor,
    this.links = const [],
    this.pinnedPostIds = const [],
    this.showOnlineStatus = true,
    this.lastSeenVisibility = LastSeenVisibility.everyone,
    this.messagePermission = MessagePermission.everyone,
  });

  final String uid;
  final String? displayName;
  final String? displayNameLower;
  final String? bio;
  final String? photoUrl;
  final String? phoneNumber;
  final String? email;
  final String? emailLower;
  final bool isOnline;
  final bool isPrivate;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final DateTime? updatedAt;
  final DateTime? lastSeen;
  final String? themeColor; // Hex color code (e.g., "#FF5733")
  final List<ProfileLink> links; // List of external links
  final List<String> pinnedPostIds; // List of pinned post IDs (max 3)
  final bool showOnlineStatus; // Hiển thị trạng thái online/offline
  final LastSeenVisibility lastSeenVisibility; // Ai được xem last seen
  final MessagePermission messagePermission; // Ai được phép nhắn tin

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'displayNameLower': displayNameLower ?? displayName?.toLowerCase(),
      'bio': bio,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'email': email,
      'emailLower': emailLower ?? email?.toLowerCase(),
      'isOnline': isOnline,
      'isPrivate': isPrivate,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'postsCount': postsCount,
      'updatedAt': updatedAt,
      'lastSeen': lastSeen,
      'themeColor': themeColor,
      'links': links.map((link) => link.toMap()).toList(),
      'pinnedPostIds': pinnedPostIds,
      'showOnlineStatus': showOnlineStatus,
      'lastSeenVisibility': lastSeenVisibility.name,
      'messagePermission': messagePermission.name,
    };
  }

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final linksData = data['links'] as List<dynamic>? ?? [];
    final links = linksData
        .map((item) => ProfileLink.fromMap(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
    final pinnedPostIdsData = data['pinnedPostIds'] as List<dynamic>? ?? [];
    final pinnedPostIds = pinnedPostIdsData
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
    
    // Parse privacy settings với default values
    final lastSeenVisibilityStr = data['lastSeenVisibility'] as String? ?? 'everyone';
    final lastSeenVisibility = LastSeenVisibility.values.firstWhere(
      (e) => e.name == lastSeenVisibilityStr,
      orElse: () => LastSeenVisibility.everyone,
    );
    
    final messagePermissionStr = data['messagePermission'] as String? ?? 'everyone';
    final messagePermission = MessagePermission.values.firstWhere(
      (e) => e.name == messagePermissionStr,
      orElse: () => MessagePermission.everyone,
    );
    
    return UserProfile(
      uid: doc.id,
      displayName: data['displayName'] as String?,
      displayNameLower: data['displayNameLower'] as String?,
      bio: data['bio'] as String?,
      photoUrl: data['photoUrl'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      email: data['email'] as String?,
      emailLower: data['emailLower'] as String?,
      isOnline: (data['isOnline'] as bool?) ?? false,
      isPrivate: (data['isPrivate'] as bool?) ?? false,
      followersCount: (data['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (data['followingCount'] as num?)?.toInt() ?? 0,
      postsCount: (data['postsCount'] as num?)?.toInt() ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      themeColor: data['themeColor'] as String?,
      links: links,
      pinnedPostIds: pinnedPostIds,
      showOnlineStatus: (data['showOnlineStatus'] as bool?) ?? true,
      lastSeenVisibility: lastSeenVisibility,
      messagePermission: messagePermission,
    );
  }
}

class UserProfileRepository {
  UserProfileRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('user_profiles');

  Future<void> ensureProfile({
    required String uid,
    String? email,
    String? phoneNumber,
    String? displayName,
    String? photoUrl,
    String? bio,
    bool? isPrivate,
  }) async {
    final normalizedEmail = email?.trim();
    final rawDisplayName = displayName?.trim() ?? '';
    final fallbackDisplayName = rawDisplayName.isNotEmpty
        ? rawDisplayName
        : (normalizedEmail?.split('@').first ??
            uid.substring(0, uid.length.clamp(0, 10)));
    final normalizedDisplayName = fallbackDisplayName.trim();

    final docRef = _collection.doc(uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'displayName': normalizedDisplayName,
        'displayNameLower': normalizedDisplayName.toLowerCase(),
        'bio': bio ?? '',
        'photoUrl': photoUrl,
        'phoneNumber': phoneNumber ?? '',
        'email': normalizedEmail,
        'emailLower': normalizedEmail?.toLowerCase(),
        'isOnline': false,
        'isPrivate': isPrivate ?? false,
        'followersCount': 0,
        'followingCount': 0,
      'postsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final update = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (normalizedEmail != null) {
        update['email'] = normalizedEmail;
        update['emailLower'] = normalizedEmail.toLowerCase();
      }
      if (displayName != null) {
        update['displayName'] = normalizedDisplayName;
        update['displayNameLower'] = normalizedDisplayName.toLowerCase();
      }
      if (phoneNumber != null) {
        update['phoneNumber'] = phoneNumber;
      }
      if (photoUrl != null) {
        update['photoUrl'] = photoUrl;
      }
      if (bio != null) {
        update['bio'] = bio;
      }
      if (isPrivate != null) {
        update['isPrivate'] = isPrivate;
      }
      if (update.length > 1) {
        await docRef.set(update, SetOptions(merge: true));
      }
    }
  }

  Stream<UserProfile?> watchProfile(String uid) {
    return _collection.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromDoc(doc);
    });
  }

  Future<UserProfile?> fetchProfile(String uid) async {
    final doc = await _collection.doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromDoc(doc);
  }

  Future<void> updateProfile(
    String uid, {
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
    bool removePhoto = false,
    String? bio,
    bool? isPrivate,
    String? themeColor,
    List<ProfileLink>? links,
    bool? showOnlineStatus,
    LastSeenVisibility? lastSeenVisibility,
    MessagePermission? messagePermission,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (displayName != null) {
      data['displayName'] = displayName;
      data['displayNameLower'] = displayName.toLowerCase();
    }
    if (phoneNumber != null) data['phoneNumber'] = phoneNumber;
    if (removePhoto) {
      data['photoUrl'] = FieldValue.delete();
    } else if (photoUrl != null) {
      data['photoUrl'] = photoUrl;
    }
    if (bio != null) {
      data['bio'] = bio;
    }
    if (isPrivate != null) {
      data['isPrivate'] = isPrivate;
    }
    if (themeColor != null) {
      data['themeColor'] = themeColor;
    } else if (themeColor == null && links != null) {
      // Nếu chỉ update links mà không update themeColor, không xóa themeColor
    }
    if (links != null) {
      data['links'] = links.map((link) => link.toMap()).toList();
    }
    if (showOnlineStatus != null) {
      data['showOnlineStatus'] = showOnlineStatus;
    }
    if (lastSeenVisibility != null) {
      data['lastSeenVisibility'] = lastSeenVisibility.name;
    }
    if (messagePermission != null) {
      data['messagePermission'] = messagePermission.name;
    }

    await _collection.doc(uid).set(data, SetOptions(merge: true));
  }

  /// Cập nhật privacy settings
  Future<void> updatePrivacySettings(
    String uid, {
    bool? showOnlineStatus,
    LastSeenVisibility? lastSeenVisibility,
    MessagePermission? messagePermission,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    if (showOnlineStatus != null) {
      data['showOnlineStatus'] = showOnlineStatus;
    }
    if (lastSeenVisibility != null) {
      data['lastSeenVisibility'] = lastSeenVisibility.name;
    }
    if (messagePermission != null) {
      data['messagePermission'] = messagePermission.name;
    }

    await _collection.doc(uid).set(data, SetOptions(merge: true));
  }

  /// Kiểm tra xem viewer có thể xem last seen của profile owner không
  /// Trả về true nếu có thể xem, false nếu không
  /// Cần truyền isFollowing từ bên ngoài để tránh circular dependency
  bool canViewLastSeen({
    required String viewerUid,
    required String profileUid,
    required bool isFollowing,
  }) {
    // Nếu là chính mình, luôn có thể xem
    if (viewerUid == profileUid) return true;

    // Tạm thời return true, sẽ được cập nhật khi có profile data
    // Logic thực tế sẽ được xử lý trong UI layer với profile data
    return true;
  }

  /// Kiểm tra xem sender có thể nhắn tin cho receiver không
  /// Trả về true nếu có thể, false nếu không
  /// Cần truyền isFollowing từ bên ngoài để tránh circular dependency
  bool canSendMessage({
    required String senderUid,
    required String receiverUid,
    required bool isFollowing,
    required MessagePermission messagePermission,
  }) {
    // Không thể nhắn tin cho chính mình
    if (senderUid == receiverUid) return false;

    switch (messagePermission) {
      case MessagePermission.everyone:
        return true;
      case MessagePermission.followers:
        return isFollowing;
      case MessagePermission.nobody:
        return false;
    }
  }

  Future<void> setPresence(String uid, bool isOnline) async {
    await _collection.doc(uid).set({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Cập nhật danh sách pinned posts (tối đa 3)
  /// Validate: không vượt quá 3, loại bỏ duplicate
  Future<void> updatePinnedPosts(
    String uid,
    List<String> postIds,
  ) async {
    // Validate: tối đa 3 posts
    if (postIds.length > 3) {
      throw Exception('Không thể ghim quá 3 bài viết');
    }
    
    // Loại bỏ duplicate
    final uniquePostIds = postIds.toSet().toList();
    if (uniquePostIds.length != postIds.length) {
      throw Exception('Danh sách bài viết không được trùng lặp');
    }
    
    await _collection.doc(uid).set({
      'pinnedPostIds': uniquePostIds,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Thêm một post vào danh sách pinned (nếu chưa đủ 3)
  Future<void> addPinnedPost(String uid, String postId) async {
    final profile = await fetchProfile(uid);
    if (profile == null) {
      throw Exception('Không tìm thấy profile');
    }
    
    final currentPinned = List<String>.from(profile.pinnedPostIds);
    
    // Kiểm tra đã ghim chưa
    if (currentPinned.contains(postId)) {
      throw Exception('Bài viết đã được ghim');
    }
    
    // Kiểm tra đã đủ 3 chưa
    if (currentPinned.length >= 3) {
      throw Exception('Đã đạt giới hạn 3 bài viết ghim');
    }
    
    currentPinned.add(postId);
    await updatePinnedPosts(uid, currentPinned);
  }

  /// Xóa một post khỏi danh sách pinned
  Future<void> removePinnedPost(String uid, String postId) async {
    final profile = await fetchProfile(uid);
    if (profile == null) {
      throw Exception('Không tìm thấy profile');
    }
    
    final currentPinned = List<String>.from(profile.pinnedPostIds);
    currentPinned.remove(postId);
    
    await updatePinnedPosts(uid, currentPinned);
  }

  /// Sắp xếp lại thứ tự pinned posts
  Future<void> reorderPinnedPosts(
    String uid,
    List<String> newOrder,
  ) async {
    final profile = await fetchProfile(uid);
    if (profile == null) {
      throw Exception('Không tìm thấy profile');
    }
    
    final currentPinned = List<String>.from(profile.pinnedPostIds);
    
    // Validate: newOrder phải chứa đúng các postId hiện tại
    if (newOrder.length != currentPinned.length) {
      throw Exception('Số lượng bài viết không khớp');
    }
    
    final currentSet = currentPinned.toSet();
    final newSet = newOrder.toSet();
    if (currentSet.length != newSet.length || 
        !currentSet.containsAll(newSet)) {
      throw Exception('Danh sách bài viết không khớp');
    }
    
    await updatePinnedPosts(uid, newOrder);
  }

  /// Tìm kiếm users theo từ khóa (displayName, email, phoneNumber)
  /// Sử dụng prefix matching trên displayNameLower và emailLower
  Future<List<UserProfile>> searchUsers({
    required String query,
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return [];
    
    final normalizedQuery = query.trim().toLowerCase();
    
    // Tìm theo displayNameLower (prefix match)
    final displayNameQuery = _collection
        .where('displayNameLower', isGreaterThanOrEqualTo: normalizedQuery)
        .where('displayNameLower', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
        .limit(limit)
        .get();
    
    // Tìm theo emailLower (prefix match)
    final emailQuery = _collection
        .where('emailLower', isGreaterThanOrEqualTo: normalizedQuery)
        .where('emailLower', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
        .limit(limit)
        .get();
    
    // Tìm theo phoneNumber (exact hoặc contains)
    final phoneQuery = _collection
        .where('phoneNumber', isGreaterThanOrEqualTo: normalizedQuery)
        .where('phoneNumber', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
        .limit(limit)
        .get();
    
    final results = await Future.wait([displayNameQuery, emailQuery, phoneQuery]);
    
    // Gộp kết quả và loại bỏ trùng lặp
    final allDocs = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    for (final snapshot in results) {
      for (final doc in snapshot.docs) {
        allDocs[doc.id] = doc;
      }
    }
    
    // Chuyển đổi sang UserProfile và filter thêm client-side nếu cần
    final profiles = allDocs.values
        .map((doc) => UserProfile.fromDoc(doc))
        .where((profile) {
          // Filter client-side để đảm bảo match chính xác hơn
          final displayNameMatch = profile.displayNameLower?.contains(normalizedQuery) ?? false;
          final emailMatch = profile.emailLower?.contains(normalizedQuery) ?? false;
          final phoneMatch = profile.phoneNumber?.contains(normalizedQuery) ?? false;
          return displayNameMatch || emailMatch || phoneMatch;
        })
        .take(limit)
        .toList();
    
    return profiles;
  }
}

final UserProfileRepository userProfileRepository = UserProfileRepository();

