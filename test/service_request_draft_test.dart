import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/features/service_request/service_request_draft.dart';

void main() {
  ServiceRequestDraft fullDraft() => ServiceRequestDraft(
        userId: 'u1',
        serviceId: 'crane',
        serviceTypeId: 'crane_rental',
        latitude: 30.05,
        longitude: 31.23,
        vehicleId: 'v1',
        notes: 'breakdown on the ring road',
        autoCancel: false,
        imagePaths: const ['/a.jpg', '/b.jpg'],
        savedAt: DateTime.parse('2026-10-13T10:00:00.000Z'),
      );

  group('ServiceRequestDraft JSON round-trip', () {
    test('preserves every field', () {
      final restored = ServiceRequestDraft.fromJson(fullDraft().toJson());

      expect(restored.userId, 'u1');
      expect(restored.serviceId, 'crane');
      expect(restored.serviceTypeId, 'crane_rental');
      expect(restored.latitude, 30.05);
      expect(restored.longitude, 31.23);
      expect(restored.vehicleId, 'v1');
      expect(restored.notes, 'breakdown on the ring road');
      expect(restored.autoCancel, isFalse);
      expect(restored.imagePaths, ['/a.jpg', '/b.jpg']);
      expect(restored.savedAt, DateTime.parse('2026-10-13T10:00:00.000Z'));
    });

    test('no longer carries an orderId key', () {
      expect(fullDraft().toJson().containsKey('orderId'), isFalse);
    });
  });

  group('ServiceRequestDraft.fromJson — tolerant defaults', () {
    test('missing fields fall back safely', () {
      final restored = ServiceRequestDraft.fromJson({
        'userId': 'u1',
        'serviceId': 'crane',
      });

      expect(restored.serviceTypeId, isNull);
      expect(restored.latitude, isNull);
      expect(restored.longitude, isNull);
      expect(restored.vehicleId, isNull);
      expect(restored.notes, '');
      expect(restored.autoCancel, isTrue);
      expect(restored.imagePaths, isEmpty);
    });
  });

  group('ServiceRequestDraft.hasContent', () {
    ServiceRequestDraft bare() =>
        ServiceRequestDraft(userId: 'u1', serviceId: 'crane', savedAt: DateTime(2026));

    test('a blank draft has no content', () {
      expect(bare().hasContent, isFalse);
    });

    test('defaults alone (autoCancel true, sharePhone false) do not count', () {
      expect(bare().hasContent, isFalse);
    });

    test('a picked vehicle counts', () {
      final draft = ServiceRequestDraft(
        userId: 'u1',
        serviceId: 'crane',
        vehicleId: 'v1',
        savedAt: DateTime(2026),
      );
      expect(draft.hasContent, isTrue);
    });

    test('a picked location counts', () {
      final draft = ServiceRequestDraft(
        userId: 'u1',
        serviceId: 'crane',
        latitude: 30.05,
        longitude: 31.23,
        savedAt: DateTime(2026),
      );
      expect(draft.hasContent, isTrue);
    });

    test('notes alone count', () {
      final draft = ServiceRequestDraft(
        userId: 'u1',
        serviceId: 'crane',
        notes: 'help',
        savedAt: DateTime(2026),
      );
      expect(draft.hasContent, isTrue);
    });

    test('a picked image alone counts', () {
      final draft = ServiceRequestDraft(
        userId: 'u1',
        serviceId: 'crane',
        imagePaths: const ['/a.jpg'],
        savedAt: DateTime(2026),
      );
      expect(draft.hasContent, isTrue);
    });

    test('opting out of auto-cancel counts', () {
      final draft = ServiceRequestDraft(
        userId: 'u1',
        serviceId: 'crane',
        autoCancel: false,
        savedAt: DateTime(2026),
      );
      expect(draft.hasContent, isTrue);
    });
  });
}
