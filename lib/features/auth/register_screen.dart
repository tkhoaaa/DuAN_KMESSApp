import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_repository.dart';

enum RegisterMode { email, phone }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController smsCodeController = TextEditingController();
  bool isLoading = false;
  String? errorText;
  RegisterMode mode = RegisterMode.email;
  String? phoneVerificationId;

  Future<void> _register() async {
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
      setState(() {
        errorText = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _sendPhoneCode() async {
    setState(() {
      isLoading = true;
      errorText = null;
      phoneVerificationId = null;
    });
    try {
      final formatted = _formatPhoneNumber(phoneController.text.trim());
      await authRepository.startPhoneVerification(
        phoneNumber: formatted,
        onCompleted: (cred) async {
          await authRepository.signInWithCredential(cred);
          if (mounted) {
            Navigator.of(context).pop({'status': 'phone'});
          }
        },
        onError: (e) {
          setState(() {
            errorText = e.message;
          });
        },
        onCodeSent: (verificationId) {
          setState(() {
            phoneVerificationId = verificationId;
            errorText = 'Code sent. Please enter the 5-6 digit SMS code.';
          });
        },
        onTimeout: (verificationId) {
          setState(() {
            phoneVerificationId = verificationId;
          });
        },
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorText = e.message;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _verifyPhoneCode() async {
    if (phoneVerificationId == null) return;
    setState(() {
      isLoading = true;
      errorText = null;
    });
    try {
      await authRepository.confirmSmsCode(
        verificationId: phoneVerificationId!,
        smsCode: smsCodeController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop({'status': 'phone'});
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorText = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _formatPhoneNumber(String input) {
    var value = input.replaceAll(' ', '');
    if (value.startsWith('+')) {
      return value;
    }
    if (value.startsWith('0')) {
      return '+84${value.substring(1)}';
    }
    if (value.startsWith('84')) {
      return '+$value';
    }
    throw FirebaseAuthException(
      code: 'invalid-phone-number',
      message:
          'Số điện thoại không đúng định dạng E.164. Vui lòng nhập dạng +84xxxxxxxx.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<RegisterMode>(
              segments: const [
                ButtonSegment(value: RegisterMode.email, label: Text('Email')),
                ButtonSegment(value: RegisterMode.phone, label: Text('Phone')),
              ],
              selected: {mode},
              onSelectionChanged: (value) {
                setState(() {
                  mode = value.first;
                  errorText = null;
                  isLoading = false;
                });
              },
            ),
            const SizedBox(height: 16),
            if (mode == RegisterMode.email) ...[
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
              onPressed: isLoading ? null : _register,
              child: isLoading
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Register'),
            ),
            ] else ...[
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone number (+84...)'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              if (phoneVerificationId != null)
                TextField(
                  controller: smsCodeController,
                  decoration: const InputDecoration(labelText: 'SMS code'),
                  keyboardType: TextInputType.number,
                ),
              const SizedBox(height: 12),
              if (errorText != null)
                Text(errorText!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : (phoneVerificationId == null ? _sendPhoneCode : _verifyPhoneCode),
                child: isLoading
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(phoneVerificationId == null ? 'Send code' : 'Verify code'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

