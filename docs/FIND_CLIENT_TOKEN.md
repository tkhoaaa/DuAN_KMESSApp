# Hướng Dẫn Tìm Client Token trong Facebook Developer Console

## 📍 Vị trí Client Token

Client Token nằm ở **phần đầu** của trang Basic Settings, **phía trên** phần Android/Google Play Store.

## 🔍 Cách Tìm:

### Bước 1: Scroll lên đầu trang
- Trong trang Basic Settings hiện tại, **scroll lên trên cùng**
- Tìm phần có **App ID** (`841543928576901`)

### Bước 2: Tìm các trường sau App ID
Sau App ID, bạn sẽ thấy (theo thứ tự):

1. **App ID:** `841543928576901` ✅ (đã thấy)
2. **App Secret:** 
   - Có nút **"Show"** hoặc **"Hiện"**
   - Click để hiện App Secret
3. **Client Token:** ⭐ **ĐÂY LÀ CÁI CẦN TÌM**
   - Có nút **"Show"** hoặc **"Hiện"**
   - Click để hiện Client Token
   - Là một chuỗi dài (thường 32-64 ký tự)

### Bước 3: Nếu không thấy Client Token

**Cách 1: Kiểm tra lại vị trí**
- Client Token có thể nằm trong section **"Thông tin cơ bản"** hoặc **"Basic Info"**
- Có thể cần **expand section** bằng cách click vào tiêu đề

**Cách 2: Tìm trong Settings khác**
- Thử vào: **Settings > Advanced** (Nâng cao)
- Hoặc: **Settings > Security** (Bảo mật)

**Cách 3: Dùng API để lấy**
- Vào: https://developers.facebook.com/tools/explorer/
- Chọn app của bạn
- Query: `/{app-id}?fields=client_token`
- Sẽ trả về Client Token

## ⚠️ Lưu ý Quan Trọng:

- **Client Token** ≠ **App Secret**
- **Client Token** ≠ **"Khóa giải mã trong phần Tham chiếu cài đặt"**
- Client Token thường **ngắn hơn** App Secret
- Client Token có thể **public** (không cần giữ bí mật như App Secret)

## 📸 Vị trí trong giao diện:

```
┌─────────────────────────────────────┐
│ Basic Settings                      │
├─────────────────────────────────────┤
│ App ID: 841543928576901             │ ← Đã thấy
│                                     │
│ App Secret: [Show]                  │ ← Scroll lên đây
│ Client Token: [Show]                │ ← ⭐ ĐÂY!
│                                     │
│ ...                                 │
│                                     │
│ Android Platform                    │ ← Bạn đang ở đây
│ Hash chính: 2jmj7l5r...            │
│ Package Name: com.example...       │
└─────────────────────────────────────┘
```

## ✅ Sau khi tìm thấy:

1. Click **"Show"** bên cạnh Client Token
2. **Copy** toàn bộ chuỗi Client Token
3. **Paste** vào `android/app/src/main/res/values/strings.xml`
4. Thay `YOUR_CLIENT_TOKEN_HERE` bằng Client Token vừa copy

