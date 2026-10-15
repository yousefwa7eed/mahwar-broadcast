import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/features/provider_home/provider_heartbeat_params.dart';

void main() {
  group('buildProviderHeartbeatParams', () {
    test('omits p_accuracy and pins exactly p_lat + p_lng when accuracy is null', () {
      final params = buildProviderHeartbeatParams(
        latitude: 30.05,
        longitude: 31.23,
      );

      expect(params.keys.toSet(), {'p_lat', 'p_lng'});
      expect(params['p_lat'], 30.05);
      expect(params['p_lng'], 31.23);
      expect(params.containsKey('p_accuracy'), isFalse);
    });

    test('adds exactly p_accuracy when provided', () {
      final params = buildProviderHeartbeatParams(
        latitude: 30.05,
        longitude: 31.23,
        accuracy: 12.5,
      );

      expect(params.keys.toSet(), {'p_lat', 'p_lng', 'p_accuracy'});
      expect(params['p_lat'], 30.05);
      expect(params['p_lng'], 31.23);
      expect(params['p_accuracy'], 12.5);
    });

    test('never sends a provider id (identity comes from auth.uid() in the DB)', () {
      final params = buildProviderHeartbeatParams(
        latitude: 1,
        longitude: 2,
        accuracy: 3,
      );

      expect(params.keys.any((k) => k.contains('provider')), isFalse);
    });
  });
}
