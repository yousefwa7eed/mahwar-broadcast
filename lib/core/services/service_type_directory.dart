import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/service_type.dart';

/// ذاكرة مؤقتة على مستوى التطبيق لجدول service_types (id → name_ar/name_en).
///
/// تُحمَّل مرة واحدة وتُعاد استخدامها لعرض اسم الخدمة بلغة العارض داخل
/// الإشعارات (عبر NotificationModel.serviceTypeNameResolver). أي فشل في
/// التحميل يُتجاهل بصمت، فنرجع عندها إلى الاسم المحفوظ في metadata الإشعار.
class ServiceTypeDirectory {
  ServiceTypeDirectory._();

  static final ServiceTypeDirectory instance = ServiceTypeDirectory._();

  Map<String, ServiceType> _byId = const {};
  bool _loadStarted = false;

  /// تحميل مرة واحدة (idempotent)؛ لا يرمي استثناءً أبدًا.
  Future<void> ensureLoaded() async {
    if (_loadStarted || _byId.isNotEmpty) return;
    _loadStarted = true;
    try {
      final rows = await Supabase.instance.client
          .from('service_types')
          .select('id, name_ar, name_en, icon_name, description_ar, description_en');
      _byId = {
        for (final row in rows)
          row['id'] as String:
              ServiceType.fromJson(Map<String, dynamic>.from(row as Map)),
      };
    } catch (_) {
      // اسمح بمحاولة أخرى لاحقًا (مثلاً بعد استعادة الاتصال).
      _loadStarted = false;
    }
  }

  /// اسم الخدمة بلغة العارض، أو null إن لم تُعرف بعد (فنرجع لاسم metadata).
  String? nameFor(String id, bool isArabic) => _byId[id]?.name(isArabic);
}
