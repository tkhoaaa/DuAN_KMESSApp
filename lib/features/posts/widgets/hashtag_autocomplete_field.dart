import 'dart:async';
import 'package:flutter/material.dart';

import '../repositories/post_repository.dart';

class HashtagAutocompleteField extends StatefulWidget {
  const HashtagAutocompleteField({
    super.key,
    required this.controller,
    this.decoration,
    this.minLines,
    this.maxLines,
  });

  final TextEditingController controller;
  final InputDecoration? decoration;
  final int? minLines;
  final int? maxLines;

  @override
  State<HashtagAutocompleteField> createState() =>
      _HashtagAutocompleteFieldState();
}

class _HashtagAutocompleteFieldState extends State<HashtagAutocompleteField> {
  final PostRepository _postRepository = PostRepository();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _hideSuggestions();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    // Kiểm tra xem có đang gõ hashtag không
    if (cursorPosition > 0 && cursorPosition <= text.length) {
      final beforeCursor = text.substring(0, cursorPosition);
      final lastHashIndex = beforeCursor.lastIndexOf('#');

      if (lastHashIndex >= 0) {
        // Có dấu #, lấy phần sau dấu #
        final afterHash = beforeCursor.substring(lastHashIndex + 1);
        // Kiểm tra xem có khoảng trắng hoặc ký tự đặc biệt không (kết thúc hashtag)
        if (afterHash.isEmpty || RegExp(r'^[\w]*$').hasMatch(afterHash)) {
          // Đang gõ hashtag, hiển thị suggestions
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            _loadSuggestions(afterHash);
          });
          return;
        }
      }
    }

    // Không phải đang gõ hashtag, ẩn suggestions
    _hideSuggestions();
  }

  Future<void> _loadSuggestions(String query) async {
    try {
      final trending = await _postRepository.fetchTrendingHashtags(limit: 10);
      
      // Filter suggestions dựa trên query
      final filtered = query.isEmpty
          ? trending
          : trending
              .where((tag) => tag.toLowerCase().startsWith(query.toLowerCase()))
              .toList();

      if (mounted) {
        setState(() {
          _suggestions = filtered;
          _showSuggestions = filtered.isNotEmpty;
        });
        _showSuggestionsOverlay();
      }
    } catch (e) {
      // Ignore errors, không hiển thị suggestions
      if (mounted) {
        _hideSuggestions();
      }
    }
  }

  void _showSuggestionsOverlay() {
    if (!_showSuggestions || _suggestions.isEmpty) {
      _hideSuggestions();
      return;
    }

    _overlayEntry?.remove();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideSuggestions() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _showSuggestions = false;
    });
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return OverlayEntry(builder: (_) => const SizedBox.shrink());
    }

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        top: offset.dy + size.height,
        left: offset.dx,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final tag = _suggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text('#$tag'),
                    onTap: () {
                      _insertHashtag(tag);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _insertHashtag(String tag) {
    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    // Tìm vị trí bắt đầu của hashtag đang gõ
    final beforeCursor = text.substring(0, cursorPosition);
    final lastHashIndex = beforeCursor.lastIndexOf('#');

    if (lastHashIndex >= 0) {
      // Thay thế phần sau # bằng tag đã chọn
      final beforeHash = text.substring(0, lastHashIndex);
      final afterCursor = text.substring(cursorPosition);
      final newText = '$beforeHash#$tag $afterCursor';
      final newCursorPosition = lastHashIndex + tag.length + 2; // +2 cho # và space

      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPosition),
      );
    }

    _hideSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        decoration: widget.decoration,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        onTap: () {
          // Khi tap vào field, kiểm tra lại xem có cần hiển thị suggestions không
          _onTextChanged();
        },
        onChanged: (_) {
          // onChanged sẽ trigger _onTextChanged qua listener
        },
      ),
    );
  }
}

