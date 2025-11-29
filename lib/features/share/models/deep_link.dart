enum DeepLinkType {
  post,
  profile,
  hashtag,
  unknown,
}

class DeepLink {
  DeepLink({
    required this.type,
    required this.rawUrl,
    this.postId,
    this.uid,
    this.hashtag,
  });

  final DeepLinkType type;
  final String rawUrl;
  final String? postId;
  final String? uid;
  final String? hashtag;

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

