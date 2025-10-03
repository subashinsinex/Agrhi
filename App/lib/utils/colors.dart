import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primaryGreen = Color(0xFF0B6623);
  static const Color primaryWhite = Colors.white;
  static const Color primaryBlack = Colors.black;

  // Background Colors
  static const Color backgroundColor = Colors.white;
  static const Color cardBackgroundLight = Color(0xFFF5F5F5);
  static const Color cardBackgroundGrey = Color(0xFFE0E0E0);

  // Text Colors
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Color(0xFF757575);
  static const Color textWhite = Colors.white;
  static const Color textOnPrimary = Colors.white;

  // Shadow and Elevation
  static const Color shadowColor = Color(0x4D000000);
  static const Color transparentShadow = Colors.transparent;

  // Weather Card Colors
  static const Color weatherIconBackground = primaryGreen;
  static const Color temperatureText = Colors.black87;
  static const Color locationText = Color(0xFF757575);

  // Status Colors
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFE53935);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color infoColor = Color(0xFF2196F3);

  // Opacity Variants
  static Color primaryGreenWithOpacity(double opacity) =>
      // ignore: deprecated_member_use
      primaryGreen.withOpacity(opacity);
  static Color blackWithOpacity(double opacity) =>
      // ignore: deprecated_member_use
      Colors.black.withOpacity(opacity);
  static Color whiteWithOpacity(double opacity) =>
      // ignore: deprecated_member_use
      Colors.white.withOpacity(opacity);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryGreen, Color(0xFF0D7A2A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Theme-specific colors
  static const Color appBarBackground = primaryGreen;
  static const Color drawerHeaderBackground = primaryGreen;
  static const Color cardPrimary = primaryGreen;
  static const Color buttonPrimary = primaryGreen;
  static const Color iconPrimary = primaryGreen;
}

// Extension for easy color access
extension AppColorsExtension on BuildContext {
  AppColors get colors => AppColors();
}
