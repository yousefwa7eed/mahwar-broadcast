import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/order.dart';
import '../../../l10n/app_localizations.dart';

/// شريط تقدّم لمراحل الطلب النشط (أفقي أو عمودي):
/// الاسناد ← عرض السعر ← التأكيد ← الإتمام.
/// الدوائر متّصلة بخطوط تعبيراً عن المراحل المقطوعة، والمرحلة الحالية
/// مميّزة بنقطة بيضاء وسط دائرة البرتقالي. الاتجاه والملصقات قابلان
/// للتخصيص — تستخدمه شاشة المزوّد أفقياً بملصقاته الافتراضية، وشاشة
/// المالك عمودياً بملصقات من منظور العميل (تم الإرسال ← استجابة المزوّد).
class OrderProgressStepper extends StatelessWidget {
  final OrderStatus status;
  final Axis direction;
  final List<String>? labels;

  const OrderProgressStepper({
    super.key,
    required this.status,
    this.direction = Axis.horizontal,
    this.labels,
  });

  static const double _nodeSize = 26;
  static const double _verticalConnectorHeight = 24;

  /// فهرس المرحلة الحالية (0..3) المشتق من حالة الطلب في قاعدة البيانات.
  int get _activeIndex {
    switch (status) {
      case OrderStatus.priced:
        return 1;
      case OrderStatus.confirmed:
        return 2;
      case OrderStatus.completed:
        return 3;
      case OrderStatus.pending:
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final l10n = AppLocalizations.of(context);
    final stepLabels = labels ??
        [
          l10n?.stepAssigned ?? 'الاسناد',
          l10n?.stepPriceOffer ?? 'عرض السعر',
          l10n?.stepConfirmation ?? 'التأكيد',
          l10n?.stepCompletion ?? 'الإتمام',
        ];

    return direction == Axis.vertical
        ? _buildVertical(active, stepLabels, muted)
        : _buildHorizontal(active, stepLabels, muted);
  }

  Widget _buildHorizontal(int active, List<String> stepLabels, Color muted) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stepLabels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (i > 0)
                      Expanded(
                        child: _connectorLine(done: (i - 1) < active, muted: muted),
                      ),
                    _node(i, active: active, muted: muted),
                    if (i < stepLabels.length - 1)
                      Expanded(
                        child: _connectorLine(done: i < active, muted: muted),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  stepLabels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    fontWeight: i <= active ? FontWeight.bold : FontWeight.normal,
                    color: i <= active ? AppColors.orangePrimary : muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVertical(int active, List<String> stepLabels, Color muted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stepLabels.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  _node(i, active: active, muted: muted),
                  if (i < stepLabels.length - 1)
                    _verticalConnector(done: i < active, muted: muted),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    stepLabels[i],
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: i <= active ? FontWeight.bold : FontWeight.normal,
                      color: i <= active ? AppColors.orangePrimary : muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  bool _isDone(int index, int active) => index < active;
  bool _isActive(int index, int active) => index == active;

  Widget _node(int index, {required int active, required Color muted}) {
    final done = _isDone(index, active);
    final isActive = _isActive(index, active);

    return Container(
      width: _nodeSize,
      height: _nodeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (done || isActive) ? AppColors.orangePrimary : Colors.transparent,
        border: (done || isActive) ? null : Border.all(color: muted.withValues(alpha: 0.6), width: 2),
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : isActive
          ? Padding(
              padding: const EdgeInsets.all(8),
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            )
          : null,
    );
  }

  Widget _connectorLine({required bool done, required Color muted}) {
    return Container(
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: done ? AppColors.orangePrimary : muted.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _verticalConnector({required bool done, required Color muted}) {
    return Container(
      width: 3,
      height: _verticalConnectorHeight,
      margin: EdgeInsets.symmetric(horizontal: (_nodeSize - 3) / 2),
      decoration: BoxDecoration(
        color: done ? AppColors.orangePrimary : muted.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}