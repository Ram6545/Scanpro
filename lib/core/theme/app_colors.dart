import 'package:flutter/material.dart';

/// Brand color palette and semantic color tokens for ScanPro.
///
/// Primary: Deep Blue (`#0D47A1` / `#1565C0`)
/// Secondary Accent: Teal (`#00897B` / `#26A69A`)
class AppColors {
  AppColors._();

  // Light Mode Palette
  static const Color primaryDeepBlue = Color(0xFF0D47A1);
  static const Color primaryBlueContainer = Color(0xFFD6E4FF);
  static const Color onPrimaryBlueContainer = Color(0xFF001B3D);

  static const Color secondaryTeal = Color(0xFF00897B);
  static const Color secondaryTealContainer = Color(0xFFB2DFDB);
  static const Color onSecondaryTealContainer = Color(0xFF00201C);

  static const Color tertiaryIndigo = Color(0xFF3949AB);
  static const Color lightBackground = Color(0xFFF6F8FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainer = Color(0xFFEEF2F9);

  // Dark Mode Palette
  static const Color darkPrimaryBlue = Color(0xFF82B1FF);
  static const Color darkPrimaryContainer = Color(0xFF003270);
  static const Color onDarkPrimaryContainer = Color(0xFFD6E4FF);

  static const Color darkSecondaryTeal = Color(0xFF4DB6AC);
  static const Color darkSecondaryContainer = Color(0xFF005047);
  static const Color onDarkSecondaryContainer = Color(0xFFB2DFDB);

  static const Color darkBackground = Color(0xFF0B101B);
  static const Color darkSurface = Color(0xFF131B2E);
  static const Color darkSurfaceContainer = Color(0xFF1C263F);

  // Semantic Status Colors
  static const Color successGreen = Color(0xFF2E7D32);
  static const Color warningAmber = Color(0xFFEF6C00);
  static const Color errorRed = Color(0xFFC62828);

  // Folder Accent Colors
  static const List<Color> folderColors = [
    Color(0xFF1565C0), // Blue
    Color(0xFF00897B), // Teal
    Color(0xFF6A1B9A), // Purple
    Color(0xFFEF6C00), // Orange
    Color(0xFF2E7D32), // Green
    Color(0xFFC62828), // Crimson
  ];
}

