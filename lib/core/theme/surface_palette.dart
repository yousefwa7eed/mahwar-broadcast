import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// لوحة أسطح مشتركة (شاشة اختيار النوع وشاشة الدخول)، مع [lerp] لتدرّج
/// سلس بين الوضعين
/// ([themeT] = 0 فاتح، 1 داكن) بدل تبديل فوري للألوان.
class SurfacePalette {
  const SurfacePalette({
    required this.themeT,
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardTop,
    required this.cardMid,
    required this.cardBottom,
    required this.cardBorder,
    required this.cardShadow,
    required this.highlightText,
    required this.highlightBackground,
    required this.highlightBorder,
    required this.footerText,
  });

  final double themeT;
  final Color background;
  final Color textPrimary;
  final Color textSecondary;
  final Color cardTop;
  final Color cardMid;
  final Color cardBottom;
  final Color cardBorder;
  final Color cardShadow;
  final Color highlightText;
  final Color highlightBackground;
  final Color highlightBorder;
  final Color footerText;

  static const Color _cardTopLight = Color(0xFFFFFFFF);
  static const Color _cardTopDark = Color(0xFF242424);
  static const Color _cardMidLight = Color(0xFFFBFBFC);
  static const Color _cardMidDark = Color(0xFF1E1E1E);
  static const Color _cardBottomLight = Color(0xFFF3F4F6);
  static const Color _cardBottomDark = Color(0xFF171717);
  static const Color _highlightTextLight = Color(0xFF1E1E1E);

  factory SurfacePalette.lerp(double t) {
    final themeT = t.clamp(0.0, 1.0);
    return SurfacePalette(
      themeT: themeT,
      background: Color.lerp(
        AppColors.lightBackground,
        AppColors.darkBackground,
        themeT,
      )!,
      textPrimary: Color.lerp(
        AppColors.lightTextPrimary,
        AppColors.darkTextPrimary,
        themeT,
      )!,
      textSecondary: Color.lerp(
        AppColors.lightTextSecondary,
        AppColors.darkTextSecondary,
        themeT,
      )!,
      cardTop: Color.lerp(_cardTopLight, _cardTopDark, themeT)!,
      cardMid: Color.lerp(_cardMidLight, _cardMidDark, themeT)!,
      cardBottom: Color.lerp(_cardBottomLight, _cardBottomDark, themeT)!,
      cardBorder: Color.lerp(
        Colors.black.withValues(alpha: 0.04),
        Colors.white.withValues(alpha: 0.06),
        themeT,
      )!,
      cardShadow: Color.lerp(
        const Color(0xFF1E1E1E).withValues(alpha: 0.06),
        Colors.black.withValues(alpha: 0.45),
        themeT,
      )!,
      highlightText: Color.lerp(
        _highlightTextLight,
        Colors.white.withValues(alpha: 0.9),
        themeT,
      )!,
      highlightBackground: Color.lerp(
        Colors.black.withValues(alpha: 0.04),
        Colors.white.withValues(alpha: 0.07),
        themeT,
      )!,
      highlightBorder: Color.lerp(
        Colors.black.withValues(alpha: 0.06),
        Colors.white.withValues(alpha: 0.12),
        themeT,
      )!,
      footerText: Color.lerp(
        Colors.black.withValues(alpha: 0.55),
        Colors.white.withValues(alpha: 0.6),
        themeT,
      )!,
    );
  }
}
