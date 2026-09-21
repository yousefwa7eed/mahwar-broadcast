import 'package:flutter/material.dart';

class AppTypography {
  static const String fontCairo = 'Cairo';
  static const String fontPoppins = 'Poppins';
  static const String fontZain = 'Zain';

  // Arabic Primary Font (Cairo)
  static const TextStyle cairoTitle = TextStyle(
    fontFamily: fontCairo,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle cairoBody = TextStyle(
    fontFamily: fontCairo,
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle cairoSubtitle = TextStyle(
    fontFamily: fontCairo,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  // English Primary Font (Poppins)
  static const TextStyle poppinsTitle = TextStyle(
    fontFamily: fontPoppins,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle poppinsBody = TextStyle(
    fontFamily: fontPoppins,
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  // Display / Accent Font (Zain)
  static const TextStyle zainHeader = TextStyle(
    fontFamily: fontZain,
    fontSize: 32,
    fontWeight: FontWeight.w900,
  );
}
