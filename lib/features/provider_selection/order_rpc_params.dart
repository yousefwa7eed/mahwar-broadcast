/// بُناة معاملات RPC لإنشاء الطلب.
///
/// These maps must match the exact PostgREST argument names of the SECURITY
/// DEFINER function in the database. PostgREST resolves an RPC by function
/// name + argument names, so a missing *required* argument makes the call fail
/// with `PGRST202 <function> not found` — even though the function exists.
///
/// Live signature (verified):
///   create_order_for_provider(p_provider_id uuid, p_service_type_id text,
///     p_vehicle_id uuid, p_latitude double precision,
///     p_longitude double precision, p_notes text, p_auto_cancel boolean,
///     p_address_text text DEFAULT NULL, p_currency text DEFAULT 'EGP',
///     p_attachments text[] DEFAULT NULL)
///
/// The server derives make/model/year/trim/color/plate from `vehicles` +
/// catalog and verifies the vehicle belongs to the caller. The phone is never
/// sent — the owner's phone reaches the provider only through
/// `get_order_contact` after confirmation.
library;

Map<String, dynamic> buildCreateOrderForProviderParams({
  required String providerId,
  required String? serviceTypeId,
  required String? vehicleId,
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
    'p_vehicle_id': vehicleId,
    'p_latitude': latitude,
    'p_longitude': longitude,
    'p_notes': notes,
    'p_auto_cancel': autoCancel,
    'p_address_text': ?addressText,
    'p_currency': ?currency,
    'p_attachments': attachments,
  };
}
