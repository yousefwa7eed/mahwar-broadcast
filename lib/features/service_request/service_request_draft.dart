import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// نسخة محفوظة محلياً من نموذج طلب الخدمة غير المكتمل — تُستعاد إذا أُعيد فتح
/// النموذج بعد انتهاء العملية أو موت النشاط، وتُمسح عند نجاح الإرسال أو عند
/// الخروج اليدوي من النموذج.
///
/// ملاحظة: الصور لا تُحفظ كبيانات — تُحفظ مساراتها المحلية فقط، وتُتجاهل
/// أي مسار لم يعد يشير لملف قائم وقت الاستعادة (قد يمسح النظام مجلد الكاش).
class ServiceRequestDraft {
  const ServiceRequestDraft({
    required this.userId,
    required this.serviceId,
    this.serviceTypeId,
    this.latitude,
    this.longitude,
    this.vehicleId,
    this.notes = '',
    this.autoCancel = true,
    this.imagePaths = const [],
    required this.savedAt,
  });

  /// مدة صلاحية المسودة: بعدها تُعدّ قديمة وتُمسح عند فتح النموذج.
  static const Duration stalenessWindow = Duration(minutes: 30);

  final String userId;

  /// معرّف الخدمة في واجهة التطبيق (قد يختلف عن معرّف قاعدة البيانات).
  final String serviceId;

  /// معرّف الخدمة الحقيقي في قاعدة البيانات — يُحمل في المسودة لأن الطلب لا
  /// يُنشأ إلا عند اختيار المزوّد، ووقتها لا يكون النموذج في المكدس.
  final String? serviceTypeId;

  final double? latitude;
  final double? longitude;
  /// معرّف السيارة من جدول `vehicles` — يُرسَل للخادم الذي يشتق لقطة
  /// الماركة/الموديل/الفئة/اللون/اللوحة ويتحقق من ملكيتها.
  final String? vehicleId;
  final String notes;
  final bool autoCancel;
  final List<String> imagePaths;
  final DateTime savedAt;

  /// هل بداخلها ما يستحق الحفظ؟ المسودة الفارغة بالكامل تُمسح بدل البقاء.
  bool get hasContent =>
      latitude != null ||
      longitude != null ||
      vehicleId != null ||
      notes.trim().isNotEmpty ||
      imagePaths.isNotEmpty ||
      autoCancel != true;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'serviceId': serviceId,
        'serviceTypeId': serviceTypeId,
        'latitude': latitude,
        'longitude': longitude,
        'vehicleId': vehicleId,
        'notes': notes,
        'autoCancel': autoCancel,
        'imagePaths': imagePaths,
        'savedAt': savedAt.toIso8601String(),
      };

  factory ServiceRequestDraft.fromJson(Map<String, dynamic> json) {
    final savedAtRaw = json['savedAt'];
    return ServiceRequestDraft(
      userId: json['userId'] as String? ?? '',
      serviceId: json['serviceId'] as String? ?? '',
      serviceTypeId: json['serviceTypeId'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      vehicleId: json['vehicleId'] as String?,
      notes: json['notes'] as String? ?? '',
      autoCancel: json['autoCancel'] as bool? ?? true,
      imagePaths: (json['imagePaths'] is List)
          ? (json['imagePaths'] as List).whereType<String>().toList()
          : const [],
      savedAt: savedAtRaw is String ? DateTime.tryParse(savedAtRaw) ?? DateTime.fromMillisecondsSinceEpoch(0) : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// يخزّن المسودة ({@link ServiceRequestDraft}) في SharedPreferences كـ JSON
/// تحت مفتاح واحد — نسخة واحدة لكل جهاز/مستخدم (كل كتابة تحل محل سابقتها).
class ServiceRequestDraftStore {
  static const String _prefsKey = 'service_request_draft';

  Future<ServiceRequestDraft?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return ServiceRequestDraft.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(ServiceRequestDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(draft.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

