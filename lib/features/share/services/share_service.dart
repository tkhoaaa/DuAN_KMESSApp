import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/deep_link.dart';

class ShareService {
  /// Share post với deep link
  static Future<void> sharePost({
    required String postId,
    String? caption,
  }) async {
    final link = DeepLink.generatePostLink(postId);
    final text = caption != null && caption.isNotEmpty
        ? '$caption\n\nXem bài viết: $link'
        : 'Xem bài viết: $link';
    
    await Share.share(text);
  }

  /// Share profile với deep link
  static Future<void> shareProfile({
    required String uid,
    String? displayName,
  }) async {
    final link = DeepLink.generateProfileLink(uid);
    final name = displayName ?? 'người dùng này';
    final text = 'Xem profile của $name: $link';
    
    await Share.share(text);
  }

  /// Share hashtag với deep link
  static Future<void> shareHashtag({
    required String hashtag,
  }) async {
    final link = DeepLink.generateHashtagLink(hashtag);
    final cleanTag = hashtag.startsWith('#') ? hashtag : '#$hashtag';
    final text = 'Khám phá $cleanTag: $link';
    
    await Share.share(text);
  }

  /// Copy link vào clipboard
  static Future<void> copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
  }

  /// Copy post link vào clipboard
  static Future<void> copyPostLink(String postId) async {
    final link = DeepLink.generatePostLink(postId);
    await copyLink(link);
  }

  /// Copy profile link vào clipboard
  static Future<void> copyProfileLink(String uid) async {
    final link = DeepLink.generateProfileLink(uid);
    await copyLink(link);
  }

  /// Copy hashtag link vào clipboard
  static Future<void> copyHashtagLink(String hashtag) async {
    final link = DeepLink.generateHashtagLink(hashtag);
    await copyLink(link);
  }
}

