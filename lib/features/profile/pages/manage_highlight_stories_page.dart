import 'package:flutter/material.dart';
import '../../stories/models/story.dart';
import '../../stories/repositories/story_repository.dart';
import '../user_profile_repository.dart';

class ManageHighlightStoriesPage extends StatefulWidget {
  const ManageHighlightStoriesPage({
    super.key,
    required this.uid,
    this.initialHighlightId,
  });

  final String uid;

  /// Nếu được truyền, trang sẽ tự động mở dialog sửa cho highlight này
  final String? initialHighlightId;

  @override
  State<ManageHighlightStoriesPage> createState() => _ManageHighlightStoriesPageState();
}

class _ManageHighlightStoriesPageState extends State<ManageHighlightStoriesPage> {
  final StoryRepository _storyRepository = StoryRepository();
  List<HighlightStory> _highlightedStories = [];
  List<Story> _availableStories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load current highlighted stories
      final profile = await userProfileRepository.fetchProfile(widget.uid);
      if (profile != null) {
        _highlightedStories = List<HighlightStory>.from(profile.highlightedStories);
      }

      // Load all available stories (bao gồm cả story đã hết hạn)
      final allStories = await _storyRepository.fetchStoriesByAuthor(widget.uid).first;
      setState(() {
        _availableStories = allStories;
        _isLoading = false;
      });

      // Nếu được mở từ nút 3 chấm trong StoryViewer với một highlight cụ thể,
      // tự động mở dialog sửa highlight đó sau khi dữ liệu đã load.
      if (mounted && widget.initialHighlightId != null) {
        final target = _highlightedStories.firstWhere(
          (h) => h.id == widget.initialHighlightId,
          orElse: () => _highlightedStories.isNotEmpty
              ? _highlightedStories.first
              : HighlightStory(id: '', name: '', storyIds: const []),
        );
        if (target.id.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _editHighlightStory(target);
            }
          });
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    }
  }

  Future<void> _saveHighlightedStories() async {
    try {
      await userProfileRepository.updateHighlightedStories(
        widget.uid,
        _highlightedStories,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật highlight stories.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật: $e')),
        );
      }
    }
  }

  Future<void> _createHighlightStory() async {
    final nameController = TextEditingController();
    final selectedStoryIds = <String>{};

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo Highlight Story'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên highlight',
                      hintText: 'Ví dụ: Kỳ nghỉ hè',
                    ),
                    maxLength: 20,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chọn stories (chỉ stories đang hoạt động)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_availableStories.isEmpty)
                    const Text(
                      'Chưa có story nào đang hoạt động',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    SizedBox(
                      height: 300,
                      child: ListView.builder(
                        shrinkWrap: true,
                        primary: false,
                        itemCount: _availableStories.length,
                        itemBuilder: (context, index) {
                          final story = _availableStories[index];
                          final isSelected = selectedStoryIds.contains(story.id);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == true) {
                                  selectedStoryIds.add(story.id);
                                } else {
                                  selectedStoryIds.remove(story.id);
                                }
                              });
                            },
                            title: Text(
                              story.text?.isNotEmpty == true
                                  ? story.text!
                                  : 'Story ${index + 1}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(_formatDate(story.createdAt)),
                            secondary: CircleAvatar(
                              radius: 20,
                              backgroundImage: story.thumbnailUrl != null
                                  ? NetworkImage(story.thumbnailUrl!)
                                  : story.type == StoryMediaType.image
                                      ? NetworkImage(story.mediaUrl)
                                      : null,
                              child: story.type == StoryMediaType.video &&
                                      story.thumbnailUrl == null
                                  ? const Icon(Icons.videocam, size: 20)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                ],
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập tên highlight')),
                );
                return;
              }
              if (selectedStoryIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng chọn ít nhất 1 story')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty && selectedStoryIds.isNotEmpty) {
      final newHighlight = HighlightStory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: nameController.text.trim(),
        storyIds: selectedStoryIds.toList(),
      );
      setState(() {
        _highlightedStories.add(newHighlight);
      });
      await _saveHighlightedStories();
    }
  }

  Future<void> _editHighlightStory(HighlightStory highlight) async {
    final nameController = TextEditingController(text: highlight.name);
    // Chỉ giữ lại các storyId vẫn còn active trong _availableStories
    final activeIds = _availableStories.map((s) => s.id).toSet();
    final selectedStoryIds = <String>{
      ...highlight.storyIds.where((id) => activeIds.contains(id)),
    };

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sửa Highlight Story'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên highlight',
                      hintText: 'Ví dụ: Kỳ nghỉ hè',
                    ),
                    maxLength: 20,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chọn stories (chỉ stories đang hoạt động)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_availableStories.isEmpty)
                    const Text(
                      'Chưa có story nào đang hoạt động',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    SizedBox(
                      height: 300,
                      child: ListView.builder(
                        shrinkWrap: true,
                        primary: false,
                        itemCount: _availableStories.length,
                        itemBuilder: (context, index) {
                          final story = _availableStories[index];
                          final isSelected = selectedStoryIds.contains(story.id);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == true) {
                                  selectedStoryIds.add(story.id);
                                } else {
                                  selectedStoryIds.remove(story.id);
                                }
                              });
                            },
                            title: Text(
                              story.text?.isNotEmpty == true
                                  ? story.text!
                                  : 'Story ${index + 1}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(_formatDate(story.createdAt)),
                            secondary: CircleAvatar(
                              radius: 20,
                              backgroundImage: story.thumbnailUrl != null
                                  ? NetworkImage(story.thumbnailUrl!)
                                  : story.type == StoryMediaType.image
                                      ? NetworkImage(story.mediaUrl)
                                      : null,
                              child: story.type == StoryMediaType.video &&
                                      story.thumbnailUrl == null
                                  ? const Icon(Icons.videocam, size: 20)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                ],
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập tên highlight')),
                );
                return;
              }
              if (selectedStoryIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng chọn ít nhất 1 story')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty && selectedStoryIds.isNotEmpty) {
      final index = _highlightedStories.indexWhere((h) => h.id == highlight.id);
      if (index != -1) {
        setState(() {
          _highlightedStories[index] = HighlightStory(
            id: highlight.id,
            name: nameController.text.trim(),
            storyIds: selectedStoryIds.toList(),
          );
        });
        await _saveHighlightedStories();
      }
    }
  }

  Future<void> _deleteHighlightStory(HighlightStory highlight) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa Highlight Story'),
        content: Text('Bạn có chắc muốn xóa "${highlight.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _highlightedStories.removeWhere((h) => h.id == highlight.id);
      });
      await _saveHighlightedStories();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Highlight Stories'),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_highlightedStories.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Chưa có highlight story nào',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _highlightedStories.length,
                      itemBuilder: (context, index) {
                        final highlight = _highlightedStories[index];
                        // Get stories for this highlight
                        final stories = _availableStories
                            .where((s) => highlight.storyIds.contains(s.id))
                            .toList();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: stories.isNotEmpty
                                ? CircleAvatar(
                                    radius: 25,
                                    backgroundImage: stories.first.thumbnailUrl != null
                                        ? NetworkImage(stories.first.thumbnailUrl!)
                                        : stories.first.type == StoryMediaType.image
                                            ? NetworkImage(stories.first.mediaUrl)
                                            : null,
                                    child: stories.first.type == StoryMediaType.video &&
                                            stories.first.thumbnailUrl == null
                                        ? const Icon(Icons.videocam)
                                        : null,
                                  )
                                : const CircleAvatar(
                                    radius: 25,
                                    child: Icon(Icons.auto_awesome),
                                  ),
                            title: Text(highlight.name),
                            subtitle: Text('${stories.length} story${stories.length > 1 ? 's' : ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editHighlightStory(highlight),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteHighlightStory(highlight),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createHighlightStory,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      return 'Hôm nay';
    } else if (diff.inDays == 1) {
      return 'Hôm qua';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} ngày trước';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
