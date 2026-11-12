import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/utils/map_launcher.dart';

void main() {
  group('MapLauncher.directionsUri', () {
    test('builds a driving directions link to the destination', () {
      final uri = MapLauncher.directionsUri(
        latitude: 30.0444,
        longitude: 31.2357,
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['destination'], '30.0444,31.2357');
      expect(uri.queryParameters['travelmode'], 'driving');
      // بلا origin: جوجل مابس يستخدم موقع الجهاز الحالي كنقطة انطلاق.
      expect(uri.queryParameters.containsKey('origin'), isFalse);
    });

    test('includes the origin when the caller passes one', () {
      final uri = MapLauncher.directionsUri(
        latitude: 30.1,
        longitude: 31.4,
        originLatitude: 30.0,
        originLongitude: 31.2,
      );

      expect(uri.queryParameters['origin'], '30.0,31.2');
      expect(uri.queryParameters['destination'], '30.1,31.4');
    });
  });
}
