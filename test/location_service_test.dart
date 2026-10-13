import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/services/location_service.dart';

void main() {
  final now = DateTime(2026, 10, 13, 12, 0, 0);

  group('LocationService.isFreshEnough', () {
    test('accepts any timestamp when maxAge is null (current behavior)', () {
      expect(LocationService.isFreshEnough(null, null, now: now), isTrue);
      expect(
        LocationService.isFreshEnough(now.subtract(const Duration(hours: 5)), null, now: now),
        isTrue,
      );
    });

    test('rejects a null timestamp when an age limit is set', () {
      expect(
        LocationService.isFreshEnough(null, const Duration(minutes: 10), now: now),
        isFalse,
      );
    });

    test('accepts a timestamp exactly at the limit', () {
      expect(
        LocationService.isFreshEnough(
          now.subtract(const Duration(minutes: 10)),
          const Duration(minutes: 10),
          now: now,
        ),
        isTrue,
      );
    });

    test('rejects a timestamp just beyond the limit', () {
      expect(
        LocationService.isFreshEnough(
          now.subtract(const Duration(minutes: 10, seconds: 1)),
          const Duration(minutes: 10),
          now: now,
        ),
        isFalse,
      );
    });

    test('accepts a very recent timestamp', () {
      expect(
        LocationService.isFreshEnough(
          now.subtract(const Duration(seconds: 30)),
          const Duration(minutes: 10),
          now: now,
        ),
        isTrue,
      );
    });

    test('rejects a future timestamp beyond tolerance (clock skew)', () {
      expect(
        LocationService.isFreshEnough(
          now.add(const Duration(minutes: 11)),
          const Duration(minutes: 10),
          now: now,
        ),
        isFalse,
      );
    });
  });
}