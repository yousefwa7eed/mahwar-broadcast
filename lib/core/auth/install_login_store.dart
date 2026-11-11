import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'phone_utils.dart';

/// أرقام الهواتف التي أثبت صاحبها ملكيتها برمز SMS على **هذه النسخة المثبّتة**
/// من التطبيق.
///
/// التخزين في SharedPreferences وحده: لا Keychain، والنسخ الاحتياطي معطّل في
/// المانيفست (`android:allowBackup="false"`). لذلك حذف التطبيق وإعادة تنزيله
/// يمحو العلامة، بينما تسجيل الخروج يبقيها — وهو الفرق الوحيد بين الحالتين في
/// بوابة `installVerificationRedirect`.
class InstallLoginStore {
  InstallLoginStore._();

  static final InstallLoginStore instance = InstallLoginStore._();

  static const String _key = 'install_verified_phones_v1';

  /// الرقم الذي فُرض عليه رمز تحقق ولم يُكمله بعد. يمنع اعتبار جلسة أُنشئت
  /// بكلمة المرور «استمرارية نسخة» عند إعادة تشغيل التطبيق قبل إدخال الرمز.
  static const String _pendingKey = 'install_pending_phone_v1';

  /// هل أثبت [phone] ملكيته على هذه النسخة؟ فشل قراءة التخزين المحلي يفتح
  /// البوابة (true): خلل في التخزين لا يجوز أن يحبس المستخدم خارج تطبيقه.
  Future<bool> isVerified(String phone) async {
    final normalized = PhoneUtils.normalize(phone);
    if (!PhoneUtils.isValidEgyptianMobile(normalized)) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      return _validPhones(prefs).contains(normalized);
    } catch (e) {
      debugPrint('[InstallLoginStore] read failed: $e');
      return true;
    }
  }

  /// هل فُرض على [phone] رمز تحقق ولم يُكمله بعد؟
  Future<bool> isPending(String phone) async {
    final normalized = PhoneUtils.normalize(phone);
    if (!PhoneUtils.isValidEgyptianMobile(normalized)) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_pendingKey) == normalized;
    } catch (e) {
      debugPrint('[InstallLoginStore] pending read failed: $e');
      return false;
    }
  }

  /// يسجّل أن [phone] تحقّق برمز SMS على هذه النسخة ويمسح علامة الانتظار.
  /// أفضل جهد: فشل الكتابة لا يُفشل التحقق نفسه.
  Future<void> markVerified(String phone) async {
    final normalized = PhoneUtils.normalize(phone);
    if (!PhoneUtils.isValidEgyptianMobile(normalized)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_pendingKey) == normalized) {
        await prefs.remove(_pendingKey);
      }
      final phones = _validPhones(prefs);
      if (!phones.add(normalized)) return;
      await prefs.setStringList(_key, phones.toList()..sort());
    } catch (e) {
      debugPrint('[InstallLoginStore] write failed: $e');
    }
  }

  /// يعلّم أن [phone] في انتظار رمز التحقق (فرضته بوابة النسخة الجديدة).
  Future<void> markPending(String phone) async {
    final normalized = PhoneUtils.normalize(phone);
    if (!PhoneUtils.isValidEgyptianMobile(normalized)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_pendingKey) != normalized) {
        await prefs.setString(_pendingKey, normalized);
      }
    } catch (e) {
      debugPrint('[InstallLoginStore] pending write failed: $e');
    }
  }

  Set<String> _validPhones(SharedPreferences prefs) {
    final stored = prefs.getStringList(_key) ?? const <String>[];
    return <String>{
      for (final raw in stored)
        if (PhoneUtils.isValidEgyptianMobile(PhoneUtils.normalize(raw)))
          PhoneUtils.normalize(raw),
    };
  }
}
