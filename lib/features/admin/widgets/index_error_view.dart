import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hiển thị thông báo lỗi thiếu index cùng đường link có thể sao chép.
class IndexErrorView extends StatelessWidget {
  const IndexErrorView({
    super.key,
    required this.error,
    this.title,
  });

  final Object error;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final message = error.toString();
    final link = _extractLink(message);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 12),
            Text(
              title ?? 'Không thể tải dữ liệu',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Firestore yêu cầu tạo index cho truy vấn này. Sao chép link bên dưới và mở trên trình duyệt để tạo index tự động.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (link != null) ...[
              const SizedBox(height: 16),
              SelectableText(
                link,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _copyLink(context, link),
                icon: const Icon(Icons.copy),
                label: const Text('Copy link'),
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Chi tiết lỗi:',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                message,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _extractLink(String message) {
    final match = RegExp(r'https:\/\/console\.firebase\.google\.com[^\s"]+')
        .firstMatch(message);
    return match?.group(0);
  }

  Future<void> _copyLink(BuildContext context, String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã copy link tạo index vào clipboard'),
        ),
      );
    }
  }
}

