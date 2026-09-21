import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/avatar_config.dart';
import '../../../../core/models/order.dart';

enum TransactionEventKind { neutral, accent, success, failure }

/// حدث في مسار المعاملة — عُنوان + توقيت (حين تتوفر منه بيانات دقيقة).
class TransactionEvent {
  final String label;
  final DateTime? time;
  final TransactionEventKind kind;

  const TransactionEvent(
    this.label, {
    this.time,
    this.kind = TransactionEventKind.neutral,
  });
}

/// يعيد مسار المعاملة كأحداث قابلة للعرض حسب الحالة الفعلية للطلب.
/// الخادم لا يخزّن سجل انتقالات، لكن المسار نفسه حتمي: إرسال ← (استلام
/// المزوّد) ← (عرض سعر) ← (تأكيد) ثم إتمام أو فشل — والتوقيتات المتاحة
/// (created_at / updated_at) تُرفق لكل حدث متاح منها بدقة.
List<TransactionEvent> buildTransactionPath(Order order) {
  final events = <TransactionEvent>[
    TransactionEvent('تم إرسال الطلب', time: order.createdAt),
  ];

  if (order.providerId != null) {
    events.add(const TransactionEvent(
      'استلم المزوّد الطلب',
      kind: TransactionEventKind.accent,
    ));
  }

  final hasOffer = order.offeredPrice != null;
  if (hasOffer && order.status != OrderStatus.pending) {
    events.add(TransactionEvent(
      'قدّم المزوّد عرض السعر (${order.offeredPrice!.toStringAsFixed(0)} ${order.currency})',
      kind: TransactionEventKind.accent,
    ));
  }

  if (order.status == OrderStatus.confirmed ||
      order.status == OrderStatus.completed) {
    events.add(const TransactionEvent(
      'تم تأكيد العرض',
      kind: TransactionEventKind.accent,
    ));
  }

  switch (order.status) {
    case OrderStatus.completed:
      events.add(TransactionEvent(
        'تم إتمام المعاملة',
        time: order.updatedAt,
        kind: TransactionEventKind.success,
      ));
      break;
    case OrderStatus.rejectedByProvider:
      events.add(TransactionEvent(
        'رفض المزوّد المعاملة',
        time: order.updatedAt,
        kind: TransactionEventKind.failure,
      ));
      break;
    case OrderStatus.rejectedByOwner:
      events.add(TransactionEvent(
        'رفض العميل عرض السعر',
        time: order.updatedAt,
        kind: TransactionEventKind.failure,
      ));
      break;
    case OrderStatus.cancelled:
      events.add(TransactionEvent(
        'أُلغي الطلب (انتهت مهلة الاستجابة)',
        time: order.updatedAt,
        kind: TransactionEventKind.failure,
      ));
      break;
    case OrderStatus.pending:
    case OrderStatus.priced:
    case OrderStatus.confirmed:
      break;
  }

  return events;
}

/// سبب فشل المعاملة + الجهة الرافضة — null إذا لم تفشل المعاملة.
String? transactionFailureReason(Order order) {
  switch (order.status) {
    case OrderStatus.rejectedByProvider:
      return 'رفض من جهة المزوّد';
    case OrderStatus.rejectedByOwner:
      return 'رفض من جهة العميل';
    case OrderStatus.cancelled:
      return 'إلغاء تلقائي (انتهت مهلة الاستجابة)';
    case OrderStatus.completed:
    case OrderStatus.pending:
    case OrderStatus.priced:
    case OrderStatus.confirmed:
      return null;
  }
}

/// بطاقة «ملخّص المعاملة» لأي طلب منتهٍ: تاريخ المعاملة، تاريخ الإنهاء،
/// اسم المزوّد، ومسار الأحداث التي مرّت عليها (الاكتمال أو الفشل مع
/// توضيح الجهة الرافضة).
class TransactionSummaryCard extends StatelessWidget {
  final Order order;
  final String providerName;
  final String workshopName;
  final String? avatarId;
  final String? avatarUrl;

  TransactionSummaryCard({
    super.key,
    required this.order,
    this.providerName = '',
    this.workshopName = '',
    this.avatarId,
    this.avatarUrl,
  }) : assert(order.isFinalized, 'ملخّص المعاملة يُعرض للطلبات المنتهية فقط');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final events = buildTransactionPath(order);
    final failureReason = transactionFailureReason(order);
    final providerLine = _providerLine();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  color: AppColors.orangePrimary, size: 22),
              const SizedBox(width: 8),
              Text(
                'ملخّص المعاملة',
                style: TextStyle(
                  fontFamily: 'Zain',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildOutcome(context, isDark, failureReason),
          const SizedBox(height: 14),
          _buildInfoRow(
            context,
            isDark,
            icon: Icons.event_rounded,
            label: 'تاريخ المعاملة',
            value: _formatStamp(context, order.createdAt),
          ),
          if (order.updatedAt != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              isDark,
              icon: Icons.flag_rounded,
              label: 'تاريخ الإنهاء',
              value: _formatStamp(context, order.updatedAt),
            ),
          ],
          if (providerLine != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AvatarWidget(
                  avatarId: avatarId,
                  role: 'provider',
                  size: 36,
                  photoUrl: avatarUrl,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInfoRow(
                    context,
                    isDark,
                    icon: Icons.storefront_rounded,
                    label: 'المزوّد',
                    value: providerLine,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Text(
            'مسار المعاملة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          for (final event in events) ...[
            _buildEventRow(context, isDark, event),
            if (event != events.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  /// شارة النتيجة: خضراء «تمت المعاملة بنجاح» أو حمراء «لم تُنجز» مع
  /// توضيح الجهة الرافضة بشكل صريح.
  Widget _buildOutcome(
      BuildContext context, bool isDark, String? failureReason) {
    final completed = order.status == OrderStatus.completed;
    final color = completed ? AppColors.success : AppColors.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            completed ? Icons.done_all_rounded : Icons.cancel_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  completed ? 'تمت المعاملة بنجاح' : 'لم تُنجز المعاملة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (!completed && failureReason != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    failureReason,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _providerLine() {
    final name = (providerName.trim().isEmpty
            ? workshopName
            : providerName)
        .trim();
    if (name.isEmpty) return null;
    final workshop = workshopName.trim();
    if (workshop.isNotEmpty && workshop != name) {
      return '$name — $workshop';
    }
    return name;
  }

  Widget _buildInfoRow(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.orangePrimary),
        const SizedBox(width: 10),
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventRow(BuildContext context, bool isDark, TransactionEvent event) {
    final color = _eventColor(event.kind);
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(_eventIcon(event.kind), size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              if (event.time != null) ...[
                const SizedBox(height: 2),
                Text(
                  _formatStamp(context, event.time),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Color _eventColor(TransactionEventKind kind) {
    switch (kind) {
      case TransactionEventKind.neutral:
        return AppColors.orangePrimary;
      case TransactionEventKind.accent:
        return AppColors.orangePrimary;
      case TransactionEventKind.success:
        return AppColors.success;
      case TransactionEventKind.failure:
        return AppColors.error;
    }
  }

  IconData _eventIcon(TransactionEventKind kind) {
    switch (kind) {
      case TransactionEventKind.neutral:
        return Icons.send_rounded;
      case TransactionEventKind.accent:
        return Icons.price_check_rounded;
      case TransactionEventKind.success:
        return Icons.check_circle_rounded;
      case TransactionEventKind.failure:
        return Icons.cancel_rounded;
    }
  }

  String _formatStamp(BuildContext context, DateTime? date) {
    if (date == null) return '—';
    final local = date.toLocal();
    final material = MaterialLocalizations.of(context);
    final day = material.formatMediumDate(local);
    final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$day • $time';
  }
}