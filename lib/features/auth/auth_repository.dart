import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../profile/user_profile_repository.dart';

abstract class AuthRepository {
  Stream<User?> authState();
  User? currentUser();

  Future<void> signOut();
  Future<void> signInWithEmail(String email, String password);
  Future<void> registerWithEmail(String email, String password);
  Future<void> signInWithGoogle();
  Future<void> signInWithFacebook();
  Future<void> sendEmailVerification();
  Future<void> reloadCurrentUser();
  Future<void> signInWithCredential(AuthCredential credential);
  
  // Password management
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<void> sendPasswordResetEmail(String email);
  Future<void> confirmPasswordReset(String code, String newPassword);

  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException error) onError,
    required void Function(PhoneAuthCredential credential) onCompleted,
    required void Function(String verificationId) onTimeout,
  });

  Future<void> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  });
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _google = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  @override
  Stream<User?> authState() => _auth.authStateChanges();

  @override
  User? currentUser() => _auth.currentUser;

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> registerWithEmail(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> signInWithGoogle() async {
    try {
      final user = await _google.signIn();
      if (user == null) {
        // User cancelled - không phải lỗi
        return;
      }
      
      final auth = await user.authentication;
      if (auth.accessToken == null || auth.idToken == null) {
        throw FirebaseAuthException(
          code: 'google-signin-failed',
          message: 'Không thể lấy thông tin xác thực từ Google',
        );
      }
      
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      
      await _auth.signInWithCredential(credential);
      
      // Auto-create/update profile sau khi đăng nhập thành công
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        try {
          await userProfileRepository.ensureProfile(
            uid: firebaseUser.uid,
            email: firebaseUser.email,
            displayName: firebaseUser.displayName,
            photoUrl: firebaseUser.photoURL,
          );
        } catch (e) {
          if (kDebugMode) {
            print('Error creating profile after Google sign-in: $e');
          }
          // Không throw error vì đăng nhập đã thành công
        }
      }
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('Google Sign-In error: $e');
      }
      
      // Xử lý PlatformException từ Google Sign-In
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('apiException') || errorStr.contains('10')) {
        throw FirebaseAuthException(
          code: 'google-signin-developer-error',
          message: 'Lỗi cấu hình Google Sign-In. Vui lòng kiểm tra SHA-1 fingerprint trong Firebase Console.',
        );
      } else if (errorStr.contains('network') || errorStr.contains('connection')) {
        throw FirebaseAuthException(
          code: 'google-signin-network-error',
          message: 'Lỗi kết nối. Vui lòng kiểm tra internet và thử lại.',
        );
      } else if (errorStr.contains('cancelled') || errorStr.contains('cancel')) {
        // User cancelled - không throw error
        return;
      }
      
      throw FirebaseAuthException(
        code: 'google-signin-failed',
        message: 'Đăng nhập Google thất bại: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> signInWithFacebook() async {
    try {
      // Login với Facebook (dùng webOnly để đảm bảo callback quay lại app)
      final LoginResult result = await FacebookAuth.instance.login(
        loginBehavior: LoginBehavior.webOnly,
      );
      
      if (result.status != LoginStatus.success) {
        if (kDebugMode) {
          print('Facebook login failed: ${result.status}');
          if (result.message != null) {
            print('Error message: ${result.message}');
          }
        }
        throw FirebaseAuthException(
          code: 'facebook-login-failed',
          message: result.message ?? 'Đăng nhập Facebook thất bại',
        );
      }

        // Lấy access token
        final AccessToken? accessToken = result.accessToken;
        if (accessToken == null) {
          throw FirebaseAuthException(
            code: 'facebook-login-failed',
            message: 'Không thể lấy access token từ Facebook',
          );
        }
        
        // Tạo Firebase credential từ Facebook token
        final OAuthCredential credential = FacebookAuthProvider.credential(
          accessToken.tokenString,
        );

      // Sign in với Firebase
      await _auth.signInWithCredential(credential);
      
      // Lấy thông tin profile từ Facebook sau khi đăng nhập thành công
      final user = _auth.currentUser;
      if (user != null) {
        try {
          // Lấy thông tin profile từ Facebook Graph API
          final userData = await FacebookAuth.instance.getUserData();
          final facebookName = userData['name'] as String?;
          final facebookEmail = userData['email'] as String?;
          final facebookPicture = userData['picture'] as Map<String, dynamic>?;
          final facebookPhotoUrl = facebookPicture?['data']?['url'] as String?;
          
          if (kDebugMode) {
            print('Facebook profile data: name=$facebookName, email=$facebookEmail');
          }
          
          // Tự động tạo/update profile với thông tin từ Facebook
          await userProfileRepository.ensureProfile(
            uid: user.uid,
            email: facebookEmail ?? user.email, 
            displayName: facebookName ?? user.displayName,
            photoUrl: facebookPhotoUrl ?? user.photoURL,
          );
        } catch (e) {
          // Nếu không lấy được thông tin từ Facebook, vẫn tạo profile với thông tin từ Firebase
          if (kDebugMode) {
            print('Error getting Facebook profile: $e');
          }
          await userProfileRepository.ensureProfile(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
            photoUrl: user.photoURL,
          );
        }
      }
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error in signInWithFacebook: $e');
      }
      throw FirebaseAuthException(
        code: 'facebook-login-failed',
        message: 'Đăng nhập Facebook thất bại: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Người dùng chưa đăng nhập',
      );
    }

    if (user.email == null) {
      throw FirebaseAuthException(
        code: 'no-email',
        message: 'Tài khoản không có email',
      );
    }

    // Re-authenticate với mật khẩu hiện tại
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);

    // Update password mới
    await user.updatePassword(newPassword);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> confirmPasswordReset(String code, String newPassword) async {
    await _auth.confirmPasswordReset(code: code, newPassword: newPassword);
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  @override
  Future<void> reloadCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
    }
  }

  @override
  Future<void> signInWithCredential(AuthCredential credential) =>
      _auth.signInWithCredential(credential);

  @override
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException error) onError,
    required void Function(PhoneAuthCredential credential) onCompleted,
    required void Function(String verificationId) onTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onCompleted,
      verificationFailed: onError,
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (verificationId) => onTimeout(verificationId),
    );
  }

  @override
  Future<void> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _auth.signInWithCredential(credential);
  }
}

// Simple global instance for now (can be replaced later by DI)
final AuthRepository authRepository = FirebaseAuthRepository();

