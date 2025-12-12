# Hướng Dẫn Cấu Hình Facebook Login cho Android

## Bước 1: Cấu hình trên Facebook Developer Console

### 1.1. Thông tin cần điền trong Facebook Developer Console

Dựa trên project của bạn, điền thông tin sau:

- **Tên gói (Package Name):** `com.example.duan_kmessapp`
- **Tên lớp hoạt động mặc định (Default Activity Class Name):** `com.example.duan_kmessapp.MainActivity`

### 1.2. Lấy Facebook App ID

Sau khi điền thông tin trên và lưu, bạn sẽ có:
- **Facebook App ID:** `841543928576901` (từ hình ảnh)
- **Facebook App Secret:** (lấy từ Settings > Basic)

## Bước 2: Cấu hình Android App

### 2.1. Tạo file `strings.xml`

Tạo file `android/app/src/main/res/values/strings.xml` với nội dung:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">duan_kmessapp</string>
    <string name="facebook_app_id">841543928576901</string>
    <string name="fb_login_protocol_scheme">fb841543928576901</string>
</resources>
```

**Lưu ý:** Thay `841543928576901` bằng Facebook App ID của bạn.

### 2.2. Cập nhật `AndroidManifest.xml`

Thêm các cấu hình sau vào `android/app/src/main/AndroidManifest.xml`:

**Trong thẻ `<application>`:**

```xml
<application
    android:label="duan_kmessapp"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher">
    
    <!-- Facebook App ID -->
    <meta-data 
        android:name="com.facebook.sdk.ApplicationId" 
        android:value="@string/facebook_app_id"/>
    <meta-data 
        android:name="com.facebook.sdk.ClientToken" 
        android:value="@string/facebook_client_token"/>
    
    <!-- ... existing code ... -->
</application>
```

**Thêm vào thẻ `<activity>` của MainActivity:**

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:taskAffinity=""
    android:theme="@style/LaunchTheme"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize">
    
    <!-- ... existing intent-filters ... -->
    
    <!-- Facebook Login Intent Filter -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="fb841543928576901"/>
    </intent-filter>
</activity>
```

**Lưu ý:** Thay `fb841543928576901` bằng `fb` + Facebook App ID của bạn.

### 2.3. Cập nhật `build.gradle`

Tìm file `android/app/build.gradle` và thêm vào phần `dependencies`:

```gradle
dependencies {
    // ... existing dependencies ...
    implementation 'com.facebook.android:facebook-android-sdk:latest.release'
}
```

## Bước 3: Cấu hình Firebase

### 3.1. Bật Facebook Provider trong Firebase Console

1. Vào [Firebase Console](https://console.firebase.google.com/)
2. Chọn project của bạn
3. Vào **Authentication** > **Sign-in method**
4. Bật **Facebook**
5. Nhập:
   - **App ID:** `841543928576901`
   - **App Secret:** (lấy từ Facebook Developer Console)

### 3.2. Cấu hình OAuth Redirect URIs

Trong Firebase Console, thêm các redirect URIs:
- `fb841543928576901://authorize`
- `https://YOUR-PROJECT-ID.firebaseapp.com/__/auth/handler`

## Bước 4: Kiểm tra Code Flutter

Code Flutter đã được cấu hình đúng trong `lib/features/auth/auth_repository.dart`:

```dart
@override
Future<void> signInWithFacebook() async {
  final LoginResult result = await FacebookAuth.instance.login();
  
  if (result.status != LoginStatus.success) {
    throw FirebaseAuthException(
      code: 'facebook-login-failed',
      message: 'Đăng nhập Facebook thất bại',
    );
  }

  final AccessToken accessToken = result.accessToken!;
  final OAuthCredential credential = FacebookAuthProvider.credential(
    accessToken.tokenString, // ✅ Đã sửa từ token thành tokenString
  );

  await _auth.signInWithCredential(credential);
  // ... profile creation code ...
}
```

## Bước 5: Test

1. Chạy app: `flutter run`
2. Thử đăng nhập bằng Facebook
3. Kiểm tra log nếu có lỗi

## Troubleshooting

### Lỗi: "Invalid key hash"
- Lấy key hash từ Facebook Developer Console > Settings > Basic
- Hoặc chạy lệnh:
  ```bash
  keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore | openssl sha1 -binary | openssl base64
  ```
- Thêm key hash vào Facebook App Settings

### Lỗi: "App not set up"
- Kiểm tra Package Name và Activity Class Name đã đúng chưa
- Đảm bảo Facebook App đang ở chế độ Development (có thể test với test users)

### Lỗi: "Invalid OAuth Access Token"
- Kiểm tra Facebook App ID và App Secret trong Firebase Console
- Đảm bảo đã bật Facebook provider trong Firebase

## Tài liệu tham khảo

- [Flutter Facebook Auth Package](https://pub.dev/packages/flutter_facebook_auth)
- [Facebook Login for Android](https://developers.facebook.com/docs/facebook-login/android)
- [Firebase Authentication - Facebook](https://firebase.google.com/docs/auth/android/facebook-login)
