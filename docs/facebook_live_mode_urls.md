# URLs cho Facebook Live Mode

## Tổng quan

Để chuyển Facebook App sang chế độ Live Mode, bạn cần cung cấp các URL sau trong Facebook Developer Console:

## Các URL cần thiết

### 1. Privacy Policy URL (URL chính sách quyền riêng tư)
```
https://duankmessapp.firebaseapp.com/privacy-policy.html
```

### 2. Terms of Service URL (URL điều khoản dịch vụ)
```
https://duankmessapp.firebaseapp.com/terms-of-service.html
```

### 3. User Data Deletion URL (URL hướng dẫn xóa dữ liệu người dùng)
```
https://duankmessapp.firebaseapp.com/user-data-deletion.html
```

## Cách deploy lên Firebase Hosting

### Bước 1: Cài đặt Firebase CLI (nếu chưa có)
```bash
npm install -g firebase-tools
```

### Bước 2: Đăng nhập Firebase
```bash
firebase login
```

### Bước 3: Deploy hosting
```bash
firebase deploy --only hosting
```

### Hoặc sử dụng script tự động
Tạo file `deploy_hosting.bat` (Windows) hoặc `deploy_hosting.sh` (Linux/Mac) để deploy tự động.

## Kiểm tra sau khi deploy

Sau khi deploy thành công, truy cập các URL sau để kiểm tra:

1. https://duankmessapp.firebaseapp.com/privacy-policy.html
2. https://duankmessapp.firebaseapp.com/terms-of-service.html
3. https://duankmessapp.firebaseapp.com/user-data-deletion.html

## Cập nhật trong Facebook Developer Console

### 1. Cập nhật Basic Settings
1. Vào https://developers.facebook.com/apps/1576453390212797/settings/basic/
2. Điền các URL vào các trường tương ứng:
   - **URL chính sách quyền riêng tư**: `https://duankmessapp.firebaseapp.com/privacy-policy.html`
   - **URL Điều khoản dịch vụ**: `https://duankmessapp.firebaseapp.com/terms-of-service.html`
   - **URL hướng dẫn xóa dữ liệu**: `https://duankmessapp.firebaseapp.com/user-data-deletion.html`
3. Lưu thay đổi

### 2. Cập nhật OAuth Redirect URI (QUAN TRỌNG)
1. Vào https://developers.facebook.com/apps/1576453390212797/fb-login/settings/
2. Cuộn xuống phần **"URI chuyển hướng OAuth hợp lệ"** (Valid OAuth redirect URIs)
3. Thêm URI sau:
   ```
   https://duankmessapp.firebaseapp.com/_/auth/handler
   ```
4. Lưu thay đổi
5. Kiểm tra lại bằng công cụ "Redirect URI validation tool" ở trên

### 3. Chuyển sang Live Mode
Sau khi hoàn tất các bước trên, chuyển chế độ từ "Phát triển" sang "Chính thức" (Live Mode)

## Lưu ý

- Đảm bảo các file HTML đã được deploy thành công trước khi cập nhật trong Facebook Console
- Các URL phải có thể truy cập công khai (public)
- Nội dung các trang phải phù hợp với chính sách của Facebook

