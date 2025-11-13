# Hướng dẫn Setup Cloudinary (Miễn phí - 25GB)

## ⚠️ Quan trọng: Cloudinary chỉ thay thế Firebase Storage

**Cloudinary KHÔNG thay thế toàn bộ Firebase!**

- ✅ **Cloudinary** → Chỉ thay thế **Firebase Storage** (upload ảnh/video)
- ✅ **Firebase vẫn cần dùng cho:**
  - **Firebase Authentication** (đăng nhập, đăng ký)
  - **Cloud Firestore** (database - lưu posts, users, messages, likes, comments)
  - **Cloud Functions** (nếu có - thông báo, sync data)

**Tóm lại:** 
- Cloudinary = Storage cho ảnh/video (thay Firebase Storage)
- Firebase = Auth + Database + Functions (vẫn cần)

## Tổng quan Cloudinary

Cloudinary cung cấp free tier rộng rãi:
- ✅ **25GB** storage
- ✅ **25GB** bandwidth/tháng
- ✅ Hỗ trợ cả ảnh và video
- ✅ Transform ảnh/video tự động
- ✅ CDN toàn cầu

## Bước 1: Đăng ký tài khoản Cloudinary

1. Truy cập: https://cloudinary.com/users/register/free
2. Đăng ký bằng email (miễn phí)
3. Xác nhận email
4. Đăng nhập vào Dashboard: https://console.cloudinary.com/

## Bước 2: Lấy API Credentials

### Cách 1: Từ Dashboard chính

1. Vào Dashboard: https://console.cloudinary.com/
2. Click vào **Settings** (biểu tượng bánh răng) ở sidebar bên trái
3. Trong Settings, tìm và click vào **Product environment credentials** (hoặc **API Keys**)
4. Bạn sẽ thấy 3 thông tin cần copy:
   - **Cloud name** (ví dụ: `dxyz123`)
   - **API Key** (ví dụ: `123456789012345`)
   - **API Secret** (ví dụ: `abcdefghijklmnopqrstuvwxyz`)

### Cách 2: Từ URL trực tiếp

Nếu bạn đang ở trang khác, truy cập trực tiếp:
```
https://console.cloudinary.com/settings/product-environment-credentials
```

Hoặc:
```
https://console.cloudinary.com/settings/api-keys
```

### ⚠️ Lưu ý quan trọng:

- **API Secret** chỉ hiển thị 1 lần khi tạo mới
- Nếu không thấy API Secret, bạn có thể:
  - Click "Reveal" hoặc "Show" để hiển thị
  - Hoặc tạo API Key mới (nếu cần)
- **KHÔNG commit API Secret vào Git!**

### Nếu vẫn không thấy:

1. Đảm bảo bạn đã đăng nhập đúng tài khoản
2. Kiểm tra bạn đang ở đúng Product Environment (free tier chỉ có 1 environment)
3. Thử refresh trang hoặc đăng xuất/đăng nhập lại

## Bước 3: Cài đặt trong Flutter

### 3.1. Thêm dependency

```yaml
# pubspec.yaml
dependencies:
  cloudinary_flutter: ^1.0.0
  # Hoặc dùng HTTP client trực tiếp
  http: ^1.1.0
  crypto: ^3.0.3  # Để tạo signature
```

### 3.2. Tạo file config

Tạo `lib/config/cloudinary_config.dart`:

```dart
class CloudinaryConfig {
  // Thay bằng thông tin của bạn
  static const String cloudName = 'YOUR_CLOUD_NAME';
  static const String apiKey = 'YOUR_API_KEY';
  static const String apiSecret = 'YOUR_API_SECRET';
  
  // Base URL cho upload
  static String get uploadUrl => 
    'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
  
  static String get videoUploadUrl => 
    'https://api.cloudinary.com/v1_1/$cloudName/video/upload';
  
  // Transform URL (để resize, crop, etc.)
  static String getImageUrl(String publicId, {
    int? width,
    int? height,
    String? format,
  }) {
    final baseUrl = 'https://res.cloudinary.com/$cloudName/image/upload';
    final transformations = <String>[];
    
    if (width != null || height != null) {
      transformations.add('w_${width ?? 'auto'},h_${height ?? 'auto'},c_limit');
    }
    if (format != null) {
      transformations.add('f_$format');
    }
    
    final transformStr = transformations.isEmpty 
        ? '' 
        : '/${transformations.join(',')}';
    
    return '$baseUrl$transformStr/$publicId';
  }
  
  static String getVideoUrl(String publicId, {
    int? width,
    int? height,
  }) {
    final baseUrl = 'https://res.cloudinary.com/$cloudName/video/upload';
    final transformations = <String>[];
    
    if (width != null || height != null) {
      transformations.add('w_${width ?? 'auto'},h_${height ?? 'auto'},c_limit');
    }
    
    final transformStr = transformations.isEmpty 
        ? '' 
        : '/${transformations.join(',')}';
    
    return '$baseUrl$transformStr/$publicId';
  }
}
```

### 3.3. Cài đặt dependencies

```bash
flutter pub get
```

### 3.4. Cấu hình Cloudinary

Mở file `lib/config/cloudinary_config.dart` và thay thế:

```dart
static const String cloudName = 'YOUR_CLOUD_NAME';  // Thay bằng cloud name của bạn
static const String apiKey = 'YOUR_API_KEY';        // Thay bằng API key của bạn
static const String apiSecret = 'YOUR_API_SECRET';  // Thay bằng API secret của bạn
```

⚠️ **QUAN TRỌNG:** Không commit API Secret vào Git! Xem phần Bảo mật bên dưới.

## Bước 4: Code đã được tích hợp sẵn

Code đã được tích hợp vào:
- ✅ `lib/services/cloudinary_service.dart` - Service upload
- ✅ `lib/config/cloudinary_config.dart` - Cấu hình
- ✅ `lib/features/posts/services/post_service.dart` - Upload posts
- ✅ `lib/features/profile/profile_screen.dart` - Upload avatar

### Chuyển đổi giữa Firebase Storage và Cloudinary

Trong `PostService` và `ProfileScreen`, có flag `storageBackend`:

```dart
// Trong lib/features/posts/services/post_service.dart
static const String storageBackend = 'cloudinary'; // hoặc 'firebase'

// Trong lib/features/profile/profile_screen.dart
static const String storageBackend = 'cloudinary'; // hoặc 'firebase'
```

**Lưu ý:** Phải đặt cùng giá trị ở cả 2 file!

## Bước 5: Sử dụng trong code

### Upload ảnh profile:
```dart
final url = await cloudinaryService.uploadImage(
  file: imageFile,
  folder: 'user_profiles/$uid',
  publicId: 'avatar',
);
```

### Upload ảnh/video post:
```dart
final url = await cloudinaryService.uploadImage(
  file: imageFile,
  folder: 'posts/$uid',
);

// Hoặc video
final videoUrl = await cloudinaryService.uploadVideo(
  file: videoFile,
  folder: 'posts/$uid',
);
```

## Bước 6: Bảo mật (Quan trọng!)

### Option A: Upload từ client (Đơn giản, ít bảo mật)

- Upload trực tiếp từ app
- Cần expose API Secret (không an toàn)
- Chỉ dùng cho development

### Option B: Upload qua Cloud Functions (Khuyến nghị)

- Upload từ Cloud Functions
- Giữ API Secret an toàn
- Có thể validate trước khi upload

### Option C: Dùng environment variables (Khuyến nghị cho production)

1. Tạo file `.env` (không commit vào Git):
```env
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

2. Dùng package `flutter_dotenv`:
```yaml
dependencies:
  flutter_dotenv: ^5.1.0
```

3. Cập nhật `CloudinaryConfig`:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryConfig {
  static String get cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get apiKey => dotenv.env['CLOUDINARY_API_KEY'] ?? '';
  static String get apiSecret => dotenv.env['CLOUDINARY_API_SECRET'] ?? '';
  // ...
}
```

**Hiện tại:** Code dùng hardcoded values (chỉ cho development). Nên chuyển sang environment variables khi deploy production.

## Transform ảnh/video

Cloudinary tự động transform:

```dart
// Resize ảnh khi hiển thị
final thumbnailUrl = CloudinaryConfig.getImageUrl(
  publicId,
  width: 300,
  height: 300,
);

// Video thumbnail
final videoThumbnail = CloudinaryConfig.getImageUrl(
  publicId,
  width: 640,
  height: 360,
);
```

## Giới hạn Free Tier

- ✅ **25GB** storage
- ✅ **25GB** bandwidth/tháng
- ✅ **25GB** monthly net transformation usage
- ⚠️ Nếu vượt quá: $0.04/GB storage, $0.04/GB bandwidth

**Ước tính:**
- 1,000 ảnh 2MB = 2GB
- 100 video 50MB = 5GB
- Tổng: ~7GB (còn 18GB free)

## Troubleshooting

### Lỗi: "Invalid API Key"
- Kiểm tra lại API Key và API Secret
- Đảm bảo đã copy đúng từ Dashboard

### Lỗi: "Upload failed"
- Kiểm tra kết nối internet
- Kiểm tra kích thước file (free tier không giới hạn kích thước)
- Kiểm tra format file (hỗ trợ: jpg, png, gif, mp4, mov, etc.)

### Upload chậm
- Cloudinary có CDN toàn cầu, upload nhanh hơn nếu server gần
- Có thể dùng `upload_preset` để tăng tốc

## Tài liệu tham khảo

- Cloudinary Docs: https://cloudinary.com/documentation
- Flutter SDK: https://pub.dev/packages/cloudinary_flutter
- Upload API: https://cloudinary.com/documentation/image_upload_api_reference

