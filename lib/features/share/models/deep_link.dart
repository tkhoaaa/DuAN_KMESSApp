enum DeepLinkType {
  post,
  profile,
  hashtag,
  resetPassword,
  unknown,
}

class DeepLink {
  DeepLink({
    required this.type,
    required this.rawUrl,
    this.postId,
    this.uid,
    this.hashtag,
    this.actionCode,
  });

  final DeepLinkType type;
  final String rawUrl;
  final String? postId;
  final String? uid;
  final String? hashtag;
  final String? actionCode; // For password reset

  /// Parse URL thành DeepLink object
  /// Hỗ trợ format:
  /// - kmessapp://posts/{postId}
  /// - kmessapp://user/{uid}
  /// - kmessapp://hashtag/{tag}
  /// - https://kmessapp.com/posts/{postId}
  /// - https://kmessapp.com/user/{uid}
  /// - https://kmessapp.com/hashtag/{tag}
  factory DeepLink.fromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Xử lý custom scheme: kmessapp://
      if (uri.scheme == 'kmessapp') {
        final path = uri.pathSegments;
        if (path.isEmpty) {
          return DeepLink(type: DeepLinkType.unknown, rawUrl: url);
        }

        final type = path[0];
        if (type == 'posts' && path.length >= 2) {
          return DeepLink(
            type: DeepLinkType.post,
            rawUrl: url,
            postId: path[1],
          );
        } else if (type == 'user' && path.length >= 2) {
          return DeepLink(
            type: DeepLinkType.profile,
            rawUrl: url,
            uid: path[1],
          );
        } else if (type == 'hashtag' && path.length >= 2) {
          return DeepLink(
            type: DeepLinkType.hashtag,
            rawUrl: url,
            hashtag: path[1],
          );
        }
      }
      
      // Xử lý universal link: https://kmessapp.com/
      if (uri.scheme == 'https' && 
          (uri.host == 'kmessapp.com' || uri.host.endsWith('.kmessapp.com'))) {
        final path = uri.pathSegments;
        if (path.isEmpty) {
          return DeepLink(type: DeepLinkType.unknown, rawUrl: url);
        }

        final type = path[0];
        if (type == 'posts' && path.length >= 2) {
          return DeepLink(
            type: DeepLinkType.post,
            rawUrl: url,
            postId: path[1],
          );
        } else if (type == 'user' && path.length >= 2) {
          return DeepLink(
            type: DeepLinkType.profile,
            rawUrl: url,
            uid: path[1],
          );
        } else if (type == 'hashtag' && path.length >= 2) {
          return DeepLink(
            type: DeepLinkType.hashtag,
            rawUrl: url,
            hashtag: path[1],
          );
        }
      }
      
      // Xử lý Firebase Auth action links (password reset, email verification, etc.)
      if (uri.scheme == 'https' && 
          (uri.host.contains('firebaseapp.com') || uri.host.contains('firebase'))) {
        final mode = uri.queryParameters['mode'];
        final oobCode = uri.queryParameters['oobCode'];
        
        if (mode == 'resetPassword' && oobCode != null) {
          return DeepLink(
            type: DeepLinkType.resetPassword,
            rawUrl: url,
            actionCode: oobCode,
          );
        }
      }
      
      return DeepLink(type: DeepLinkType.unknown, rawUrl: url);
    } catch (e) {
      return DeepLink(type: DeepLinkType.unknown, rawUrl: url);
    }
  }

  /// Generate deep link URL cho post
  static String generatePostLink(String postId) {
    return 'kmessapp://posts/$postId';
  }

  /// Generate deep link URL cho profile
  static String generateProfileLink(String uid) {
    return 'kmessapp://user/$uid';
  }

  /// Generate deep link URL cho hashtag
  static String generateHashtagLink(String hashtag) {
    // Remove # nếu có
    final cleanTag = hashtag.startsWith('#') ? hashtag.substring(1) : hashtag;
    return 'kmessapp://hashtag/$cleanTag';
  }
}

