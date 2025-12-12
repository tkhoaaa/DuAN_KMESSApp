# Hướng Dẫn: Thêm SHA-1 vào Firebase Console

## 🔑 SHA-1 Fingerprint Của Bạn

```
2B:A0:44:DF:6C:0B:8D:18:A0:72:0C:52:36:98:E0:05:B5:DB:D3:63
```

## 📋 Các Bước Thêm SHA-1 Vào Firebase Console

### Bước 1: Mở Firebase Console

1. Vào [Firebase Console](https://console.firebase.google.com/)
2. Đăng nhập bằng tài khoản Google của bạn
3. Chọn **project** của bạn (hoặc tạo project mới nếu chưa có)

### Bước 2: Vào Project Settings

1. Click vào **⚙️ Settings** (biểu tượng bánh răng) ở góc trên bên trái
2. Chọn **Project settings**

### Bước 3: Tìm App Android Của Bạn

1. Scroll xuống phần **"Your apps"**
2. Tìm app Android của bạn (có icon Android màu xanh lá)
3. Nếu chưa có app Android, click **"Add app"** > chọn **Android** và làm theo hướng dẫn

### Bước 4: Thêm SHA-1 Fingerprint

1. Trong phần app Android, tìm mục **"SHA certificate fingerprints"**
2. Click nút **"Add fingerprint"** (hoặc icon **+**)
3. Một dialog sẽ hiện ra với ô input
4. **Paste SHA-1** vào:
   ```
   2B:A0:44:DF:6C:0B:8D:18:A0:72:0C:52:36:98:E0:05:B5:DB:D3:63
   ```
5. Click **"Save"** hoặc **"Add"**

### Bước 5: Tải Lại google-services.json

**QUAN TRỌNG:** Sau khi thêm SHA-1, bạn **PHẢI** tải lại file `google-services.json`!

1. Vẫn ở trang **Project settings**
2. Scroll xuống phần **"Your apps"** > app Android của bạn
3. Click nút **"Download google-services.json"** (hoặc icon download)
4. File `google-services.json` sẽ được tải về

### Bước 6: Thay Thế File google-services.json

1. Mở file `google-services.json` vừa tải về
2. Copy toàn bộ nội dung
3. Mở file `android/app/google-services.json` trong project
4. **Thay thế** toàn bộ nội dung bằng nội dung mới
5. **Save** file

### Bước 7: Rebuild App

```bash
flutter clean
flutter pub get
flutter run
```

## ✅ Kiểm Tra

Sau khi thêm SHA-1 và rebuild, Google Sign-In sẽ hoạt động. Nếu vẫn gặp lỗi:

1. Kiểm tra lại SHA-1 đã được thêm chưa trong Firebase Console
2. Đảm bảo đã tải lại `google-services.json`
3. Đảm bảo đã rebuild app sau khi thay file

## 📸 Hình Ảnh Tham Khảo

### Vị Trí Thêm SHA-1:
```
Firebase Console
  └─ Project Settings (⚙️)
      └─ Your apps
          └─ Android app
              └─ SHA certificate fingerprints
                  └─ [Add fingerprint] ← Click đây
```

### Dialog Thêm SHA-1:
```
┌─────────────────────────────────────┐
│ Add SHA certificate fingerprint    │
├─────────────────────────────────────┤
│ SHA-1:                              │
│ [2B:A0:44:DF:6C:0B:8D:18:...]       │
│                                     │
│ [Cancel]  [Save]                    │
└─────────────────────────────────────┘
```

## 🔄 Nếu Có Nhiều SHA-1

Bạn có thể thêm nhiều SHA-1 (ví dụ: debug, release, của các developer khác):
- Click **"Add fingerprint"** nhiều lần
- Mỗi lần thêm một SHA-1 khác nhau

## ⚠️ Lưu Ý

- **Debug keystore:** SHA-1 này (`2B:A0:44:DF:...`) là của debug keystore
- **Release keystore:** Khi build release, bạn cần thêm SHA-1 của release keystore
- **Multiple developers:** Mỗi developer cần thêm SHA-1 của họ vào Firebase Console

## 🆘 Nếu Không Tìm Thấy Nút "Add fingerprint"

1. Đảm bảo bạn đã tạo app Android trong Firebase Console
2. Đảm bảo bạn đang ở đúng project
3. Thử refresh trang (F5)
4. Thử đăng xuất và đăng nhập lại

