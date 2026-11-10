import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/avatar_config.dart';
import '../../core/models/provider_details.dart';
import '../../core/models/provider_review.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/service_type_directory.dart';
import '../../core/widgets/offline_view.dart';
import '../../l10n/app_localizations.dart';
import 'provider_profile_params.dart';

/// الملف العام للمزوّد: ورشته وتخصصاته ومتوسط تقييمه وعدد طلباته المكتملة،
/// ثم آراء العملاء (اسم ثنائي + avatar + نجوم + تاريخ + تعليق + الخدمة).
///
/// تُفتح من شاشة تفاصيل المزوّد قبل الطلب، ومن قائمة بروفايل المزوّد نفسه
/// («ملفي العام»)، ومن رابط QR الخارجي `mahwar://provider?id=...`.
///
/// لا تعرض رقم هاتف المزوّد ولا أي بيانات عن العملاء غير ما يعيده
/// `get_provider_reviews` (اسم ثنائي وavatar فقط).
class ProviderPublicProfileScreen extends StatefulWidget {
  const ProviderPublicProfileScreen({super.key, required this.providerId});

  final String providerId;

  @override
  State<ProviderPublicProfileScreen> createState() =>
      _ProviderPublicProfileScreenState();
}

class _ProviderPublicProfileScreenState
    extends State<ProviderPublicProfileScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  ProviderDetails? _provider;
  final List<ProviderReview> _reviews = [];
  int _totalReviews = 0;
  int _completedOrders = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  LoadFailure? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_isLoading && mounted) {
      setState(() {
        _isLoading = true;
        _failure = null;
      });
    }

    try {
      final results = await Future.wait([
        _client.rpc(
          'get_provider_details',
          params: {'p_provider_id': widget.providerId},
        ),
        _client.rpc(
          'get_provider_reviews',
          params: buildProviderReviewsParams(providerId: widget.providerId),
        ),
        _client.rpc(
          'get_provider_completed_orders',
          params: buildProviderCompletedOrdersParams(
            providerId: widget.providerId,
          ),
        ),
      ]);

      final detailsRows = results[0] as List;
      if (detailsRows.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _provider = null;
            _failure = LoadFailure.failed;
          });
        }
        return;
      }

      final provider = ProviderDetails.fromJson(
        Map<String, dynamic>.from(detailsRows.first as Map),
      );
      final reviews = _parseReviews(results[1]);

      await ServiceTypeDirectory.instance.ensureLoaded();

      final completed = (results[2] as num?)?.toInt() ?? 0;

      if (!mounted) return;
      setState(() {
        _provider = provider;
        _reviews
          ..clear()
          ..addAll(reviews);
        _totalReviews = reviews.isEmpty ? 0 : reviews.first.totalCount;
        _completedOrders = completed < 0 ? 0 : completed;
        _isLoading = false;
      });
    } catch (_) {
      final failure = await classifyLoadFailure();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _failure = failure;
        });
      }
    }
  }

  List<ProviderReview> _parseReviews(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (row) => ProviderReview.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _reviews.length >= _totalReviews) return;
    setState(() => _isLoadingMore = true);
    try {
      final raw = await _client.rpc(
        'get_provider_reviews',
        params: buildProviderReviewsParams(
          providerId: widget.providerId,
          offset: _reviews.length,
        ),
      );
      final more = _parseReviews(raw);
      if (!mounted) return;
      setState(() {
        _reviews.addAll(more);
        if (more.isNotEmpty) _totalReviews = more.first.totalCount;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.providerProfileLoadFailed ??
                'تعذّر تحميل ملف المزوّد',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: primary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n?.providerPublicProfileTitle ?? 'ملف المزوّد',
          style: TextStyle(
            fontFamily: 'Zain',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(child: _buildBody(context, isDark, l10n)),
    );
  }

  Widget _buildBody(
    BuildContext context,
    bool isDark,
    AppLocalizations? l10n,
  ) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.orangePrimary),
      );
    }

    final provider = _provider;
    if (provider == null) {
      return _failure == LoadFailure.offline
          ? OfflineView(onRetry: _load)
          : LoadFailedView(
              message:
                  l10n?.providerProfileLoadFailed ?? 'تعذّر تحميل ملف المزوّد',
              onRetry: _load,
            );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.orangePrimary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeader(provider, isDark, l10n),
          const SizedBox(height: 20),
          _buildReviewsHeader(isDark, l10n),
          const SizedBox(height: 10),
          if (_reviews.isEmpty)
            _buildEmptyReviews(isDark, l10n)
          else
            ..._reviews.map(
              (review) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ReviewCard(review: review, isDark: isDark),
              ),
            ),
          if (_reviews.length < _totalReviews) _buildLoadMore(isDark, l10n),
        ],
      ),
    );
  }

  Widget _buildHeader(
    ProviderDetails provider,
    bool isDark,
    AppLocalizations? l10n,
  ) {
    final primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final services = provider.services
        .map(
          (id) =>
              ServiceTypeDirectory.instance.nameFor(id, isArabic) ?? id,
        )
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          AvatarWidget(
            avatarId: provider.avatarId,
            role: 'provider',
            size: 88,
            photoUrl: provider.avatarUrl,
          ),
          const SizedBox(height: 12),
          Text(
            provider.workshopName.isNotEmpty
                ? provider.workshopName
                : provider.fullName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Zain',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primary,
            ),
          ),
          if (provider.fullName.isNotEmpty &&
              provider.workshopName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              provider.fullName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: secondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.star_rounded,
                size: 20,
                color: AppColors.notifRating,
              ),
              const SizedBox(width: 4),
              Text(
                provider.ratingLabel(l10n),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              l10n?.providerCompletedOrdersCount(_completedOrders) ??
                  '$_completedOrders طلب مكتمل',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
          ),
          if (services.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: services
                  .map(
                    (s) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orangePrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.orangePrimary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewsHeader(bool isDark, AppLocalizations? l10n) {
    final primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    return Row(
      children: [
        Icon(Icons.reviews_outlined, size: 20, color: AppColors.orangePrimary),
        const SizedBox(width: 8),
        Text(
          l10n?.providerReviewsTitle ?? 'آراء العملاء',
          style: TextStyle(
            fontFamily: 'Zain',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        const Spacer(),
        if (_totalReviews > 0)
          Text(
            '$_totalReviews',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: secondary,
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyReviews(bool isDark, AppLocalizations? l10n) {
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.rate_review_outlined, size: 36, color: secondary),
          const SizedBox(height: 8),
          Text(
            l10n?.providerReviewsEmpty ?? 'لا توجد آراء بعد',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMore(bool isDark, AppLocalizations? l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: SizedBox(
        width: double.infinity,
        height: 46,
        child: OutlinedButton(
          onPressed: _isLoadingMore ? null : _loadMore,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoadingMore
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.orangePrimary,
                  ),
                )
              : Text(
                  l10n?.providerReviewsLoadMore ?? 'عرض المزيد',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.orangePrimary,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.isDark});

  final ProviderReview review;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final service = review.serviceLabel(isArabic);
    final reviewer = (review.reviewerName ?? '').isNotEmpty
        ? review.reviewerName!
        : (l10n?.providerReviewAnonymous ?? 'عميل محور');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarWidget(
                avatarId: review.reviewerAvatarId,
                role: 'car_owner',
                size: 40,
                photoUrl: review.reviewerAvatarUrl,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reviewer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (index) => Icon(
                            index < review.rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 16,
                            color: index < review.rating
                                ? AppColors.notifRating
                                : secondary,
                          ),
                        ),
                        if (review.createdAt != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            MaterialLocalizations.of(
                              context,
                            ).formatMediumDate(review.createdAt!.toLocal()),
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              color: secondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.hasComment) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                height: 1.5,
                color: primary,
              ),
            ),
          ],
          if (service.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.orangePrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                service,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.orangePrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
