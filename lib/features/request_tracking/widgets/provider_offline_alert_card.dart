import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../provider_alert_status.dart';

/// بطاقة هادية داخل شاشة التتبع: تُخبر العميل أن المزوّد سجّل خروجه وتقترح
/// (حسب الحصة) إرسال رسالة تنبيه واحدة. لا تظهر بعد ردّ المزوّد ولا بعد
/// إرسال تنبيه لهذا الطلب.
class ProviderOfflineAlertCard extends StatelessWidget {
  final ProviderAlertReason reason;
  final bool canSend;
  final bool isSending;
  final bool sent;
  final VoidCallback? onSend;
  final VoidCallback? onDismiss;

  const ProviderOfflineAlertCard({
    super.key,
    required this.reason,
    required this.canSend,
    required this.isSending,
    required this.sent,
    this.onSend,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final title = sent
        ? (l10n?.providerAlertSmsSent ?? 'تم إرسال التنبيه')
        : (l10n?.providerOfflineAlertTitle ?? 'المزوّد غير متصل حاليًا');

    String body;
    if (sent) {
      body = l10n?.providerAlertSmsSentBody ??
          'سنُخطر المزوّد برسالة نصية على هاتفه.';
    } else if (canSend) {
      body = l10n?.providerOfflineAlertBody ??
          'سجّل المزوّد خروجه قبل قليل. تحب نبعته له رسالة تنبيه؟';
    } else if (reason == ProviderAlertReason.dailyCapReached) {
      body = l10n?.providerOfflineAlertDailyCap ??
          'تعذّر إرسال تنبيه إضافي الآن، حاول لاحقًا.';
    } else {
      body = l10n?.providerOfflineAlertMonthlyUsed ??
          'تم استخدام رسالة التنبيه الشهرية لهذا المزوّد.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 12),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                sent
                    ? Icons.check_circle_outline_rounded
                    : Icons.notifications_paused_outlined,
                size: 22,
                color: sent ? AppColors.success : AppColors.orangePrimary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        height: 1.4,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (canSend && !sent) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: isSending ? null : onSend,
                icon: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.orangePrimary,
                        ),
                      )
                    : const Icon(Icons.sms_outlined, size: 18),
                label: Text(
                  l10n?.sendProviderAlertSms ?? 'إرسال رسالة تنبيه',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.orangePrimary,
                  side: const BorderSide(color: AppColors.orangePrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
