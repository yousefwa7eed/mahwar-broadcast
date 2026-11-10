import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/features/provider_profile/provider_profile_params.dart';

void main() {
  // التوقيع الحي (مُتحقَّق في القاعدة بعد migration 20261110175516):
  //   get_provider_reviews(p_provider_id uuid, p_limit integer default 20,
  //                        p_offset integer default 0)
  //   get_provider_completed_orders(p_provider_id uuid) returns bigint
  group('buildProviderReviewsParams', () {
    test('يبني مفاتيح p_provider_id و p_limit و p_offset فقط', () {
      final params = buildProviderReviewsParams(providerId: 'p-1');

      expect(params.keys.toSet(), {'p_provider_id', 'p_limit', 'p_offset'});
      expect(params['p_provider_id'], 'p-1');
      expect(params['p_limit'], providerReviewsPageSize);
      expect(params['p_offset'], 0);
    });

    test('يمرر limit و offset المخصصين كما هما', () {
      final params = buildProviderReviewsParams(
        providerId: 'p-2',
        limit: 50,
        offset: 40,
      );

      expect(params['p_limit'], 50);
      expect(params['p_offset'], 40);
    });

    test('حجم الصفحة الافتراضي 20', () {
      expect(providerReviewsPageSize, 20);
    });
  });

  group('buildProviderCompletedOrdersParams', () {
    test('يبني مفتاح p_provider_id فقط', () {
      final params = buildProviderCompletedOrdersParams(providerId: 'p-3');

      expect(params.keys.toSet(), {'p_provider_id'});
      expect(params['p_provider_id'], 'p-3');
    });
  });
}
