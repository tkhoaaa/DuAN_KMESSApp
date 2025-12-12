import 'package:flutter/material.dart';

import '../models/deep_link.dart';
import '../../posts/pages/post_permalink_page.dart';
import '../../profile/public_profile_page.dart';
import '../../posts/pages/hashtag_page.dart';
import '../../auth/pages/reset_password_page.dart';

class DeepLinkService {
  /// Handle deep link và navigate đến page tương ứng
  static Future<void> handleDeepLink(
    BuildContext context,
    DeepLink link,
  ) async {
    if (!context.mounted) return;

    switch (link.type) {
      case DeepLinkType.post:
        if (link.postId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostPermalinkPage(postId: link.postId!),
            ),
          );
        } else {
          _showError(context, 'Link bài viết không hợp lệ');
        }
        break;

      case DeepLinkType.profile:
        if (link.uid != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PublicProfilePage(uid: link.uid!),
            ),
          );
        } else {
          _showError(context, 'Link profile không hợp lệ');
        }
        break;

      case DeepLinkType.hashtag:
        if (link.hashtag != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HashtagPage(hashtag: link.hashtag!),
            ),
          );
        } else {
          _showError(context, 'Link hashtag không hợp lệ');
        }
        break;

      case DeepLinkType.resetPassword:
        if (link.actionCode != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ResetPasswordPage(actionCode: link.actionCode!),
            ),
          );
        } else {
          _showError(context, 'Link reset mật khẩu không hợp lệ');
        }
        break;

      case DeepLinkType.unknown:
        _showError(context, 'Link không được hỗ trợ');
        break;
    }
  }

  static void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

