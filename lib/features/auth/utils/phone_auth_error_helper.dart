import 'package:firebase_auth/firebase_auth.dart';

/// Helper class để dịch lỗi Firebase Phone Auth sang tiếng Việt
class PhoneAuthErrorHelper {
  /// Chuyển đổi FirebaseAuthException thành thông báo lỗi tiếng Việt
  static String getErrorMessage(FirebaseAuthException e) {
    final code = e.code;
    final message = e.message ?? '';

    // Xử lý lỗi BILLING_NOT_ENABLED
    if (code == 'internal-error' && message.contains('BILLING_NOT_ENABLED')) {
      return 'Xác thực số điện thoại yêu cầu bật thanh toán trên Firebase. '
          'Vui lòng liên hệ quản trị viên để bật tính năng này.';
    }

    // Xử lý các lỗi phổ biến khác
    switch (code) {
      case 'invalid-phone-number':
        return 'Số điện thoại không hợp lệ. Vui lòng kiểm tra lại.';
      case 'too-many-requests':
        return 'Bạn đã gửi quá nhiều yêu cầu. Vui lòng thử lại sau vài phút.';
      case 'quota-exceeded':
        return 'Đã vượt quá giới hạn gửi OTP. Vui lòng thử lại sau.';
      case 'missing-phone-number':
        return 'Vui lòng nhập số điện thoại.';
      case 'invalid-verification-code':
        return 'Mã OTP không đúng. Vui lòng kiểm tra lại.';
      case 'session-expired':
        return 'Phiên xác thực đã hết hạn. Vui lòng gửi lại mã OTP.';
      case 'credential-already-in-use':
        return 'Số điện thoại này đã được sử dụng bởi tài khoản khác.';
      case 'invalid-verification-id':
        return 'Mã xác thực không hợp lệ. Vui lòng gửi lại mã OTP.';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng. Vui lòng kiểm tra kết nối và thử lại.';
      case 'internal-error':
        if (message.contains('BILLING')) {
          return 'Xác thực số điện thoại yêu cầu bật thanh toán trên Firebase. '
              'Vui lòng liên hệ quản trị viên.';
        }
        return 'Đã xảy ra lỗi nội bộ. Vui lòng thử lại sau.';
      default:
        // Nếu có message từ Firebase, dùng nó; nếu không, dùng code
        if (message.isNotEmpty && !message.contains('BILLING')) {
          return message;
        }
        return 'Gửi OTP thất bại. Vui lòng thử lại.';
    }
  }

  /// Kiểm tra xem lỗi có phải là lỗi billing không
  static bool isBillingError(FirebaseAuthException e) {
    return e.code == 'internal-error' && 
           (e.message?.contains('BILLING_NOT_ENABLED') ?? false);
  }
}

