class MessageAttachment {
  const MessageAttachment({
    required this.url,
    required this.name,
    required this.size,
    required this.mimeType,
    this.type,
    this.durationMs,
    this.thumbnailUrl,
  });

  final String url;
  final String name;
  final int size;
  final String mimeType;
  /// Loại file: image | video | voice | other
  final String? type;
  /// Thời lượng (ms) cho voice/video (nếu có)
  final int? durationMs;
  /// Thumbnail cho video (hoặc preview khác nếu cần)
  final String? thumbnailUrl;

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'name': name,
      'size': size,
      'mimeType': mimeType,
      'type': type,
      'durationMs': durationMs,
      'thumbnailUrl': thumbnailUrl,
    };
  }

  factory MessageAttachment.fromMap(Map<String, dynamic> map) {
    return MessageAttachment(
      url: map['url'] as String? ?? '',
      name: map['name'] as String? ?? '',
      size: (map['size'] as num?)?.toInt() ?? 0,
      mimeType: map['mimeType'] as String? ?? 'application/octet-stream',
      type: map['type'] as String?,
      durationMs: (map['durationMs'] as num?)?.toInt(),
      thumbnailUrl: map['thumbnailUrl'] as String?,
    );
  }
}

