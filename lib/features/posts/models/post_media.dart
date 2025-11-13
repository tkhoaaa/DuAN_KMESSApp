enum PostMediaType { image, video }

class PostMedia {
  PostMedia({
    required this.url,
    required this.type,
    this.thumbnailUrl,
    this.durationMs,
  });

  final String url;
  final PostMediaType type;
  final String? thumbnailUrl;
  final int? durationMs;

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'type': type.name,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (durationMs != null) 'durationMs': durationMs,
    };
  }

  factory PostMedia.fromMap(Map<String, dynamic> map) {
    final typeString = map['type'] as String? ?? 'image';
    final type = PostMediaType.values.firstWhere(
      (t) => t.name == typeString,
      orElse: () => PostMediaType.image,
    );
    return PostMedia(
      url: map['url'] as String? ?? '',
      type: type,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      durationMs: (map['durationMs'] as num?)?.toInt(),
    );
  }
}

