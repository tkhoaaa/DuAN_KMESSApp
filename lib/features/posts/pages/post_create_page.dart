import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post_media.dart';
import '../services/post_service.dart';

class PostCreatePage extends StatefulWidget {
  const PostCreatePage({super.key});

  @override
  State<PostCreatePage> createState() => _PostCreatePageState();
}

class _PostCreatePageState extends State<PostCreatePage> {
  final PostService _postService = PostService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();
  final PageController _pageController = PageController();

  final List<PostMediaUpload> _selectedMedia = [];
  int _currentIndex = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _captionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickImagesFromGallery() async {
    final picked = await _picker.pickMultiImage(
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked.isEmpty) return;
    setState(() {
      _selectedMedia.addAll(
        picked.map(
          (file) => PostMediaUpload(
            file: file,
            type: PostMediaType.image,
          ),
        ),
      );
    });
  }

  Future<void> _captureImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() {
      _selectedMedia.add(
        PostMediaUpload(file: file, type: PostMediaType.image),
      );
    });
  }

  Future<void> _pickVideo({required ImageSource source}) async {
    final file = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 2),
    );
    if (file == null) return;
    setState(() {
      _selectedMedia.add(
        PostMediaUpload(file: file, type: PostMediaType.video),
      );
    });
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedia.removeAt(index);
      if (_selectedMedia.isEmpty) {
        _currentIndex = 0;
      } else if (_currentIndex >= _selectedMedia.length) {
        _currentIndex = _selectedMedia.length - 1;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentIndex);
        }
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedMedia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chọn ít nhất một ảnh hoặc video.')),
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      await _postService.createPost(
        media: List<PostMediaUpload>.from(_selectedMedia),
        caption: _captionController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tạo bài đăng: $e')),
      );
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
        title: const Text('Tạo bài đăng'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
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
            _buildMediaPreview(),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _pickImagesFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Chọn nhiều ảnh'),
                ),
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _captureImage,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Chụp ảnh'),
                ),
                OutlinedButton.icon(
                  onPressed: _isSubmitting
                      ? null
                      : () => _pickVideo(source: ImageSource.gallery),
                  icon: const Icon(Icons.video_library),
                  label: const Text('Chọn video'),
                ),
                OutlinedButton.icon(
                  onPressed: _isSubmitting
                      ? null
                      : () => _pickVideo(source: ImageSource.camera),
                  icon: const Icon(Icons.videocam),
                  label: const Text('Quay video'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _captionController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Caption',
                border: OutlineInputBorder(),
                hintText: 'Viết chú thích cho bài đăng...',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    if (_selectedMedia.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('Chưa chọn media'),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 280,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _selectedMedia.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final entry = _selectedMedia[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildPreviewFor(entry),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed:
                            _isSubmitting ? null : () => _removeMedia(index),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (_selectedMedia.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_selectedMedia.length, (index) {
                final selected = index == _currentIndex;
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? Colors.blue : Colors.grey.shade400,
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewFor(PostMediaUpload entry) {
    switch (entry.type) {
      case PostMediaType.image:
        if (kIsWeb) {
          return Image.network(
            entry.file.path,
            fit: BoxFit.cover,
          );
        }
        return Image.file(
          File(entry.file.path),
          fit: BoxFit.cover,
        );
      case PostMediaType.video:
        return Container(
          color: Colors.black87,
          child: const Center(
            child: Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 72,
            ),
          ),
        );
    }
  }
}

