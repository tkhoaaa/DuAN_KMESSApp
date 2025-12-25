# Hướng dẫn sửa lỗi "Broken URL" trên Facebook

## Vấn đề
Facebook Developer Console báo các URL bị hỏng (Broken URL detected) mặc dù đã deploy thành công.

## Giải pháp

### Bước 1: Kiểm tra URL bằng Meta Sharing Debugger

1. Truy cập: https://developers.facebook.com/tools/debug/
2. Nhập từng URL và kiểm tra:
   - https://duankmessapp.firebaseapp.com/privacy-policy.html
   - https://duankmessapp.firebaseapp.com/terms-of-service.html
   - https://duankmessapp.firebaseapp.com/user-data-deletion.html

3. Kiểm tra "Response Code" phải là **200-299** (không phải 100-199, 300-399, 400-499, 500-599)

4. Nếu có lỗi, click "Scrape Again" để Facebook crawler kiểm tra lại

### Bước 2: Sử dụng domain .firebaseapp.com thay vì .web.app

Trong Facebook Developer Console, sử dụng các URL sau (với domain `.firebaseapp.com`):

- **Privacy Policy:**
  ```
  https://duankmessapp.firebaseapp.com/privacy-policy.html
  ```

- **Terms of Service:**
  ```
  https://duankmessapp.firebaseapp.com/terms-of-service.html
  ```

- **User Data Deletion:**
  ```
  https://duankmessapp.firebaseapp.com/user-data-deletion.html
  ```

### Bước 3: Kiểm tra trực tiếp trong trình duyệt

Mở các URL trên trong trình duyệt để đảm bảo chúng hiển thị đúng nội dung.

### Bước 4: Nếu vẫn bị lỗi - Whitelist Facebook Crawler

Nếu Facebook crawler vẫn không truy cập được, bạn có thể cần whitelist:

#### IP Addresses của Facebook Crawler:
- 31.13.24.0/21
- 31.13.64.0/18
- 66.220.144.0/20
- 69.63.176.0/20
- 69.171.224.0/19
- 74.119.76.0/22
- 103.4.96.0/22
- 157.240.0.0/17
- 173.252.64.0/18
- 179.60.192.0/22
- 185.60.216.0/22
- 204.15.20.0/22

#### User Agent Strings:
- `facebookexternalhit/*`
- `Facebot`
- `MetaBot`

### Bước 5: Cập nhật lại trong Facebook Console

1. Vào: https://developers.facebook.com/apps/1576453390212797/settings/basic/
2. Xóa các URL cũ và nhập lại các URL mới (sử dụng `.firebaseapp.com`)
3. Lưu thay đổi
4. Đợi vài phút để Facebook crawler kiểm tra lại
5. Thử chuyển sang chế độ "Chính thức" lại

### Bước 6: Kiểm tra Google Play Package Name

Đảm bảo package name `com.example.duan_kmessapp` đã được publish trên Google Play Store hoặc ít nhất là có thể truy cập công khai.

Nếu app chưa publish, bạn có thể:
- Tạm thời để trống trường này (nếu không bắt buộc)
- Hoặc tạo một trang landing page giải thích app đang trong quá trình phát triển

## Lưu ý quan trọng

1. **Response Code 200-299**: Facebook chỉ chấp nhận mã phản hồi từ 200-299
2. **Public Access**: Các URL phải có thể truy cập công khai, không yêu cầu đăng nhập
3. **HTTPS**: Phải sử dụng HTTPS (không phải HTTP)
4. **Content-Type**: Phải trả về `text/html` với charset UTF-8
5. **Thời gian chờ**: Sau khi cập nhật URL, đợi 5-10 phút để Facebook crawler kiểm tra lại

## Kiểm tra nhanh

Chạy lệnh sau để kiểm tra response code (trên Linux/Mac):
```bash
curl -I https://duankmessapp.firebaseapp.com/privacy-policy.html
```

Hoặc sử dụng Meta Sharing Debugger: https://developers.facebook.com/tools/debug/

