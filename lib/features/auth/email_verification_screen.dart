import 'package:flutter/material.dart';
import 'auth_repository.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    required this.onVerified,
    super.key,
  });

  final VoidCallback onVerified;

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool isSending = false;
  bool isRefreshing = false;
  String? message;
  bool _initialEmailSent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendEmail(initial: true));
  }

  Future<void> _sendEmail({bool initial = false}) async {
    final user = authRepository.currentUser();
    if (user == null || user.email == null) return;
    if (initial && _initialEmailSent) return;

    setState(() {
      isSending = true;
      message = null;
    });
    try {
      await authRepository.sendEmailVerification();
      setState(() {
        _initialEmailSent = true;
        message = 'Đã gửi email xác thực tới ${user.email}. Vui lòng kiểm tra hộp thư.';
      });
    } catch (e) {
      setState(() {
        message = 'Không thể gửi email: $e';
      });
    } finally {
      setState(() {
        isSending = false;
      });
    }
  }

  Future<void> _refreshStatus() async {
    setState(() {
      isRefreshing = true;
      message = null;
    });
    try {
      await authRepository.reloadCurrentUser();
      final user = authRepository.currentUser();
      if (user?.emailVerified == true) {
        setState(() {
          message = 'Email đã được xác thực. Bạn sẽ được chuyển tiếp ngay.';
        });
        widget.onVerified();
      } else {
        setState(() {
          message = 'Email chưa được xác thực. Vui lòng mở mail và nhấn vào liên kết.';
        });
      }
    } catch (e) {
      setState(() {
        message = 'Không thể kiểm tra trạng thái: $e';
      });
    } finally {
      setState(() {
        isRefreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = authRepository.currentUser();
    final email = user?.email ?? '(không có email)';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác thực email'),
        actions: [
          IconButton(
            onPressed: authRepository.signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Chúng tôi đã gửi liên kết xác thực tới $email.\n'
              'Bấm vào liên kết trong email để hoàn tất xác thực, sau đó nhấn "Tôi đã xác thực" bên dưới.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: isSending ? null : () => _sendEmail(),
              child: isSending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Gửi lại email xác thực'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: isRefreshing ? null : _refreshStatus,
              child: isRefreshing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Tôi đã xác thực'),
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                style: const TextStyle(color: Colors.blueGrey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

