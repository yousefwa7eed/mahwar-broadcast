import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/utils/distance.dart';
import 'package:mahwar/core/utils/distance_format.dart';

void main() {
  group('distanceMeters — Haversine with earthRadiusMeters=6378168', () {
    test('same point yields 0', () {
      final d = distanceMeters(30.0, 31.0, 30.0, 31.0);
      expect(d, closeTo(0.0, 0.001));
    });

    test('provider (30.8571057,31.5269518) to (30.0,31.0) ≈ 107990 m', () {
      final d = distanceMeters(30.8571057, 31.5269518, 30.0, 31.0);
      expect(d, closeTo(107990.43, 0.5));
    });

    test('Cairo (30.0444,31.2357) to Alexandria (31.2001,29.9187) ≈ 180187 m', () {
      final d = distanceMeters(30.0444, 31.2357, 31.2001, 29.9187);
      expect(d, closeTo(180186.90, 0.5));
    });

    test('symmetry', () {
      final a = distanceMeters(30.04, 31.24, 30.05, 31.23);
      final b = distanceMeters(30.05, 31.23, 30.04, 31.24);
      expect(a, closeTo(b, 0.001));
    });
  });

  group('optionalDistanceMeters — null/zero guards', () {
    test('null lat/lng returns null', () {
      expect(optionalDistanceMeters(null, 31.0, 30.0, 31.0), isNull);
      expect(optionalDistanceMeters(30.0, null, 30.0, 31.0), isNull);
      expect(optionalDistanceMeters(30.0, 31.0, null, 31.0), isNull);
      expect(optionalDistanceMeters(30.0, 31.0, 30.0, null), isNull);
    });

    test('(0,0) treated as unavailable returns null', () {
      expect(optionalDistanceMeters(0, 0, 30.0, 31.0), isNull);
      expect(optionalDistanceMeters(30.0, 31.0, 0, 0), isNull);
    });

    test('valid coordinates return distance', () {
      final d = optionalDistanceMeters(30.0, 31.0, 30.0444, 31.2357);
      expect(d, isNotNull);
      expect(d!, closeTo(23250.0, 100)); // Cairo center to 30.0444,31.2357
    });
  });

  group('formatApproxDistance — unified display', () {
    test('null returns dash', () {
      expect(formatApproxDistance(null, meterUnit: 'م', kmUnit: 'كم'), '—');
    });

    test('0 returns ≈ 0 م', () {
      expect(formatApproxDistance(0, meterUnit: 'م', kmUnit: 'كم'), '≈ 0 م');
    });

    test('4 m rounds to 0 → ≈ 0 م', () {
      expect(formatApproxDistance(4, meterUnit: 'م', kmUnit: 'كم'), '≈ 0 م');
    });

    test('994 m rounds to 990 → ≈ 990 م', () {
      expect(formatApproxDistance(994, meterUnit: 'م', kmUnit: 'كم'), '≈ 990 م');
    });

    test('995 m rounds to 1000 → ≥1000 uses km → ≈ 1.0 كم', () {
      expect(formatApproxDistance(995, meterUnit: 'م', kmUnit: 'كم'), '≈ 1.0 كم');
    });

    test('3500 m → ≈ 3.5 كم', () {
      expect(formatApproxDistance(3500, meterUnit: 'م', kmUnit: 'كم'), '≈ 3.5 كم');
    });

    test('51610 m → ≈ 51.6 كم', () {
      expect(formatApproxDistance(51610, meterUnit: 'م', kmUnit: 'كم'), '≈ 51.6 كم');
    });

    test('English units work', () {
      expect(formatApproxDistance(3500, meterUnit: 'm', kmUnit: 'km'), '≈ 3.5 km');
    });
  });
}