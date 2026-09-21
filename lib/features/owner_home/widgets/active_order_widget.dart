import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/order.dart';
import '../../provider_home/widgets/order_live_badge.dart';
import '../../provider_home/widgets/order_progress_stepper.dart';

/// بطاقة حالة الطلب النشط في رئيسية المالك: تظهر تلقائياً ما دام هناك
/// طلب غير نهائي (pending / priced / confirmed) وتختفي عند انتقاله لحالة
/// نهائية (completed / cancelled / rejected_*). تعرض بيانات الطلب مع
/// شريط تقدّم عمودي لمراحل: تم الإرسال ← استجابة المزوّد ← التأكيد ← الإتمام.
/// عند وصول عرض سعر من المزوّد (status == priced) تظهر أزرار «قبول / رفض»
/// داخل البطاقة مباشرة — فلا يضطر العميل لفتح شاشة التتبع لقبول العرض.
class ActiveOrderWidget extends StatefulWidget {
  final Order order;
  final String providerName;
  final VoidCallback? onTap;

  /// قِبل العرض — يُنفَّذ عرضاً في الرئيسية (RPC owner_accept_price).
  final Future<void> Function()? onAccept;

  /// رفض العرض — يُنفَّذ عرضاً في الرئيسية (RPC owner_reject_price).
  final Future<void> Function()? onReject;

  const ActiveOrderWidget({
    super.key,
    required this.order,
    this.providerName = '',
    this.onTap,
    this.onAccept,
    this.onReject,
  });

  /// ملصقات المراحل من منظور العميل (تطابق ترتيب مراحل المزوّد نفسها).
  static const List<String> _ownerStepLabels = [
    'تم الإرسال',
    'استجابة المزوّد',
    'التأكيد',
    'الإتمام',
  ];

  @override
  State<ActiveOrderWidget> createState() => _ActiveOrderWidgetState();
}

class _ActiveOrderWidgetState extends State<ActiveOrderWidget> {
  bool _isActing = false;

  Order get order => widget.order;
  String get providerName => widget.providerName;
  VoidCallback? get onTap => widget.onTap;

  Future<void> _run(Future<void> Function()? action) async {
    if (action == null || _isActing) return;
    setState(() => _isActing = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.orangePrimary.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.orangePrimary.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.statusLabel,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // كرة ملوّنة + توقيت حيّ: صفراء أثناء الانتظار وتصبح خضراء
                  // عند وصول المزوّد لخطوة ما قبل الإتمام (التأكيد) واكتمالها.
                  // ملاحظة: مساحة مرنة واحدة فقط (Expanded) بدلًا من
                  // Flexible + Spacer — فلو تشاركت الشريحتان لتقسّمت المساحة
                  // نصفين ووقف السهم في منتصف البطاقة على الشاشات العريضة.
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: OrderLiveBadge(
                        createdAt: order.createdAt,
                        dotColor: _liveDotColor,
                      ),
                    ),
                  ),
                  Icon(
                    // سهم اتجاهي: يشير نحو جهة القراءة — يسار في العربي (RTL)
                    // ويمين في الإنجليزي، بنفس نمط بانر S.O.S.
                    Localizations.localeOf(context).languageCode == 'ar'
                        ? Icons.arrow_back_ios_rounded
                        : Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                order.carDisplayName,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              if (providerName.isNotEmpty)
                Text(
                  'المزود: $providerName',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              if (order.offeredPrice != null) ...[
                const SizedBox(height: 12),
                _buildOfferBanner(context, isDark),
              ],
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              OrderProgressStepper(
                status: order.status,
                direction: Axis.vertical,
                labels: ActiveOrderWidget._ownerStepLabels,
              ),
              // أزرار القبول/الرفض في أسفل البطاقة تماماً (بنفس نمط زر
              // «إتمام الطلب» عند المزوّد) — تظهر فور وصول عرض السعر بدون
              // دخول شاشة التتبع، وتختفي بعد القرار عبر التحديث الحي.
              if (order.status == OrderStatus.priced) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isActing ? null : () => _run(widget.onAccept),
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text(
                          'قبول العرض',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isActing ? null : () => _run(widget.onReject),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        label: const Text(
                          'رفض العرض',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// بانر عرض السعر — يوضّح أن المزوّد هو من قدّم هذا السعر (وليست فقط
  /// قيمةً معلّقة في الهواء): بالتدرّج البرتقالي حال انتظار القرار،
  /// وبالأخضر بعد تأكيد السعر المتفق عليه.
  Widget _buildOfferBanner(BuildContext context, bool isDark) {
    final isPending = order.status == OrderStatus.priced;
    final accent = isPending ? AppColors.orangePrimary : AppColors.success;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.16),
            accent.withValues(alpha: 0.04),
          ],
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPending ? Icons.request_quote_rounded : Icons.verified_rounded,
              color: accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPending ? 'ردّ المزوّد على طلبك بعرض سعر' : 'السعر المُتفق عليه',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.offeredPrice!.toStringAsFixed(0)} ${order.currency}',
                  style: TextStyle(
                    fontFamily: 'Zain',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color get _statusColor {
    switch (order.status) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.priced:
        return AppColors.orangePrimary;
      case OrderStatus.confirmed:
        return AppColors.success;
      case OrderStatus.rejectedByProvider:
      case OrderStatus.rejectedByOwner:
      case OrderStatus.cancelled:
        return AppColors.error;
      case OrderStatus.completed:
        return AppColors.success;
    }
  }

  /// لون الكرة الحيّة: أصفر (انتظار) للطلبات المنتظرة، وأخضر لحظة وصول
  /// الطلب لمرحلة التأكيد (الخطوة قبل الإتمام من المزوّد) أو اكتماله.
  Color get _liveDotColor {
    switch (order.status) {
      case OrderStatus.confirmed:
      case OrderStatus.completed:
        return AppColors.success;
      case OrderStatus.rejectedByProvider:
      case OrderStatus.rejectedByOwner:
      case OrderStatus.cancelled:
        return AppColors.error;
      case OrderStatus.pending:
      case OrderStatus.priced:
        return AppColors.warning;
    }
  }
}