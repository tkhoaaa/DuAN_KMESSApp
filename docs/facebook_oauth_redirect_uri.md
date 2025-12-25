# Hướng dẫn thêm OAuth Redirect URI vào Facebook Developer Console

## Vấn đề
Facebook báo lỗi: "This is an invalid redirect URI of this app" vì URI chưa được thêm vào danh sách "Valid OAuth redirect URIs".

## OAuth Redirect URI cần thêm

Bạn có thể sử dụng một trong hai URI sau (hoặc cả hai):

### 1. Firebase Auth Handler (Khuyến nghị - Tự động xử lý):
```
https://duankmessapp.firebaseapp.com/_/auth/handler
```

**Lưu ý quan trọng:** URI này có **một dấu gạch dưới** (`_/auth/handler`), không phải hai (`__/auth/handler`).

### 2. Custom Callback URL (Tùy chỉnh):
```
https://duankmessapp.firebaseapp.com/auth/facebook/callback
```

Đây là trang callback tùy chỉnh đã được tạo sẵn, cho phép bạn xử lý logic sau khi đăng nhập.

## Các bước thêm URI vào Facebook Developer Console

### Bước 1: Truy cập Facebook Login Settings
1. Vào: https://developers.facebook.com/apps/1576453390212797/fb-login/settings/
2. Hoặc: Vào App → Sản phẩm → Đăng nhập bằng Facebook → Cài đặt

### Bước 2: Tìm phần "Valid OAuth redirect URIs"
- Cuộn xuống phần **"Cài đặt OAuth ứng dụng"** (App OAuth Settings)
- Tìm trường **"URI chuyển hướng OAuth hợp lệ"** (Valid OAuth redirect URIs)
- Đây là một textarea lớn để nhập nhiều URI

### Bước 3: Thêm URI
1. Click vào trường "URI chuyển hướng OAuth hợp lệ"
2. Nhập URI sau (mỗi URI trên một dòng):
   ```
   https://duankmessapp.firebaseapp.com/_/auth/handler
   https://duankmessapp.firebaseapp.com/auth/facebook/callback
   ```
   
   **Lưu ý:** Bạn có thể thêm cả hai URI hoặc chỉ một trong hai. Firebase Auth Handler (`/_/auth/handler`) được khuyến nghị vì nó tự động xử lý authentication flow.

### Bước 4: Lưu thay đổi
- Click nút **"Lưu thay đổi"** (Save Changes) ở cuối trang
- Đợi vài giây để Facebook lưu

### Bước 5: Kiểm tra lại
1. Cuộn lên phần **"Công cụ xác thực URI chuyển hướng"** (Redirect URI validation tool)
2. Kiểm tra từng URI:
   - Nhập: `https://duankmessapp.firebaseapp.com/_/auth/handler`
   - Click **"Kiểm tra URI"** (Check URI)
   - Sau đó kiểm tra: `https://duankmessapp.firebaseapp.com/auth/facebook/callback`
3. Cả hai URI đều phải hiển thị dấu tích xanh (✓) thay vì dấu X đỏ

## Các URI bổ sung (nếu cần)

Nếu bạn cũng sử dụng domain `.web.app`, có thể thêm:
```
https://duankmessapp.web.app/_/auth/handler
https://duankmessapp.web.app/auth/facebook/callback
```

## Sự khác biệt giữa hai URI

### Firebase Auth Handler (`/_/auth/handler`)
- ✅ Tự động xử lý toàn bộ authentication flow
- ✅ Tích hợp sẵn với Firebase Auth
- ✅ Không cần code xử lý thêm
- ✅ Khuyến nghị sử dụng cho Flutter apps

### Custom Callback (`/auth/facebook/callback`)
- ✅ Cho phép tùy chỉnh logic sau khi đăng nhập
- ✅ Có thể thêm xử lý tùy chỉnh (analytics, logging, etc.)
- ✅ Có UI loading đẹp mắt
- ⚠️ Cần xử lý token và redirect thủ công (nếu không dùng Firebase Handler)

## Lưu ý quan trọng

1. **Đúng định dạng:** URI phải bắt đầu bằng `https://` (không phải `http://`)
2. **Không có dấu cách:** Đảm bảo không có khoảng trắng thừa
3. **Một URI mỗi dòng:** Nếu thêm nhiều URI, mỗi URI trên một dòng riêng
4. **Không có dấu phẩy:** Không cần dấu phẩy giữa các URI
5. **Chế độ Strict Mode:** Nếu "Chế độ sử dụng nghiêm ngặt cho URI chuyển hướng" (Strict mode) đang bật, URI phải khớp chính xác

## Kiểm tra cấu hình

Sau khi thêm URI, đảm bảo:
- ✅ "Đăng nhập OAuth ứng dụng" (App OAuth Login): **Bật** (Có)
- ✅ "Đăng nhập OAuth trên web" (Web OAuth Login): **Bật** (Có)
- ✅ "URI chuyển hướng OAuth hợp lệ" đã chứa URI của bạn
- ✅ Validation tool hiển thị dấu tích xanh

## Troubleshooting

### Nếu vẫn báo lỗi sau khi thêm:
1. Đảm bảo đã **lưu thay đổi** (click nút Save)
2. Đợi 1-2 phút và thử lại
3. Kiểm tra lại URI có đúng chính tả không
4. Đảm bảo không có khoảng trắng thừa
5. Thử xóa và nhập lại URI

### Nếu cần thêm quyền truy cập nâng cao:
- Click nút **"Nhận quyền truy cập nâng cao"** (Get advanced access) ở phần cảnh báo màu vàng
- Điều này cần thiết để sử dụng Facebook Login với quyền `public_profile`

