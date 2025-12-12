import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool isBusy = false;
  bool _obscurePassword = true;
  String? errorText;

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập email';
    }
    if (!value.contains('@') || !value.contains('.')) {
      return 'Email không đúng định dạng';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    if (value.length < 6) {
      return 'Mật khẩu phải có ít nhất 6 ký tự';
    }
    return null;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorText = null;
    });
    try {
      await authRepository.registerWithEmail(
        emailController.text.trim(),
        passwordController.text,
      );
      await authRepository.sendEmailVerification();
      await authRepository.signOut();
      if (mounted) {
        Navigator.of(context).pop({
          'status': 'email',
        });
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'Email này đã được sử dụng. Vui lòng đăng nhập.';
          break;
        case 'invalid-email':
          errorMessage = 'Email không đúng định dạng';
          break;
        case 'weak-password':
          errorMessage = 'Mật khẩu quá yếu. Vui lòng chọn mật khẩu mạnh hơn';
          break;
        default:
          errorMessage = e.message ?? 'Lỗi đăng ký: ${e.code}';
      }
      setState(() {
        errorText = errorMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _setBusy(bool value) {
    if (!mounted) return;
    setState(() {
      isBusy = value;
    });
  }

  Future<void> _registerWithFacebook() async {
    _setBusy(true);
    try {
      await authRepository.signInWithFacebook();
      if (mounted) {
        Navigator.of(context).pop({'status': 'facebook'});
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMessage;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage = 'Tài khoản Facebook này đã được sử dụng. Vui lòng đăng nhập thay vì đăng ký.';
          break;
        case 'email-already-in-use':
          errorMessage = 'Email này đã được sử dụng. Vui lòng đăng nhập.';
          break;
        case 'invalid-credential':
          errorMessage = 'Thông tin đăng ký không hợp lệ. Vui lòng thử lại.';
          break;
        case 'facebook-login-failed':
          errorMessage = 'Đăng ký Facebook thất bại. Vui lòng thử lại.';
          break;
        default:
          errorMessage = e.message ?? 'Lỗi đăng ký: ${e.code}';
      }
      setState(() {
        errorText = errorMessage;
      });
    } catch (e) {
      if (!mounted) return;
      // Handle non-Firebase errors (e.g., user cancelled)
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('cancelled') || errorStr.contains('cancel')) {
        // User cancelled - don't show error
        return;
      }
      setState(() {
        errorText = 'Đăng ký Facebook thất bại. Vui lòng thử lại.';
      });
    } finally {
      _setBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = isLoading || isBusy;
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
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
                  helperText: 'Tối thiểu 6 ký tự',
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
              onPressed: disabled ? null : _register,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Đăng ký'),
            ),
            const Divider(height: 32),
            const Text(
              'Hoặc đăng ký bằng',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: disabled ? null : _registerWithFacebook,
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.facebook, color: Color(0xFF1877F2)),
              label: const Text(
                'Đăng ký bằng Facebook',
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

