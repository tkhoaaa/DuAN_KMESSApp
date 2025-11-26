import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../auth/auth_repository.dart';
import '../../notifications/services/notification_service.dart';
import '../../profile/user_profile_repository.dart';
import '../../../services/cloudinary_service.dart';
import '../models/post.dart';
import '../models/post_comment.dart';
import '../models/post_media.dart';
import '../repositories/post_repository.dart';

class PostMediaUpload {
  PostMediaUpload({
    required this.file,
    required this.type,
  });

  final XFile file;
  final PostMediaType type;
}

class PostFeedEntry {
  PostFeedEntry({
    required this.doc,
    required this.author,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final UserProfile? author;
}

class PostFeedPageResult {
  PostFeedPageResult({
    required this.entries,
    required this.lastDoc,
    required this.hasMore,
  });

  final List<PostFeedEntry> entries;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
}

class PostCommentEntry {
  PostCommentEntry({
    required this.comment,
    required this.author,
  });

  final PostComment comment;
  final UserProfile? author;
}

class PostService {
  /// Chọn storage backend: 'firebase' hoặc 'cloudinary'
  /// Mặc định: 'firebase'
  static const String storageBackend = 'cloudinary'; // Thay đổi thành 'firebase' nếu muốn dùng Firebase Storage
  
  PostService({
    PostRepository? repository,
    UserProfileRepository? profileRepository,
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
  })  : _repository = repository ?? PostRepository(firestore: firestore),
        _profiles = profileRepository ?? userProfileRepository,
        _storage = storage ?? FirebaseStorage.instance;

  final PostRepository _repository;
  final UserProfileRepository _profiles;
  final NotificationService _notificationService = NotificationService();
  final FirebaseStorage _storage;

  Future<PostFeedPageResult> fetchFeedPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 10,
  }) async {
    final page = await _repository.fetchPosts(
      startAfter: startAfter,
      limit: limit,
    );

    final futures = page.docs.map((doc) async {
      final post = Post.fromDoc(doc);
      final author = await _profiles.fetchProfile(post.authorUid);
      return PostFeedEntry(
        doc: doc,
        author: author,
      );
    }).toList();

    final entries = await Future.wait(futures);
    return PostFeedPageResult(
      entries: entries,
      lastDoc: page.lastDoc,
      hasMore: page.hasMore,
    );
  }

  Future<void> createPost({
    required List<PostMediaUpload> media,
    String? caption,
  }) async {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) {
      throw StateError('Bạn cần đăng nhập.');
    }

    if (media.isEmpty) {
      throw ArgumentError('Cần chọn ít nhất một ảnh hoặc video.');
    }

    final uploads = <Map<String, dynamic>>[];

    for (final entry in media) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Làm sạch tên file: loại bỏ khoảng trắng và ký tự đặc biệt
      final originalName = entry.file.name.isNotEmpty 
          ? entry.file.name
              .trim()
              .replaceAll(RegExp(r'[^\w\-.]'), '_')
              .replaceAll(RegExp(r'\s+'), '_')
          : 'media';
      
      String downloadUrl;
      String? thumbnailUrl;
      int? durationMs;

      String? publicId;

      if (storageBackend == 'cloudinary') {
        // Dùng Cloudinary
        if (entry.type == PostMediaType.video) {
          final result = await CloudinaryService.uploadVideo(
            file: entry.file,
            folder: 'posts/$currentUid',
            publicId: '$timestamp-$originalName',
          );
          downloadUrl = result['url'] as String;
          thumbnailUrl = result['thumbnailUrl'] as String?;
          durationMs = result['durationMs'] as int?;
          publicId = result['publicId'] as String?;
        } else {
          final result = await CloudinaryService.uploadImage(
            file: entry.file,
            folder: 'posts/$currentUid',
            publicId: '$timestamp-$originalName',
          );
          downloadUrl = result['url'] as String;
          publicId = result['publicId'] as String?;
        }
      } else {
        // Dùng Firebase Storage (code cũ)
        final ref = _storage
            .ref()
            .child('posts')
            .child(currentUid)
            .child('$timestamp-$originalName');

        final metadata = SettableMetadata(
          contentType: entry.type == PostMediaType.video
              ? (entry.file.mimeType ?? 'video/mp4')
              : (entry.file.mimeType ?? 'image/jpeg'),
        );

        UploadTask uploadTask;
        if (kIsWeb) {
          final data = await entry.file.readAsBytes();
          uploadTask = ref.putData(data, metadata);
        } else {
          final file = File(entry.file.path);
          if (!await file.exists()) {
            throw StateError('File không tồn tại: ${entry.file.path}');
          }
          uploadTask = ref.putFile(file, metadata);
        }

        // Đợi upload hoàn thành và kiểm tra kết quả với retry
        TaskSnapshot uploadSnapshot;
        try {
          uploadSnapshot = await uploadTask;
        } catch (e) {
          // Retry một lần nếu lỗi
          print('Upload failed, retrying... Error: $e');
          if (kIsWeb) {
            final data = await entry.file.readAsBytes();
            uploadTask = ref.putData(data, metadata);
          } else {
            final file = File(entry.file.path);
            uploadTask = ref.putFile(file, metadata);
          }
          uploadSnapshot = await uploadTask;
        }

        if (uploadSnapshot.state != TaskState.success) {
          throw StateError('Upload thất bại: ${uploadSnapshot.state}');
        }

        // Lấy download URL sau khi upload thành công
        try {
          downloadUrl = await ref.getDownloadURL();
        } catch (e) {
          // Nếu không lấy được URL, thử lại sau 1 giây
          await Future.delayed(const Duration(seconds: 1));
          downloadUrl = await ref.getDownloadURL();
        }

        if (entry.type == PostMediaType.video) {
          if (kIsWeb) {
            // Tạo thumbnail từ video trên web bằng canvas
            try {
              final thumbData = await _generateWebVideoThumbnail(entry.file);
              if (thumbData != null) {
                final thumbRef = _storage
                    .ref()
                    .child('posts')
                    .child(currentUid)
                    .child('thumbnails')
                    .child('$timestamp-$originalName.png');
                final thumbUploadTask = thumbRef.putData(
                  thumbData,
                  SettableMetadata(contentType: 'image/png'),
                );
                final thumbSnapshot = await thumbUploadTask;
                if (thumbSnapshot.state == TaskState.success) {
                  thumbnailUrl = await thumbRef.getDownloadURL();
                }
              }
            } catch (e) {
              print('Web thumbnail generation failed: $e');
            }
          } else {
            try {
              final thumbData = await VideoThumbnail.thumbnailData(
                video: entry.file.path,
                imageFormat: ImageFormat.PNG,
                maxHeight: 480,
                quality: 75,
              );
              if (thumbData != null) {
                final thumbRef = _storage
                    .ref()
                    .child('posts')
                    .child(currentUid)
                    .child('thumbnails')
                    .child('$timestamp-$originalName.png');
                final thumbUploadTask = thumbRef.putData(
                  thumbData,
                  SettableMetadata(contentType: 'image/png'),
                );
                final thumbSnapshot = await thumbUploadTask;
                if (thumbSnapshot.state == TaskState.success) {
                  thumbnailUrl = await thumbRef.getDownloadURL();
                }
              }
            } catch (_) {
              // Ignore thumbnail failures for now
            }

            VideoPlayerController? controller;
            try {
              controller = VideoPlayerController.file(File(entry.file.path));
              await controller.initialize();
              durationMs = controller.value.duration.inMilliseconds;
            } catch (_) {
              durationMs = null;
            } finally {
              await controller?.dispose();
            }
          }
        }
      }

      uploads.add({
        'url': downloadUrl,
        'type': entry.type.name,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (durationMs != null) 'durationMs': durationMs,
        if (publicId != null) 'publicId': publicId,
      });
    }

    await _repository.createPost(
      authorUid: currentUid,
      media: uploads,
      caption: caption,
    );
  }

  Future<void> toggleLike({
    required String postId,
    required bool like,
  }) async {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) {
      throw StateError('Bạn cần đăng nhập.');
    }
    if (like) {
      // Lấy post để lấy authorUid trước khi like (với timeout và error handling)
      Post post;
      try {
        post = await _repository.watchPost(postId).first.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('Không thể lấy thông tin bài đăng. Vui lòng thử lại.');
          },
        );
      } catch (e) {
        // Nếu không lấy được post, vẫn thử like (có thể post đã bị xóa)
        // Nhưng không tạo notification
        await _repository.likePost(postId: postId, uid: currentUid);
        debugPrint('Warning: Could not fetch post info for notification: $e');
        return;
      }
      
      // Like post trước (với retry logic)
      await _repository.likePost(postId: postId, uid: currentUid);
      
      // Tạo notification sau (không block, không throw exception)
      // Chạy async và bỏ qua lỗi để không ảnh hưởng đến like operation
      _notificationService.createLikeNotification(
        postId: postId,
        likerUid: currentUid,
        postAuthorUid: post.authorUid,
      ).catchError((e) {
        // Chỉ log lỗi, không throw để không ảnh hưởng đến like operation
        debugPrint('Error creating like notification: $e');
      });
    } else {
      await _repository.unlikePost(postId: postId, uid: currentUid);
    }
  }

  Stream<List<PostCommentEntry>> watchComments(String postId) {
    return _repository.watchComments(postId).asyncMap((comments) async {
      final futures = comments.map((comment) async {
        final author = await _profiles.fetchProfile(comment.authorUid);
        return PostCommentEntry(comment: comment, author: author);
      }).toList();
      return Future.wait(futures);
    });
  }

  Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) {
      throw StateError('Bạn cần đăng nhập.');
    }
    // Lấy post để lấy authorUid trước khi comment (với timeout và error handling)
    Post post;
    try {
      post = await _repository.watchPost(postId).first.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Không thể lấy thông tin bài đăng. Vui lòng thử lại.');
        },
      );
    } catch (e) {
      // Nếu không lấy được post, vẫn thử comment (có thể post đã bị xóa)
      // Nhưng không tạo notification
      await _repository.addComment(
        postId: postId,
        authorUid: currentUid,
        text: text,
      );
      debugPrint('Warning: Could not fetch post info for notification: $e');
      return;
    }
    
    // Tạo comment và lấy commentId (với retry logic)
    final commentId = await _repository.addComment(
      postId: postId,
      authorUid: currentUid,
      text: text,
    );
    
    // Tạo notification sau (không block, không throw exception)
    // Chạy async và bỏ qua lỗi để không ảnh hưởng đến comment operation
    _notificationService.createCommentNotification(
      postId: postId,
      commentId: commentId,
      commenterUid: currentUid,
      postAuthorUid: post.authorUid,
      commentText: text,
    ).catchError((e) {
      // Chỉ log lỗi, không throw để không ảnh hưởng đến comment operation
      debugPrint('Error creating comment notification: $e');
    });
  }

  Stream<Post> watchPost(String postId) => _repository.watchPost(postId);

  Stream<bool> watchLikeStatus(String postId) {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) {
      return const Stream<bool>.empty();
    }
    return _repository.watchUserLike(postId: postId, uid: currentUid);
  }

  Future<void> deletePost(String postId) async {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) {
      throw StateError('Bạn cần đăng nhập.');
    }
    // Lấy thông tin post để biết danh sách media trước khi xóa
    try {
      final post = await _repository.watchPost(postId).first;
      await _repository.deletePost(
        postId: postId,
        authorUid: currentUid,
      );

      // Nếu dùng Cloudinary, xóa media tương ứng (best effort, không throw)
      if (PostService.storageBackend == 'cloudinary') {
        for (final media in post.media) {
          if (media.publicId == null || media.publicId!.isEmpty) continue;
          final resourceType =
              media.type == PostMediaType.video ? 'video' : 'image';
          CloudinaryService.deleteFile(
            media.publicId!,
            resourceType: resourceType,
          ).catchError((e) {
            debugPrint('Error deleting Cloudinary media: $e');
          });
        }
      }
    } catch (e) {
      // Nếu có lỗi trong quá trình lấy/xóa, throw như cũ
      rethrow;
    }
  }

  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final currentUid = authRepository.currentUser()?.uid;
    if (currentUid == null) {
      throw StateError('Bạn cần đăng nhập.');
    }
    await _repository.deleteComment(
      postId: postId,
      commentId: commentId,
      currentUid: currentUid,
    );
  }

  /// Tạo thumbnail từ video trên web bằng HTML5 video + canvas
  Future<Uint8List?> _generateWebVideoThumbnail(XFile videoFile) async {
    if (!kIsWeb) return null;

    try {
      // Dynamic import để tránh lỗi compile trên non-web
      // Sử dụng JS interop hoặc fallback
      // Note: Cần import 'dart:html' chỉ khi compile cho web
      // Tạm thời return null và để Cloud Functions xử lý
      // Hoặc có thể dùng package universal_html nếu cần
      print('Web thumbnail generation: using fallback (Cloud Functions recommended)');
      return null;
    } catch (e) {
      print('Web thumbnail generation error: $e');
      return null;
    }
  }
}

