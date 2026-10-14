import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Ù†Ø³Ø®Ø© Ù…Ø­ÙÙˆØ¸Ø© Ù…Ø­Ù„ÙŠØ§Ù‹ Ù…Ù† Ù†Ù…ÙˆØ°Ø¬ Ø·Ù„Ø¨ Ø§Ù„Ø®Ø¯Ù…Ø© ØºÙŠØ± Ø§Ù„Ù…ÙƒØªÙ…Ù„ â€” ØªÙØ³ØªØ¹Ø§Ø¯ Ø¥Ø°Ø§ Ø£ÙØ¹ÙŠØ¯ ÙØªØ­
/// Ø§Ù„Ù†Ù…ÙˆØ°Ø¬ Ø¨Ø¹Ø¯ Ø§Ù†ØªÙ‡Ø§Ø¡ Ø§Ù„Ø¹Ù…Ù„ÙŠØ© Ø£Ùˆ Ù…ÙˆØª Ø§Ù„Ù†Ø´Ø§Ø·ØŒ ÙˆØªÙÙ…Ø³Ø­ Ø¹Ù†Ø¯ Ù†Ø¬Ø§Ø­ Ø§Ù„Ø¥Ø±Ø³Ø§Ù„ Ø£Ùˆ Ø¹Ù†Ø¯
/// Ø§Ù„Ø®Ø±ÙˆØ¬ Ø§Ù„ÙŠØ¯ÙˆÙŠ Ù…Ù† Ø§Ù„Ù†Ù…ÙˆØ°Ø¬.
///
/// Ù…Ù„Ø§Ø­Ø¸Ø©: Ø§Ù„ØµÙˆØ± Ù„Ø§ ØªÙØ­ÙØ¸ ÙƒØ¨ÙŠØ§Ù†Ø§Øª â€” ØªÙØ­ÙØ¸ Ù…Ø³Ø§Ø±Ø§ØªÙ‡Ø§ Ø§Ù„Ù…Ø­Ù„ÙŠØ© ÙÙ‚Ø·ØŒ ÙˆØªÙØªØ¬Ø§Ù‡Ù„
/// Ø£ÙŠ Ù…Ø³Ø§Ø± Ù„Ù… ÙŠØ¹Ø¯ ÙŠØ´ÙŠØ± Ù„Ù…Ù„Ù Ù‚Ø§Ø¦Ù… ÙˆÙ‚Øª Ø§Ù„Ø§Ø³ØªØ¹Ø§Ø¯Ø© (Ù‚Ø¯ ÙŠÙ…Ø³Ø­ Ø§Ù„Ù†Ø¸Ø§Ù… Ù…Ø¬Ù„Ø¯ Ø§Ù„ÙƒØ§Ø´).
class ServiceRequestDraft {
  const ServiceRequestDraft({
    required this.userId,
    required this.serviceId,
    this.serviceTypeId,
    this.latitude,
    this.longitude,
    this.carId,
    this.carMake,
    this.carModel,
    this.carYear,
    this.notes = '',
    this.autoCancel = true,
    this.imagePaths = const [],
    required this.savedAt,
  });

  /// Ù…Ø¯Ø© ØµÙ„Ø§Ø­ÙŠØ© Ø§Ù„Ù…Ø³ÙˆØ¯Ø©: Ø¨Ø¹Ø¯Ù‡Ø§ ØªÙØ¹Ø¯Ù‘ Ù‚Ø¯ÙŠÙ…Ø© ÙˆØªÙÙ…Ø³Ø­ Ø¹Ù†Ø¯ ÙØªØ­ Ø§Ù„Ù†Ù…ÙˆØ°Ø¬.
  static const Duration stalenessWindow = Duration(minutes: 30);

  final String userId;

  /// Ù…Ø¹Ø±Ù‘Ù Ø§Ù„Ø®Ø¯Ù…Ø© ÙÙŠ ÙˆØ§Ø¬Ù‡Ø© Ø§Ù„ØªØ·Ø¨ÙŠÙ‚ (Ù‚Ø¯ ÙŠØ®ØªÙ„Ù Ø¹Ù† Ù…Ø¹Ø±Ù‘Ù Ù‚Ø§Ø¹Ø¯Ø© Ø§Ù„Ø¨ÙŠØ§Ù†Ø§Øª).
  final String serviceId;

  /// Ù…Ø¹Ø±Ù‘Ù Ø§Ù„Ø®Ø¯Ù…Ø© Ø§Ù„Ø­Ù‚ÙŠÙ‚ÙŠ ÙÙŠ Ù‚Ø§Ø¹Ø¯Ø© Ø§Ù„Ø¨ÙŠØ§Ù†Ø§Øª â€” ÙŠÙØ­Ù…Ù„ ÙÙŠ Ø§Ù„Ù…Ø³ÙˆØ¯Ø© Ù„Ø£Ù† Ø§Ù„Ø·Ù„Ø¨ Ù„Ø§
  /// ÙŠÙÙ†Ø´Ø£ Ø¥Ù„Ø§ Ø¹Ù†Ø¯ Ø§Ø®ØªÙŠØ§Ø± Ø§Ù„Ù…Ø²ÙˆÙ‘Ø¯ØŒ ÙˆÙˆÙ‚ØªÙ‡Ø§ Ù„Ø§ ÙŠÙƒÙˆÙ† Ø§Ù„Ù†Ù…ÙˆØ°Ø¬ ÙÙŠ Ø§Ù„Ù…ÙƒØ¯Ø³.
  final String? serviceTypeId;

  final double? latitude;
  final double? longitude;
  final String? carId;
  final String? carMake;
  final String? carModel;
  final int? carYear;
  final String notes;
  final bool autoCancel;
  final List<String> imagePaths;
  final DateTime savedAt;

  /// Ù‡Ù„ Ø¨Ø¯Ø§Ø®Ù„Ù‡Ø§ Ù…Ø§ ÙŠØ³ØªØ­Ù‚ Ø§Ù„Ø­ÙØ¸ØŸ Ø§Ù„Ù…Ø³ÙˆØ¯Ø© Ø§Ù„ÙØ§Ø±ØºØ© Ø¨Ø§Ù„ÙƒØ§Ù…Ù„ ØªÙÙ…Ø³Ø­ Ø¨Ø¯Ù„ Ø§Ù„Ø¨Ù‚Ø§Ø¡.
  bool get hasContent =>
      latitude != null ||
      longitude != null ||
      carId != null ||
      carMake != null ||
      notes.trim().isNotEmpty ||
      imagePaths.isNotEmpty ||
      autoCancel != true;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'serviceId': serviceId,
        'serviceTypeId': serviceTypeId,
        'latitude': latitude,
        'longitude': longitude,
        'carId': carId,
        'carMake': carMake,
        'carModel': carModel,
        'carYear': carYear,
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
      carId: json['carId'] as String?,
      carMake: json['carMake'] as String?,
      carModel: json['carModel'] as String?,
      carYear: (json['carYear'] as num?)?.toInt(),
      notes: json['notes'] as String? ?? '',
      autoCancel: json['autoCancel'] as bool? ?? true,
      imagePaths: (json['imagePaths'] is List)
          ? (json['imagePaths'] as List).whereType<String>().toList()
          : const [],
      savedAt: savedAtRaw is String ? DateTime.tryParse(savedAtRaw) ?? DateTime.fromMillisecondsSinceEpoch(0) : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// ÙŠØ®Ø²Ù‘Ù† Ø§Ù„Ù…Ø³ÙˆØ¯Ø© ({@link ServiceRequestDraft}) ÙÙŠ SharedPreferences ÙƒÙ€ JSON
/// ØªØ­Øª Ù…ÙØªØ§Ø­ ÙˆØ§Ø­Ø¯ â€” Ù†Ø³Ø®Ø© ÙˆØ§Ø­Ø¯Ø© Ù„ÙƒÙ„ Ø¬Ù‡Ø§Ø²/Ù…Ø³ØªØ®Ø¯Ù… (ÙƒÙ„ ÙƒØªØ§Ø¨Ø© ØªØ­Ù„ Ù…Ø­Ù„ Ø³Ø§Ø¨Ù‚ØªÙ‡Ø§).
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
