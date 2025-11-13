import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoadingEmail = false;
  bool isBusy = false;
  String? errorText;

  void _setBusy(bool value) {
    if (!mounted) return;
    setState(() {
      isBusy = value;
    });
  }

  Future<void> _login() async {
    setState(() {
      isLoadingEmail = true;
      errorText = null;
    });
    try {
      await authRepository.signInWithEmail(
        emailController.text.trim(),
        passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorText = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingEmail = false;
        });
      }
    }
  }

  Future<void> _signInAnonymously() async {
    _setBusy(true);
    try {
      await authRepository.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      _showError(e.message);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _signInWithGoogle() async {
    _setBusy(true);
    try {
      await authRepository.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      _showError(e.message);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _signInWithPhone() async {
    _setBusy(true);
    try {
      final phone = await _promptForValue(
        title: 'Phone number (+84...)',
        keyboardType: TextInputType.phone,
      );
      if (phone == null || phone.isEmpty) {
        _setBusy(false);
        return;
      }
      await authRepository.startPhoneVerification(
        phoneNumber: phone,
        onCompleted: (cred) async {
          await authRepository.signInWithCredential(cred);
        },
        onError: (e) => _showError(e.message),
        onCodeSent: (verificationId) async {
          final smsCode = await _promptForValue(
            title: 'SMS code',
            keyboardType: TextInputType.number,
          );
          if (smsCode == null || smsCode.isEmpty) return;
          await authRepository.confirmSmsCode(
            verificationId: verificationId,
            smsCode: smsCode,
          );
        },
        onTimeout: (_) {},
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message);
    } finally {
      _setBusy(false);
    }
  }

  void _showError(String? message) {
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<String?> _promptForValue({
    required String title,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disabled = isBusy || isLoadingEmail;
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            if (errorText != null)
              Text(errorText!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: isLoadingEmail ? null : _login,
              child: isLoadingEmail
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Login'),
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
                        } else if (status == 'phone') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đăng ký bằng số điện thoại thành công.'),
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Create an account'),
            ),
            const Divider(height: 32),
            const Text(
              'Or continue with',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: disabled ? null : _signInAnonymously,
              child: const Text('Continue anonymously'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: disabled ? null : _signInWithGoogle,
              icon: const Icon(Icons.login),
              label: const Text('Sign in with Google'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: disabled ? null : _signInWithPhone,
              child: const Text('Sign in with Phone'),
            ),
          ],
        ),
      ),
    );
  }
}

