# Khắc Phục Lỗi Đăng Nhập Facebook

## 🔍 Các Lỗi Thường Gặp

### 1. Lỗi: "Facebook login failed" hoặc không có phản hồi

**Nguyên nhân có thể:**
- Facebook App chưa được cấu hình đúng
- Hash key chưa được thêm vào Facebook Console
- Client Token chưa được cập nhật
- Firebase chưa được cấu hình Facebook provider

**Cách khắc phục:**

1. **Kiểm tra Hash Key:**
   - Vào Facebook Console > Settings > Basic
   - Kiểm tra Hash Key đã được thêm chưa
   - Nếu chưa, tạo lại hash key và thêm vào

2. **Kiểm tra Client Token:**
   - Mở: `android/app/src/main/res/values/strings.xml`
   - Đảm bảo `facebook_client_token` đã được cập nhật (không phải `YOUR_CLIENT_TOKEN_HERE`)

3. **Kiểm tra Firebase Console:**
   - Vào Firebase Console > Authentication > Sign-in method
   - Đảm bảo Facebook provider đã được bật
   - Kiểm tra App ID và App Secret đã được nhập đúng

4. **Kiểm tra AndroidManifest.xml:**
   - Đảm bảo đã có FacebookActivity và CustomTabActivity
   - Đảm bảo meta-data cho App ID và Client Token đã được thêm

### 2. Lỗi: "Invalid key hash"

**Nguyên nhân:** Hash key không khớp với Facebook Console

**Cách khắc phục:**
1. Tạo lại hash key:
   ```bash
   keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | openssl sha1 -binary | openssl base64
   ```
2. Copy hash key mới
3. Vào Facebook Console > Settings > Basic
4. Thêm hash key mới vào "Hash khóa"
5. Save

### 3. Lỗi: "App not set up"

**Nguyên nhân:** Package name hoặc Class name không đúng

**Cách khắc phục:**
1. Kiểm tra Package Name trong Facebook Console:
   - Phải là: `com.example.duan_kmessapp`
2. Kiểm tra Class Name:
   - Phải là: `com.example.duan_kmessapp.MainActivity`
3. Nếu sai, cập nhật trong Facebook Console > Settings > Basic > Android

### 4. Lỗi: User cancelled (Người dùng hủy)

**Đây không phải lỗi:** Người dùng đã hủy đăng nhập
- Code đã xử lý và không hiển thị error message

### 5. Lỗi: "Account exists with different credential"

**Nguyên nhân:** Email đã được đăng ký bằng phương thức khác (email/password)

**Cách khắc phục:**
- Thông báo cho user: "Tài khoản này đã được đăng ký bằng email/mật khẩu"
- User cần đăng nhập bằng email/password thay vì Facebook

## 🛠️ Debug Steps

### Bước 1: Kiểm tra Logs

Khi test Facebook login, xem logcat để tìm lỗi cụ thể:
```bash
flutter run
# Hoặc
adb logcat | grep -i facebook
```

### Bước 2: Kiểm tra Cấu Hình

**Checklist:**
- [ ] Hash key đã được thêm vào Facebook Console
- [ ] Client Token đã được cập nhật trong strings.xml
- [ ] AndroidManifest.xml đã có FacebookActivity và CustomTabActivity
- [ ] Firebase Console đã cấu hình Facebook provider
- [ ] App ID và App Secret trong Firebase đúng với Facebook Console

### Bước 3: Test với Facebook Test Users

1. Vào Facebook Console > Roles > Test Users
2. Tạo test user
3. Test login với test user này

### Bước 4: Kiểm tra App Mode

- **Development mode:** Chỉ test users mới login được
- **Live mode:** Tất cả users có thể login (cần review từ Facebook)

## 📝 Code Đã Được Cải Thiện

Code hiện tại đã có:
- ✅ Error handling tốt hơn với logging
- ✅ Auto-create profile từ Facebook data
- ✅ Fallback nếu không lấy được Facebook profile
- ✅ Xử lý user cancelled (không hiển thị error)

## 🔧 Nếu Vẫn Gặp Lỗi

1. **Xem logcat đầy đủ:**
   ```bash
   adb logcat | grep -E "(Facebook|flutter|auth)"
   ```

2. **Kiểm tra Facebook App Status:**
   - Vào Facebook Console > App Review
   - Đảm bảo app không bị restricted

3. **Test trên thiết bị thật:**
   - Emulator có thể có vấn đề với Facebook SDK
   - Test trên thiết bị Android thật

4. **Kiểm tra Internet Connection:**
   - Facebook login cần internet
   - Đảm bảo device có kết nối internet

## 📞 Thông Tin Debug

Khi gặp lỗi, cung cấp:
- Logcat output (đặc biệt là errors)
- Screenshot của error message (nếu có)
- Facebook App ID
- Package name và class name
- Hash key đã thêm vào Facebook Console

