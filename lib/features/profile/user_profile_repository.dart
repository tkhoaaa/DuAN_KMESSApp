import 'package:cloud_firestore/cloud_firestore.dart';

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
    };
  }

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
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

    await _collection.doc(uid).set(data, SetOptions(merge: true));
  }

  Future<void> setPresence(String uid, bool isOnline) async {
    await _collection.doc(uid).set({
      'isOnline': isOnline,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

final UserProfileRepository userProfileRepository = UserProfileRepository();

