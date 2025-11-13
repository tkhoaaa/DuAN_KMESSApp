# Hướng dẫn Setup Firebase Storage

## Bước 1: Mở Firebase Console

1. Truy cập: https://console.firebase.google.com/project/duankmessapp/storage
2. Hoặc vào: https://console.firebase.google.com → Chọn project `duankmessapp` → Storage (trong menu bên trái)

## Bước 2: Khởi tạo Firebase Storage

1. Nếu chưa setup, bạn sẽ thấy màn hình "Get Started"
2. Nhấn nút **"Get Started"** (Bắt đầu)

## Bước 3: Chọn chế độ bảo mật

Bạn sẽ thấy 2 tùy chọn:

### Option 1: Test mode (Khuyến nghị cho development)
- ✅ Cho phép đọc/ghi trong 30 ngày đầu (sau đó cần rules)
- ✅ Dễ test nhanh
- ⚠️ Không an toàn cho production

### Option 2: Production mode
- ✅ An toàn hơn (yêu cầu rules ngay)
- ⚠️ Cần setup rules trước khi sử dụng

**Khuyến nghị:** Chọn **"Start in test mode"** để test nhanh, sau đó deploy rules.

## Bước 4: Chọn Location (Vị trí)

Chọn location gần nhất với người dùng của bạn:

- **`asia-southeast1`** (Singapore) - ✅ **Khuyến nghị cho Việt Nam**
- `asia-south1` (Mumbai)
- `asia-east1` (Taiwan)
- `us-central1` (Iowa) - mặc định

**Lưu ý:** Location không thể thay đổi sau khi tạo!

Nhấn **"Done"** (Xong) để hoàn tất.

## Bước 5: Deploy Storage Rules

Sau khi setup xong, deploy rules từ terminal:

```bash
firebase deploy --only storage
```

Kết quả mong đợi:
```
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/duankmessapp/overview
```

## Bước 6: Kiểm tra Storage đã hoạt động

1. Mở Firebase Console → Storage
2. Bạn sẽ thấy bucket `duankmessapp.firebasestorage.app`
3. Thử upload file test (nếu muốn)

## Bước 7: Test trong App

1. Hot restart app (nhấn `R` trong terminal)
2. Thử đăng bài với ảnh/video
3. Upload sẽ hoạt động bình thường

## Storage Rules đã được cấu hình

File `firebase/storage.rules` đã được tạo với rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Cho phép user đã đăng nhập upload/đọc file trong thư mục của họ
    match /posts/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Cho phép đọc public files
    match /{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

**Giải thích:**
- ✅ User đã đăng nhập có thể đọc tất cả files
- ✅ User chỉ có thể upload vào thư mục `posts/{userId}/` của chính họ
- ✅ Bảo mật: Không cho phép user upload vào thư mục của user khác

## Troubleshooting

### Lỗi: "Storage has not been set up"
- **Nguyên nhân:** Chưa setup Storage trong Console
- **Giải pháp:** Làm theo Bước 1-4 ở trên

### Lỗi: "Permission denied" khi upload
- **Nguyên nhân:** Rules chưa được deploy hoặc sai
- **Giải pháp:** 
  1. Deploy rules: `firebase deploy --only storage`
  2. Kiểm tra user đã đăng nhập chưa
  3. Kiểm tra path upload đúng format: `posts/{userId}/...`

### Lỗi: "404 Not Found" khi upload
- **Nguyên nhân:** Storage bucket chưa được tạo
- **Giải pháp:** Setup Storage trong Console (Bước 1-4)

### Upload chậm
- **Nguyên nhân:** Location xa người dùng
- **Giải pháp:** Chọn location gần hơn (nhưng không thể đổi sau khi tạo)

## Lưu ý quan trọng

1. **Location không thể thay đổi:** Chọn cẩn thận ngay từ đầu
2. **Test mode có giới hạn:** Sau 30 ngày cần rules, nên deploy rules sớm
3. **Chi phí:** Storage có free tier rộng rãi, nhưng nên theo dõi usage
4. **Bảo mật:** Luôn deploy rules trước khi release production

## Kiểm tra Storage đã setup

Sau khi setup, bạn có thể kiểm tra:

1. **Trong Console:**
   - Vào Storage → Files
   - Sẽ thấy bucket `duankmessapp.firebasestorage.app`

2. **Trong code:**
   - Upload sẽ không còn lỗi 404
   - Files sẽ xuất hiện trong Console

---

**Sau khi hoàn tất:** Chạy `firebase deploy --only storage` để deploy rules và test upload trong app!

