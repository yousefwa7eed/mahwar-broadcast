import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/order.dart';
import '../../../l10n/app_localizations.dart';

class OrderStatusIndicator extends StatelessWidget {
  final OrderStatus status;

  const OrderStatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_statusIcon, color: _statusColor, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            _statusTitle(l10n),
            style: TextStyle(
              fontFamily: 'Zain',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _statusSubtitle(l10n),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          if (status == OrderStatus.pending) ...[
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.orangePrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color get _statusColor {
    switch (status) {
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

  IconData get _statusIcon {
    switch (status) {
      case OrderStatus.pending:
        return Icons.hourglass_empty_rounded;
      case OrderStatus.priced:
        return Icons.request_quote_rounded;
      case OrderStatus.confirmed:
        return Icons.check_circle_rounded;
      case OrderStatus.rejectedByProvider:
      case OrderStatus.rejectedByOwner:
        return Icons.cancel_rounded;
      case OrderStatus.cancelled:
        return Icons.stop_circle_rounded;
      case OrderStatus.completed:
        return Icons.done_all_rounded;
    }
  }

  String _statusTitle(AppLocalizations? l10n) {
    switch (status) {
      case OrderStatus.pending:
        return l10n?.searchingProviderTitle ?? 'جاري البحث عن مزود...';
      case OrderStatus.priced:
        return l10n?.priceOfferReceived ?? 'تم استلام عرض سعر!';
      case OrderStatus.confirmed:
        return l10n?.orderConfirmed ?? 'تم تأكيد الطلب';
      case OrderStatus.rejectedByProvider:
        return l10n?.rejectedByProvider ?? 'تم رفض الطلب من المزود';
      case OrderStatus.rejectedByOwner:
        return l10n?.priceRejected ?? 'تم رفض عرض السعر';
      case OrderStatus.cancelled:
        return l10n?.orderCancelled ?? 'تم إلغاء الطلب';
      case OrderStatus.completed:
        return l10n?.orderStatusCompletedTitle ?? 'تم إتمام الطلب';
    }
  }

  String _statusSubtitle(AppLocalizations? l10n) {
    switch (status) {
      case OrderStatus.pending:
        return l10n?.searchingProviderSub ?? 'نبحث عن أقرب مزود خدمة متاح لمساعدتك';
      case OrderStatus.priced:
        return l10n?.reviewPriceOfferSub ?? 'يمكنك مراجعة عرض السعر والقبول أو الرفض';
      case OrderStatus.confirmed:
        return l10n?.providerOnWaySub ?? 'المزود في طريقه إليك الآن';
      case OrderStatus.rejectedByProvider:
        return l10n?.resendOrChooseOther ?? 'يمكنك إعادة إرسال الطلب أو اختيار مزود آخر';
      case OrderStatus.rejectedByOwner:
        return l10n?.orderCancelledSub ?? 'تم إلغاء هذا الطلب';
      case OrderStatus.cancelled:
        return l10n?.orderCancelledSub ?? 'تم إلغاء هذا الطلب';
      case OrderStatus.completed:
        return l10n?.orderStatusCompletedSubtitle ??
            'تمت الخدمة بنجاح، نأمل أن تكون تجربتك جيدة';
    }
  }
}
