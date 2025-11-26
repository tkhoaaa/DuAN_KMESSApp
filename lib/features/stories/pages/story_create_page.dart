import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/auth_repository.dart';
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

  XFile? _selectedFile;
  StoryMediaType? _mediaType;
  bool _isUploading = false;

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

  Future<void> _submit() async {
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
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi đăng story: $e')),
      );
    } finally {
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
        title: const Text('Tạo story'),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _submit,
            child: _isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Đăng'),
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


