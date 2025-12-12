import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/phone_auth_error_helper.dart';

class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Chuẩn hóa số điện thoại về dạng E.164. Mặc định: nếu bắt đầu bằng '0' thì chuyển thành +84.
  /// - Bỏ khoảng trắng, dấu gạch.
  /// - Nếu đã có dấu '+' thì giữ nguyên.
  /// - Nếu không hợp lệ, throw [FormatException].
  String normalizePhone(String raw) {
    var phone = raw.replaceAll(RegExp(r'[\s\-]'), '');
    if (phone.isEmpty) {
      throw FormatException('Số điện thoại trống');
    }
    if (phone.startsWith('+')) {
      return phone;
    }
    if (phone.startsWith('0')) {
      // Default VN (+84). Có thể đổi tuỳ quốc gia.
      return '+84${phone.substring(1)}';
    }
    // Nếu không có + và không bắt đầu bằng 0, coi là không hợp lệ
    throw FormatException('Số điện thoại phải ở dạng +[mã quốc gia][số] hoặc bắt đầu bằng 0');
  }

  Future<String> sendCode(String phoneNumber) async {
    String verificationId = '';
    final completer = Completer<String>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        // Auto complete on Android
        await _auth.signInWithCredential(credential);
        completer.complete('');
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) {
          // Wrap error với message tiếng Việt
          final friendlyError = FirebaseAuthException(
            code: e.code,
            message: PhoneAuthErrorHelper.getErrorMessage(e),
          );
          completer.completeError(friendlyError);
        }
      },
      codeSent: (vId, _) {
        verificationId = vId;
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
      codeAutoRetrievalTimeout: (vId) {
        verificationId = vId;
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
    );
    return completer.future;
  }

  Future<UserCredential> signInWithCode(
    String verificationId,
    String smsCode,
  ) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> linkPhoneWithCode(
    User user,
    String verificationId,
    String smsCode,
  ) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return user.linkWithCredential(credential);
  }
}

