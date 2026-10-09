import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/services/provider_location_write.dart';

void main() {
  final now = DateTime.utc(2026, 10, 9, 12, 0, 0);

  LocationWriteDecision decide({
    DateTime? storedUpdatedAt,
    double? storedAccuracy,
    required double newAccuracy,
    required double movedMeters,
  }) {
    return decideLocationWrite(
      storedUpdatedAt: storedUpdatedAt,
      storedAccuracy: storedAccuracy,
      newAccuracy: newAccuracy,
      movedMeters: movedMeters,
      now: now,
    );
  }

  group('decideLocationWrite — no stored location / stale', () {
    test('null updated_at (no stored info) always writes', () {
      final d = decide(
        storedUpdatedAt: null,
        storedAccuracy: null,
        newAccuracy: 8,
        movedMeters: 1,
      );
      expect(d.shouldWrite, isTrue);
      expect(d.reason, LocationWriteReason.noStoredOrStale);
    });

    test('stored older than freshness window writes even without movement', () {
      final d = decide(
        storedUpdatedAt: now.subtract(const Duration(minutes: 31)),
        storedAccuracy: 5,
        newAccuracy: 40,
        movedMeters: 0,
      );
      expect(d.shouldWrite, isTrue);
      expect(d.reason, LocationWriteReason.noStoredOrStale);
    });

    test('stored exactly at the window boundary counts as fresh', () {
      final d = decide(
        storedUpdatedAt: now.subtract(const Duration(minutes: 30)),
        storedAccuracy: 10,
        newAccuracy: 8,
        movedMeters: 500,
      );
      expect(d.shouldWrite, isTrue);
      expect(d.reason, LocationWriteReason.improvedFreshMove);
    });
  });

  group('decideLocationWrite — fresh stored location', () {
    test('fresher and clearly more accurate + big move -> write', () {
      final d = decide(
        storedUpdatedAt: now.subtract(const Duration(minutes: 5)),
        storedAccuracy: 10,
        newAccuracy: 4,
        movedMeters: 500,
      );
      expect(d.shouldWrite, isTrue);
      expect(d.reason, LocationWriteReason.improvedFreshMove);
    });

    test('equal accuracy + big move -> write', () {
      final d = decide(
        storedUpdatedAt: now.subtract(const Duration(minutes: 5)),
        storedAccuracy: 10,
        newAccuracy: 10,
        movedMeters: 500,
      );
      expect(d.shouldWrite, isTrue);
      expect(d.reason, LocationWriteReason.improvedFreshMove);
    });

    test('worse accuracy (150m) must never overwrite a fresh more-accurate (10m) stored fix', () {
      final d = decide(
        storedUpdatedAt: now.subtract(const Duration(minutes: 5)),
        storedAccuracy: 10,
        newAccuracy: 150,
        movedMeters: 500,
      );
      expect(d.shouldWrite, isFalse);
      expect(d.reason, LocationWriteReason.skipWorseAccuracy);
    });

    test('small move on fresh stored is skipped even with better accuracy', () {
      final d = decide(
        storedUpdatedAt: now.subtract(const Duration(minutes: 5)),
        storedAccuracy: 10,
        newAccuracy: 4,
        movedMeters: 10,
      );
      expect(d.shouldWrite, isFalse);
      expect(d.reason, LocationWriteReason.skipSmallMove);
    });

    test('move exactly at the threshold is treated as small (skip)', () {
      final d = decide(
        storedUpdatedAt: now.subtract(const Duration(minutes: 5)),
        storedAccuracy: 10,
        newAccuracy: 4,
        movedMeters: 30,
      );
      expect(d.shouldWrite, isFalse);
      expect(d.reason, LocationWriteReason.skipSmallMove);
    });

    test('move just above the threshold + better accuracy -> write', () {
      final d = decide(
        storedUpdatedAt: now.subtract(const Duration(minutes: 5)),
        storedAccuracy: 10,
        newAccuracy: 4,
        movedMeters: 30.01,
      );
      expect(d.shouldWrite, isTrue);
      expect(d.reason, LocationWriteReason.improvedFreshMove);
    });

    test('worse accuracy takes precedence over small-move skip', () {
      final d = decide(
        storedUpdatedAt: now.subtract(const Duration(minutes: 5)),
        storedAccuracy: 4,
        newAccuracy: 150,
        movedMeters: 5,
      );
      expect(d.shouldWrite, isFalse);
      expect(d.reason, LocationWriteReason.skipWorseAccuracy);
    });

    test('fresh stored with unknown accuracy + big move -> write', () {
      final d = decide(
        storedUpdatedAt: now.subtract(const Duration(minutes: 5)),
        storedAccuracy: null,
        newAccuracy: 8,
        movedMeters: 500,
      );
      expect(d.shouldWrite, isTrue);
      expect(d.reason, LocationWriteReason.improvedFreshMove);
    });

    test('fresh stored with unknown accuracy + big move even with coarse new fix -> write', () {
      final d = decide(
        storedUpdatedAt: now.subtract(const Duration(minutes: 5)),
        storedAccuracy: null,
        newAccuracy: 400,
        movedMeters: 500,
      );
      // no stored accuracy to compare -> treat as unknown; moved -> write
      expect(d.shouldWrite, isTrue);
      expect(d.reason, LocationWriteReason.improvedFreshMove);
    });
  });

  group('distanceMetersBetween', () {
    test('same point is 0 meters', () {
      expect(distanceMetersBetween(30.05, 31.23, 30.05, 31.23), closeTo(0, 0.001));
    });

    test('1 degree of latitude is ~111.2 km', () {
      final d = distanceMetersBetween(0, 0, 1, 0);
      expect(d, closeTo(111195, 60));
    });

    test('symmetric (order of points does not matter)', () {
      final a = distanceMetersBetween(30.04, 31.24, 30.05, 31.23);
      final b = distanceMetersBetween(30.05, 31.23, 30.04, 31.24);
      expect(a, closeTo(b, 0.0001));
    });
  });
}