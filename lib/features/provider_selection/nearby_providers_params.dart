/// بُناة معاملات RPC لشاشة المزوّدين القريبين.
///
/// PostgREST resolves an RPC by function name + argument names. The live
/// function uses unprefixed argument names (unlike the `p_…` order RPCs), so
/// the keys below must match it verbatim:
///
///   get_nearest_providers(user_lat double precision, user_lng double precision,
///     service_filter text DEFAULT NULL,
///     max_distance_meters double precision DEFAULT 50000)
///
/// Returns `location_updated_at` (timestamptz) among its columns.
/// `test/nearby_providers_params_test.dart` locks these keys.
library;

Map<String, dynamic> buildNearestProvidersParams({
  required double userLat,
  required double userLng,
  required String? serviceFilter,
  double maxDistanceMeters = 50000,
}) {
  return {
    'user_lat': userLat,
    'user_lng': userLng,
    'service_filter': serviceFilter,
    'max_distance_meters': maxDistanceMeters,
  };
}
