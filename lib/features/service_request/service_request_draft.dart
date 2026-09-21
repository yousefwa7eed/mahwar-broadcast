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
    this.orderId,
    this.latitude,
    this.longitude,
    this.carId,
    this.notes = '',
    this.autoCancel = true,
    this.sharePhone = false,
    this.imagePaths = const [],
    required this.savedAt,
  });

  /// مدة صلاحية المسودة: بعدها تُعدّ قديمة وتُمسح عند فتح النموذج.
  static const Duration stalenessWindow = Duration(minutes: 30);

  final String userId;
  final String serviceId;

  /// معرّف الطلب المعلّق الذي كان النموذج يعدّله — للتأكد أن الاستعادة تخصّ
  /// نفس الطلب عند فتح النموذج مرة أخرى بمعرّف محدد.
  final String? orderId;

  final double? latitude;
  final double? longitude;
  final String? carId;
  final String notes;
  final bool autoCancel;
  final bool sharePhone;
  final List<String> imagePaths;
  final DateTime savedAt;

  /// هل بداخلها ما يستحق الحفظ؟ المسودة الفارغة بالكامل تُمسح بدل البقاء.
  bool get hasContent =>
      latitude != null ||
      longitude != null ||
      carId != null ||
      notes.trim().isNotEmpty ||
      sharePhone ||
      imagePaths.isNotEmpty ||
      autoCancel != true;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'serviceId': serviceId,
        'orderId': orderId,
        'latitude': latitude,
        'longitude': longitude,
        'carId': carId,
        'notes': notes,
        'autoCancel': autoCancel,
        'sharePhone': sharePhone,
        'imagePaths': imagePaths,
        'savedAt': savedAt.toIso8601String(),
      };

  factory ServiceRequestDraft.fromJson(Map<String, dynamic> json) {
    final savedAtRaw = json['savedAt'];
    return ServiceRequestDraft(
      userId: json['userId'] as String? ?? '',
      serviceId: json['serviceId'] as String? ?? '',
      orderId: json['orderId'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      carId: json['carId'] as String?,
      notes: json['notes'] as String? ?? '',
      autoCancel: json['autoCancel'] as bool? ?? true,
      sharePhone: json['sharePhone'] as bool? ?? false,
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