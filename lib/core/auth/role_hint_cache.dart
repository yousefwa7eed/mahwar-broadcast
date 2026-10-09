import 'package:shared_preferences/shared_preferences.dart';

import 'role_gate.dart';

/// تخزين مؤقت محلي لآخر دور معروف للمستخدم.
/// يُستخدم فقط لاختيار الهيكل (skeleton) عند الإقلاع — ولا يُستخدم أبدًا
/// للتوجيه أو Authorization.
class RoleHintCache {
  static const String _key = 'auth_role_hint';

  Future<AppRole?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return AppRole.tryParse(raw);
  }

  Future<void> write(AppRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, role.dbValue);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}