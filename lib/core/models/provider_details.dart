class ProviderDetails {
  final String providerId;
  final String fullName;
  final String phoneNumber;
  final String workshopName;
  final String address;
  final double latitude;
  final double longitude;
  final String supportScope;
  final bool hasVehicle;
  final String? vehicleType;
  final String? vehicleSpecs;
  final bool isOnline;
  final double avgRating;
  final int ratingCount;
  final List<String> services;
  final double? distanceMeters;
  final String? avatarId;
  final String? avatarUrl;

  const ProviderDetails({
    required this.providerId,
    required this.fullName,
    required this.phoneNumber,
    required this.workshopName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.supportScope,
    required this.hasVehicle,
    this.vehicleType,
    this.vehicleSpecs,
    required this.isOnline,
    required this.avgRating,
    required this.ratingCount,
    required this.services,
    this.distanceMeters,
    this.avatarId,
    this.avatarUrl,
  });

  factory ProviderDetails.fromJson(Map<String, dynamic> json) {
    return ProviderDetails(
      providerId: json['provider_id'] as String,
      fullName: json['full_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      workshopName: json['workshop_name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      supportScope: json['support_scope'] as String? ?? 'both',
      hasVehicle: json['has_vehicle'] as bool? ?? false,
      vehicleType: json['vehicle_type'] as String?,
      vehicleSpecs: json['vehicle_specs'] as String?,
      isOnline: json['is_online'] as bool? ?? true,
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      services: json['services'] != null
          ? List<String>.from(json['services'] as List)
          : const [],
      distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
      avatarId: json['avatar_id'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  String get ratingLabel {
    if (ratingCount <= 0) return 'لا توجد تقييمات بعد';
    final avg = avgRating.toStringAsFixed(1);
    return '$avgم ($ratingCount تقييم)';
  }

  String get supportScopeLabel {
    switch (supportScope) {
      case 'emergency':
        return 'طوارئ الطريق';
      case 'on_site':
        return 'في الورشة';
      case 'both':
      default:
        return 'بداخل الورشة وعلى الطريق';
    }
  }
}