# Cách Lấy Facebook Client Token

## Bước 1: Vào Basic Settings

1. Vào Facebook Developer Console
2. Sidebar bên trái → Click **"Cài đặt ứng dụng"** (App Settings)
3. Tab đầu tiên là **"Cơ bản"** (Basic)

Hoặc mở URL trực tiếp:
```
https://developers.facebook.com/apps/841543928576901/settings/basic/
```

## Bước 2: Tìm Client Token

Trong Basic Settings, **scroll lên phần đầu trang** (phía trên phần Android), bạn sẽ thấy:

### Vị trí Client Token:

1. **Ở phần đầu Basic Settings** (phía trên App ID):
   - Tìm section **"Thông tin cơ bản"** hoặc **"Basic Info"**
   - Client Token thường nằm **ngay sau App ID** hoặc **bên cạnh App Secret**

2. **Các trường bạn sẽ thấy:**
   - **App ID:** `841543928576901` ✅ (đã thấy)
   - **App Secret:** (Click "Show" để hiện) - thường nằm ngay dưới App ID
   - **Client Token:** (Click "Show" để hiện) ⭐ **CẦN THIẾT** - thường nằm ngay dưới App Secret

3. **Nếu không thấy:**
   - Scroll lên **đầu trang** (phía trên phần Android/Google Play Store)
   - Hoặc tìm section có tiêu đề **"Thông tin cơ bản"** hoặc **"Basic"**
   - Client Token có thể bị ẩn, cần click **"Show"** để hiện

### Lưu ý:
- Client Token **KHÔNG PHẢI** là "Khóa giải mã trong phần Tham chiếu cài đặt"
- Client Token là một chuỗi riêng biệt, thường ngắn hơn App Secret
- Nếu vẫn không thấy, có thể Facebook đã thay đổi giao diện - thử refresh trang

## Bước 3: Copy Client Token

1. Click nút **"Show"** bên cạnh **Client Token**
2. **Copy** Client Token (chuỗi dài)
3. **Lưu lại** để dùng

## Bước 4: Cập nhật strings.xml

Mở file: `android/app/src/main/res/values/strings.xml`

Thay `YOUR_CLIENT_TOKEN_HERE` bằng Client Token vừa copy:

```xml
<string name="facebook_client_token">PASTE_CLIENT_TOKEN_HERE</string>
```

## Lưu ý:

- Client Token khác với App Secret
- Client Token có thể public (không cần giữ bí mật)
- App Secret phải giữ bí mật (chỉ dùng cho Firebase Console)

## Ví dụ:

```xml
<string name="facebook_client_token">a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6</string>
```

