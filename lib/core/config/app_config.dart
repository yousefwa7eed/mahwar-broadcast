import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  /// عنوان مشروع Supabase والمفتاح العام (anon). مصدر واحد يُستخدم في
  /// `Supabase.initialize` وفي بناء عميل معزول مؤقت للتحقق من كلمة المرور
  /// الحالية بلا المسّ بالجلسة الرئيسية. يمكن تجاوزهما عبر --dart-define.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://trgesfzojaoirutkkfcs.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRyZ2VzZnpvamFvaXJ1dGtrZmNzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwNTIwMTMsImV4cCI6MjEwMTYyODAxM30.FtFVE8KilYJqU9hATPT1ylrVTjkmVx6UbQMIb_QvcXI',
  );

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