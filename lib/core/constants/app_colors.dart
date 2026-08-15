import 'package:flutter/material.dart';

class AppColors {
  // Brand Accent (Orange)
  static const Color orangePrimary = Color(0xFFFF6B00);
  static const Color orangeLight = Color(0xFFFF8533);
  static const Color orangeDark = Color(0xFFCC5500);

  // Gradient definitions
  static const LinearGradient orangeGradient = LinearGradient(
    colors: [Color(0xFFFF8533), Color(0xFFFF6B00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF2C2C2C), Color(0xFF181818)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Light Theme Tokens
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF8F9FA);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF1E1E1E);
  static const Color lightTextSecondary = Color(0xFF6C757D);
  static const Color lightBorder = Color(0xFFE9ECEF);

  // Dark Theme Tokens
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF242424);
  static const Color darkTextPrimary = Color(0xFFF8F9FA);
  static const Color darkTextSecondary = Color(0xFFA0A0A0);
  static const Color darkBorder = Color(0xFF333333);

  // Status & Utility Colors
  static const Color success = Color(0xFF28A745);
  static const Color error = Color(0xFFDC3545);
  static const Color warning = Color(0xFFFFC107);
}
