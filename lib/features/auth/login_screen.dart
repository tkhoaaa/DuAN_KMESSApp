import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'auth_repository.dart';
import 'pages/forgot_password_page.dart';
import 'pages/add_phone_page.dart';
import 'saved_accounts_repository.dart';
import 'saved_credentials_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialIdentifier});

  final String? initialIdentifier;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoadingEmail = false;
  bool isBusy = false;
  bool _obscurePassword = true;
  String? errorText;

  @override
  void initState() {
    super.initState();
    if (widget.initialIdentifier != null &&
        widget.initialIdentifier!.isNotEmpty) {
      emailController.text = widget.initialIdentifier!;
    }
  }

  Future<void> _maybePromptAddPhone() async {
    final user = authRepository.currentUser();
    if (user == null) return;
    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) return;
    if (!mounted) return;
    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm số điện thoại'),
        content: const Text(
          'Bạn chưa thêm số điện thoại. Thêm số để đăng nhập/khôi phục mật khẩu bằng SĐT.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thêm ngay'),
          ),
        ],
      ),
    );
    if (shouldAdd == true && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AddPhonePage()),
      );
    }
  }

  void _setBusy(bool value) {
    if (!mounted) return;
    setState(() {
      isBusy = value;
    });
  }

  bool _isEmail(String input) => input.contains('@');

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập email hoặc số điện thoại';
    }
    if (_isEmail(value)) {
    if (!value.contains('@') || !value.contains('.')) {
      return 'Email không đúng định dạng';
      }
    } else {
      if (value.length < 6) return 'Số điện thoại không hợp lệ';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    return null;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoadingEmail = true;
      errorText = null;
    });
    final identifier = emailController.text.trim();
    try {
      if (_isEmail(identifier)) {
        await authRepository.signInWithEmail(
          identifier,
          passwordController.text,
        );

        // Sau khi đăng nhập thành công: lưu thông tin tài khoản + mật khẩu để chuyển đổi nhanh
        final user = authRepository.currentUser();
        if (user != null) {
          await SavedAccountsRepository.instance.saveAccountFromUser(user);
          await SavedCredentialsRepository.instance.savePassword(
            uid: user.uid,
            password: passwordController.text,
          );
        }

        await _maybePromptAddPhone();
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Tài khoản chưa đăng ký';
          break;
        case 'wrong-password':
          errorMessage = 'Mật khẩu không đúng';
          break;
        case 'invalid-email':
          errorMessage = 'Email không đúng định dạng';
          break;
        case 'user-disabled':
          errorMessage = 'Tài khoản đã bị vô hiệu hóa';
          break;
        case 'too-many-requests':
          errorMessage = 'Quá nhiều lần thử. Vui lòng đợi vài phút';
          break;
        default:
          errorMessage = e.message ?? 'Lỗi đăng nhập: ${e.code}';
      }
      setState(() {
        errorText = errorMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingEmail = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    _setBusy(true);
    try {
      await authRepository.signInWithGoogle();
      
      // Lưu tài khoản sau khi đăng nhập thành công
      final user = authRepository.currentUser();
      if (user != null) {
        try {
          await SavedAccountsRepository.instance.saveAccountFromUser(user);
        } catch (e) {
          // Ignore errors khi lưu tài khoản
          debugPrint('Error saving account after Google sign in: $e');
        }
      }
      
      // Success - navigation handled by auth state listener
      await _maybePromptAddPhone();
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'google-signin-developer-error':
          errorMessage = 'Lỗi cấu hình Google Sign-In. Vui lòng kiểm tra SHA-1 fingerprint trong Firebase Console.';
          break;
        case 'google-signin-network-error':
          errorMessage = 'Lỗi kết nối. Vui lòng kiểm tra internet và thử lại.';
          break;
        case 'account-exists-with-different-credential':
          errorMessage = 'Tài khoản này đã được đăng ký bằng phương thức khác. Vui lòng sử dụng email/mật khẩu.';
          break;
        case 'invalid-credential':
          errorMessage = 'Thông tin đăng nhập không hợp lệ. Vui lòng thử lại.';
          break;
        case 'google-signin-failed':
          errorMessage = 'Đăng nhập Google thất bại. Vui lòng thử lại.';
          break;
        default:
          errorMessage = e.message ?? 'Lỗi đăng nhập: ${e.code}';
      }
      _showError(errorMessage);
    } catch (e) {
      // Handle non-Firebase errors (e.g., user cancelled)
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('cancelled') || errorStr.contains('cancel')) {
        // User cancelled - don't show error
        return;
      }
      _showError('Đăng nhập Google thất bại. Vui lòng thử lại.');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _signInWithFacebook() async {
    _setBusy(true);
    try {
      await authRepository.signInWithFacebook();
      // Success - navigation handled by auth state listener
      await _maybePromptAddPhone();
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage = 'Tài khoản này đã được đăng ký bằng phương thức khác. Vui lòng sử dụng email/mật khẩu.';
          break;
        case 'invalid-credential':
          errorMessage = 'Thông tin đăng nhập không hợp lệ. Vui lòng thử lại.';
          break;
        case 'facebook-login-failed':
          errorMessage = 'Đăng nhập Facebook thất bại. Vui lòng thử lại.';
          break;
        default:
          errorMessage = e.message ?? 'Lỗi đăng nhập: ${e.code}';
      }
      _showError(errorMessage);
    } catch (e) {
      // Handle non-Firebase errors (e.g., user cancelled)
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('cancelled') || errorStr.contains('cancel')) {
        // User cancelled - don't show error
        return;
      }
      _showError('Đăng nhập Facebook thất bại. Vui lòng thử lại.');
    } finally {
      _setBusy(false);
    }
  }

  void _showError(String? message) {
    if (!mounted || message == null) return;
    // Sử dụng SchedulerBinding để đảm bảo context vẫn valid
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
    );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final disabled = isBusy || isLoadingEmail;
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !disabled,
                validator: _validateEmail,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                enabled: !disabled,
                validator: _validatePassword,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 12),
              if (errorText != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorText!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              if (errorText != null) const SizedBox(height: 12),
            FilledButton(
              onPressed: (isLoadingEmail || disabled) ? null : _login,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: isLoadingEmail
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Đăng nhập'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: disabled
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordPage(),
                        ),
                      );
                    },
              child: const Text('Quên mật khẩu?'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: disabled
                  ? null
                  : () async {
                      final result = await Navigator.of(context).push<dynamic>(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                      if (!mounted) return;
                      if (result is Map) {
                        final status = result['status'] as String?;
                        if (status == 'email') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Đăng ký email thành công. Vui lòng kiểm tra hộp thư để xác thực.',
                              ),
                            ),
                          );
                        } else if (status == 'facebook') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đăng ký bằng Facebook thành công.'),
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Tạo tài khoản'),
            ),
            const Divider(height: 32),
            const Text(
              'Hoặc đăng nhập bằng',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: disabled ? null : _signInWithGoogle,
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: const Text('Đăng nhập bằng Google'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: disabled ? null : _signInWithFacebook,
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.facebook, color: Color(0xFF1877F2)),
              label: const Text(
                'Đăng nhập bằng Facebook',
                style: TextStyle(color: Color(0xFF1877F2)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1877F2)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

