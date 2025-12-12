# Hướng Dẫn Tạo Hash Key cho Facebook Login

## Bước 1: Tạo Development Hash Key (cho môi trường phát triển)

### Trên Windows:

1. **Mở Command Prompt (CMD) hoặc PowerShell** với quyền Administrator

2. **Tìm đường dẫn Java SDK của bạn:**
   - Thường nằm tại: `C:\Program Files\Java\jdk-XX\bin\` hoặc
   - `C:\Program Files (x86)\Java\jdk-XX\bin\`
   - Hoặc nếu dùng Android Studio: `C:\Program Files\Android\Android Studio\jbr\bin\`

3. **Chạy lệnh sau** (thay `USERNAME` bằng tên user Windows của bạn):

```bash
keytool -exportcert -alias androiddebugkey -keystore "C:\Users\USERNAME\.android\debug.keystore" -storepass android -keypass android | openssl sha1 -binary | openssl base64
```

**Ví dụ:**
```bash
keytool -exportcert -alias androiddebugkey -keystore "C:\Users\Admin\.android\debug.keystore" -storepass android -keypass android | openssl sha1 -binary | openssl base64
```

### Nếu không có OpenSSL:

**Cách 1: Cài đặt OpenSSL**
- Tải từ: https://slproweb.com/products/Win32OpenSSL.html
- Hoặc dùng Git Bash (đã có sẵn OpenSSL)

**Cách 2: Dùng Git Bash**
1. Mở Git Bash
2. Chạy lệnh:
```bash
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | openssl sha1 -binary | openssl base64
```

**Cách 3: Chỉ lấy certificate, sau đó convert**
```bash
# Bước 1: Export certificate
keytool -exportcert -alias androiddebugkey -keystore "C:\Users\Admin\.android\debug.keystore" -storepass android -keypass android > cert.txt

# Bước 2: Convert sang base64 (dùng online tool hoặc openssl)
```

### Kết quả:
Bạn sẽ nhận được một chuỗi 28 ký tự dạng base64, ví dụ: `nm0blrXpAM3cUsh...`

## Bước 2: Thêm Hash Key vào Facebook Developer Console

1. **Copy hash key** vừa tạo
2. **Paste vào trường "Hash khóa"** trong Facebook Developer Console (trang hiện tại)
3. **Nhấn "Save"**

## Bước 3: Vào Basic Settings

### Cách 1: Từ Sidebar
1. Trong sidebar bên trái, tìm và click vào **"Cài đặt ứng dụng"** (App Settings)
2. Click vào **"Cơ bản"** (Basic) - đây là tab đầu tiên

### Cách 2: Từ URL trực tiếp
1. URL sẽ là: `https://developers.facebook.com/apps/841543928576901/settings/basic/`
2. Hoặc thay `841543928576901` bằng App ID của bạn

### Cách 3: Từ Menu
1. Click vào tên app **"Kmess"** ở góc trên bên trái
2. Chọn **"Settings"** hoặc **"Cài đặt"**
3. Chọn **"Basic"** hoặc **"Cơ bản"**

## Trong Basic Settings bạn sẽ thấy:

- **App ID:** `841543928576901`
- **App Secret:** (Click "Show" để hiện) - **CẦN THIẾT cho Firebase**
- **Display Name:** Tên hiển thị của app
- **App Domains:** Domain của app
- **Privacy Policy URL:** (Cần thiết khi publish)
- **Terms of Service URL:** (Cần thiết khi publish)
- **Category:** Loại app
- **Contact Email:** Email liên hệ

## Lưu ý quan trọng:

1. **App Secret:** Copy và lưu lại để dùng trong Firebase Console
2. **Hash Key:** Cần thêm hash key cho mỗi developer/máy tính khác nhau
3. **Release Hash Key:** Khi publish app, cần tạo hash key từ release keystore

## Tạo Release Hash Key (khi publish):

```bash
keytool -exportcert -alias YOUR_RELEASE_KEY_ALIAS -keystore "PATH_TO_YOUR_RELEASE_KEYSTORE" -storepass YOUR_STORE_PASSWORD -keypass YOUR_KEY_PASSWORD | openssl sha1 -binary | openssl base64
```

Thay:
- `YOUR_RELEASE_KEY_ALIAS`: Tên alias của release key
- `PATH_TO_YOUR_RELEASE_KEYSTORE`: Đường dẫn đến file .jks hoặc .keystore
- `YOUR_STORE_PASSWORD`: Mật khẩu của keystore
- `YOUR_KEY_PASSWORD`: Mật khẩu của key

## Troubleshooting:

### Lỗi: "keytool không được nhận dạng"
- Thêm Java bin vào PATH environment variable
- Hoặc dùng full path: `"C:\Program Files\Java\jdk-XX\bin\keytool.exe"`

### Lỗi: "openssl không được nhận dạng"
- Cài đặt OpenSSL hoặc dùng Git Bash
- Hoặc dùng online tool để convert certificate sang base64

### Không tìm thấy debug.keystore
- Chạy Flutter app một lần để tự động tạo debug.keystore
- Hoặc tạo thủ công bằng Android Studio

