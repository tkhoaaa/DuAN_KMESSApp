import 'package:flutter/material.dart';

/// Trang xem ảnh đại diện toàn màn hình, có nền đen và hỗ trợ zoom cơ bản.
class AvatarFullscreenViewer extends StatelessWidget {
  const AvatarFullscreenViewer({
    super.key,
    required this.photoUrl,
  });

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Ảnh đại diện',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: Hero(
            tag: 'profile_avatar_fullscreen',
            child: Image.network(
              photoUrl,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}


