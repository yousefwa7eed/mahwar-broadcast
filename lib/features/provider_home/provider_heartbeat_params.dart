/// بُناة معاملات RPC لنبضة موقع المزوّد.
///
/// This map must match the exact PostgREST argument names of the SECURITY
/// DEFINER function in the database. PostgREST resolves an RPC by function
/// name + argument names, so a wrong/missing *required* argument fails with
/// `PGRST202 <function> not found`.
///
/// Live signature (verified):
///   provider_heartbeat(p_lat double precision,
///                      p_lng double precision,
///                      p_accuracy double precision DEFAULT NULL)
///
/// `p_lat`/`p_lng` are required. `p_accuracy` is optional and is OMITTED from
/// the map when unknown (null), so the database default (NULL) applies; the
/// function reads the provider identity from `auth.uid()` — never from a param.
library;

/// يبني خريطة معاملات `provider_heartbeat`.
///
/// المفاتيح بالضبط: `p_lat`, `p_lng`, و`p_accuracy` (يُحذف عند null فقط).
Map<String, dynamic> buildProviderHeartbeatParams({
  required double latitude,
  required double longitude,
  double? accuracy,
}) {
  return {
    'p_lat': latitude,
    'p_lng': longitude,
    'p_accuracy': ?accuracy,
  };
}
