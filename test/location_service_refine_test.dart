import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mahwar/core/services/location_service.dart';

/// دالة مساعدة لتوليد تيَّار يصدر تحديداً واحداً فور الاستماع.
Stream<Position> _fakePositionStream(Position pos) async* {
  yield pos;
}

/// تيَّار يصدر تسلسلاً من التحديدات (لاختبار التوقيت).
Stream<Position> _fakeSequenceStream(Iterable<Position> positions) async* {
  for (final pos in positions) {
    yield pos;
  }
}

/// تيَّار يُصدر خطأ فور الاستماع.
Stream<Position> _fakeErrorStream(Object error) async* {
  throw error;
}

Position _pos(double lat, double lng, double accuracy) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.now(),
    accuracy: accuracy,
    altitude: 0,
    heading: 0,
    speed: 0,
    speedAccuracy: 0,
    altitudeAccuracy: 0,
    headingAccuracy: 0,
  );
}

void main() {
  group('LocationService.refinePosition', () {
    test('first fix ≤ 50 m returns immediately (not approximate)', () async {
      final fix = await LocationService.instance.refinePosition(
        targetAccuracyMeters: 50,
        maxDuration: const Duration(seconds: 2),
        positionStreamFactory: () => _fakePositionStream(_pos(30.0444, 31.2357, 30.0)),
        isServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        requestPermission: () async => LocationPermission.whileInUse,
      );

      expect(fix, isNotNull);
      expect(fix!.isApproximate, isFalse);
      expect(fix.accuracyMeters, closeTo(30.0, 0.001));
    });

    test('only poor fixes → best at timeout with isApproximate=true', () async {
      // تيَّار يصدر تسلسلاً من التحديدات الضعيفة
      final stream = _fakeSequenceStream([
        _pos(30.0444, 31.2357, 120.0),
        _pos(30.0445, 31.2358, 90.0),
        _pos(30.0446, 31.2359, 80.0),
      ]);

      final fix = await LocationService.instance.refinePosition(
        targetAccuracyMeters: 50,
        maxDuration: const Duration(milliseconds: 150),
        positionStreamFactory: () => stream,
        isServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        requestPermission: () async => LocationPermission.whileInUse,
      );

      expect(fix, isNotNull);
      expect(fix!.isApproximate, isTrue);
      expect(fix.accuracyMeters, closeTo(80.0, 0.001));
    });

    test('permission denied returns null', () async {
      final fix = await LocationService.instance.refinePosition(
        positionStreamFactory: () => _fakePositionStream(_pos(30.0, 31.0, 10.0)),
        isServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.denied,
        requestPermission: () async => LocationPermission.denied,
      );

      expect(fix, isNull);
    });

    test('service disabled returns null', () async {
      final fix = await LocationService.instance.refinePosition(
        positionStreamFactory: () => const Stream.empty(),
        isServiceEnabled: () async => false,
        checkPermission: () async => LocationPermission.whileInUse,
        requestPermission: () async => LocationPermission.whileInUse,
      );

      expect(fix, isNull);
    });

    test('stream error returns null (no prior fix)', () async {
      final fix = await LocationService.instance.refinePosition(
        maxDuration: const Duration(milliseconds: 150),
        positionStreamFactory: () => _fakeErrorStream('GPS error'),
        isServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        requestPermission: () async => LocationPermission.whileInUse,
      );

      expect(fix, isNull);
    });
  });
}