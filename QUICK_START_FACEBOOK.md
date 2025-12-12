# Hướng Dẫn Nhanh: Tạo Hash Key & Vào Basic Settings

## 🚀 CÁCH NHANH NHẤT: Dùng Git Bash

### Bước 1: Mở Git Bash
- Tìm "Git Bash" trong Start Menu và mở

### Bước 2: Chạy lệnh này:
```bash
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | openssl sha1 -binary | openssl base64
```

**Lưu ý:** Nếu gặp lỗi khi paste, hãy **gõ trực tiếp** thay vì paste, hoặc:
- Tắt paste mode: Nhấn `Shift + Insert` thay vì `Ctrl + V`
- Hoặc paste vào Notepad trước, rồi copy lại

### Bước 3: Copy kết quả (chuỗi ~28 ký tự)
- Ví dụ: `nm0blrXpAM3cUsh...`

### Bước 4: Paste vào Facebook Console
- Paste vào ô "Hash khóa" trong trang hiện tại
- Nhấn "Save"

---

## 📍 CÁCH VÀO BASIC SETTINGS

### Cách 1: Từ Sidebar (Dễ nhất)
1. Nhìn vào **sidebar bên trái**
2. Click vào **"Cài đặt ứng dụng"** (App Settings) 
3. Tab đầu tiên chính là **"Cơ bản"** (Basic)

### Cách 2: Từ URL
Copy và paste vào browser:
```
https://developers.facebook.com/apps/841543928576901/settings/basic/
```

### Cách 3: Từ Menu trên cùng
1. Click vào tên app **"Kmess"** (góc trên bên trái, cạnh logo Meta)
2. Chọn **"Settings"** hoặc **"Cài đặt"**
3. Chọn **"Basic"** hoặc **"Cơ bản"**

---

## 🔑 TRONG BASIC SETTINGS BẠN CẦN:

1. **App ID:** `841543928576901` (đã có)
2. **App Secret:** 
   - Click nút **"Show"** để hiện
   - **COPY và LƯU LẠI** - cần cho Firebase Console

---

## ⚠️ NẾU KHÔNG CÓ GIT BASH:

### Cách 1: Cài OpenSSL
1. Tải: https://slproweb.com/products/Win32OpenSSL.html
2. Cài đặt
3. Chạy lại lệnh trong CMD

### Cách 2: Dùng Online Tool
1. Export certificate:
   ```cmd
   keytool -exportcert -alias androiddebugkey -keystore "C:\Users\Admin\.android\debug.keystore" -storepass android -keypass android > cert.cer
   ```
2. Vào: https://www.base64encode.org/
3. Upload file `cert.cer`
4. Encode sang base64
5. Lấy hash từ kết quả

---

## ✅ CHECKLIST:

- [ ] Đã tạo hash key bằng Git Bash
- [ ] Đã paste hash key vào Facebook Console và Save
- [ ] Đã vào Basic Settings
- [ ] Đã copy App Secret
- [ ] Đã thêm App Secret vào Firebase Console

---

## 🎯 BƯỚC TIẾP THEO:

Sau khi có App Secret:
1. Vào Firebase Console
2. Authentication > Sign-in method
3. Bật Facebook
4. Nhập App ID và App Secret
5. Save

Xong! 🎉

