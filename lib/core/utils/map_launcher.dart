import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

/// فتح الاتجاهات نحو نقطة في تطبيق خرائط جوجل.
///
/// التطبيق لا يملك ملاحة داخلية، فنسلّم الأمر لتطبيق الخرائط:
/// `google.navigation:` على أندرويد و`comgooglemaps:` على iOS يفتحان
/// جوجل مابس مباشرة، ثم رابط الويب كبديل يعمل حتى بلا التطبيق.
///
/// لا نستخدم `canLaunchUrl` قبل الإطلاق: أندرويد 11+ يحجب رؤية الحزم
/// (package visibility) فترجع false رغم وجود متصفح أو خرائط، بينما
/// `launchUrl` نفسه يرجع false عند غياب أي معالِج فننتقل للبديل بأمان.
class MapLauncher {
  const MapLauncher._();

  /// رابط اتجاهات الويب — يُستخدم كبديل أخير ويعمل على أي جهاز.
  static Uri directionsUri({
    required double latitude,
    required double longitude,
    double? originLatitude,
    double? originLongitude,
  }) {
    final origin = originLatitude != null && originLongitude != null
        ? '&origin=$originLatitude,$originLongitude'
        : '';
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$latitude,$longitude'
      '$origin'
      '&travelmode=driving',
    );
  }

  /// يحاول فتح تطبيق خرائط جوجل، ثم يقع على رابط الويب.
  /// يرجع false فقط إذا فشلت كل المحاولات.
  static Future<bool> openDirections({
    required double latitude,
    required double longitude,
    double? originLatitude,
    double? originLongitude,
  }) async {
    final candidates = <Uri>[
      if (!kIsWeb && Platform.isAndroid)
        Uri.parse('google.navigation:q=$latitude,$longitude&mode=d'),
      if (!kIsWeb && Platform.isIOS)
        Uri.parse(
          'comgooglemaps://?daddr=$latitude,$longitude&directionsmode=driving',
        ),
      directionsUri(
        latitude: latitude,
        longitude: longitude,
        originLatitude: originLatitude,
        originLongitude: originLongitude,
      ),
    ];

    for (final uri in candidates) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }
}
