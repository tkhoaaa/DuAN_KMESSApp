# Khắc Phục Nhanh Lỗi Đăng Nhập Facebook

## ✅ Đã Cải Thiện Code

1. **Thêm logging** để debug dễ hơn
2. **Cải thiện error handling** với các error codes cụ thể
3. **Auto-create profile** từ Facebook data
4. **Thêm Facebook SDK dependency** vào build.gradle.kts

## 🔧 Các Bước Khắc Phục

### Bước 1: Rebuild App

Sau khi thay đổi AndroidManifest và strings.xml, cần rebuild:

```bash
flutter clean
flutter pub get
flutter run
```

### Bước 2: Kiểm tra Checklist

- [x] Hash key đã thêm vào Facebook Console: `2jmj7l5rSw0yVb/vlWAYkK/YBwk=`
- [x] Client Token đã cập nhật: `47317f61b2f10e1ff5cf0a0a6c7f829a`
- [x] AndroidManifest.xml đã có FacebookActivity và CustomTabActivity
- [x] strings.xml đã có đầy đủ Facebook config
- [ ] **Firebase Console đã cấu hình Facebook provider** ⭐ QUAN TRỌNG
- [ ] **App Secret đã được thêm vào Firebase** ⭐ QUAN TRỌNG

### Bước 3: Cấu Hình Firebase Console

**QUAN TRỌNG:** Đây là bước dễ bỏ sót nhất!

1. Vào [Firebase Console](https://console.firebase.google.com/)
2. Chọn project của bạn
3. Vào **Authentication** > **Sign-in method**
4. Tìm **Facebook** và click vào
5. **Bật** Facebook provider
6. Nhập:
   - **App ID:** `841543928576901`
   - **App Secret:** (Lấy từ Facebook Console > Settings > Basic > App Secret)
7. Click **Save**

### Bước 4: Test Lại

1. **Clean và rebuild:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Test Facebook login:**
   - Click nút "Đăng nhập bằng Facebook"
   - Kiểm tra logcat để xem có lỗi gì không

3. **Xem logs:**
   ```bash
   adb logcat | grep -E "(Facebook|flutter|auth|error)"
   ```

## 🐛 Debug Logs

Code đã được thêm logging. Khi test, xem logcat để thấy:
- `Facebook login failed: ...` - Nếu login thất bại
- `Facebook profile data: ...` - Nếu lấy được profile
- `Error getting Facebook profile: ...` - Nếu không lấy được profile từ Facebook

## ⚠️ Lỗi Thường Gặp

### "Invalid OAuth Access Token"
- **Nguyên nhân:** Firebase chưa được cấu hình Facebook provider
- **Giải pháp:** Cấu hình Firebase Console (Bước 3 ở trên)

### "App not set up"
- **Nguyên nhân:** Package name hoặc hash key không đúng
- **Giải pháp:** Kiểm tra lại trong Facebook Console

### User cancelled
- **Không phải lỗi:** Code đã xử lý, không hiển thị error

## 📝 Lưu Ý

- **Development mode:** Chỉ test users mới login được
- **Cần rebuild** sau khi thay đổi AndroidManifest hoặc strings.xml
- **Firebase configuration** là bước quan trọng nhất, dễ bỏ sót

