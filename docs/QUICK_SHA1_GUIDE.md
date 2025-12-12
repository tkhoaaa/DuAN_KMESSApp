# Hướng Dẫn Nhanh: Lấy SHA-1 Fingerprint

## ✅ SHA-1 Fingerprint Hiện Tại

**SHA-1:** `2B:A0:44:DF:6C:0B:8D:18:A0:72:0C:52:36:98:E0:05:B5:DB:D3:63`

## 🚀 Cách Lấy SHA-1 (Nếu Cần Lấy Lại)

### Windows PowerShell:
```powershell
cd android
.\gradlew.bat signingReport
```

### Windows CMD:
```cmd
cd android
gradlew.bat signingReport
```

### Hoặc dùng Script:
```powershell
# PowerShell
.\scripts\get_sha1.ps1

# CMD
scripts\get_sha1.bat
```

Tìm dòng `SHA1:` trong output và copy giá trị.

## 📝 Thêm SHA-1 Vào Firebase Console

1. Vào [Firebase Console](https://console.firebase.google.com/)
2. Chọn project của bạn
3. Vào **Project Settings** (⚙️) > **Your apps**
4. Chọn app Android của bạn
5. Click **"Add fingerprint"**
6. Paste SHA-1: `2B:A0:44:DF:6C:0B:8D:18:A0:72:0C:52:36:98:E0:05:B5:DB:D3:63`
7. Click **Save**

## 🔄 Sau Khi Thêm SHA-1

1. **Tải lại `google-services.json`:**
   - Vẫn ở trang Project Settings
   - Click **"Download google-services.json"**
   - Thay thế file cũ trong `android/app/google-services.json`

2. **Rebuild app:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## ⚠️ Lưu Ý

- **Debug keystore:** SHA-1 này là của debug keystore (dùng khi development)
- **Release keystore:** Khi build release, cần thêm SHA-1 của release keystore
- **Multiple developers:** Mỗi developer cần thêm SHA-1 của họ vào Firebase Console

## 🐛 Nếu Vẫn Gặp Lỗi

Xem chi tiết trong: `docs/GOOGLE_SIGNIN_TROUBLESHOOTING.md`



