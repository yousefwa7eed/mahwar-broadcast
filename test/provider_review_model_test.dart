import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/models/provider_review.dart';

void main() {
  group('ProviderReview.fromJson', () {
    test('يقرأ صف get_provider_reviews كما يعيده الخادم', () {
      final review = ProviderReview.fromJson({
        'rating': 4,
        'comment': '  خدمة سريعة  ',
        'created_at': '2026-10-21T20:57:12.108712+00:00',
        'service_type_id': 'tire',
        'service_name_ar': 'خدمات الإطارات',
        'service_name_en': 'Tire Repair',
        'reviewer_name': 'yousef waheed',
        'reviewer_avatar_id': 'car_owner_5',
        'reviewer_avatar_url': null,
        'total_count': 7,
      });

      expect(review.rating, 4);
      expect(review.comment, 'خدمة سريعة');
      expect(review.createdAt?.toUtc().year, 2026);
      expect(review.reviewerName, 'yousef waheed');
      expect(review.reviewerAvatarId, 'car_owner_5');
      expect(review.reviewerAvatarUrl, isNull);
      expect(review.totalCount, 7);
      expect(review.hasComment, isTrue);
    });

    test('يتحمل القيم الناقصة بلا استثناء', () {
      final review = ProviderReview.fromJson({
        'rating': null,
        'comment': '   ',
        'created_at': null,
        'service_type_id': null,
        'reviewer_name': null,
        'total_count': null,
      });

      expect(review.rating, 0);
      expect(review.hasComment, isFalse);
      expect(review.createdAt, isNull);
      expect(review.reviewerName, isNull);
      expect(review.totalCount, 0);
    });
  });

  group('serviceLabel', () {
    const review = ProviderReview(
      rating: 5,
      serviceTypeId: 'battery',
      serviceNameAr: 'خدمة البطارية',
      serviceNameEn: 'Battery service',
    );

    test('العربية أولًا ثم الإنجليزية', () {
      expect(review.serviceLabel(true), 'خدمة البطارية');
      expect(review.serviceLabel(false), 'Battery service');
    });

    test('يسقط للغة الأخرى عند غياب اللغة المطلوبة', () {
      const onlyEnglish = ProviderReview(
        rating: 5,
        serviceTypeId: 'battery',
        serviceNameEn: 'Battery service',
      );

      expect(onlyEnglish.serviceLabel(true), 'Battery service');
    });

    test('يسقط لمعرّف الخدمة عند غياب الاسمين', () {
      const onlyId = ProviderReview(rating: 3, serviceTypeId: 'fuel');

      expect(onlyId.serviceLabel(true), 'fuel');
    });
  });
}
