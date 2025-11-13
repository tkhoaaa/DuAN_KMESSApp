# Hướng dẫn: Chạy App KHÔNG CẦN Firebase Storage

> ⚠️ **Lưu ý:** App của bạn có tính năng đăng bài với ảnh/video, nên **KHÔNG THỂ** bỏ hoàn toàn storage. Tuy nhiên, bạn có thể:
> 1. Tạm thời bỏ tính năng upload (chỉ text posts)
> 2. Dùng Base64 cho ảnh nhỏ (xem [base64_storage_guide.md](base64_storage_guide.md))
> 3. Hoặc dùng dịch vụ miễn phí khác (xem [storage_alternatives.md](storage_alternatives.md))

## Option 1: Tạm thời bỏ tính năng upload (Nhanh nhất)

### Bước 1: Xóa Storage config

File `firebase.json` đã được cập nhật (đã xóa phần storage).

### Bước 2: Vô hiệu hóa tính năng upload trong app

Sửa `lib/features/posts/pages/post_create_page.dart`:

```dart
// Tạm thời disable upload
Future<void> _pickImage({required ImageSource source}) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Tính năng upload ảnh tạm thời tắt. Vui lòng dùng text posts.'),
    ),
  );
  return; // Không làm gì
}

Future<void> _pickVideo({required ImageSource source}) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Tính năng upload video tạm thời tắt. Vui lòng dùng text posts.'),
    ),
  );
  return; // Không làm gì
}
```

### Bước 3: Cho phép posts không có media

Sửa `lib/features/posts/services/post_service.dart`:

```dart
Future<void> createPost({
  required List<PostMediaUpload> media,
  String? caption,
}) async {
  // Cho phép post không có media (chỉ text)
  // if (media.isEmpty) {
  //   throw ArgumentError('Cần chọn ít nhất một ảnh hoặc video.');
  // }
  
  final uploads = <Map<String, dynamic>>[];
  
  // Chỉ xử lý media nếu có
  if (media.isNotEmpty) {
    // ... existing upload code ...
  }
  
  await _repository.createPost(
    authorUid: currentUid,
    media: uploads, // Có thể rỗng
    caption: caption,
  );
}
```

### Kết quả:
- ✅ App chạy được mà không cần Storage
- ✅ Có thể đăng bài text-only
- ❌ Không thể upload ảnh/video

---

## Option 2: Dùng Base64 (Miễn phí, có giới hạn)

Xem hướng dẫn chi tiết: [base64_storage_guide.md](base64_storage_guide.md)

**Tóm tắt:**
- Chỉ upload ảnh nhỏ (< 500KB)
- Không hỗ trợ video
- Lưu base64 trong Firestore

---

## Option 3: Dùng Cloudinary (Miễn phí, tốt hơn)

Xem hướng dẫn: [storage_alternatives.md](storage_alternatives.md)

**Tóm tắt:**
- Free tier: 25GB storage
- Hỗ trợ cả ảnh và video
- Cần setup account riêng

---

## Option 4: Firebase Storage với Blaze Plan (Khuyến nghị)

**Free tier rất rộng:**
- 5GB storage
- 1GB/ngày downloads
- 20,000 uploads/ngày

**Hầu hết dự án nhỏ không bao giờ vượt quá free tier!**

Xem: [setup_storage.md](setup_storage.md)

---

## So sánh nhanh

| Option | Storage | Video | Free | Setup | Khuyến nghị |
|--------|---------|-------|------|-------|-------------|
| **Bỏ upload** | ❌ | ❌ | ✅ | Dễ | ⭐ (tạm thời) |
| **Base64** | ⚠️ | ❌ | ✅ | Dễ | ⭐⭐ |
| **Cloudinary** | ✅ | ✅ | ✅ | Trung bình | ⭐⭐⭐⭐ |
| **Firebase Storage** | ✅ | ✅ | ✅* | Dễ | ⭐⭐⭐⭐⭐ |

*Free tier rộng rãi, chỉ trả phí khi vượt quá

---

## Khuyến nghị

**Nếu muốn miễn phí hoàn toàn:**
- Dùng **Base64** cho ảnh nhỏ
- Hoặc **Cloudinary** free tier

**Nếu chấp nhận Blaze plan:**
- Dùng **Firebase Storage** (free tier đủ dùng)

**Tạm thời:**
- Bỏ tính năng upload, chỉ dùng text posts

