import '../../orders/widgets/order_contact_card.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/order.dart';
import '../../../core/widgets/attachments_gallery.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../l10n/app_localizations.dart';
import 'order_live_badge.dart';
import 'order_progress_stepper.dart';

/// بطاقة الطلب النشط في لوحة تحكم المزوّد (مرحلة عرض السعر أو التأكيد).
/// تعرض بيانات العميل والسيارة والموقع، مع شريط تقدّم المراحل
/// (الاسناد ← عرض السعر ← التأكيد ← الإتمام)، وزر إتمام الطلب عند التأكيد.
class ActiveOrderCard extends StatelessWidget {
  final String customerName;
  final String carMake;
  final String carModel;
  final int carYear;
  final String? brandId;
  final String? carTrim;
  final String? carColor;
  final String? carPlate;
  final String issueType;
  final String address;
  final List<String> attachments;
  final String orderId;
  final OrderStatus status;
  final String statusLabel;
  final double? offeredPrice;
  final DateTime? createdAt;
  final VoidCallback? onComplete;
  final VoidCallback? onLocationTap;

  const ActiveOrderCard({
    super.key,
    this.customerName = '',
    required this.carMake,
    required this.carModel,
    required this.carYear,
    this.brandId,
    this.carTrim,
    this.carColor,
    this.carPlate,
    required this.issueType,
    required this.address,
    this.attachments = const [],
    this.orderId = '',
    required this.status,
    required this.statusLabel,
    this.offeredPrice,
    this.createdAt,
    this.onComplete,
    this.onLocationTap,
  });

  String _carDetails() => [
        if (carTrim != null && carTrim!.trim().isNotEmpty) carTrim!,
        if (carColor != null && carColor!.trim().isNotEmpty) carColor!,
        if (carPlate != null && carPlate!.trim().isNotEmpty) carPlate!,
      ].join(' · ');

  Color get _statusColor {
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final customerDisplayName = customerName.isEmpty
        ? (l10n?.notificationCustomerFallback ?? 'العميل')
        : customerName;
    final carDetails = _carDetails();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status chip + offered price
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // دائرة خضراء + مدة الطلب — توحي أن الطلب جديد وحالي.
              // مساحة مرنة واحدة (Expanded) لئلا تتقاسمها مساحتان فيتوسّط
              // الزر/السعر على الشاشات العريضة (التابلت).
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OrderLiveBadge(
                    createdAt: createdAt,
                    dotColor: AppColors.success,
                  ),
                ),
              ),
              if (offeredPrice != null) ...[
                Icon(
                  Icons.price_change_rounded,
                  size: 16,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${offeredPrice!.toStringAsFixed(0)} ${l10n?.egp ?? 'ج.م'}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.orangePrimary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Customer name
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 20, color: AppColors.orangePrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  customerDisplayName,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Car info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: BrandMark(brandId: brandId, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$carMake $carModel $carYear',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    if (carDetails.isNotEmpty)
                      Text(
                        carDetails,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Service type
          Row(
            children: [
              const Icon(Icons.build_outlined, size: 16, color: AppColors.orangePrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  issueType,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Location (Arabic address) — tap to open full map
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onLocationTap,
            child: Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address.isEmpty ? (l10n?.locationUnavailable ?? 'الموقع غير متاح') : address,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onLocationTap != null)
                  Icon(
                    Icons.open_in_full_rounded,
                    size: 14,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
              ],
            ),
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            AttachmentsGallery(urls: attachments, height: 70),
          ],
          if (orderId.isNotEmpty) ...[
            const SizedBox(height: 10),
            OrderContactCard(orderId: orderId, status: status.name),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Progress stepper
          OrderProgressStepper(status: status),
          const SizedBox(height: 14),

          // Footer action
          _buildFooter(context, isDark),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case OrderStatus.confirmed:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onComplete,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: Text(
                  l10n?.completeOrder ?? 'إتمام الطلب',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );
      case OrderStatus.pending:
      case OrderStatus.priced:
      default:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.orangePrimary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.orangePrimary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top_rounded, size: 18, color: AppColors.orangePrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status == OrderStatus.pending
                      ? (l10n?.waitingYourResponse ?? 'بانتظار ردّك على الطلب')
                      : (l10n?.waitingCustomerConfirmation ??
                          'بانتظار تأكيد العميل للعرض'),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.orangePrimary,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}
