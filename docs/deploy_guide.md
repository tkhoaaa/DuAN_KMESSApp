# Hướng dẫn Deploy Firestore Rules & Cloud Functions

## Yêu cầu

1. **Firebase CLI** đã cài đặt:
   ```bash
   npm install -g firebase-tools
   ```

2. **Đăng nhập Firebase**:
   ```bash
   firebase login
   ```

3. **Liên kết dự án** (nếu chưa):
   ```bash
   firebase use --add
   # Chọn project ID của bạn (ví dụ: duankmessapp)
   ```

## 1. Deploy Firestore Rules

### Bước 1: Kiểm tra cấu hình

Đảm bảo file `firebase.json` tồn tại và trỏ đúng đến `firebase/firestore.rules`:

```json
{
  "firestore": {
    "rules": "firebase/firestore.rules"
  }
}
```

### Bước 2: Deploy rules

```bash
firebase deploy --only firestore:rules
```

Kết quả mong đợi:
```
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/duankmessapp/overview
```

### Bước 3: Kiểm tra rules đã áp dụng

1. Mở [Firebase Console](https://console.firebase.google.com)
2. Vào **Firestore Database** → **Rules**
3. Xác nhận nội dung rules đã được cập nhật

### Bước 4: Test rules (tùy chọn)

Sử dụng Firebase Emulator Suite để test rules trước khi deploy:

```bash
# Khởi động emulator
firebase emulators:start --only firestore

# Trong terminal khác, chạy test script hoặc test thủ công
```

## 2. Deploy Firestore Indexes

Nếu có file `firebase/firestore.indexes.json`:

```bash
firebase deploy --only firestore:indexes
```

## 2.5. Setup Firebase Storage (Lần đầu tiên)

> **Lưu ý:** Nếu chưa setup Storage, bạn cần làm bước này trước khi deploy rules.

### Bước 1: Mở Firebase Console
1. Truy cập: https://console.firebase.google.com/project/duankmessapp/storage
2. Nhấn **"Get Started"**

### Bước 2: Chọn chế độ
- **Test mode** (khuyến nghị cho development): Cho phép đọc/ghi trong 30 ngày
- **Production mode**: An toàn hơn, cần rules ngay

### Bước 3: Chọn Location
- **Khuyến nghị:** `asia-southeast1` (Singapore) - gần Việt Nam nhất
- ⚠️ **Lưu ý:** Location không thể thay đổi sau khi tạo!

### Bước 4: Deploy Storage Rules
Sau khi setup xong:

```bash
firebase deploy --only storage
```

> 📖 **Xem chi tiết:** [docs/setup_storage.md](docs/setup_storage.md)

## 3. Deploy Cloud Functions (Tùy chọn - Cần Blaze Plan)

> **Lưu ý:** Cloud Functions **KHÔNG BẮT BUỘC** cho app hoạt động. App hiện tại đã hoạt động đầy đủ mà không cần Cloud Functions:
> - ✅ Posts, likes, comments đều hoạt động
> - ✅ `postsCount` được cập nhật trực tiếp trong app (không cần Cloud Functions)
> - ❌ Chỉ thiếu: Push notifications (có thể thêm sau)

### Khi nào cần Cloud Functions?

- **Cần thiết:** Khi muốn gửi push notifications (like/comment)
- **Không cần:** Để app hoạt động cơ bản (đã đủ)

### Về Blaze Plan (Pay-as-you-go)

- **Free tier rất rộng:** 2 triệu invocations/tháng, 400,000 GB-seconds/tháng
- **Chỉ trả phí khi vượt quá:** Hầu hết dự án nhỏ không bao giờ vượt free tier
- **Có thể upgrade sau:** Không cần ngay bây giờ

### Nếu muốn deploy Cloud Functions:

#### Bước 1: Upgrade lên Blaze Plan
1. Truy cập: https://console.firebase.google.com/project/duankmessapp/usage/details
2. Chọn "Upgrade to Blaze plan"
3. Thêm payment method (chỉ trả khi vượt free tier)

#### Bước 2: Cài đặt dependencies

```bash
cd functions
npm install
```

#### Bước 3: Build TypeScript

```bash
npm run build
```

#### Bước 4: Deploy functions

```bash
# Deploy tất cả functions
firebase deploy --only functions

# Hoặc deploy function cụ thể
firebase deploy --only functions:onNewComment
firebase deploy --only functions:onNewLike
```

#### Bước 5: Xem logs

```bash
# Xem logs realtime
firebase functions:log

# Xem logs của function cụ thể
firebase functions:log --only onNewComment
```

## 4. Kiểm tra truy cập trái phép bị chặn

### Test 1: Tạo bài đăng với authorUid sai

Trong Flutter app, thử tạo post với `authorUid` khác `request.auth.uid`:

```dart
// Sẽ bị từ chối bởi rule:
// request.resource.data.authorUid == request.auth.uid
await firestore.collection('posts').add({
  'authorUid': 'someOtherUid', // ❌ PERMISSION_DENIED
  'caption': 'Test',
  ...
});
```

### Test 2: Like với UID sai

```dart
// Sẽ bị từ chối:
await firestore
  .collection('posts')
  .doc(postId)
  .collection('likes')
  .doc('differentUid') // ❌ PERMISSION_DENIED
  .set({'likedAt': FieldValue.serverTimestamp()});
```

### Test 3: Sửa comment

```dart
// Sẽ bị từ chối (rule: allow update: if false)
await firestore
  .collection('posts')
  .doc(postId)
  .collection('comments')
  .doc(commentId)
  .update({'text': 'Modified'}); // ❌ PERMISSION_DENIED
```

### Test 4: Đọc posts khi chưa đăng nhập

```dart
// Sau khi signOut():
await firestore.collection('posts').get(); // ❌ PERMISSION_DENIED
```

### Kiểm tra trong Console

1. Mở **Firestore Database** → **Usage**
2. Xem các lỗi `PERMISSION_DENIED` trong tab **Denied requests**

## 5. Cấu hình FCM Tokens (chỉ cần nếu có Cloud Functions)

> **Lưu ý:** Chỉ cần cấu hình FCM tokens nếu đã deploy Cloud Functions. Nếu chưa có Cloud Functions, có thể bỏ qua phần này.

Để nhận thông báo đẩy, app cần lưu FCM token vào Firestore:

```dart
// Trong Flutter app (sau khi đăng nhập)
import 'package:firebase_messaging/firebase_messaging.dart';

final fcmToken = await FirebaseMessaging.instance.getToken();
if (fcmToken != null) {
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (currentUid != null) {
    await FirebaseFirestore.instance
      .collection('user_profiles')
      .doc(currentUid)
      .collection('fcm_tokens')
      .doc(fcmToken)
      .set({
        'createdAt': FieldValue.serverTimestamp(),
        'platform': Platform.isAndroid ? 'android' : 'ios',
      });
  }
}
```

## 6. Troubleshooting

### Lỗi: "Permission denied" sau khi deploy rules

- Kiểm tra `request.auth.uid` có tồn tại (user đã đăng nhập)
- Xem logs trong Firebase Console → Firestore → Usage

### Functions không trigger

- Kiểm tra logs: `firebase functions:log`
- Đảm bảo function đã deploy thành công
- Kiểm tra Firestore triggers trong Console → Functions

### Rules không áp dụng ngay

- Đợi vài giây (rules có thể cache)
- Hard refresh Firebase Console
- Kiểm tra project ID đúng

## 7. Rollback (nếu cần)

```bash
# Xem lịch sử releases
firebase firestore:releases:list

# Rollback về release trước
firebase firestore:releases:rollback <release-id>
```

---

**Lưu ý:** Sau khi deploy rules, tất cả truy cập sẽ tuân theo rules mới. Đảm bảo test kỹ trên môi trường development trước khi deploy production.

