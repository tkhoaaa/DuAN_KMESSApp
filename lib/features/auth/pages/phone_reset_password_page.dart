import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/phone_auth_service.dart';
import '../utils/phone_auth_error_helper.dart';

class PhoneResetPasswordPage extends StatefulWidget {
  final String? initialPhone;
  const PhoneResetPasswordPage({super.key, this.initialPhone});

  @override
  State<PhoneResetPasswordPage> createState() => _PhoneResetPasswordPageState();
}

class _PhoneResetPasswordPageState extends State<PhoneResetPasswordPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  String? _verificationId;
  bool _isSending = false;
  bool _isVerifying = false;
  String? _error;
  final PhoneAuthService _phoneService = PhoneAuthService();

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) {
      _phoneController.text = widget.initialPhone!;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    String normalized;
    try {
      normalized = _phoneService.normalizePhone(_phoneController.text.trim());
    } catch (e) {
      setState(() => _error = e.toString());
      return;
    }
    setState(() {
      _isSending = true;
      _error = null;
    });
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: normalized,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        if (mounted) {
          setState(() {
            _error = PhoneAuthErrorHelper.getErrorMessage(e);
            _isSending = false;
          });
        }
      },
      codeSent: (verificationId, _) {
        setState(() {
          _verificationId = verificationId;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi mã OTP')),
        );
      },
      codeAutoRetrievalTimeout: (verificationId) {
        setState(() {
          _verificationId = verificationId;
        });
      },
    );
    if (mounted) {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _verifyAndReset() async {
    if (_verificationId == null) {
      setState(() => _error = 'Vui lòng gửi mã OTP trước');
      return;
    }
    final code = _codeController.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Mã OTP không hợp lệ');
      return;
    }
    final newPassword = _newPasswordController.text.trim();
    if (newPassword.length < 6) {
      setState(() => _error = 'Mật khẩu mới phải từ 6 ký tự');
      return;
    }
    setState(() {
      _isVerifying = true;
      _error = null;
    });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      // Đăng nhập bằng credential, sau đó đổi mật khẩu
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      await userCred.user?.updatePassword(newPassword);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đặt lại mật khẩu thành công')),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = PhoneAuthErrorHelper.getErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu (SĐT)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại',
                hintText: 'Ví dụ: 0867xxx hoặc +84867xxx',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Mã OTP',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSending ? null : _sendCode,
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Gửi mã'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPasswordController,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu mới',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isVerifying ? null : _verifyAndReset,
              child: _isVerifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Xác thực & đổi mật khẩu'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

