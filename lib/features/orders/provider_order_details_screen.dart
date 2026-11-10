import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/order.dart';
import '../../core/services/service_type_directory.dart';
import '../../l10n/app_localizations.dart';

/// شاشة تفاصيل الطلب من منظور المزوّد: تُفتح من بطاقة الطلب في سجل المزوّد
/// ومن أي إشعار مرتبط بطلب عبر زر «تفاصيل الطلب».
///
/// تعرض بيانات الطلب التي يحتاجها المزوّد للعمل عليه (الحالة، الخدمة، السيارة،
/// العنوان والملاحظات، السعر المعروض)، ثم **تقييم العميل** لهذه المعاملة إن
/// وُجد — نجوم + تعليق + تاريخ — قراءةً فقط. لا تُعرض أي بيانات شخصية إضافية
/// عن العميل (لا رقم ولا اسم)؛ الـ RLS على orders/ratings يقصر القراءة على
/// المزوّد المرتبط بالطلب.
class ProviderOrderDetailsScreen extends StatefulWidget {
  const ProviderOrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<ProviderOrderDetailsScreen> createState() =>
      _ProviderOrderDetailsScreenState();
}

class _ProviderOrderDetailsScreenState
    extends State<ProviderOrderDetailsScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  Order? _order;
  String? _serviceName;
  int? _rating;
  String? _ratingComment;
  DateTime? _ratedAt;
  bool _isLoading = true;
  bool _isLoadingRating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    try {
      final response = await _client
          .from('orders')
          .select()
          .eq('id', widget.orderId)
          .maybeSingle();

      if (response == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _order = null;
          });
        }
        return;
      }

      final order = Order.fromJson(response);
      await ServiceTypeDirectory.instance.ensureLoaded();
      final serviceName = ServiceTypeDirectory.instance.nameFor(
        order.serviceTypeId,
        isArabic,
      );

      if (!mounted) return;
      setState(() {
        _order = order;
        _serviceName = serviceName;
        _isLoading = false;
      });

      if (order.status == OrderStatus.completed) {
        setState(() => _isLoadingRating = true);
        await _loadRating();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// تقييم العميل لهذا الطلب — سياسة RLS على ratings تتيح للمزوّد المرتبط
  /// بالطلب قراءته (provider_id = auth.uid()). لا نطلب أي جدول آخر.
  Future<void> _loadRating() async {
    try {
      final row = await _client
          .from('ratings')
          .select('rating, comment, created_at')
          .eq('order_id', widget.orderId)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() {
          _rating = (row['rating'] as num?)?.toInt();
          _ratingComment = row['comment'] as String?;
          _ratedAt = DateTime.tryParse(row['created_at'] as String? ?? '');
        });
      }
    } catch (_) {
      // تعذّر جلب التقييم لا يمنع عرض تفاصيل الطلب.
    }
    if (mounted) setState(() => _isLoadingRating = false);
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
          l10n?.orderDetails ?? 'تفاصيل الطلب',
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

  Widget _buildBody(BuildContext context, bool isDark, AppLocalizations? l10n) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.orangePrimary),
      );
    }

    final order = _order;
    if (order == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n?.orderDetailsLoadFailed ?? 'تعذّر تحميل تفاصيل الطلب',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.orangePrimary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeader(order, isDark, l10n),
          const SizedBox(height: 16),
          _buildInfoCard(order, isDark, l10n),
          if (order.status == OrderStatus.completed) ...[
            const SizedBox(height: 16),
            _buildRatingCard(isDark, l10n),
          ],
          const SizedBox(height: 24),
          _buildAction(order, l10n),
        ],
      ),
    );
  }

  Widget _buildHeader(Order order, bool isDark, AppLocalizations? l10n) {
    final statusColor = _statusColor(order.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              order.statusLabel(l10n),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          const Spacer(),
          if (order.createdAt != null)
            Text(
              _formatDateTime(context, order.createdAt!),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Order order, bool isDark, AppLocalizations? l10n) {
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    return Container(
      padding: const EdgeInsets.all(16),
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
          _infoRow(
            Icons.build_circle_outlined,
            l10n?.serviceLabel ?? 'خدمة:',
            _serviceName ??
                ServiceTypeDirectory.instance.nameFor(
                  order.serviceTypeId,
                  Localizations.localeOf(context).languageCode == 'ar',
                ) ??
                order.serviceTypeId,
            primary,
            secondary,
          ),
          const SizedBox(height: 12),
          _infoRow(
            Icons.directions_car_rounded,
            l10n?.carLabel ?? 'السيارة:',
            [
              order.carDisplayName,
              order.carDetails,
            ].where((v) => v.trim().isNotEmpty).join(' · '),
            primary,
            secondary,
          ),
          if ((order.addressText ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoRow(
              Icons.location_on_outlined,
              l10n?.addressLabel ?? 'العنوان:',
              order.addressText!.trim(),
              primary,
              secondary,
            ),
          ],
          if ((order.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoRow(
              Icons.notes_rounded,
              l10n?.notesLabel ?? 'ملاحظات:',
              order.notes!.trim(),
              primary,
              secondary,
            ),
          ],
          if (order.offeredPrice != null) ...[
            const SizedBox(height: 12),
            _infoRow(
              Icons.payments_outlined,
              l10n?.offerPrice ?? 'تقديم عرض سعر',
              '${order.offeredPrice!.toStringAsFixed(0)} ${order.currency == 'EGP' ? (l10n?.egp ?? 'ج.م') : order.currency}',
              primary,
              secondary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingCard(bool isDark, AppLocalizations? l10n) {
    final primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    return Container(
      padding: const EdgeInsets.all(16),
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
            l10n?.customerRating ?? 'تقييم العميل',
            style: TextStyle(
              fontFamily: 'Zain',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primary,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingRating)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(
                  color: AppColors.orangePrimary,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_rating == null)
            Text(
              l10n?.customerRatingEmpty ?? 'لم يقيّم العميل هذه المعاملة بعد',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: secondary,
              ),
            )
          else ...[
            Row(
              children: [
                ...List.generate(5, (index) {
                  final filled = index < _rating!;
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: filled ? AppColors.notifRating : secondary,
                    size: 28,
                  );
                }),
                const SizedBox(width: 8),
                Text(
                  l10n?.notificationRatingOfFive('$_rating') ?? '$_rating من 5',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ],
            ),
            if ((_ratingComment ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _ratingComment!.trim(),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  height: 1.5,
                  color: secondary,
                ),
              ),
            ],
            if (_ratedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                _formatDateTime(context, _ratedAt!),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: secondary,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAction(Order order, AppLocalizations? l10n) {
    if (order.status == OrderStatus.pending) {
      return SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: () => context.push('/request/quote?orderId=${order.id}'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.orangePrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            l10n?.providePriceOffer ?? 'تقديم عرض سعر',
            style: const TextStyle(
              fontFamily: 'Zain',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
    if (order.status == OrderStatus.confirmed ||
        order.status == OrderStatus.priced) {
      return SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: () => context.push('/request/track?orderId=${order.id}'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.orangePrimary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            l10n?.trackOrder ?? 'تتبع الطلب',
            style: const TextStyle(
              fontFamily: 'Zain',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.orangePrimary,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
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
          '$label ',
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

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.priced:
        return AppColors.orangePrimary;
      case OrderStatus.confirmed:
      case OrderStatus.completed:
        return AppColors.success;
      case OrderStatus.rejectedByProvider:
      case OrderStatus.rejectedByOwner:
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  String _formatDateTime(BuildContext context, DateTime value) {
    final local = value.toLocal();
    final material = MaterialLocalizations.of(context);
    final day = material.formatMediumDate(local);
    final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$day • $time';
  }
}
