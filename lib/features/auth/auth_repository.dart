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
        _google = googleSignIn ?? GoogleSignIn(
          scopes: ['email', 'profile'],
          // Force account picker để đảm bảo user chọn đúng account
          forceCodeForRefreshToken: true,
        );

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  @override
  Stream<User?> authState() => _auth.authStateChanges();

  @override
  User? currentUser() => _auth.currentUser;

  @override
  Future<void> signOut() async {
    // Sign out Google Sign In nếu đang đăng nhập bằng Google
    try {
      await _google.signOut();
    } catch (e) {
      // Ignore errors khi sign out Google (có thể chưa đăng nhập bằng Google)
      if (kDebugMode) {
        print('Error signing out from Google: $e');
      }
    }
    
    // Sign out Firebase Auth
    await _auth.signOut();
  }

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> registerWithEmail(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> signInWithGoogle() async {
    try {
      // Sign out trước để đảm bảo clean state
      try {
        await _google.signOut();
      } catch (e) {
        // Ignore errors khi sign out (có thể chưa đăng nhập)
        if (kDebugMode) {
          print('Note: Error during pre-signout (can be ignored): $e');
        }
      }
      
      // Thực hiện sign in
      final user = await _google.signIn();
      if (user == null) {
        // User cancelled - không phải lỗi
        return;
      }
      
      // Lấy authentication tokens với retry logic
      GoogleSignInAuthentication? auth;
      int retryCount = 0;
      const maxRetries = 2;
      
      while (retryCount <= maxRetries) {
        try {
          auth = await user.authentication;
          if (auth.accessToken != null && auth.idToken != null) {
            break; // Thành công
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error getting authentication (attempt ${retryCount + 1}): $e');
          }
        }
        
        if (retryCount < maxRetries) {
          // Đợi một chút trước khi retry
          await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
          retryCount++;
        } else {
          // Thử request lại authentication
          try {
            auth = await user.authentication;
          } catch (e) {
            if (kDebugMode) {
              print('Final attempt to get authentication failed: $e');
            }
          }
          break;
        }
      }
      
      if (auth == null || auth.accessToken == null || auth.idToken == null) {
        // Kiểm tra xem có phải lỗi cấu hình không
        final errorDetails = auth == null 
            ? 'Không thể lấy thông tin xác thực từ Google. '
            : 'Thiếu accessToken hoặc idToken. ';
        
        throw FirebaseAuthException(
          code: 'google-signin-failed',
          message: '$errorDetails\n\n'
              'Vui lòng kiểm tra:\n'
              '1. SHA-1 fingerprint đã được thêm vào Firebase Console\n'
              '2. google-services.json đã được cập nhật\n'
              '3. OAuth client ID đã được cấu hình đúng',
        );
      }
      
      // Tạo credential và sign in với Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Kiểm tra xem có user không
      if (userCredential.user == null) {
        throw FirebaseAuthException(
          code: 'google-signin-failed',
          message: 'Không thể tạo tài khoản Firebase từ Google',
        );
      }
      
      // Auto-create/update profile sau khi đăng nhập thành công
      final firebaseUser = userCredential.user!;
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
    } on FirebaseAuthException catch (e) {
      // Re-throw FirebaseAuthException với thông tin chi tiết hơn
      if (kDebugMode) {
        print('FirebaseAuthException during Google sign-in: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Google Sign-In error: $e');
        print('Stack trace: $stackTrace');
      }
      
      // Xử lý PlatformException từ Google Sign-In
      final errorStr = e.toString().toLowerCase();
      
      // Kiểm tra các loại lỗi phổ biến
      if (errorStr.contains('apiException') || 
          errorStr.contains('10') || 
          errorStr.contains('DEVELOPER_ERROR') ||
          errorStr.contains('sign_in_failed')) {
        throw FirebaseAuthException(
          code: 'google-signin-developer-error',
          message: 'Lỗi cấu hình Google Sign-In. Vui lòng kiểm tra SHA-1 fingerprint trong Firebase Console.',
        );
      } else if (errorStr.contains('network') || 
                 errorStr.contains('connection') ||
                 errorStr.contains('socket') ||
                 errorStr.contains('timeout')) {
        throw FirebaseAuthException(
          code: 'google-signin-network-error',
          message: 'Lỗi kết nối. Vui lòng kiểm tra internet và thử lại.',
        );
      } else if (errorStr.contains('cancelled') || 
                 errorStr.contains('cancel') ||
                 errorStr.contains('12500')) {
        // User cancelled - không throw error
        return;
      } else if (errorStr.contains('account-exists-with-different-credential') ||
                 errorStr.contains('email-already-in-use')) {
        throw FirebaseAuthException(
          code: 'account-exists-with-different-credential',
          message: 'Tài khoản này đã được đăng ký bằng phương thức khác. Vui lòng sử dụng email/mật khẩu.',
        );
      }
      
      // Lỗi không xác định
      throw FirebaseAuthException(
        code: 'google-signin-failed',
        message: 'Đăng nhập Google thất bại. Vui lòng thử lại. Lỗi: ${e.toString()}',
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

