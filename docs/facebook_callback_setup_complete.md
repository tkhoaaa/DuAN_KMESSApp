# Hướng dẫn hoàn chỉnh: Thêm Callback URL vào Facebook Developer Console

## Vấn đề
Lỗi "Ứng dụng không hoạt động" xảy ra vì:
1. Thiếu OAuth Redirect URI trong Facebook Developer Console
2. Ứng dụng đang ở chế độ Development (chưa chuyển sang Live Mode)
3. Thiếu các URL bắt buộc (Privacy Policy, Terms of Service, User Data Deletion)

## Các URL Callback cần thêm

### 1. OAuth Redirect URIs (QUAN TRỌNG NHẤT)

Thêm **CẢ HAI** URL sau vào Facebook Developer Console:

```
https://duankmessapp.firebaseapp.com/_/auth/handler
https://duankmessapp.firebaseapp.com/auth/facebook/callback
```

## Hướng dẫn từng bước

### BƯỚC 1: Thêm OAuth Redirect URIs

1. **Truy cập Facebook Login Settings:**
   - Vào: https://developers.facebook.com/apps/1576453390212797/fb-login/settings/
   - Hoặc: App → Sản phẩm → Đăng nhập bằng Facebook → Cài đặt

2. **Cuộn xuống phần "Cài đặt OAuth ứng dụng" (App OAuth Settings)**

3. **Tìm trường "URI chuyển hướng OAuth hợp lệ" (Valid OAuth redirect URIs)**
   - Đây là một textarea lớn, có thể trống hoặc đã có một số URI

4. **Thêm các URI sau (mỗi URI trên một dòng):**
   ```
   https://duankmessapp.firebaseapp.com/_/auth/handler
   https://duankmessapp.firebaseapp.com/auth/facebook/callback
   ```

5. **Lưu thay đổi:**
   - Click nút **"Lưu thay đổi"** (Save Changes) ở cuối trang
   - Đợi vài giây để Facebook lưu

6. **Kiểm tra lại:**
   - Cuộn lên phần **"Công cụ xác thực URI chuyển hướng"** (Redirect URI validation tool)
   - Nhập từng URI và click "Kiểm tra URI"
   - Cả hai URI phải hiển thị dấu tích xanh (✓)

### BƯỚC 2: Cập nhật Basic Settings (Nếu chưa có)

1. **Truy cập Basic Settings:**
   - Vào: https://developers.facebook.com/apps/1576453390212797/settings/basic/

2. **Thêm các URL bắt buộc:**
   - **URL chính sách quyền riêng tư:**
     ```
     https://duankmessapp.firebaseapp.com/privacy-policy.html
     ```
   
   - **URL Điều khoản dịch vụ:**
     ```
     https://duankmessapp.firebaseapp.com/terms-of-service.html
     ```
   
   - **URL hướng dẫn xóa dữ liệu người dùng:**
     ```
     https://duankmessapp.firebaseapp.com/user-data-deletion.html
     ```

3. **Lưu thay đổi**

### BƯỚC 3: Cấu hình Android (Nếu chưa có)

1. **Vào phần Settings → Basic**
2. **Thêm Android Platform:**
   - Click **"+ Thêm nền tảng"** (+ Add Platform) → Chọn **Android**
   - **Package Name:** `com.example.duan_kmessapp`
   - **Class Name:** `com.example.duan_kmessapp.MainActivity`
   - **Key Hashes:** Thêm key hash của bạn (ví dụ: `K6BE32wLjRigcgxSNpjgBbXb02M=`)

### BƯỚC 4: Chuyển sang Live Mode (QUAN TRỌNG)

1. **Kiểm tra tất cả yêu cầu đã hoàn thành:**
   - ✅ OAuth Redirect URIs đã được thêm
   - ✅ Privacy Policy URL đã được thêm
   - ✅ Terms of Service URL đã được thêm
   - ✅ User Data Deletion URL đã được thêm
   - ✅ Android Package Name đã được cấu hình (nếu có)

2. **Chuyển sang Live Mode:**
   - Vào: https://developers.facebook.com/apps/1576453390212797/settings/basic/
   - Tìm phần **"Chế độ của ứng dụng"** (App Mode)
   - Toggle switch từ **"Phát triển"** (Development) sang **"Chính thức"** (Live)
   - Xác nhận chuyển đổi

3. **Lưu ý:**
   - Khi chuyển sang Live Mode, Facebook sẽ kiểm tra lại tất cả các URL
   - Đảm bảo tất cả URL đều có thể truy cập công khai (Response Code 200-299)
   - Nếu có lỗi, Facebook sẽ hiển thị cảnh báo

## Kiểm tra sau khi cấu hình

### 1. Kiểm tra OAuth Redirect URIs
- Vào: https://developers.facebook.com/apps/1576453390212797/fb-login/settings/
- Sử dụng "Công cụ xác thực URI chuyển hướng" để kiểm tra từng URI
- Tất cả URI phải hiển thị dấu tích xanh

### 2. Kiểm tra URLs bằng Meta Sharing Debugger
- Vào: https://developers.facebook.com/tools/debug/
- Kiểm tra từng URL:
  - https://duankmessapp.firebaseapp.com/privacy-policy.html
  - https://duankmessapp.firebaseapp.com/terms-of-service.html
  - https://duankmessapp.firebaseapp.com/user-data-deletion.html
- Response Code phải là 200-299

### 3. Test Facebook Login
- Mở ứng dụng và thử đăng nhập bằng Facebook
- Nếu vẫn lỗi, kiểm tra lại:
  - App đã chuyển sang Live Mode chưa?
  - Tất cả URL đã được thêm đúng chưa?
  - Có cảnh báo nào trong Facebook Console không?

## Troubleshooting

### Lỗi: "Ứng dụng không hoạt động"
**Nguyên nhân:**
- App đang ở chế độ Development
- Thiếu OAuth Redirect URIs
- Thiếu các URL bắt buộc

**Giải pháp:**
1. Thêm đầy đủ OAuth Redirect URIs (Bước 1)
2. Thêm các URL bắt buộc (Bước 2)
3. Chuyển sang Live Mode (Bước 4)

### Lỗi: "Invalid redirect URI"
**Nguyên nhân:**
- URI chưa được thêm vào danh sách "Valid OAuth redirect URIs"
- URI có lỗi chính tả

**Giải pháp:**
1. Kiểm tra lại URI có đúng không
2. Đảm bảo đã thêm vào "Valid OAuth redirect URIs"
3. Lưu thay đổi và đợi vài phút

### Lỗi: "Broken URL detected"
**Nguyên nhân:**
- URL không thể truy cập được
- Response Code không phải 200-299

**Giải pháp:**
1. Kiểm tra URL có thể truy cập được không
2. Sử dụng Meta Sharing Debugger để kiểm tra
3. Đảm bảo URL trả về Response Code 200-299

## Tóm tắt các URL cần thêm

### OAuth Redirect URIs (Facebook Login Settings):
```
https://duankmessapp.firebaseapp.com/_/auth/handler
https://duankmessapp.firebaseapp.com/auth/facebook/callback
```

### Basic Settings URLs:
```
Privacy Policy: https://duankmessapp.firebaseapp.com/privacy-policy.html
Terms of Service: https://duankmessapp.firebaseapp.com/terms-of-service.html
User Data Deletion: https://duankmessapp.firebaseapp.com/user-data-deletion.html
```

## Checklist hoàn chỉnh

Trước khi chuyển sang Live Mode, đảm bảo:

- [ ] Đã thêm OAuth Redirect URI: `/_/auth/handler`
- [ ] Đã thêm OAuth Redirect URI: `/auth/facebook/callback`
- [ ] Đã kiểm tra cả hai URI bằng validation tool (dấu tích xanh)
- [ ] Đã thêm Privacy Policy URL
- [ ] Đã thêm Terms of Service URL
- [ ] Đã thêm User Data Deletion URL
- [ ] Đã kiểm tra tất cả URL bằng Meta Sharing Debugger (Response Code 200-299)
- [ ] Đã cấu hình Android Package Name (nếu có)
- [ ] Đã chuyển App Mode sang "Chính thức" (Live)

Sau khi hoàn tất tất cả các bước trên, Facebook Login sẽ hoạt động bình thường!

