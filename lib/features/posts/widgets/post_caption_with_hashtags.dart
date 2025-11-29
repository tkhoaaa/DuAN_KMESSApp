import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../pages/hashtag_page.dart';

class PostCaptionWithHashtags extends StatelessWidget {
  const PostCaptionWithHashtags({
    super.key,
    required this.caption,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String caption;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    if (caption.isEmpty) return const SizedBox.shrink();

    // Parse caption để tìm hashtags
    final textSpans = _parseCaption(context, caption);

    return RichText(
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      text: TextSpan(
        style: style ?? DefaultTextStyle.of(context).style,
        children: textSpans,
      ),
    );
  }

  List<TextSpan> _parseCaption(BuildContext context, String text) {
    if (text.isEmpty) return [];

    final spans = <TextSpan>[];
    final regex = RegExp(r'#[\w]{1,50}', caseSensitive: false);
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      // Thêm text trước hashtag
      if (match.start > lastIndex) {
        final beforeText = text.substring(lastIndex, match.start);
        if (beforeText.isNotEmpty) {
          spans.add(TextSpan(text: beforeText));
        }
      }

      // Thêm hashtag (tap-able)
      final hashtagText = match.group(0) ?? '';
      final hashtag = hashtagText.substring(1).toLowerCase(); // Bỏ dấu #

      spans.add(
        TextSpan(
          text: hashtagText,
          style: TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              // Navigate đến HashtagPage
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => HashtagPage(hashtag: hashtag),
                ),
              );
            },
        ),
      );

      lastIndex = match.end;
    }

    // Thêm text còn lại sau hashtag cuối cùng
    if (lastIndex < text.length) {
      final remainingText = text.substring(lastIndex);
      if (remainingText.isNotEmpty) {
        spans.add(TextSpan(text: remainingText));
      }
    }

    // Nếu không có hashtag nào, trả về text bình thường
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }

    return spans;
  }
}

