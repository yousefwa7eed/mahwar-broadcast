import 'package:shared_preferences/shared_preferences.dart';

/// يتذكّر الطلبات التي عُرض فيها اقتراح تنبيه المزوّد (قرار المنتج: مرة
/// واحدة لكل طلب). محلي على الجهاز — لا نكتب شيئًا على الخادم لمجرد العرض؛
/// الرقم الوحيد المحفوظ على الخادم هو الرسالة نفسها.
class ProviderAlertPromptStore {
  static const _key = 'provider_alert_prompt_shown_v1';
  static const _maxEntries = 100;

  static final ProviderAlertPromptStore instance =
      ProviderAlertPromptStore._();

  ProviderAlertPromptStore._();

  Future<bool> wasShown(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key)?.contains(orderId) ?? false;
  }

  Future<void> markShown(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getStringList(_key) ?? <String>[];
    if (shown.contains(orderId)) return;
    shown.add(orderId);
    if (shown.length > _maxEntries) {
      shown.removeRange(0, shown.length - _maxEntries);
    }
    await prefs.setStringList(_key, shown);
  }
}
