import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/features/provider_selection/nearby_providers_params.dart';
import 'package:mahwar/features/provider_selection/nearby_providers_screen.dart';
import 'package:mahwar/l10n/app_localizations_ar.dart';
import 'package:mahwar/l10n/app_localizations_en.dart';

void main() {
  group('buildNearestProvidersParams', () {
    // التوقيع الحي: user_lat, user_lng, service_filter, max_distance_meters
    // (بلا بادئة p_ — خلافًا لدوال الطلب). أي تغيير في الأسماء يكسر النداء.
    test('contains exactly the live argument names', () {
      final params = buildNearestProvidersParams(
        userLat: 30.05,
        userLng: 31.23,
        serviceFilter: 'crane_rental',
      );

      expect(params.keys.toSet(), {
        'user_lat',
        'user_lng',
        'service_filter',
        'max_distance_meters',
      });
      expect(params.containsKey('p_user_lat'), isFalse);
      expect(params.containsKey('p_service_filter'), isFalse);
    });

    test('passes values through and defaults the radius to 50 km', () {
      final params = buildNearestProvidersParams(
        userLat: 30.05,
        userLng: 31.23,
        serviceFilter: null,
      );

      expect(params['user_lat'], 30.05);
      expect(params['user_lng'], 31.23);
      expect(params['service_filter'], isNull);
      expect(params['max_distance_meters'], 50000);
    });

    test('honours a custom radius', () {
      final params = buildNearestProvidersParams(
        userLat: 1,
        userLng: 2,
        serviceFilter: 'towing',
        maxDistanceMeters: 10000,
      );

      expect(params['max_distance_meters'], 10000);
    });
  });

  group('NearbyProvidersScreen.formatLastSeen', () {
    final now = DateTime.utc(2026, 10, 27, 12);

    test('returns empty when the provider never reported a location', () {
      expect(NearbyProvidersScreen.formatLastSeen(null), '');
    });

    test('formats relative to the provided server time (Arabic)', () {
      final l10n = AppLocalizationsAr();

      expect(
        NearbyProvidersScreen.formatLastSeen(
          now.subtract(const Duration(minutes: 3)),
          asOf: now,
          l10n: l10n,
        ),
        'آخر ظهور: منذ 3 دقيقة',
      );
      expect(
        NearbyProvidersScreen.formatLastSeen(
          now.subtract(const Duration(hours: 2)),
          asOf: now,
          l10n: l10n,
        ),
        'آخر ظهور: منذ 2 ساعة',
      );
    });

    test('formats relative to the provided server time (English)', () {
      expect(
        NearbyProvidersScreen.formatLastSeen(
          now.subtract(const Duration(minutes: 3)),
          asOf: now,
          l10n: AppLocalizationsEn(),
        ),
        'Last seen: 3 minutes ago',
      );
    });
  });
}
