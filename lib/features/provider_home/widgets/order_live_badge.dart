import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/server_clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_ar.dart';

/// شارة حيّة لحالة الطلب: دائرة ملوّنة + مدة منذ إنشاء الطلب («منذ X دقيقة»)
/// تُحدَّث تلقائياً كل ٣٠ ثانية. على بطاقة المزوّد تكون الدائرة خضراء
/// (توحي بأن الطلب جديد وحالي)، وعند العميل تتحوّل من أصفر (انتظار) إلى
/// أخضر لحظة وصول الطلب لمرحلة التأكيد (الخطوة قبل إتمام المزوّد) واكتماله.
class OrderLiveBadge extends StatefulWidget {
  final DateTime? createdAt;
  final Color dotColor;

  const OrderLiveBadge({
    super.key,
    required this.createdAt,
    required this.dotColor,
  });

  /// يحوّل المدة المنقضية منذ [createdAt] إلى نص عربي مختصر مثل «الآن» أو
  /// «منذ ٥ دقائق». تُحسب مقابل UTC (ساعة السيرفر) حتى لا تختلف بساعة الجهاز.
  /// [asOf] معرَّض للاختبار فقط — عند الغياب يُستخدم ServerClock.instance.now.
  static String formatElapsed(
    DateTime? createdAt, {
    DateTime? asOf,
    AppLocalizations? l10n,
  }) {
    if (createdAt == null) return '';
    final t = l10n ?? AppLocalizationsAr();
    final now = (asOf ?? ServerClock.instance.now).toUtc();
    final diff = now.isBefore(createdAt) ? Duration.zero : now.difference(createdAt);
    if (diff.inMinutes < 1) return t.notificationTimeNow;
    if (diff.inMinutes < 60) return t.notificationTimeMinutes(diff.inMinutes);
    if (diff.inHours < 24) return t.notificationTimeHours(diff.inHours);
    return t.notificationTimeDays(diff.inDays);
  }

  @override
  State<OrderLiveBadge> createState() => _OrderLiveBadgeState();
}

class _OrderLiveBadgeState extends State<OrderLiveBadge> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.createdAt != null) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.createdAt == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        // Flexible داخل المساحة المرنة الوحيدة بالبطاقة — لو ضُغطت الشاشة
        // (موبايل ضيّق) يتقلّص النص بقطع بدلًا من تجاوز حدود البطاقة.
        Flexible(
          child: Text(
            OrderLiveBadge.formatElapsed(widget.createdAt, l10n: l10n),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}