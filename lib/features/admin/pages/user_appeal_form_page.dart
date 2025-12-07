import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/auth_repository.dart';
import '../models/appeal.dart';
import '../repositories/appeal_repository.dart';
import '../repositories/ban_repository.dart';
import '../../../services/cloudinary_service.dart';

class UserAppealFormPage extends StatefulWidget {
  const UserAppealFormPage({
    super.key,
    required this.banId,
  });

  final String banId;

  @override
  State<UserAppealFormPage> createState() => _UserAppealFormPageState();
}

class _UserAppealFormPageState extends State<UserAppealFormPage> {
  final AppealRepository _appealRepository = AppealRepository();
  final BanRepository _banRepository = BanRepository();
  final TextEditingController _reasonController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<String> _evidenceUrls = [];
  bool _isSubmitting = false;
  bool _isUploading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    setState(() {
      _isUploading = true;
    });

    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );

      if (picked == null) {
        setState(() {
          _isUploading = false;
        });
        return;
      }

      // Upload to Cloudinary
      final uploadResult = await CloudinaryService.uploadImage(
        file: picked,
        folder: 'appeals',
      );
      final url = uploadResult['url'];
      if (url == null || url.isEmpty) {
        throw StateError('Không lấy được URL ảnh sau khi upload');
      }

      setState(() {
        _evidenceUrls.add(url);
        _isUploading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi upload ảnh: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _removeImage(int index) async {
    setState(() {
      _evidenceUrls.removeAt(index);
    });
  }

  Future<void> _submitAppeal() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập lý do kháng cáo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = authRepository.currentUser();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn cần đăng nhập'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Kiểm tra xem đã có appeal chưa
    final existingAppeals = await _appealRepository.getAppealsByUser(user.uid);
    final hasPendingAppeal = existingAppeals.any(
      (a) => a.banId == widget.banId && a.status == AppealStatus.pending,
    );

    if (hasPendingAppeal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn đã có đơn kháng cáo đang chờ xử lý'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _appealRepository.createAppeal(
        uid: user.uid,
        banId: widget.banId,
        reason: _reasonController.text.trim(),
        evidence: _evidenceUrls,
      );

      // Update ban với appealId
      final ban = await _banRepository.getBan(widget.banId);
      if (ban != null) {
        // Appeal ID sẽ được set sau khi tạo, nhưng để đơn giản ta không cần update ban ở đây
        // Ban sẽ được update khi admin xử lý appeal
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi đơn kháng cáo thành công'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gửi đơn kháng cáo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lý do kháng cáo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Giải thích tại sao bạn nghĩ việc khóa tài khoản là không đúng...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Bằng chứng (tùy chọn)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bạn có thể đính kèm ảnh để làm bằng chứng',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            // Evidence images grid
            if (_evidenceUrls.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _evidenceUrls.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Image.network(
                        _evidenceUrls[index],
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            padding: const EdgeInsets.all(4),
                            minimumSize: const Size(32, 32),
                          ),
                          onPressed: () => _removeImage(index),
                        ),
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate),
              label: Text(_isUploading ? 'Đang upload...' : 'Thêm ảnh'),
              onPressed: _isUploading ? null : _pickAndUploadImage,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitAppeal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Gửi đơn kháng cáo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

