# Quick Start: Cloudinary Setup (5 phút)

## Bước 1: Đăng ký Cloudinary (2 phút)

1. Truy cập: https://cloudinary.com/users/register/free
2. Đăng ký bằng email
3. Xác nhận email và đăng nhập

## Bước 2: Lấy API Credentials (1 phút)

1. Vào Dashboard: https://console.cloudinary.com/
2. **Cách 1:** Settings → **Product environment credentials**
3. **Cách 2:** Truy cập trực tiếp: https://console.cloudinary.com/settings/product-environment-credentials
4. Copy 3 thông tin:
   - **Cloud name** (ví dụ: `drhppamlz` - thường thấy ở sidebar)
   - **API Key** (số dài ~15-20 ký tự)
   - **API Secret** (click "Reveal" để hiển thị, sau đó copy)

⚠️ **Lưu ý:** 
- Nếu bạn đang ở trang "Product Environments", bạn cần điều hướng đến "Product environment credentials" (khác nhau!)
- API Secret có thể bị ẩn, click "Reveal" để xem
- Xem chi tiết: [CLOUDINARY_FIND_API_KEY.md](CLOUDINARY_FIND_API_KEY.md)

## Bước 3: Cấu hình trong App (2 phút)

✅ **Đã cấu hình sẵn!** File `lib/config/cloudinary_config.dart` đã được cập nhật với:
- Cloud name: `drhppamiz`
- API Key: `993289453561116`
- API Secret: `w0ciVAw-XPZjputlBizd_XFx_1M`

Nếu cần thay đổi, mở file và sửa 3 dòng trên.

## Bước 4: Kiểm tra (30 giây)

1. Chạy app: `flutter run`
2. Thử upload ảnh profile hoặc tạo post
3. Nếu thành công → Xong! 🎉

## ⚠️ Lưu ý bảo mật

- **KHÔNG commit** file `cloudinary_config.dart` có API Secret vào Git
- File đã được thêm vào `.gitignore` (nếu dùng `.env`)
- Nên dùng environment variables cho production (xem [cloudinary_setup_guide.md](cloudinary_setup_guide.md))

## ✅ Xong!

App giờ đã dùng Cloudinary để upload ảnh/video. Free tier 25GB đủ cho dự án nhỏ!

**Cần hỗ trợ?** Xem [cloudinary_setup_guide.md](cloudinary_setup_guide.md) để biết chi tiết.

