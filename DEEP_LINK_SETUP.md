# Hướng Dẫn Cấu Hình Deep Links

## Android (Đã cấu hình)

Deep links đã được cấu hình trong `android/app/src/main/AndroidManifest.xml`:
- Custom scheme: `kmessapp://`
- Universal links: `https://kmessapp.com` và `https://*.kmessapp.com`

## iOS (Đã cấu hình ✅)

### 1. Cấu hình URL Schemes

Đã thêm vào `ios/Runner/Info.plist`:
- Custom scheme: `kmessapp://`
- URL name: `com.kmessapp.deeplink`

### 2. Xử lý Deep Links trong iOS Native Code

Đã cập nhật `ios/Runner/AppDelegate.swift` với:
- MethodChannel để giao tiếp với Flutter
- Handle deep links khi app đang chạy (`application(_:open:options:)`)
- Handle initial link khi app mở từ terminated state
- Handle universal links (`application(_:continue:restorationHandler:)`)

### 3. Cấu hình Associated Domains (Universal Links - Optional)

Nếu muốn sử dụng universal links (`https://kmessapp.com`), cần:

1. Thêm vào `ios/Runner/Info.plist`:
```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:kmessapp.com</string>
    <string>applinks:*.kmessapp.com</string>
</array>
```

2. Thêm Associated Domains capability trong Xcode:
   - Mở `ios/Runner.xcworkspace` trong Xcode
   - Chọn target "Runner" → Signing & Capabilities
   - Thêm "Associated Domains"
   - Thêm: `applinks:kmessapp.com` và `applinks:*.kmessapp.com`

3. Tạo file `.well-known/apple-app-site-association` trên server với nội dung:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAM_ID.com.kmessapp",
        "paths": ["/posts/*", "/user/*", "/hashtag/*"]
      }
    ]
  }
}
```

**Lưu ý:** Thay `TEAM_ID` bằng Team ID thực tế của bạn (có thể tìm trong Apple Developer account).

## Format Deep Links

- **Post**: `kmessapp://posts/{postId}` hoặc `https://kmessapp.com/posts/{postId}`
- **Profile**: `kmessapp://user/{uid}` hoặc `https://kmessapp.com/user/{uid}`
- **Hashtag**: `kmessapp://hashtag/{tag}` hoặc `https://kmessapp.com/hashtag/{tag}`

## Testing

### Android
```bash
adb shell am start -W -a android.intent.action.VIEW -d "kmessapp://posts/POST_ID" com.kmessapp
```

### iOS
```bash
xcrun simctl openurl booted "kmessapp://posts/POST_ID"
```

## Lưu Ý

- ✅ Deep link handling đã được implement cho cả Android và iOS sử dụng MethodChannel
- ✅ iOS native code đã được cấu hình trong `AppDelegate.swift`
- ✅ Android intent filters đã được cấu hình trong `AndroidManifest.xml`
- Universal links (https://kmessapp.com) cần cấu hình thêm Associated Domains và server-side file nếu muốn sử dụng
- Có thể sử dụng package `uni_links` hoặc `app_links` để đơn giản hóa việc xử lý deep links trong tương lai, nhưng hiện tại implementation native đã hoạt động tốt

## Tóm Tắt Cấu Hình

### Android ✅
- ✅ Intent filters cho custom scheme `kmessapp://`
- ✅ Intent filters cho universal links `https://kmessapp.com`

### iOS ✅
- ✅ URL Schemes: `kmessapp://`
- ✅ AppDelegate.swift: Handle deep links, initial links, và universal links
- ✅ MethodChannel: Giao tiếp giữa native và Flutter

### Flutter ✅
- ✅ DeepLink model: Parse và validate URLs
- ✅ DeepLinkService: Navigate đến các pages tương ứng
- ✅ ShareService: Share content với deep links
- ✅ AuthGate: Listen và handle deep links trong app lifecycle

