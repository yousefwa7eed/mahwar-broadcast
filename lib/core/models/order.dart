import '../utils/supabase_time.dart';
import '../../l10n/app_localizations.dart';

enum OrderStatus {
  pending,
  priced,
  confirmed,
  rejectedByProvider,
  rejectedByOwner,
  cancelled,
  completed,
}

class Order {
  final String id;
  final String carOwnerId;
  final String? providerId;
  final String serviceTypeId;
  final OrderStatus status;
  final double? offeredPrice;
  final String? providerNotes;
  final int? etaMinutes;
  final String currency;
  final double latitude;
  final double longitude;
  final String? addressText;
  final String? notes;
  final List<String>? attachments;
  final List<String>? providerAttachments;
  final String carMake;
  final String carModel;
  final int carYear;

  /// لقطة بيانات السيارة من الكتالوج وقت الإنشاء (تبقى صحيحة حتى لو تغيّر
  /// الكتالوج لاحقاً). الطلبات القديمة قد تحتوي null في كل هذه الحقول.
  final String? vehicleId;
  final String? carBrandId;
  final String? carTrimId;
  final String? carTrim;
  final String? carColorId;
  final String? carColor;
  final String? carPlate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? respondDeadline;

  /// قرار العميل: إلغاء الطلب تلقائياً بعد 5 دقائق من الإنشاء (افتراضياً true).
  final bool autoCancel;

  const Order({
    required this.id,
    required this.carOwnerId,
    this.providerId,
    required this.serviceTypeId,
    required this.status,
    this.offeredPrice,
    this.providerNotes,
    this.etaMinutes,
    this.currency = 'EGP',
    required this.latitude,
    required this.longitude,
    this.addressText,
    this.notes,
    this.attachments,
    this.providerAttachments,
    required this.carMake,
    required this.carModel,
    required this.carYear,
    this.vehicleId,
    this.carBrandId,
    this.carTrimId,
    this.carTrim,
    this.carColorId,
    this.carColor,
    this.carPlate,
    this.createdAt,
    this.updatedAt,
    this.respondDeadline,
    this.autoCancel = true,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      carOwnerId: json['car_owner_id'] as String,
      providerId: json['provider_id'] as String?,
      serviceTypeId: json['service_type_id'] as String,
      status: _parseStatus(json['status'] as String),
      offeredPrice: json['offered_price'] != null ? (json['offered_price'] as num).toDouble() : null,
      providerNotes: json['provider_notes'] as String?,
      etaMinutes: json['eta_minutes'] as int?,
      currency: json['currency'] as String? ?? 'EGP',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      addressText: json['address_text'] as String?,
      notes: json['notes'] as String?,
      attachments: json['attachments'] != null ? List<String>.from(json['attachments'] as List) : null,
      providerAttachments: json['provider_attachments'] != null
          ? List<String>.from(json['provider_attachments'] as List)
          : null,
      carMake: json['car_make'] as String,
      carModel: json['car_model'] as String,
      carYear: json['car_year'] as int,
      vehicleId: json['vehicle_id'] as String?,
      carBrandId: json['car_brand_id'] as String?,
      carTrimId: json['car_trim_id'] as String?,
      carTrim: json['car_trim'] as String?,
      carColorId: json['car_color_id'] as String?,
      carColor: json['car_color'] as String?,
      carPlate: json['car_plate'] as String?,
      createdAt: parseSupabaseTimestamp(json['created_at']),
      updatedAt: parseSupabaseTimestamp(json['updated_at']),
      respondDeadline: parseSupabaseTimestamp(json['respond_deadline']),
      autoCancel: json['auto_cancel'] as bool? ?? true,
    );
  }

  /// يحوّل نص الحالة القادم من قاعدة البيانات/Realtime، أو null لقيمة غير
  /// معروفة — يمنع تفسير حالة مستقبلية كـ pending بصمت.
  static OrderStatus? tryParseStatus(String value) {
    switch (value) {
      case 'pending':
        return OrderStatus.pending;
      case 'priced':
        return OrderStatus.priced;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'rejected_by_provider':
        return OrderStatus.rejectedByProvider;
      case 'rejected_by_owner':
        return OrderStatus.rejectedByOwner;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'completed':
        return OrderStatus.completed;
      default:
        return null;
    }
  }

  static OrderStatus _parseStatus(String value) =>
      tryParseStatus(value) ?? OrderStatus.pending;

  String statusLabel(AppLocalizations? l10n) {
    switch (status) {
      case OrderStatus.pending:
        return l10n?.orderStatusPending ?? 'قيد الإرسال';
      case OrderStatus.priced:
        return l10n?.orderStatusPriced ?? 'تم تقديم عرض';
      case OrderStatus.confirmed:
        return l10n?.orderStatusConfirmed ?? 'مؤكد';
      case OrderStatus.rejectedByProvider:
        return l10n?.orderStatusRejectedProvider ?? 'مرفوض من المزود';
      case OrderStatus.rejectedByOwner:
        return l10n?.orderStatusRejectedOwner ?? 'مرفوض من المالك';
      case OrderStatus.cancelled:
        return l10n?.orderStatusCancelled ?? 'ملغي';
      case OrderStatus.completed:
        return l10n?.orderStatusCompleted ?? 'مكتمل';
    }
  }

  String get carDisplayName => '$carMake $carModel $carYear';

  /// تفاصيل إضافية للعرض (الفئة/اللون/اللوحة) — تُرشَّح من الفراغات.
  String get carDetails {
    return [
      if (carTrim != null && carTrim!.trim().isNotEmpty) carTrim!,
      if (carColor != null && carColor!.trim().isNotEmpty) carColor!,
      if (carPlate != null && carPlate!.trim().isNotEmpty) carPlate!,
    ].join(' · ');
  }

  /// الطلب وصل لحالة نهائية: إتمام ناجح أو فشل (رفض/إلغاء).
  bool get isFinalized =>
      status == OrderStatus.completed ||
      status == OrderStatus.rejectedByProvider ||
      status == OrderStatus.rejectedByOwner ||
      status == OrderStatus.cancelled;

  /// الطلب أُرسل فعلياً لمزوّد محدد (provider_id مسجّل) — وليس بعد مسودة
  /// معلّقة قبل اختيار المزوّد في شاشة «اختيار المزوّد».
  bool get isSentToProvider => providerId != null && providerId!.isNotEmpty;

  /// بطاقة الطلب النشط في رئيسية المالك تظهر فقط عندما يكون الطلب قد أُرسل
  /// فعلاً لمزوّد (provider_id مسجّل) ولم يصل بعد لحالة نهائية
  /// (pending / priced / confirmed). الطلب المعلّق قبل اختيار المزوّد
  /// (provider_id = null) لا يظهر لأنه لم يُرسل لأحد بعد.
  bool get showsActiveOrderCard =>
      isSentToProvider &&
      (status == OrderStatus.pending ||
          status == OrderStatus.priced ||
          status == OrderStatus.confirmed);
}