import '../utils/supabase_time.dart';



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

  final double? price;

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

  final DateTime? createdAt;

  final DateTime? updatedAt;

  final DateTime? respondDeadline;



  /// ┘é╪▒╪º╪▒ ╪º┘ä╪╣┘à┘è┘ä: ╪Ñ┘ä╪║╪º╪í ╪º┘ä╪╖┘ä╪¿ ╪¬┘ä┘é╪º╪ª┘è╪º┘ï ╪¿╪╣╪» 5 ╪»┘é╪º╪ª┘é ┘à┘å ╪º┘ä╪Ñ┘å╪┤╪º╪í (╪º┘ü╪¬╪▒╪º╪╢┘è╪º┘ï true).

  final bool autoCancel;



  /// ┘é╪▒╪º╪▒ ╪º┘ä╪╣┘à┘è┘ä: ┘à╪┤╪º╪▒┘â╪⌐ ╪▒┘é┘à ┘ç╪º╪¬┘ü┘ç ┘à╪╣ ╪º┘ä┘à╪▓┘ê┘æ╪» ╪º┘ä┘à╪▒╪│┘ä ╪Ñ┘ä┘è┘ç ╪º┘ä╪╖┘ä╪¿ (╪º┘ü╪¬╪▒╪º╪╢┘è╪º┘ï false).




  const Order({

    required this.id,

    required this.carOwnerId,

    this.providerId,

    required this.serviceTypeId,

    required this.status,

    this.price,

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

      price: json['offered_price'] != null ? (json['offered_price'] as num).toDouble() : null,

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

      createdAt: parseSupabaseTimestamp(json['created_at']),

      updatedAt: parseSupabaseTimestamp(json['updated_at']),

      respondDeadline: parseSupabaseTimestamp(json['respond_deadline']),

      autoCancel: json['auto_cancel'] as bool? ?? true,


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

        return '┘é┘è╪» ╪º┘ä╪Ñ╪▒╪│╪º┘ä';

      case OrderStatus.priced:

        return '╪¬┘à ╪¬┘é╪»┘è┘à ╪╣╪▒╪╢';

      case OrderStatus.confirmed:

        return '┘à╪ñ┘â╪»';

      case OrderStatus.rejectedByProvider:

        return '┘à╪▒┘ü┘ê╪╢ ┘à┘å ╪º┘ä┘à╪▓┘ê╪»';

      case OrderStatus.rejectedByOwner:

        return '┘à╪▒┘ü┘ê╪╢ ┘à┘å ╪º┘ä┘à╪º┘ä┘â';

      case OrderStatus.cancelled:

        return '┘à┘ä╪║┘è';

      case OrderStatus.completed:

        return '┘à┘â╪¬┘à┘ä';

    }

  }



  String get carDisplayName => '$carMake $carModel $carYear';



  /// ╪º┘ä╪╖┘ä╪¿ ┘ê╪╡┘ä ┘ä╪¡╪º┘ä╪⌐ ┘å┘ç╪º╪ª┘è╪⌐: ╪Ñ╪¬┘à╪º┘à ┘å╪º╪¼╪¡ ╪ú┘ê ┘ü╪┤┘ä (╪▒┘ü╪╢/╪Ñ┘ä╪║╪º╪í).

  bool get isFinalized =>

      status == OrderStatus.completed ||

      status == OrderStatus.rejectedByProvider ||

      status == OrderStatus.rejectedByOwner ||

      status == OrderStatus.cancelled;



  /// ╪º┘ä╪╖┘ä╪¿ ╪ú┘Å╪▒╪│┘ä ┘ü╪╣┘ä┘è╪º┘ï ┘ä┘à╪▓┘ê┘æ╪» ┘à╪¡╪»╪» (provider_id ┘à╪│╪¼┘æ┘ä) ΓÇö ┘ê┘ä┘è╪│ ╪¿╪╣╪» ┘à╪│┘ê╪»╪⌐

  /// ┘à╪╣┘ä┘æ┘é╪⌐ ┘é╪¿┘ä ╪º╪«╪¬┘è╪º╪▒ ╪º┘ä┘à╪▓┘ê┘æ╪» ┘ü┘è ╪┤╪º╪┤╪⌐ ┬½╪º╪«╪¬┘è╪º╪▒ ╪º┘ä┘à╪▓┘ê┘æ╪»┬╗.

  bool get isSentToProvider => providerId != null && providerId!.isNotEmpty;



  /// ╪¿╪╖╪º┘é╪⌐ ╪º┘ä╪╖┘ä╪¿ ╪º┘ä┘å╪┤╪╖ ┘ü┘è ╪▒╪ª┘è╪│┘è╪⌐ ╪º┘ä┘à╪º┘ä┘â ╪¬╪╕┘ç╪▒ ┘ü┘é╪╖ ╪╣┘å╪»┘à╪º ┘è┘â┘ê┘å ╪º┘ä╪╖┘ä╪¿ ┘é╪» ╪ú┘Å╪▒╪│┘ä

  /// ┘ü╪╣┘ä╪º┘ï ┘ä┘à╪▓┘ê┘æ╪» (provider_id ┘à╪│╪¼┘æ┘ä) ┘ê┘ä┘à ┘è╪╡┘ä ╪¿╪╣╪» ┘ä╪¡╪º┘ä╪⌐ ┘å┘ç╪º╪ª┘è╪⌐

  /// (pending / priced / confirmed). ╪º┘ä╪╖┘ä╪¿ ╪º┘ä┘à╪╣┘ä┘æ┘é ┘é╪¿┘ä ╪º╪«╪¬┘è╪º╪▒ ╪º┘ä┘à╪▓┘ê┘æ╪»

  /// (provider_id = null) ┘ä╪º ┘è╪╕┘ç╪▒ ┘ä╪ú┘å┘ç ┘ä┘à ┘è┘Å╪▒╪│┘ä ┘ä╪ú╪¡╪» ╪¿╪╣╪».

  bool get showsActiveOrderCard =>

      isSentToProvider &&

      (status == OrderStatus.pending ||

          status == OrderStatus.priced ||

          status == OrderStatus.confirmed);

}

