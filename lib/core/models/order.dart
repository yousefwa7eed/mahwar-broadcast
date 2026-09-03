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
  final String ownerPhone;
  final double latitude;
  final double longitude;
  final String? addressText;
  final String? notes;
  final List<String>? attachments;
  final List<String>? providerAttachments;
  final String carMake;
  final String carModel;
  final int carYear;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? respondDeadline;

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
    required this.ownerPhone,
    required this.latitude,
    required this.longitude,
    this.addressText,
    this.notes,
    this.attachments,
    this.providerAttachments,
    required this.carMake,
    required this.carModel,
    required this.carYear,
    this.createdAt,
    this.updatedAt,
    this.respondDeadline,
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
      ownerPhone: json['owner_phone'] as String,
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
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      respondDeadline: json['respond_deadline'] != null
          ? DateTime.parse(json['respond_deadline'] as String)
          : null,
    );
  }

  static OrderStatus _parseStatus(String value) {
    switch (value) {
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
      case 'pending':
      default:
        return OrderStatus.pending;
    }
  }

  String get statusLabel {
    switch (status) {
      case OrderStatus.pending:
        return 'قيد الإرسال';
      case OrderStatus.priced:
        return 'تم تقديم عرض';
      case OrderStatus.confirmed:
        return 'مؤكد';
      case OrderStatus.rejectedByProvider:
        return 'مرفوض من المزود';
      case OrderStatus.rejectedByOwner:
        return 'مرفوض من المالك';
      case OrderStatus.cancelled:
        return 'ملغي';
      case OrderStatus.completed:
        return 'مكتمل';
    }
  }

  String get carDisplayName => '$carMake $carModel $carYear';
}