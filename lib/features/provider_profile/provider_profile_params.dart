/// معاملات استدعاءات آراء المزوّد وإحصائه العامة.
///
/// التوقيع الحي (مُطبَّق في القاعدة):
/// - `get_provider_reviews(p_provider_id uuid, p_limit integer default 20,
///   p_offset integer default 0)`
/// - `get_provider_completed_orders(p_provider_id uuid) returns bigint`
///
/// الخادم يقيّد limit بـ 1..50 ويستخدم offset >= 0، لكن نبني القيم صراحةً
/// ونثبّت مفاتيح الخريطة باختبار حتى لا ينزلق أي اسم معامل عند التعديل.
library;

const int providerReviewsPageSize = 20;

Map<String, dynamic> buildProviderReviewsParams({
  required String providerId,
  int limit = providerReviewsPageSize,
  int offset = 0,
}) {
  return {
    'p_provider_id': providerId,
    'p_limit': limit,
    'p_offset': offset,
  };
}

Map<String, dynamic> buildProviderCompletedOrdersParams({
  required String providerId,
}) {
  return {'p_provider_id': providerId};
}
