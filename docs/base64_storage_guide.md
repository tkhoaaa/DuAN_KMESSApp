# Hướng dẫn: Lưu ảnh dạng Base64 trong Firestore (Miễn phí)

> ⚠️ **Lưu ý:** Giải pháp này chỉ phù hợp nếu:
> - Chỉ upload ảnh nhỏ (< 500KB)
> - Không cần video
> - Muốn ở lại Spark plan miễn phí

## Giới hạn

- Firestore document tối đa: **1MB**
- Base64 tăng kích thước: **~33%**
- Ảnh thực tế tối đa: **~750KB** (sau khi base64 = ~1MB)
- **Khuyến nghị:** Chỉ upload ảnh < 500KB để an toàn

## Cài đặt

### Bước 1: Thêm dependency

```yaml
# pubspec.yaml
dependencies:
  image: ^4.1.3  # Để compress ảnh
  dart:convert:  # Đã có sẵn trong Flutter
```

### Bước 2: Tạo service upload Base64

Tạo file `lib/features/posts/services/base64_storage_service.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class Base64StorageService {
  /// Compress và convert ảnh sang base64
  static Future<String> compressAndEncodeImage(XFile file) async {
    final bytes = await file.readAsBytes();
    
    // Decode ảnh
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw StateError('Không thể đọc ảnh');
    }
    
    // Resize nếu quá lớn (max 1024px)
    img.Image resized = image;
    if (image.width > 1024 || image.height > 1024) {
      resized = img.copyResize(
        image,
        width: image.width > image.height ? 1024 : null,
        height: image.height > image.width ? 1024 : null,
        maintainAspect: true,
      );
    }
    
    // Encode lại với quality 85%
    final compressedBytes = Uint8List.fromList(
      img.encodeJpg(resized, quality: 85),
    );
    
    // Kiểm tra kích thước
    if (compressedBytes.length > 500 * 1024) {
      throw StateError('Ảnh quá lớn sau khi nén. Vui lòng chọn ảnh nhỏ hơn.');
    }
    
    // Convert sang base64
    return base64Encode(compressedBytes);
  }
  
  /// Tạo data URL để hiển thị
  static String getDataUrl(String base64String, {String mimeType = 'image/jpeg'}) {
    return 'data:$mimeType;base64,$base64String';
  }
}
```

### Bước 3: Cập nhật PostService

Sửa `lib/features/posts/services/post_service.dart` để hỗ trợ base64:

```dart
// Thêm flag để chọn storage mode
static const bool useBase64Storage = true; // Set false để dùng Firebase Storage

Future<void> createPost({
  required List<PostMediaUpload> media,
  String? caption,
}) async {
  // ... existing code ...
  
  for (final entry in media) {
    if (useBase64Storage && entry.type == PostMediaType.image) {
      // Dùng base64 cho ảnh
      final base64String = await Base64StorageService.compressAndEncodeImage(entry.file);
      uploads.add({
        'type': 'image',
        'data': base64String, // Lưu base64 thay vì URL
        'mimeType': entry.file.mimeType ?? 'image/jpeg',
      });
    } else {
      // Dùng Firebase Storage cho video hoặc nếu không dùng base64
      // ... existing Firebase Storage code ...
    }
  }
}
```

### Bước 4: Cập nhật Post model

Sửa `lib/features/posts/models/post_media.dart`:

```dart
class PostMedia {
  PostMedia({
    required this.type,
    this.url,        // Cho Firebase Storage
    this.data,       // Cho Base64
    this.thumbnailUrl,
    this.durationMs,
  });

  final PostMediaType type;
  final String? url;
  final String? data;  // Base64 string
  final String? thumbnailUrl;
  final int? durationMs;
  
  // Getter để lấy URL hiển thị
  String get displayUrl {
    if (data != null) {
      return Base64StorageService.getDataUrl(data!);
    }
    return url ?? '';
  }
}
```

### Bước 5: Cập nhật UI để hiển thị

Trong `post_feed_page.dart`, sử dụng `displayUrl`:

```dart
Image.network(
  media.displayUrl, // Tự động xử lý cả URL và base64
  // ...
)
```

## Ưu và nhược điểm

### Ưu điểm:
- ✅ Miễn phí hoàn toàn (Spark plan)
- ✅ Không cần setup Storage
- ✅ Đơn giản

### Nhược điểm:
- ❌ Giới hạn kích thước nghiêm ngặt
- ❌ Không thể upload video
- ❌ Tăng chi phí Firestore reads
- ❌ Chậm hơn (không có CDN)
- ❌ Tăng kích thước document

## Kết luận

**Chỉ nên dùng Base64 nếu:**
- App chỉ cần ảnh nhỏ
- Không cần video
- Muốn miễn phí hoàn toàn

**Khuyến nghị:** Nếu có thể, nên dùng Firebase Storage với Blaze plan (free tier rộng rãi).

