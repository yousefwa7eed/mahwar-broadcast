import '../../l10n/app_localizations.dart';

enum SupportScope { emergency, onSite, both }

class ProviderModel {
  final String id;
  final String workshopName;
  final String address;
  final double latitude;
  final double longitude;
  final SupportScope supportScope;
  final bool hasVehicle;
  final String? vehicleType;
  final String? vehicleSpecs;
  final bool isOnline;
  final DateTime? createdAt;

  const ProviderModel({
    required this.id,
    required this.workshopName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.supportScope,
    this.hasVehicle = false,
    this.vehicleType,
    this.vehicleSpecs,
    this.isOnline = true,
    this.createdAt,
  });

  factory ProviderModel.fromJson(Map<String, dynamic> json) {
    return ProviderModel(
      id: json['id'] as String,
      workshopName: json['workshop_name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      supportScope: _parseSupportScope(json['support_scope'] as String),
      hasVehicle: json['has_vehicle'] as bool? ?? false,
      vehicleType: json['vehicle_type'] as String?,
      vehicleSpecs: json['vehicle_specs'] as String?,
      isOnline: json['is_online'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  static SupportScope _parseSupportScope(String value) {
    switch (value) {
      case 'emergency':
        return SupportScope.emergency;
      case 'on_site':
        return SupportScope.onSite;
      case 'both':
      default:
        return SupportScope.both;
    }
  }

  String supportScopeLabel(AppLocalizations? l10n) {
    switch (supportScope) {
      case SupportScope.emergency:
        return l10n?.supportScopeEmergency ?? 'طوارئ الطريق';
      case SupportScope.onSite:
        return l10n?.supportScopeOnSite ?? 'في الورشة';
      case SupportScope.both:
        return l10n?.supportScopeBoth ?? 'كلاهما';
    }
  }
}
