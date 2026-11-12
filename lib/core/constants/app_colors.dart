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

  // Splash (أبيض صريح)
  static const Color splashBackground = Color(0xFFFFFFFF);

  // Light Theme Tokens
  static const Color lightBackground = Color(0xFFF7F8FA);
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

  // Notification Colors (مصدر واحد للألوان الخاصة بالإشعارات)
  static const Color notifSuccess = Color(0xFF28A745); // مؤكد / مكتمل
  static const Color notifDanger = Color(0xFFE53935); // مرفوض / ملغى
  static const Color notifPending = Color(0xFFFF6B00); // جديد / عرض سعر
  static const Color notifRating = Color(0xFFFFC107); // تقييم
  static const Color notifBroadcast = Color(0xFF3F51B5); // إشعار عام
  static const Color notifDefault = Color(0xFFFFC107); // افتراضي

  // ثنائيات تدرّج مطفأة لأيقونات قوائم الإعدادات بنمط iOS: أيقونة بيضاء
  // فوق لون هادئ غير صارخ، والتدرّج خفيف داخل نفس الدرجة.
  static const List<Color> iconBlueTile = [
    Color(0xFF7B9AC7),
    Color(0xFF5C7AA8),
  ];
  static const List<Color> iconGreenTile = [
    Color(0xFF6FAE9B),
    Color(0xFF4F8C7A),
  ];
  static const List<Color> iconVioletTile = [
    Color(0xFF918BBC),
    Color(0xFF6F6A99),
  ];
  static const List<Color> iconAmberTile = [
    Color(0xFFC7A072),
    Color(0xFFA47D50),
  ];
  static const List<Color> iconPurpleTile = [
    Color(0xFFA98BC0),
    Color(0xFF856A9C),
  ];
  static const List<Color> iconRoseTile = [
    Color(0xFFC08892),
    Color(0xFF9D6873),
  ];
  static const List<Color> iconGrayTile = [
    Color(0xFF9BA1A8),
    Color(0xFF7C828A),
  ];
  static const List<Color> iconSlateTile = [
    Color(0xFF7F8E9C),
    Color(0xFF63717E),
  ];
}
