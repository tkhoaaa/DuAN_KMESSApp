class MessageAttachment {
  const MessageAttachment({
    required this.url,
    required this.name,
    required this.size,
    required this.mimeType,
  });

  final String url;
  final String name;
  final int size;
  final String mimeType;

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'name': name,
      'size': size,
      'mimeType': mimeType,
    };
  }

  factory MessageAttachment.fromMap(Map<String, dynamic> map) {
    return MessageAttachment(
      url: map['url'] as String? ?? '',
      name: map['name'] as String? ?? '',
      size: (map['size'] as num?)?.toInt() ?? 0,
      mimeType: map['mimeType'] as String? ?? 'application/octet-stream',
    );
  }
}

