import 'package:flutter/material.dart';

import '../../theme/colors.dart';

class StoryAvatar extends StatefulWidget {
  const StoryAvatar({
    super.key,
    required this.imageUrl,
    this.size = 60,
    this.isUnseen = false,
  });

  final String imageUrl;
  final double size;
  final bool isUnseen;

  @override
  State<StoryAvatar> createState() => _StoryAvatarState();
}

class _StoryAvatarState extends State<StoryAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.97,
      upperBound: 1.03,
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    if (widget.isUnseen) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant StoryAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isUnseen && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isUnseen && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double borderSize = widget.size;
    final double avatarSize = widget.size - 8;

    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: borderSize,
        height: borderSize,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: widget.isUnseen
              ? AppColors.storyPinkGradient as Gradient?
              : const LinearGradient(
                  colors: [AppColors.borderGrey, AppColors.borderGrey],
                ),
        ),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          padding: const EdgeInsets.all(2),
          child: ClipOval(
            child: Image.network(
              widget.imageUrl,
              width: avatarSize,
              height: avatarSize,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.borderGrey,
                child: const Icon(Icons.person, color: AppColors.textLight),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

