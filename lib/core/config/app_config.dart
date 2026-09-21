import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  /// تجاوز خطوة التحقق من رقم الهاتف (كود OTP) في وضع التطوير فقط.
  ///
  /// - [kDebugMode] يضمن أن التجاوز مستحيل في إصدارات Release: في البناء
  ///   الإنتاجي تُعوَّض قيمة kDebugMode بـ false وتُصبح جملة `&&` كلها false
  ///   بغض النظر عن قيمة OTP_DBG_BYPASS.
  /// - `OTP_DBG_BYPASS` هي flag إضافية تُفعَّل يدويًا في تشغيل التطوير
  ///   (المحاكي / اختبارات الـ integration):
  ///   `flutter run --dart-define=OTP_DBG_BYPASS=true`
  static const bool otpBypass = kDebugMode && bool.fromEnvironment('OTP_DBG_BYPASS');
}