import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'phone_utils.dart';

/// آخر حساب سُجّل دخوله على هذا الجهاز: الاسم والرقم والدور فقط — بلا أي سر
/// أو توكن أو جلسة. يبقى بعد تسجيل الخروج ليُلمَّح للمستخدم بالعودة إلى حسابه
/// بعد إعادة تثبيت التطبيق، ويُمسح فقط عند حذف الحساب.
///
/// لا يُستخدم أبدًا للتوجيه أو Authorization — تلميح محلي فقط، والدور الحقيقي
/// يُقرأ دائمًا من `profiles.role` بعد المصادقة.
class LastAccount {
  /// الاسم المعروض كما في `profiles.full_name`.
  final String name;

  /// الرقم المحلي الموحّد (01xxxxxxxxx).
  final String phone;

  /// الدور الفعلي في قاعدة البيانات (car_owner / provider).
  final String role;

  const LastAccount({
    required this.name,
    required this.phone,
    required this.role,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'role': role,
  };

  /// يعيد null لأي قيمة ناقصة/غير صالحة — سجل تالف لا يُظهر تلميحًا خاطئًا.
  static LastAccount? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    final phone = raw['phone'];
    final role = raw['role'];
    if (name is! String || phone is! String || role is! String) return null;
    final trimmedName = name.trim();
    final normalizedPhone = PhoneUtils.normalize(phone);
    if (trimmedName.isEmpty) return null;
    if (!PhoneUtils.isValidEgyptianMobile(normalizedPhone)) return null;
    if (role != 'car_owner' && role != 'provider') return null;
    return LastAccount(
      name: trimmedName,
      phone: normalizedPhone,
      role: role,
    );
  }

  /// رقم مقنّع للعرض: أول 3 أرقام ثم النهاية (010••••5678).
  String get maskedPhone => maskPhone(phone);

  static String maskPhone(String phone) {
    if (phone.length < 7) return phone;
    return '${phone.substring(0, 3)}••••${phone.substring(phone.length - 4)}';
  }
}

class LastAccountStore {
  static const String _key = 'last_account_v1';

  Future<LastAccount?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      return LastAccount.fromJson(jsonDecode(raw));
    } catch (_) {
      // فشل التخزين المحلي لا يعطّل شاشة الدخول — يُعامَل كغياب تلميح.
      return null;
    }
  }

  Future<void> write(LastAccount account) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(account.toJson()));
    } catch (_) {
      // أفضل جهد — التلميح ميزة ثانوية لا تُفشل الجلسة.
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
