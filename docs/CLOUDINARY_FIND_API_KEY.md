# Hướng dẫn: Tìm API Key trong Cloudinary

## 🔍 Bạn đang ở đâu?

Nếu bạn đang ở trang **"Product Environments"** (như trong hình), bạn cần điều hướng đến trang **"Product environment credentials"** để lấy API Key.

## 📍 Cách tìm API Key

### Bước 1: Xác định vị trí hiện tại

Từ hình ảnh, bạn đang ở:
- **Trang:** Product Environments
- **URL:** `.../settings/product-environments`

### Bước 2: Điều hướng đến trang API Credentials

**Cách A: Từ Sidebar (Khuyến nghị)**

1. Ở sidebar bên trái, tìm section **"Account settings"**
2. Click vào **"Account settings"** để mở rộng (nếu chưa mở)
3. Bạn sẽ thấy các mục:
   - My Profile
   - Account
   - **Product Environments** ← Bạn đang ở đây
   - User Management
   - Account Security
4. **KHÔNG** click vào "Product Environments"
5. Thay vào đó, tìm và click vào **"Product environment credentials"** hoặc **"API Keys"**

**Cách B: Từ Settings**

1. Click vào **"Settings"** (biểu tượng bánh răng) ở sidebar
2. Tìm tab hoặc mục **"Product environment credentials"** hoặc **"API Keys"**
3. Click vào đó

**Cách C: URL trực tiếp**

Copy và paste URL này vào trình duyệt:
```
https://console.cloudinary.com/settings/product-environment-credentials
```

Hoặc:
```
https://console.cloudinary.com/settings/api-keys
```

## ✅ Trang API Credentials sẽ hiển thị:

Khi vào đúng trang, bạn sẽ thấy:

```
┌─────────────────────────────────────┐
│ Product environment credentials     │
├─────────────────────────────────────┤
│ Cloud name: drhppamlz              │
│ API Key: 123456789012345           │
│ API Secret: [Reveal] [Copy]        │
└─────────────────────────────────────┘
```

### Thông tin cần copy:

1. **Cloud name**: `drhppamlz` (từ hình ảnh của bạn)
2. **API Key**: Số dài khoảng 15-20 ký tự
3. **API Secret**: Click "Reveal" hoặc "Show" để hiển thị

## ⚠️ Lưu ý về API Secret

- API Secret có thể bị ẩn (hiển thị dạng `••••••••`)
- Click nút **"Reveal"** hoặc **"Show"** để xem
- Sau khi reveal, copy ngay vì có thể tự động ẩn lại

## 🎯 Từ hình ảnh của bạn:

Tôi thấy:
- **Cloud name**: `drhppamlz` (hiển thị ở sidebar và trong bảng)
- **ID**: `e3b90e33aba7ab99395a70... drhppamlz`

Nhưng **API Key và API Secret** không hiển thị ở trang "Product Environments". Bạn cần vào trang "Product environment credentials" để thấy.

## 📝 Nếu vẫn không tìm thấy:

1. **Kiểm tra plan**: Free tier có đầy đủ API credentials
2. **Thử cách khác**: 
   - Vào Dashboard chính → Settings → Product environment credentials
   - Hoặc search "API" trong thanh tìm kiếm của Cloudinary
3. **Liên hệ support**: Nếu vẫn không thấy, có thể cần verify email hoặc account

## ✅ Sau khi có đủ 3 thông tin:

1. Cloud name: `drhppamlz`
2. API Key: `...` (copy từ trang credentials)
3. API Secret: `...` (reveal và copy)

Dán vào file `lib/config/cloudinary_config.dart` như hướng dẫn trong [cloudinary_setup_guide.md](cloudinary_setup_guide.md).

