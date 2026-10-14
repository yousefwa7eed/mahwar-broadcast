import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/features/provider_selection/order_rpc_params.dart';

void main() {
  group('buildCreateOrderForProviderParams', () {
    test('always sends the required phone params as null/false', () {
      final params = buildCreateOrderForProviderParams(
        providerId: 'prov-1',
        serviceTypeId: 'crane_rental',
        carMake: 'Toyota',
        carModel: 'Corolla',
        carYear: 2019,
        latitude: 30.05,
        longitude: 31.23,
        notes: 'breakdown',
        autoCancel: true,
        attachments: null,
      );

      expect(params['p_owner_phone'], isNull);
      expect(params['p_share_phone'], isFalse);
    });

    test('contains exactly the expected keys (plus optional attachments)', () {
      final params = buildCreateOrderForProviderParams(
        providerId: 'prov-1',
        serviceTypeId: 'crane_rental',
        carMake: 'Toyota',
        carModel: 'Corolla',
        carYear: 2019,
        latitude: 30.05,
        longitude: 31.23,
        notes: 'breakdown',
        autoCancel: false,
        attachments: const ['https://cdn/a.jpg'],
      );

      expect(params.keys.toSet(), {
        'p_provider_id',
        'p_service_type_id',
        'p_car_make',
        'p_car_model',
        'p_car_year',
        'p_latitude',
        'p_longitude',
        'p_notes',
        'p_owner_phone',
        'p_auto_cancel',
        'p_share_phone',
        'p_attachments',
      });
      expect(params['p_provider_id'], 'prov-1');
      expect(params['p_service_type_id'], 'crane_rental');
      expect(params['p_car_make'], 'Toyota');
      expect(params['p_car_model'], 'Corolla');
      expect(params['p_car_year'], 2019);
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
        carMake: null,
        carModel: null,
        carYear: null,
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
        carMake: null,
        carModel: null,
        carYear: null,
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

  group('buildUpdatePendingOrderParams', () {
    test('always sends the required phone params as null/false', () {
      final params = buildUpdatePendingOrderParams(
        orderId: 'order-1',
        serviceTypeId: 'crane_rental',
        carMake: 'Toyota',
        carModel: 'Corolla',
        carYear: 2019,
        latitude: 30.05,
        longitude: 31.23,
        notes: 'breakdown',
        autoCancel: true,
      );

      expect(params['p_owner_phone'], isNull);
      expect(params['p_share_phone'], isFalse);
    });

    test('contains exactly the expected keys', () {
      final params = buildUpdatePendingOrderParams(
        orderId: 'order-1',
        serviceTypeId: 'crane_rental',
        carMake: 'Toyota',
        carModel: 'Corolla',
        carYear: 2019,
        latitude: 30.05,
        longitude: 31.23,
        notes: 'breakdown',
        autoCancel: false,
      );

      expect(params.keys.toSet(), {
        'p_order_id',
        'p_service_type_id',
        'p_car_make',
        'p_car_model',
        'p_car_year',
        'p_latitude',
        'p_longitude',
        'p_notes',
        'p_owner_phone',
        'p_auto_cancel',
        'p_share_phone',
      });
      expect(params['p_order_id'], 'order-1');
      expect(params['p_auto_cancel'], isFalse);
    });
  });
}
