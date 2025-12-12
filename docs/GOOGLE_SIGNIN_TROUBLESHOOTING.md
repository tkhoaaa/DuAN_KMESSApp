# Khắc Phục Lỗi Google Sign-In

## 🔴 Lỗi: `ApiException: 10` (DEVELOPER_ERROR)

**Nguyên nhân:** SHA-1 fingerprint chưa được thêm vào Firebase Console hoặc Google Cloud Console.

### Cách Khắc Phục:

#### Bước 1: Lấy SHA-1 Fingerprint

**Windows (PowerShell):**
```powershell
cd android
.\gradlew.bat signingReport
```

**Windows (CMD):**
```cmd
cd android
gradlew.bat signingReport
```

**Hoặc dùng script có sẵn:**
```powershell
# PowerShell
.\scripts\get_sha1.ps1

# CMD
scripts\get_sha1.bat
```

**Hoặc dùng keytool trực tiếp:**
```cmd
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**Lưu ý:** Nếu keystore chưa tồn tại, nó sẽ được tạo tự động khi bạn build app lần đầu. Hoặc tạo thủ công:
```cmd
keytool -genkey -v -keystore "%USERPROFILE%\.android\debug.keystore" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000
```

**macOS/Linux:**
```bash
cd android
./gradlew signingReport
```

Hoặc:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Tìm dòng `SHA1:` và copy giá trị (ví dụ: `A1:B2:C3:D4:E5:F6:...`)

#### Bước 2: Thêm SHA-1 vào Firebase Console

1. Vào [Firebase Console](https://console.firebase.google.com/)
2. Chọn project của bạn
3. Vào **Project Settings** (⚙️) > **Your apps**
4. Chọn app Android của bạn
5. Click **Add fingerprint**
6. Paste SHA-1 fingerprint đã copy
7. Click **Save**

#### Bước 3: Tải lại `google-services.json`

1. Trong Firebase Console, vẫn ở trang **Project Settings**
2. Tải lại file `google-services.json`
3. Thay thế file cũ trong `android/app/google-services.json`

#### Bước 4: Rebuild App

```bash
flutter clean
flutter pub get
flutter run
```

## 🔴 Lỗi: "Network Error" hoặc "Connection Failed"

**Nguyên nhân:** 
- Không có internet
- Firewall chặn kết nối
- Google Play Services chưa được cập nhật

**Cách khắc phục:**
1. Kiểm tra kết nối internet
2. Đảm bảo Google Play Services đã được cập nhật
3. Test trên thiết bị thật thay vì emulator

## 🔴 Lỗi: "User cancelled"

**Đây không phải lỗi:** Người dùng đã hủy đăng nhập. Code đã xử lý và không hiển thị error.

## ✅ Checklist Cấu Hình Google Sign-In

- [ ] SHA-1 fingerprint đã được thêm vào Firebase Console
- [ ] `google-services.json` đã được tải lại sau khi thêm SHA-1
- [ ] Google Sign-In provider đã được bật trong Firebase Console
- [ ] OAuth consent screen đã được cấu hình trong Google Cloud Console
- [ ] Package name trong Firebase Console khớp với `applicationId` trong `build.gradle.kts`

## 📝 Lưu Ý

- **Debug keystore:** SHA-1 của debug keystore khác với release keystore
- **Release build:** Cần thêm SHA-1 của release keystore khi build release
- **Multiple developers:** Mỗi developer cần thêm SHA-1 của họ vào Firebase Console

## 🔧 Kiểm Tra Cấu Hình

1. **Firebase Console:**
   - Authentication > Sign-in method > Google (phải bật)
   - Project Settings > Your apps > Android app (có SHA-1)

2. **Google Cloud Console:**
   - APIs & Services > Credentials (có OAuth 2.0 Client ID)
   - OAuth consent screen (đã cấu hình)

3. **Android App:**
   - `android/app/google-services.json` (file mới nhất)
   - `android/app/build.gradle.kts` (có `com.google.gms.google-services` plugin)

## 🐛 Debug

Khi gặp lỗi, xem logcat:
```bash
adb logcat | grep -E "(Google|SignIn|auth|error)"
```

Code đã được cải thiện với:
- ✅ Error handling tốt hơn với các error codes cụ thể
- ✅ Logging để debug dễ hơn
- ✅ Auto-create profile sau khi đăng nhập thành công
- ✅ Xử lý user cancelled (không hiển thị error)

