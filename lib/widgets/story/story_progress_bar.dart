import 'package:flutter/material.dart';

import '../../theme/colors.dart';

class StoryProgressBar extends StatefulWidget {
  const StoryProgressBar({
    super.key,
    required this.duration,
    this.onFinished,
  });

  final Duration duration;
  final VoidCallback? onFinished;

  @override
  State<StoryProgressBar> createState() => _StoryProgressBarState();
}

class _StoryProgressBarState extends State<StoryProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished?.call();
      }
    });
  }

  @override
  void didUpdateWidget(covariant StoryProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller
        ..duration = widget.duration
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: AppColors.lightPink.withOpacity(0.35),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _controller.value,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFF48FB1),
                      AppColors.primaryPink,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

