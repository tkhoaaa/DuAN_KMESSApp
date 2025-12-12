# Khắc phục lỗi BILLING_NOT_ENABLED cho Phone Authentication

## Vấn đề

Khi sử dụng Firebase Phone Authentication, bạn có thể gặp lỗi:
```
An internal error has occurred. [BILLING_NOT_ENABLED]
```

Lỗi này xảy ra vì Firebase Phone Authentication **yêu cầu bật thanh toán (Billing)** trên Firebase project, ngay cả khi bạn chỉ sử dụng gói miễn phí (Spark Plan).

## Giải pháp

### Bước 1: Bật Billing trên Firebase Console

1. Truy cập [Firebase Console](https://console.firebase.google.com/)
2. Chọn project của bạn
3. Vào **⚙️ Settings (Cài đặt)** > **Usage and billing (Sử dụng và thanh toán)**
4. Click **Upgrade project (Nâng cấp dự án)**
5. Chọn **Blaze Plan (Pay as you go)**
   - ⚠️ **Lưu ý**: Blaze Plan có **free tier** cho Phone Authentication:
     - **10,000 lượt xác minh/tháng** miễn phí
     - Chỉ tính phí khi vượt quá giới hạn
6. Thêm phương thức thanh toán (thẻ tín dụng/ghi nợ)
   - Firebase sẽ **KHÔNG** tính phí nếu bạn không vượt quá free tier

### Bước 2: Kích hoạt Phone Authentication

1. Trong Firebase Console, vào **Authentication** > **Sign-in method**
2. Tìm **Phone** trong danh sách providers
3. Click để bật (Enable)
4. Chọn quốc gia được phép (hoặc để mặc định)

### Bước 3: Kiểm tra lại ứng dụng

Sau khi bật billing và Phone Authentication:
1. Build lại ứng dụng
2. Thử gửi OTP lại
3. Lỗi `BILLING_NOT_ENABLED` sẽ biến mất

## Free Tier cho Phone Authentication

Với Blaze Plan, bạn được miễn phí:
- **10,000 lượt xác minh/tháng** (gửi OTP)
- Sau đó: **$0.06 mỗi lượt xác minh**

Ví dụ:
- 5,000 lượt/tháng = **Miễn phí**
- 15,000 lượt/tháng = 5,000 lượt đầu miễn phí + 10,000 lượt × $0.06 = **$600/tháng**

## Lưu ý quan trọng

⚠️ **Firebase KHÔNG tự động tính phí** nếu bạn không vượt quá free tier.

✅ Bạn có thể:
- Đặt **budget alerts** để nhận cảnh báo khi gần đạt giới hạn
- Đặt **spending limits** để tự động tắt tính năng khi đạt ngưỡng

## Tài liệu tham khảo

- [Firebase Phone Authentication Pricing](https://firebase.google.com/pricing)
- [Enable Phone Authentication](https://firebase.google.com/docs/auth/android/phone-auth)
- [Firebase Billing Plans](https://firebase.google.com/pricing)

