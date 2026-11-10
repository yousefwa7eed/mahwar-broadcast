/// رأي عميل على مزوّد كما يعيده `get_provider_reviews`.
///
/// الخادم لا يُرجع سوى الاسم الثنائي وavatar — لا هاتف ولا معرّف حساب ولا
/// بقية أجزاء الاسم. أي غياب للاسم يُعرض كعميل مجهول في الشاشة.
class ProviderReview {
  final int rating;
  final String? comment;
  final DateTime? createdAt;
  final String? serviceTypeId;
  final String? serviceNameAr;
  final String? serviceNameEn;
  final String? reviewerName;
  final String? reviewerAvatarId;
  final String? reviewerAvatarUrl;
  final int totalCount;

  const ProviderReview({
    required this.rating,
    this.comment,
    this.createdAt,
    this.serviceTypeId,
    this.serviceNameAr,
    this.serviceNameEn,
    this.reviewerName,
    this.reviewerAvatarId,
    this.reviewerAvatarUrl,
    this.totalCount = 0,
  });

  factory ProviderReview.fromJson(Map<String, dynamic> json) {
    return ProviderReview(
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: (json['comment'] as String?)?.trim(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      serviceTypeId: json['service_type_id'] as String?,
      serviceNameAr: json['service_name_ar'] as String?,
      serviceNameEn: json['service_name_en'] as String?,
      reviewerName: (json['reviewer_name'] as String?)?.trim(),
      reviewerAvatarId: json['reviewer_avatar_id'] as String?,
      reviewerAvatarUrl: json['reviewer_avatar_url'] as String?,
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// اسم الخدمة بلغة العارض مع السقوط لمعرّف الخدمة.
  String serviceLabel(bool isArabic) {
    final preferred = isArabic ? serviceNameAr : serviceNameEn;
    final other = isArabic ? serviceNameEn : serviceNameAr;
    for (final candidate in [preferred, other]) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return (serviceTypeId ?? '').trim();
  }

  bool get hasComment => (comment ?? '').isNotEmpty;
}
