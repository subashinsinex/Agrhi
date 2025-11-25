import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primaryGreen = Color(0xFF0B6623); // Dark forest green
  static const Color secondaryGreen = Color(0xFF1B8A3A); // Medium green
  static const Color tertiaryGreen = Color(
    0xFF77D889,
  ); // Light/background green

  static const Color primaryWhite = Colors.white;
  static const Color primaryBlack = Colors.black;

  // Background Colors
  static const Color backgroundColor = Color(0xFF77D889); // Light green
  static const Color cardBackgroundLight = Color(0xFFF5F5F5);
  static const Color cardBackgroundGrey = Color(0xFFE0E0E0);

  // Green variations for UI elements
  static const Color lightGreenAccent = Color(0xFFE8F5E9); // Very light green
  static const Color mediumGreenAccent = Color(0xFFA5D6A7); // Soft green
  static const Color darkGreenAccent = Color(0xFF0D7A2A); // Deep green

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
      primaryGreen.withOpacity(opacity);
  static Color blackWithOpacity(double opacity) =>
      Colors.black.withOpacity(opacity);
  static Color whiteWithOpacity(double opacity) =>
      Colors.white.withOpacity(opacity);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryGreen, secondaryGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightGradient = LinearGradient(
    colors: [mediumGreenAccent, tertiaryGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Theme-specific colors
  static const Color appBarBackground = primaryGreen;
  static const Color drawerHeaderBackground = primaryGreen;
  static const Color cardPrimary = primaryGreen;
  static const Color buttonPrimary = primaryGreen;
  static const Color iconPrimary = primaryGreen;

  static const Color accentBlue = Color(0xFF2196F3);
}

// Extension for easy color access
extension AppColorsExtension on BuildContext {
  AppColors get colors => AppColors();
}
