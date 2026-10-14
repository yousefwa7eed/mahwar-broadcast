/// بُناة معاملات RPC لإنشاء الطلب وتعديله.
///
/// These maps must match the exact PostgREST argument names of the SECURITY
/// DEFINER functions in the database. PostgREST resolves an RPC by function
/// name + argument names, so a missing *required* argument makes the call fail
/// with `PGRST202 <function> not found` — even though the function exists.
///
/// Live signatures (verified):
///   create_order_for_provider(p_provider_id uuid, p_service_type_id text,
///     p_car_make text, p_car_model text, p_car_year integer, p_latitude
///     double precision, p_longitude double precision, p_notes text,
///     p_owner_phone text, p_auto_cancel boolean, p_share_phone boolean,
///     p_address_text text DEFAULT NULL, p_currency text DEFAULT 'EGP',
///     p_attachments text[] DEFAULT NULL)
///
///   update_pending_order(p_order_id uuid, p_service_type_id text,
///     p_car_make text, p_car_model text, p_car_year integer, p_latitude
///     double precision, p_longitude double precision, p_notes text,
///     p_owner_phone text, p_auto_cancel boolean, p_share_phone boolean)
///
/// `p_owner_phone` and `p_share_phone` have NO defaults, so they must always be
/// sent explicitly. The database trigger `trg_orders_force_null_phone` forces
/// `owner_phone = NULL` and `share_phone = false` on every write anyway, so the
/// client sends `null`/`false` and never leaks the phone number.
library;

Map<String, dynamic> buildCreateOrderForProviderParams({
  required String providerId,
  required String? serviceTypeId,
  required String? carMake,
  required String? carModel,
  required int? carYear,
  required double? latitude,
  required double? longitude,
  required String? notes,
  required bool autoCancel,
  required List<String>? attachments,
  String? addressText,
  String? currency,
}) {
  return {
    'p_provider_id': providerId,
    'p_service_type_id': serviceTypeId,
    'p_car_make': carMake,
    'p_car_model': carModel,
    'p_car_year': carYear,
    'p_latitude': latitude,
    'p_longitude': longitude,
    'p_notes': notes,
    'p_owner_phone': null,
    'p_auto_cancel': autoCancel,
    'p_share_phone': false,
    'p_address_text': ?addressText,
    'p_currency': ?currency,
    'p_attachments': attachments,
  };
}

Map<String, dynamic> buildUpdatePendingOrderParams({
  required String orderId,
  required String? serviceTypeId,
  required String? carMake,
  required String? carModel,
  required int? carYear,
  required double? latitude,
  required double? longitude,
  required String? notes,
  required bool autoCancel,
}) {
  return {
    'p_order_id': orderId,
    'p_service_type_id': serviceTypeId,
    'p_car_make': carMake,
    'p_car_model': carModel,
    'p_car_year': carYear,
    'p_latitude': latitude,
    'p_longitude': longitude,
    'p_notes': notes,
    'p_owner_phone': null,
    'p_auto_cancel': autoCancel,
    'p_share_phone': false,
  };
}
