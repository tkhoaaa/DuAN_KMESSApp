# Hướng Dẫn Điền Basic Settings trong Facebook Developer Console

## ✅ Các Trường Đã Có (Không Cần Sửa)

- **ID ứng dụng (App ID):** `841543928576901` ✅
- **Tên hiển thị (Display Name):** `Kmess` ✅
- **Email liên hệ (Contact Email):** `votienkhoa111@gmail.com` ✅

## 🔑 Các Trường Cần Điền/Quan Trọng

### 1. **Khóa bí mật của ứng dụng (App Secret)**
- **Đã có:** Click "Hiển thị" để xem
- **Cần:** Copy và lưu lại để dùng cho **Firebase Console**
- **Lưu ý:** Giữ bí mật, không public

### 2. **Client Token** ⭐ **QUAN TRỌNG**
- **Vị trí:** Scroll xuống dưới trong section "Thông tin cơ bản"
- **Hoặc:** Có thể nằm ngay dưới App Secret
- **Cách lấy:**
  1. Tìm trường "Client Token" hoặc "Mã ứng dụng"
  2. Click "Hiển thị" để xem
  3. Copy Client Token
  4. Paste vào `android/app/src/main/res/values/strings.xml`

**Nếu không thấy Client Token:**
- Scroll xuống trong section "Thông tin cơ bản"
- Hoặc thử refresh trang
- Hoặc dùng Graph API Explorer để lấy (xem bên dưới)

### 3. **Biểu tượng ứng dụng (App Icon)**
- **Kích thước:** 1024 x 1024 pixels
- **Định dạng:** PNG hoặc JPG
- **Tùy chọn:** Có thể bỏ qua nếu chưa có
- **Khi nào cần:** Khi publish app lên store

### 4. **Privacy Policy URL** (Chính sách bảo mật)
- **Bắt buộc:** Khi publish app
- **Hiện tại:** Có thể bỏ trống (cho development)
- **Format:** `https://yourdomain.com/privacy-policy`
- **Ví dụ:** `https://kmessapp.com/privacy-policy`

### 5. **Terms of Service URL** (Điều khoản dịch vụ)
- **Bắt buộc:** Khi publish app
- **Hiện tại:** Có thể bỏ trống (cho development)
- **Format:** `https://yourdomain.com/terms`
- **Ví dụ:** `https://kmessapp.com/terms`

### 6. **User Data Deletion URL** (URL xóa dữ liệu người dùng)
- **Tùy chọn:** Nhưng nên có khi publish
- **Format:** `https://yourdomain.com/delete-account`
- **Mục đích:** Cho phép user xóa dữ liệu của họ

### 7. **Category** (Danh mục)
- **Chọn:** Danh mục phù hợp với app
- **Ví dụ:** "Social", "Communication", "Entertainment"

### 8. **App Domains** (Tên miền ứng dụng)
- **Nếu có website:** Thêm domain
- **Ví dụ:** `kmessapp.com`
- **Nếu chỉ có mobile app:** Có thể bỏ trống

## 🎯 Checklist Cho Development (Hiện Tại)

### Bắt buộc:
- [x] App ID ✅
- [x] Display Name ✅
- [x] Contact Email ✅
- [ ] **Client Token** ⭐ (Cần tìm và copy)
- [ ] App Secret (Đã có, chỉ cần copy cho Firebase)

### Tùy chọn (Có thể bỏ qua cho development):
- [ ] App Icon (Có thể thêm sau)
- [ ] Privacy Policy URL (Cần khi publish)
- [ ] Terms of Service URL (Cần khi publish)
- [ ] User Data Deletion URL (Nên có khi publish)
- [ ] Category (Có thể chọn sau)
- [ ] App Domains (Nếu không có website)

## 🔍 Cách Tìm Client Token Nếu Không Thấy

### Cách 1: Scroll trong Basic Settings
- Scroll xuống trong section "Thông tin cơ bản"
- Tìm trường "Client Token" hoặc "Mã ứng dụng"

### Cách 2: Dùng Graph API Explorer
1. Vào: https://developers.facebook.com/tools/explorer/
2. Chọn app "Kmess" từ dropdown
3. Query: `841543928576901?fields=client_token`
4. Click "Submit"
5. Sẽ trả về Client Token

### Cách 3: Kiểm tra trong Settings khác
- Thử vào: **Settings > Advanced**
- Hoặc: **Settings > Security**

## 📝 Sau Khi Có Client Token

1. Copy Client Token
2. Mở: `android/app/src/main/res/values/strings.xml`
3. Thay `YOUR_CLIENT_TOKEN_HERE` bằng Client Token
4. Save file

## ⚠️ Lưu Ý

- **App Secret:** Chỉ dùng cho Firebase Console, giữ bí mật
- **Client Token:** Có thể public, dùng trong Android app
- **Privacy Policy & Terms:** Bắt buộc khi publish, có thể bỏ trống cho development
- **App Icon:** Nên có khi publish, không bắt buộc cho development

