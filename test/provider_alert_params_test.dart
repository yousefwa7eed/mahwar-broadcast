import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/features/request_tracking/provider_alert_params.dart';

void main() {
  group('buildOrderProviderAlertStatusParams', () {
    test('contains exactly the live signature argument (p_order_id)', () {
      final params = buildOrderProviderAlertStatusParams(orderId: 'order-1');

      expect(params.keys.toSet(), {'p_order_id'});
      expect(params['p_order_id'], 'order-1');
    });
  });
}
