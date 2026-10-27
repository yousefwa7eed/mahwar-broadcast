import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/features/provider_selection/order_rpc_params.dart';

void main() {
  group('buildCreateOrderForProviderParams', () {
    test('never sends phone params — the server derives contact separately', () {
      final params = buildCreateOrderForProviderParams(
        providerId: 'prov-1',
        serviceTypeId: 'crane',
        vehicleId: 'vehicle-1',
        latitude: 30.05,
        longitude: 31.23,
        notes: 'breakdown',
        autoCancel: true,
        attachments: null,
      );

      expect(
        params.keys.where((key) => key.contains('phone')),
        isEmpty,
      );
    });

    test('contains exactly the expected keys (plus optional attachments)', () {
      final params = buildCreateOrderForProviderParams(
        providerId: 'prov-1',
        serviceTypeId: 'crane',
        vehicleId: 'vehicle-1',
        latitude: 30.05,
        longitude: 31.23,
        notes: 'breakdown',
        autoCancel: false,
        attachments: const ['https://cdn/a.jpg'],
      );

      expect(params.keys.toSet(), {
        'p_provider_id',
        'p_service_type_id',
        'p_vehicle_id',
        'p_latitude',
        'p_longitude',
        'p_notes',
        'p_auto_cancel',
        'p_attachments',
      });
      expect(params['p_provider_id'], 'prov-1');
      expect(params['p_service_type_id'], 'crane');
      expect(params['p_vehicle_id'], 'vehicle-1');
      expect(params['p_latitude'], 30.05);
      expect(params['p_longitude'], 31.23);
      expect(params['p_notes'], 'breakdown');
      expect(params['p_auto_cancel'], isFalse);
      expect(params['p_attachments'], ['https://cdn/a.jpg']);
    });

    test('adds optional p_address_text and p_currency only when provided', () {
      final bare = buildCreateOrderForProviderParams(
        providerId: 'prov-1',
        serviceTypeId: null,
        vehicleId: null,
        latitude: null,
        longitude: null,
        notes: null,
        autoCancel: true,
        attachments: null,
      );
      expect(bare.containsKey('p_address_text'), isFalse);
      expect(bare.containsKey('p_currency'), isFalse);

      final full = buildCreateOrderForProviderParams(
        providerId: 'prov-1',
        serviceTypeId: null,
        vehicleId: null,
        latitude: null,
        longitude: null,
        notes: null,
        autoCancel: true,
        attachments: null,
        addressText: '12 Nile St',
        currency: 'EGP',
      );
      expect(full['p_address_text'], '12 Nile St');
      expect(full['p_currency'], 'EGP');
    });
  });
}
