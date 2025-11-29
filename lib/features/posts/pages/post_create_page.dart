import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/post_media.dart';
import '../models/draft_post.dart';
import '../services/post_service.dart';
import '../widgets/hashtag_autocomplete_field.dart';

class PostCreatePage extends StatefulWidget {
  const PostCreatePage({
    this.draftId,
    super.key,
  });

  final String? draftId;

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
  bool _isSavingDraft = false;
  bool _isScheduled = false;
  DateTime? _scheduledAt;
  String? _currentDraftId;
  bool _isLoadingDraft = false;

  @override
  void initState() {
    super.initState();
    if (widget.draftId != null) {
      _loadDraft(widget.draftId!);
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadDraft(String draftId) async {
    setState(() {
      _isLoadingDraft = true;
    });

    try {
      final draft = await _postService.fetchDraft(draftId);
      if (draft == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tìm thấy bài nháp')),
          );
        }
        return;
      }
      
      if (!mounted) return;

      // Load caption
      if (draft.caption?.isNotEmpty == true) {
        _captionController.text = draft.caption!;
      }

      // Load media - Lưu ý: Draft lưu local path, cần kiểm tra file còn tồn tại không
      final mediaList = <PostMediaUpload>[];
      int skippedCount = 0;
      
      for (final media in draft.media) {
        try {
          // Kiểm tra xem URL có phải là local path không
          if (media.url.startsWith('/') || media.url.contains('file://')) {
            // Local file path - normalize path
            String filePath = media.url;
            if (filePath.startsWith('file://')) {
              filePath = filePath.substring(7);
            }
            
            // Kiểm tra file có tồn tại không (chỉ trên mobile, không check trên web)
            if (!kIsWeb) {
              final fileExists = await File(filePath).exists();
              if (!fileExists) {
                // File không tồn tại, bỏ qua
                skippedCount++;
                continue;
              }
            }
            
            final file = XFile(filePath);
            mediaList.add(PostMediaUpload(
              file: file,
              type: media.type,
            ));
          } else {
            // Network URL - có thể là media đã được upload trước đó
            // Tạm thời bỏ qua vì không thể convert network URL thành XFile
            skippedCount++;
            continue;
          }
        } catch (e) {
          // Bỏ qua media không load được
          print('Error loading media from draft: $e');
          skippedCount++;
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _selectedMedia.addAll(mediaList);
          _currentDraftId = draftId;
          _isLoadingDraft = false;
        });
        
        // Thông báo nếu có media không load được
        if (skippedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$skippedCount media không thể tải lại (file đã bị xóa hoặc không tìm thấy)'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDraft = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải bài nháp: $e')),
        );
      }
    }
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
    
    // Validate scheduled time
    if (_isScheduled && _scheduledAt != null) {
      if (_scheduledAt!.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thời gian hẹn đăng phải trong tương lai.')),
        );
        return;
      }
    }
    
    setState(() {
      _isSubmitting = true;
    });
    try {
      await _postService.createPost(
        media: List<PostMediaUpload>.from(_selectedMedia),
        caption: _captionController.text.trim(),
        scheduledAt: _isScheduled ? _scheduledAt : null,
      );
      
      // Xóa draft nếu đã publish từ draft
      if (_currentDraftId != null) {
        try {
          await _postService.deleteDraft(_currentDraftId!);
        } catch (e) {
          // Ignore error khi xóa draft
          debugPrint('Error deleting draft after publish: $e');
        }
      }
      
      // Kiểm tra mounted trước khi sử dụng context
      if (!mounted) return;
      
      final message = _isScheduled
          ? 'Đã lên lịch đăng bài vào ${DateFormat('dd/MM/yyyy HH:mm').format(_scheduledAt!)}'
          : 'Đã đăng bài thành công';
      
      // Kiểm tra lại mounted trước khi show SnackBar
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      
      // Kiểm tra lại mounted trước khi pop Navigator
      // Sử dụng maybeOf để tránh lỗi nếu Navigator đã bị dispose
      if (!mounted) return;
      final navigator = Navigator.maybeOf(context);
      if (navigator != null) {
        navigator.pop(true);
      }
    } catch (e) {
      // Kiểm tra mounted trước khi sử dụng context
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tạo bài đăng: $e')),
      );
    } finally {
      // Đảm bảo reset state ngay cả khi có lỗi
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _saveDraft() async {
    setState(() {
      _isSavingDraft = true;
    });
    try {
      if (_currentDraftId != null) {
        // Update existing draft
        await _postService.updateDraft(
          draftId: _currentDraftId!,
          media: _selectedMedia.isEmpty ? null : List<PostMediaUpload>.from(_selectedMedia),
          caption: _captionController.text.trim().isEmpty ? null : _captionController.text.trim(),
        );
      } else {
        // Create new draft
        final draftId = await _postService.saveDraft(
          media: _selectedMedia.isEmpty ? null : List<PostMediaUpload>.from(_selectedMedia),
          caption: _captionController.text.trim().isEmpty ? null : _captionController.text.trim(),
        );
        setState(() {
          _currentDraftId = draftId;
        });
      }
      // Kiểm tra mounted trước khi sử dụng context
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_currentDraftId != null ? 'Đã cập nhật nháp' : 'Đã lưu nháp')),
      );
    } catch (e) {
      // Kiểm tra mounted trước khi sử dụng context
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi lưu nháp: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingDraft = false;
        });
      }
    }
  }

  Future<void> _pickScheduledTime() async {
    if (!mounted) return;
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _scheduledAt != null
          ? TimeOfDay.fromDateTime(_scheduledAt!)
          : TimeOfDay.now(),
    );
    if (pickedTime == null || !mounted) return;

    final scheduledDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (scheduledDateTime.isBefore(now)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thời gian hẹn đăng phải trong tương lai.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _scheduledAt = scheduledDateTime;
      _isScheduled = true;
    });
  }

  /// Chỉ chỉnh giờ đăng bài (giữ nguyên ngày)
  Future<void> _pickScheduledTimeOnly() async {
    if (!mounted) return;
    final now = DateTime.now();
    
    // Nếu chưa có scheduledAt, yêu cầu chọn ngày trước
    if (_scheduledAt == null) {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: now.add(const Duration(days: 1)),
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
      );
      if (pickedDate == null || !mounted) return;
      
      // Set ngày mặc định với giờ hiện tại
      _scheduledAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        now.hour,
        now.minute,
      );
    }

    if (!mounted) return;
    final currentScheduled = _scheduledAt!;
    
    // Chỉ hiển thị TimePicker, giữ nguyên ngày
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentScheduled),
    );
    if (pickedTime == null || !mounted) return;

    // Giữ nguyên ngày, chỉ cập nhật giờ
    final scheduledDateTime = DateTime(
      currentScheduled.year,
      currentScheduled.month,
      currentScheduled.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // Kiểm tra nếu thời gian mới vẫn trong tương lai
    if (scheduledDateTime.isBefore(now)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thời gian hẹn đăng phải trong tương lai.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _scheduledAt = scheduledDateTime;
      _isScheduled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDraft) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tạo bài đăng')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentDraftId != null ? 'Chỉnh sửa bài nháp' : 'Tạo bài đăng'),
        actions: [
          TextButton(
            onPressed: (_isSubmitting || _isSavingDraft) ? null : _saveDraft,
            child: _isSavingDraft
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Lưu nháp'),
          ),
          TextButton(
            onPressed: (_isSubmitting || _isSavingDraft) ? null : _submit,
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
            HashtagAutocompleteField(
              controller: _captionController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Caption',
                border: OutlineInputBorder(),
                hintText: 'Viết chú thích cho bài đăng... (Gõ # để thêm hashtag)',
              ),
            ),
            const SizedBox(height: 16),
            // Schedule section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _isScheduled,
                          onChanged: (value) {
                            setState(() {
                              _isScheduled = value ?? false;
                              if (!_isScheduled) {
                                _scheduledAt = null;
                              } else if (_scheduledAt == null) {
                                // Mặc định là ngày mai cùng giờ hiện tại
                                final now = DateTime.now();
                                _scheduledAt = DateTime(
                                  now.year,
                                  now.month,
                                  now.day + 1,
                                  now.hour,
                                  now.minute,
                                );
                              }
                            });
                          },
                        ),
                        const Text('Hẹn giờ đăng'),
                      ],
                    ),
                    if (_isScheduled) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickScheduledTime,
                              icon: const Icon(Icons.calendar_today),
                              label: Text(
                                _scheduledAt != null
                                    ? '${DateFormat('dd/MM/yyyy').format(_scheduledAt!)}'
                                    : 'Chọn ngày',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickScheduledTimeOnly,
                              icon: const Icon(Icons.access_time),
                              label: Text(
                                _scheduledAt != null
                                    ? '${DateFormat('HH:mm').format(_scheduledAt!)}'
                                    : 'Chọn giờ',
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_scheduledAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Sẽ đăng vào: ${DateFormat('dd/MM/yyyy HH:mm').format(_scheduledAt!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
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

