import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/auth_cubit.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/notification_model.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/utils/supabase_time.dart';
import '../../core/widgets/offline_view.dart';
import '../../l10n/app_localizations.dart';

/// شاشة التفاصيل الكاملة لإشعار:
///   - إشعار عام (broadcast): العنوان والنص كاملًا + صورة الإشعار (إن وُجدت).
///   - إشعار تقييم (rating_received) للمزوّد: النجوم والتعليق والتاريخ.
///   - أي إشعار مرتبط بطلب: نص الإشعار + زر «تفاصيل الطلب» يوجّه المزوّد إلى
///     شاشة تفاصيل الطلب الخاصة به والمالك إلى شاشة التتبع.
///
/// تُفتح بالمعرّف (`notificationId`) من الـ URL — من قائمة الإشعارات أو من إشعار
/// الدفع — فتجلب الصفّ بنفسها مقيّدًا بـ `user_id` الجلسة الحالية. هذا يمنع فتح
/// إشعار حساب آخر على نفس الجهاز، ويجعل المسار قابلًا للاستئناف بعد إعادة
/// تشغيل التطبيق (extra لا يبقى).
class NotificationDetailScreen extends StatefulWidget {
  const NotificationDetailScreen({
    super.key,
    this.notification,
    this.notificationId,
  }) : assert(
         notification != null || notificationId != null,
         'Either notification or notificationId is required',
       );

  final NotificationModel? notification;
  final String? notificationId;

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  NotificationModel? _notification;
  bool _isLoadingNotification = false;
  bool _notificationFailed = false;

  /// فشل بسبب انقطاع الشبكة — تُعرض رسالة «لا يوجد اتصال» بدل خطأ عام.
  bool _offline = false;

  // بيانات التقييم (تُجلب من جدول ratings حين يكون نوع الإشعار تقييمًا).
  int? _rating;
  String? _comment;
  DateTime? _ratedAt;
  String? _customerName;
  bool _isLoadingRating = false;

  /// دور الجلسة الحالية — يحدد وجهة زر «تفاصيل الطلب».
  String? _role;

  bool get _isRating => _notification?.type == 'rating_received';

  @override
  void initState() {
    super.initState();
    _notification = widget.notification;
    final cubit = context.read<AuthCubit>();
    _role = cubit.cachedRole;
    if (_role == null) {
      cubit.resolveCurrentRole().then((role) {
        if (mounted) setState(() => _role = role);
      });
    }
    if (_notification != null) {
      _onNotificationReady();
    } else {
      _isLoadingNotification = true;
      _loadNotification();
    }
  }

  Future<void> _loadNotification() async {
    if (!_isLoadingNotification && mounted) {
      setState(() {
        _isLoadingNotification = true;
        _notificationFailed = false;
        _offline = false;
      });
    }
    final id = widget.notificationId;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (id == null || id.isEmpty || userId == null) {
      if (mounted) {
        setState(() {
          _isLoadingNotification = false;
          _notificationFailed = true;
        });
      }
      return;
    }
    try {
      final row = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('id', id)
          .eq('user_id', userId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _isLoadingNotification = false;
        _notificationFailed = row == null;
        _notification = row == null ? null : NotificationModel.fromJson(row);
      });
      if (_notification != null) _onNotificationReady();
    } catch (_) {
      final failure = await classifyLoadFailure();
      if (!mounted) return;
      setState(() {
        _isLoadingNotification = false;
        _notificationFailed = true;
        _offline = failure == LoadFailure.offline;
      });
    }
  }

  void _onNotificationReady() {
    final notification = _notification;
    if (notification == null) return;
    if (notification.type != 'rating_received') return;
    _rating = (notification.metadata?['rating'] as num?)?.toInt();
    if (notification.orderId != null) {
      _isLoadingRating = true;
      _loadRating();
    }
  }

  /// يجلب تفاصيل التقييم من جدول ratings (المصدر الموثوق: القيمة الفعلية
  /// والتعليق وتاريخ التقييم والمعرّف)، ثم اسم العميل عبر get_public_profile.
  /// إن فشل الجلب نكتفي بالقيمة الموجودة في metadata الإشعار.
  Future<void> _loadRating() async {
    final orderId = _notification?.orderId;
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
            final name = (profile.first as Map)['full_name'] as String?;
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
    final created = _notification?.createdAt?.toLocal();
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
    switch (_notification?.type) {
      case 'broadcast':
        return l10n?.notificationBroadcast ?? 'إشعار عام';
      case 'rating_received':
        return l10n?.notificationRatingLabel ?? 'تقييم';
      default:
        return l10n?.notificationDetails ?? 'تفاصيل الإشعار';
    }
  }

  /// زر تفاصيل الطلب حسب دور الجلسة الحالية: المزوّد → شاشة تفاصيل الطلب
  /// الخاصة به (تقييم العميل + بيانات الطلب)، والمالك → شاشة التتبع.
  void _openOrder(String orderId) {
    if (_role == 'provider') {
      context.push('/orders/provider/detail?orderId=$orderId');
    } else {
      context.push('/request/track?orderId=$orderId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final notification = _notification;

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
        child: _isLoadingNotification
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.orangePrimary,
                ),
              )
            : _offline
            ? OfflineView(onRetry: _loadNotification)
            : notification == null
            ? _buildLoadError(secondary, l10n)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (notification.imageUrl != null && !_isRating) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          notification.imageUrl!,
                          height: 200,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 200,
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
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
                          errorBuilder: (context, error, stack) =>
                              const SizedBox.shrink(),
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

  Widget _buildLoadError(Color secondary, AppLocalizations? l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined, size: 48, color: secondary),
            const SizedBox(height: 12),
            Text(
              _notificationFailed
                  ? (l10n?.notificationLoadFailed ?? 'تعذّر تحميل الإشعار')
                  : (l10n?.notificationNotFound ?? 'الإشعار غير موجود'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: secondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoadingNotification = true;
                  _notificationFailed = false;
                });
                _loadNotification();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orangePrimary,
              ),
              child: Text(
                l10n?.retry ?? 'إعادة المحاولة',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بطاقة الإشعار العام: العنوان + النص الكامل + زر تفاصيل الطلب إن ارتبط
  /// الإشعار بطلب.
  Widget _buildGenericCard(
    BuildContext context,
    bool isDark,
    Color primary,
    Color secondary,
  ) {
    final l10n = AppLocalizations.of(context);
    final notification = _notification!;
    final title = notification.localizedTitle(l10n);
    final body = notification.localizedBody(l10n);
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
          if (orderId != null) ...[
            const SizedBox(height: 20),
            _buildOrderCta(l10n, () => _openOrder(orderId)),
          ],
        ],
      ),
    );
  }

  /// بطاقة التقييم: نجوم + X من 5 + اسم العميل + تاريخ التقييم + التعليق +
  /// زر «تفاصيل الطلب» (يفتح شاشة تفاصيل المزوّد أو تتبع المالك).
  Widget _buildRatingCard(
    BuildContext context,
    bool isDark,
    Color primary,
    Color secondary,
  ) {
    final l10n = AppLocalizations.of(context);
    final notification = _notification!;
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
                  ? _dateTimeLabel(context, _ratedAt!, '').trim()
                  : (notification.createdAt != null
                        ? _dateTimeLabel(
                            context,
                            notification.createdAt!,
                            '',
                          ).trim()
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
            _buildOrderCta(l10n, () => _openOrder(orderId)),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderCta(AppLocalizations? l10n, VoidCallback onPressed) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(
          Icons.receipt_long_rounded,
          color: Colors.white,
          size: 20,
        ),
        label: Text(
          l10n?.orderDetails ?? 'تفاصيل الطلب',
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
            style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: primary),
          ),
        ),
      ],
    );
  }
}
