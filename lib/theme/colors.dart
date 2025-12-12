import 'package:flutter/material.dart';

/// Central place for the app color system (pink–white theme).
class AppColors {
  AppColors._();

  static const Color primaryPink = Color(0xFFF06292);
  static const Color lightPink = Color(0xFFF8BBD0);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF2D2D2D);
  static const Color textLight = Color(0xFF8E8E93);
  static const Color borderGrey = Color(0xFFE0E0E0);

  static const Gradient storyPinkGradient = LinearGradient(
    colors: [
      Color(0xFFF48FB1),
      Color(0xFFF06292),
      Color(0xFFE91E63),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

