# Hướng Dẫn Test Chat Trên 2 Thiết Bị

## 📱 Cách 1: Dùng 2 Emulator (Khuyên dùng)

### Bước 1: Tạo 2 Emulator

1. Mở **Android Studio**
2. Vào **Tools > Device Manager**
3. Tạo 2 emulator khác nhau:
   - **Emulator 1**: Tên "Test Device 1" (ví dụ: Pixel 5)
   - **Emulator 2**: Tên "Test Device 2" (ví dụ: Pixel 6)

### Bước 2: Chạy App Trên 2 Emulator

**Terminal 1 - Chạy trên Emulator 1:**
```bash
flutter run -d <device_id_1>
```

**Terminal 2 - Chạy trên Emulator 2:**
```bash
flutter run -d <device_id_2>
```

**Hoặc dùng Android Studio:**
1. Chạy app trên Emulator 1 (click Run)
2. Mở **Run > Edit Configurations**
3. Tạo configuration mới, chọn Emulator 2
4. Chạy lại app trên Emulator 2

**Xem danh sách devices:**
```bash
flutter devices
```

---

## 📱 Cách 2: Dùng 1 Emulator + 1 Thiết Bị Thật

### Bước 1: Kết nối thiết bị thật

1. Bật **USB Debugging** trên điện thoại
2. Kết nối điện thoại qua USB
3. Chấp nhận "Allow USB debugging" trên điện thoại

### Bước 2: Chạy app

**Terminal 1 - Chạy trên Emulator:**
```bash
flutter run -d <emulator_id>
```

**Terminal 2 - Chạy trên thiết bị thật:**
```bash
flutter run -d <device_id>
```

---

## 📱 Cách 3: Dùng 2 Thiết Bị Thật

1. Kết nối cả 2 điện thoại qua USB
2. Chạy app trên từng thiết bị:
   ```bash
   flutter devices  # Xem danh sách
   flutter run -d <device_id_1>
   flutter run -d <device_id_2>
   ```

---

## 🧪 Quy Trình Test Chat

### Bước 1: Đăng Ký 2 Tài Khoản

**Trên Thiết Bị 1:**
1. Mở app
2. Tap **Đăng ký**
3. Đăng ký với:
   - Email: `user1@test.com`
   - Password: `password123`
   - Display Name: `User 1`

**Trên Thiết Bị 2:**
1. Mở app
2. Tap **Đăng ký**
3. Đăng ký với:
   - Email: `user2@test.com`
   - Password: `password123`
   - Display Name: `User 2`

### Bước 2: Follow Nhau

**Trên Thiết Bị 1:**
1. Vào tab **Kết nối** (Contacts)
2. Tap icon **Tìm kiếm** (🔍)
3. Tìm kiếm: `user2@test.com` hoặc `User 2`
4. Tap vào kết quả
5. Tap **Follow** hoặc **Gửi yêu cầu**

**Trên Thiết Bị 2:**
1. Vào tab **Kết nối**
2. Nếu User 1 gửi yêu cầu:
   - Vào tab **Yêu cầu đến**
   - Tap **Chấp nhận**
3. Hoặc tìm User 1 và Follow lại

### Bước 3: Bắt Đầu Chat

**Trên Thiết Bị 1:**
1. Vào tab **Kết nối**
2. Tap tab **Đang theo dõi**
3. Tìm **User 2**
4. Tap icon **Nhắn tin** (💬)
5. Màn hình chat sẽ mở

**Trên Thiết Bị 2:**
1. Vào tab **Hội thoại** (Conversations)
2. Sẽ thấy conversation với **User 1**
3. Tap để mở chat

---

## ✅ Test Các Tính Năng

### 1. Test Gửi Text Message

**Trên Thiết Bị 1:**
- Gõ tin nhắn: "Xin chào!"
- Tap **Gửi** (➤)

**Trên Thiết Bị 2:**
- Sẽ thấy tin nhắn "Xin chào!" xuất hiện realtime
- Gõ phản hồi: "Chào bạn!"
- Tap **Gửi**

**Kết quả mong đợi:**
- ✅ Tin nhắn hiển thị realtime
- ✅ Bubble màu khác nhau cho tin nhắn của mình/đối phương

---

### 2. Test Typing Indicator

**Trên Thiết Bị 1:**
- Bắt đầu gõ trong input (chưa gửi)

**Trên Thiết Bị 2:**
- Sẽ thấy "Đang gõ..." với loading indicator
- Sau 2 giây không gõ → "Đang gõ..." biến mất

**Kết quả mong đợi:**
- ✅ "Đang gõ..." hiển thị khi đối phương gõ
- ✅ Tự động ẩn sau 2 giây không gõ
- ✅ Tự động ẩn khi gửi tin nhắn

---

### 3. Test Gửi Hình Ảnh

**Trên Thiết Bị 1:**
- Tap icon **Ảnh** (🖼️) bên trái input
- Chọn **Chọn từ thư viện** hoặc **Chụp ảnh**
- Chọn/chụp ảnh
- Ảnh sẽ tự động upload và gửi

**Trên Thiết Bị 2:**
- Sẽ thấy ảnh xuất hiện trong chat
- Tap ảnh để xem fullscreen
- Có thể zoom ảnh (pinch to zoom)

**Kết quả mong đợi:**
- ✅ Ảnh upload lên Cloudinary
- ✅ Hiển thị trong message bubble
- ✅ Tap để xem fullscreen
- ✅ Có loading indicator khi upload

---

### 4. Test Realtime Updates

**Trên Thiết Bị 1:**
- Gửi nhiều tin nhắn liên tiếp

**Trên Thiết Bị 2:**
- Tất cả tin nhắn hiển thị realtime (không cần refresh)

**Kết quả mong đợi:**
- ✅ Tin nhắn hiển thị ngay lập tức
- ✅ Không cần pull-to-refresh

---

## 🐛 Troubleshooting

### Lỗi: "Bạn cần đăng nhập"

**Giải pháp:**
- Đảm bảo đã đăng ký/đăng nhập trên cả 2 thiết bị
- Kiểm tra Firebase Authentication đã enable

---

### Lỗi: Không thấy người dùng khi tìm kiếm

**Giải pháp:**
1. Đảm bảo cả 2 user đã tạo profile:
   - Vào **Profile** tab
   - Cập nhật Display Name
2. Đợi vài giây để Firestore index được tạo
3. Thử tìm kiếm lại

---

### Lỗi: Permission Denied khi gửi tin nhắn

**Giải pháp:**
1. Kiểm tra Firestore rules đã deploy:
   ```bash
   firebase deploy --only firestore:rules
   ```
2. Đảm bảo cả 2 user đã follow nhau
3. Kiểm tra conversation đã được tạo

---

### Lỗi: Typing indicator không hiển thị

**Giải pháp:**
1. Đảm bảo đang gõ trên thiết bị khác (không phải thiết bị đang xem)
2. Kiểm tra Firestore rules cho phép đọc `user_profiles`
3. Kiểm tra `typingIn` field trong Firestore Console

---

### Lỗi: Ảnh không upload

**Giải pháp:**
1. Kiểm tra Cloudinary config:
   - `lib/config/cloudinary_config.dart`
   - Đảm bảo `cloudName`, `apiKey`, `apiSecret` đúng
2. Kiểm tra internet connection
3. Xem logs trong console để biết lỗi cụ thể

---

## 📊 Kiểm Tra Firestore Console

Để debug, mở [Firebase Console](https://console.firebase.google.com):

1. **Firestore Database:**
   - `user_profiles/{uid}` - Kiểm tra profile
   - `conversations/{conversationId}` - Kiểm tra conversation
   - `conversations/{conversationId}/messages/{messageId}` - Kiểm tra messages
   - `user_profiles/{uid}/typingIn` - Kiểm tra typing status

2. **Authentication:**
   - Kiểm tra 2 user đã được tạo

---

## 💡 Tips

1. **Dùng 2 emulator cùng lúc:**
   - Tốt nhất là dùng 2 emulator khác nhau
   - Dễ debug và test

2. **Ghi nhớ UID:**
   - Copy UID từ Firestore Console để debug
   - UID hiển thị trong profile hoặc console logs

3. **Test từng tính năng:**
   - Test text message trước
   - Sau đó test typing indicator
   - Cuối cùng test gửi ảnh

4. **Xem logs:**
   - Mở **Run** tab trong Android Studio
   - Xem logs từ cả 2 thiết bị
   - Tìm lỗi trong logs

---

## 🎯 Checklist Test

- [ ] Đăng ký 2 tài khoản thành công
- [ ] Follow nhau thành công
- [ ] Tạo conversation thành công
- [ ] Gửi text message thành công
- [ ] Nhận text message realtime
- [ ] Typing indicator hiển thị
- [ ] Typing indicator tự ẩn sau 2 giây
- [ ] Gửi ảnh thành công
- [ ] Xem ảnh fullscreen
- [ ] Zoom ảnh hoạt động

---

Chúc bạn test thành công! 🚀

