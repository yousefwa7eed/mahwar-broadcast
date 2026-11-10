/// بُناة معاملات RPC لحالة اقتراح تنبيه المزوّد الغائب.
///
/// Live signature (verified 2026-11-10):
///   order_provider_alert_status(p_order_id uuid)
///     returns table(is_logged_out boolean, can_alert boolean, reason text)
///
/// `test/provider_alert_params_test.dart` locks the key.
library;

Map<String, dynamic> buildOrderProviderAlertStatusParams({
  required String orderId,
}) {
  return {'p_order_id': orderId};
}
