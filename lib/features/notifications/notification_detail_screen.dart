import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/notification_model.dart';
import '../../core/utils/supabase_time.dart';
import '../../l10n/app_localizations.dart';

/// شاشة التفاصيل الكاملة لإشعار:
///   - إشعار عام (broadcast): العنوان والنص كاملاً + صورة الإشعار (إن وُجدت)
///     ووقت الإرسال.
///   - إشعار تقييم (rating_received) للمزوّد: مقدار التقييم (نجوم + X من 5)
///     ومن أي عميل وتاريخ التقييم (والتعليق إن وُجد)، مع زر «عرض تفاصيل
///     المعاملة» يفتح شاشة التتبع/ملخّص المعاملة من سجل الطلبات.
/// يُفتح من لمس الإشعار في قوائم الإشعارات (صفحة الإشعارات + تبويب الرئيسية
/// للعميل والمزوّد) ومن لمس إشعار الدفع نفسه.
class NotificationDetailScreen extends StatefulWidget {
  const NotificationDetailScreen({super.key, required this.notification});

  final NotificationModel notification;

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  // بيانات التقييم (تُجلب من جدول ratings حين يكون نوع الإشعار تقييمًا).
  int? _rating;
  String? _comment;
  DateTime? _ratedAt;
  String? _customerName;
  bool _isLoadingRating = false;

  bool get _isRating => widget.notification.type == 'rating_received';

  @override
  void initState() {
    super.initState();
    if (_isRating) {
      _rating = (widget.notification.metadata?['rating'] as num?)?.toInt();
      if (widget.notification.orderId != null) {
        _isLoadingRating = true;
        _loadRating();
      }
    }
  }

  /// يجلب تفاصيل التقييم من جدول ratings (المصدر الموثوق: القيمة الفعلية
  /// والتعليق وتاريخ التقييم والمعرّف)، ثم اسم العميل عبر get_public_profile.
  /// إن فشل الجلب نكتفي بالقيمة الموجودة في metadata الإشعار.
  Future<void> _loadRating() async {
    final orderId = widget.notification.orderId;
    if (orderId == null) return;
    // نؤجّل العمل للميكروتاسك التالي حتى لا نُستدعي setState أثناء initState.
    await Future<void>.value();

    try {
      final row = await Supabase.instance.client
          .from('ratings')
          .select('rating, comment, created_at, user_id')
          .eq('order_id', orderId)
          .maybeSingle();

      if (row != null) {
        _rating = (row['rating'] as num?)?.toInt() ?? _rating;
        _comment = row['comment'] as String?;
        _ratedAt = parseSupabaseTimestamp(row['created_at']);

        final ownerId = row['user_id'] as String?;
        if (ownerId != null) {
          final profile = await Supabase.instance.client.rpc(
            'get_public_profile',
            params: {'p_user_id': ownerId},
          );
          if (profile is List && profile.isNotEmpty) {
            final name =
                (profile.first as Map)['full_name'] as String?;
            if (name != null && name.trim().isNotEmpty) {
              _customerName = name.trim();
            }
          }
        }
      }
    } catch (_) {
      // تجاهل — نعرض ما توفّر (قيمة metadata إن وُجدت).
    }
    if (mounted) setState(() => _isLoadingRating = false);
  }

  /// "أُرسل في <تاريخ> • <وقت>" — التاريخ/الوقت منسّقان حسب لغة التطبيق.
  String _sentAtLabel(BuildContext context) {
    final created = widget.notification.createdAt?.toLocal();
    if (created == null) return '';
    return _dateTimeLabel(context, created, 'أُرسل في');
  }

  String _dateTimeLabel(BuildContext context, DateTime value, String prefix) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final local = value.toLocal();
    final date = material.formatMediumDate(local);
    final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    final label = prefix == 'أُرسل في'
        ? (l10n?.notificationSentAt ?? 'أُرسل في')
        : prefix;
    return '$label $date • $time';
  }

  String _kindLabel(AppLocalizations? l10n) {
    switch (widget.notification.type) {
      case 'broadcast':
        return l10n?.notificationBroadcast ?? 'إشعار عام';
      case 'rating_received':
        return l10n?.notificationRatingLabel ?? 'تقييم';
      default:
        return l10n?.notificationDetails ?? 'تفاصيل الإشعار';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final notification = widget.notification;
    final imageUrl = notification.imageUrl;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n?.notificationDetails ?? 'تفاصيل الإشعار',
          style: TextStyle(
            fontFamily: 'Zain',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (imageUrl != null && !_isRating) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrl,
                    height: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 200,
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.orangePrimary,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: notification.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      notification.icon,
                      color: notification.color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _kindLabel(l10n),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: notification.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _sentAtLabel(context),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_isRating)
                _buildRatingCard(context, isDark, primary, secondary)
              else
                _buildGenericCard(context, isDark, primary, secondary),
            ],
          ),
        ),
      ),
    );
  }

  /// بطاقة الإشعار العام: العنوان + النص الكامل.
  Widget _buildGenericCard(
    BuildContext context,
    bool isDark,
    Color primary,
    Color secondary,
  ) {
    final l10n = AppLocalizations.of(context);
    final notification = widget.notification;
    final title = notification.localizedTitle(l10n);
    final body = notification.localizedBody(l10n);
    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Zain',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primary,
            ),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              body,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                height: 1.6,
                color: secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// بطاقة التقييم: نجوم + X من 5 + اسم العميل + تاريخ التقييم + التعليق +
  /// زر «عرض تفاصيل المعاملة» (يفتح شاشة التتبع/ملخّص المعاملة إن وُجد orderId).
  Widget _buildRatingCard(
    BuildContext context,
    bool isDark,
    Color primary,
    Color secondary,
  ) {
    final l10n = AppLocalizations.of(context);
    final notification = widget.notification;
    final orderId = notification.orderId;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            notification.localizedTitle(l10n),
            style: TextStyle(
              fontFamily: 'Zain',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primary,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingRating)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.orangePrimary,
                  strokeWidth: 2,
                ),
              ),
            )
          else ...[
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final filled = index < (_rating ?? 0);
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: filled
                        ? AppColors.notifRating
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                    size: 34,
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _rating != null
                    ? (l10n?.notificationRatingOfFive('$_rating') ??
                        '$_rating من 5')
                    : (l10n?.notificationTitleRatingReceived ?? 'تقييم جديد'),
                style: TextStyle(
                  fontFamily: 'Zain',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _infoRow(
              Icons.person_rounded,
              l10n?.notificationFromCustomer ?? 'من العميل',
              _customerName ?? (l10n?.notificationCustomerFallback ?? 'العميل'),
              primary,
              secondary,
            ),
            const SizedBox(height: 12),
            _infoRow(
              Icons.event_rounded,
              l10n?.notificationRatingDate ?? 'تاريخ التقييم',
              _ratedAt != null
                  ? _dateTimeLabel(context, _ratedAt!, '')
                      .trim()
                  : (notification.createdAt != null
                      ? _dateTimeLabel(
                              context, notification.createdAt!, '')
                          .trim()
                      : '—'),
              primary,
              secondary,
            ),
            if (_comment != null && _comment!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _infoRow(
                Icons.comment_rounded,
                l10n?.notificationCommentLabel ?? 'تعليق',
                _comment!.trim(),
                primary,
                secondary,
              ),
            ],
          ],
          if (orderId != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () =>
                    context.push('/request/track?orderId=$orderId'),
                icon: const Icon(Icons.receipt_long_rounded,
                    color: Colors.white, size: 20),
                label: Text(
                  l10n?.viewTransactionDetails ?? 'عرض تفاصيل المعاملة',
                  style: const TextStyle(
                    fontFamily: 'Zain',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orangePrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
    Color primary,
    Color secondary,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.orangePrimary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: secondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: primary,
            ),
          ),
        ),
      ],
    );
  }
}
