import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class PostVideoPage extends StatefulWidget {
  const PostVideoPage({super.key, required this.videoUrl});

  final String videoUrl;

  @override
  State<PostVideoPage> createState() => _PostVideoPageState();
}

class _PostVideoPageState extends State<PostVideoPage> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  bool _isDisposed = false;
  bool _isBuffering = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
    )..setLooping(true);

    _controller.addListener(_handleControllerUpdate);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      if (!mounted || _isDisposed) return;
      setState(() {
        _initialized = true;
        _isBuffering = _controller.value.isBuffering;
      });
      _controller.play();
    } catch (_) {
      if (!mounted || _isDisposed) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải video')),
        );
      }
    }
  }

  void _handleControllerUpdate() {
    if (!mounted || _isDisposed) return;
    final buffering = _controller.value.isBuffering;
    if (buffering != _isBuffering) {
      setState(() {
        _isBuffering = buffering;
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.removeListener(_handleControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Video'),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: _initialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    if (_isBuffering)
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                        padding: const EdgeInsets.only(top: 8),
                        colors: VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white54,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (!_controller.value.isInitialized) return;
          if (_controller.value.isPlaying) {
            _controller.pause();
          } else {
            if (_controller.value.position >= _controller.value.duration) {
              _controller.seekTo(Duration.zero);
            }
            _controller.play();
          }
          setState(() {});
        },
        child: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),
    );
  }
}

