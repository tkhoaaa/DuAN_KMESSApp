import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../profile/user_profile_repository.dart';
import '../services/phone_auth_service.dart';
import '../utils/phone_auth_error_helper.dart';

class AddPhonePage extends StatefulWidget {
  const AddPhonePage({super.key});

  @override
  State<AddPhonePage> createState() => _AddPhonePageState();
}

class _AddPhonePageState extends State<AddPhonePage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  String? _verificationId;
  bool _isSending = false;
  bool _isVerifying = false;
  String? _error;
  final PhoneAuthService _phoneService = PhoneAuthService();

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
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

  Future<void> _verifyAndLink() async {
    if (_verificationId == null) {
      setState(() => _error = 'Vui lòng gửi mã OTP trước');
      return;
    }
    final code = _codeController.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Mã OTP không hợp lệ');
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _error = 'Bạn cần đăng nhập trước');
        return;
      }
      await user.linkWithCredential(credential);
      // Cập nhật profile
      await userProfileRepository.ensureProfile(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoURL,
        phoneNumber: user.phoneNumber,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm số điện thoại thành công')),
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
      appBar: AppBar(title: const Text('Thêm số điện thoại')),
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
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isVerifying ? null : _verifyAndLink,
              child: _isVerifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Xác thực & liên kết'),
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

