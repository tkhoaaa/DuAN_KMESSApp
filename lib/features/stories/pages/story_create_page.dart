import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/auth_repository.dart';
import '../../profile/user_profile_repository.dart';
import '../models/story.dart';
import '../repositories/story_repository.dart';

class StoryCreatePage extends StatefulWidget {
  const StoryCreatePage({super.key});

  @override
  State<StoryCreatePage> createState() => _StoryCreatePageState();
}

class _StoryCreatePageState extends State<StoryCreatePage> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _textController = TextEditingController();
  final StoryRepository _storyRepository = StoryRepository();
  final UserProfileRepository userProfileRepository = UserProfileRepository();

  XFile? _selectedFile;
  StoryMediaType? _mediaType;
  bool _isUploading = false;
  int _storiesCreatedInSession = 0; // Đếm số story đã tạo trong session này

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source, StoryMediaType type) async {
    try {
      XFile? picked;
      if (type == StoryMediaType.image) {
        picked = await _picker.pickImage(
          source: source,
          maxWidth: 1080,
          imageQuality: 85,
        );
      } else {
        picked = await _picker.pickVideo(
          source: source,
          maxDuration: const Duration(seconds: 30),
        );
      }
      if (picked == null) return;
      setState(() {
        _selectedFile = picked;
        _mediaType = type;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi chọn media: $e')),
      );
    }
  }

  Future<void> _submit({bool closeAfterSubmit = false}) async {
    final user = authRepository.currentUser();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để tạo story.')),
      );
      return;
    }
    if (_selectedFile == null || _mediaType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ảnh hoặc video.')),
      );
      return;
    }
    setState(() {
      _isUploading = true;
    });
    try {
      final text = _textController.text.trim();
      
      // Debug: Kiểm tra authentication
      debugPrint('Story create - User UID: ${user.uid}');
      debugPrint('Story create - User email: ${user.email}');
      
      // Đảm bảo user profile đã được tạo trước khi tạo story
      // Điều này đảm bảo Firestore rules có thể kiểm tra banStatus
      try {
        debugPrint('Ensuring profile for user: ${user.uid}');
        await userProfileRepository.ensureProfile(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          photoUrl: user.photoURL,
        );
        debugPrint('User profile ensured successfully');
        
        // Kiểm tra lại profile sau khi ensure
        final profile = await userProfileRepository.fetchProfile(user.uid);
        debugPrint('Profile after ensure - banStatus: ${profile?.banStatus}');
      } catch (e, stackTrace) {
        debugPrint('Error ensuring profile: $e');
        debugPrint('Stack trace: $stackTrace');
        // Không tiếp tục nếu không thể tạo profile - đây là lỗi nghiêm trọng
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tạo profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isUploading = false;
        });
        return;
      }
      
      if (_mediaType == StoryMediaType.image) {
        await _storyRepository.uploadAndCreateStoryImage(
          authorUid: user.uid,
          file: _selectedFile!,
          text: text.isNotEmpty ? text : null,
        );
      } else {
        await _storyRepository.uploadAndCreateStoryVideo(
          authorUid: user.uid,
          file: _selectedFile!,
          text: text.isNotEmpty ? text : null,
        );
      }
      if (!mounted) return;
      
      setState(() {
        _storiesCreatedInSession++;
        _selectedFile = null;
        _mediaType = null;
        _textController.clear();
        _isUploading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã đăng story thành công! (${_storiesCreatedInSession} story)'),
          action: closeAfterSubmit
              ? null
              : SnackBarAction(
                  label: 'Đóng',
                  onPressed: () => Navigator.of(context).pop(true),
                ),
        ),
      );
      
      if (closeAfterSubmit) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      
      debugPrint('=== Story Create Error ===');
      debugPrint('Error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      
      String errorMessage = 'Lỗi đăng story: $e';
      
      // Kiểm tra lỗi cụ thể và hiển thị thông báo phù hợp
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('permission') || errorString.contains('denied')) {
        errorMessage = 'Không có quyền đăng story.\n'
            'Vui lòng kiểm tra:\n'
            '- Bạn đã đăng nhập đúng tài khoản?\n'
            '- Tài khoản của bạn có bị khóa không?\n'
            '- Vui lòng thử đăng xuất và đăng nhập lại.';
      } else if (errorString.contains('banned') || errorString.contains('ban')) {
        errorMessage = 'Tài khoản của bạn đã bị khóa.\n'
            'Vui lòng liên hệ quản trị viên.';
      } else if (errorString.contains('not authenticated')) {
        errorMessage = 'Bạn chưa đăng nhập.\n'
            'Vui lòng đăng nhập lại.';
      } else if (errorString.contains('uid mismatch')) {
        errorMessage = 'Lỗi xác thực tài khoản.\n'
            'Vui lòng đăng xuất và đăng nhập lại.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red,
        ),
      );
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget preview;
    if (_selectedFile == null) {
      preview = Container(
        height: 320,
        color: Colors.grey.shade200,
        child: const Center(
          child: Text('Chọn ảnh hoặc video để tạo story'),
        ),
      );
    } else if (_mediaType == StoryMediaType.image) {
      preview = Container(
        height: 320,
        color: Colors.black,
        child: kIsWeb
            ? Image.network(
                _selectedFile!.path,
                fit: BoxFit.cover,
              )
            : Image.file(
                File(_selectedFile!.path),
                fit: BoxFit.cover,
              ),
      );
    } else {
      preview = Container(
        height: 320,
        color: Colors.black,
        child: const Center(
          child: Icon(
            Icons.play_circle_fill,
            color: Colors.white,
            size: 64,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_storiesCreatedInSession > 0
            ? 'Tạo story (${_storiesCreatedInSession} đã đăng)'
            : 'Tạo story'),
        actions: [
          if (_storiesCreatedInSession > 0)
            TextButton(
              onPressed: _isUploading
                  ? null
                  : () => Navigator.of(context).pop(true),
              child: const Text('Hoàn thành'),
            ),
          if (_selectedFile != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'submit_and_close') {
                  _submit(closeAfterSubmit: true);
                } else if (value == 'submit_and_continue') {
                  _submit(closeAfterSubmit: false);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'submit_and_continue',
                  enabled: !_isUploading,
                  child: const Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 20),
                      SizedBox(width: 8),
                      Text('Đăng và thêm story'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'submit_and_close',
                  enabled: !_isUploading,
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 20),
                      SizedBox(width: 8),
                      Text('Đăng và đóng'),
                    ],
                  ),
                ),
              ],
              child: _isUploading
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.more_vert),
            )
          else if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            preview,
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _isUploading
                      ? null
                      : () => _pickMedia(ImageSource.gallery, StoryMediaType.image),
                  icon: const Icon(Icons.photo),
                  label: const Text('Ảnh từ thư viện'),
                ),
                OutlinedButton.icon(
                  onPressed: _isUploading
                      ? null
                      : () => _pickMedia(ImageSource.camera, StoryMediaType.image),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Chụp ảnh'),
                ),
                OutlinedButton.icon(
                  onPressed: _isUploading
                      ? null
                      : () => _pickMedia(ImageSource.gallery, StoryMediaType.video),
                  icon: const Icon(Icons.video_library),
                  label: const Text('Video từ thư viện'),
                ),
                OutlinedButton.icon(
                  onPressed: _isUploading
                      ? null
                      : () => _pickMedia(ImageSource.camera, StoryMediaType.video),
                  icon: const Icon(Icons.videocam),
                  label: const Text('Quay video'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Caption (tùy chọn)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


