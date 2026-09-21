import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/notification_model.dart';
import '../../l10n/app_localizations.dart';

/// شاشة التفاصيل الكاملة لإشعار عام (broadcast) — يعرض العنوان والنص كاملاً
/// وصورة الإشعار (إن وُجدت) ووقت الإرسال. يُفتح من لمس إشعار broadcast في
/// قوائم الإشعارات (صفحة الإشعارات + تبويب الرئيسية للعميل والمزوّد) ومن
/// لمس إشعار الدفع نفسه.
class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({super.key, required this.notification});

  final NotificationModel notification;

  /// "أُرسل في <تاريخ> • <وقت>" — التاريخ/الوقت منسّقان حسب لغة التطبيق.
  String _sentAtLabel(BuildContext context) {
    final created = notification.createdAt?.toLocal();
    if (created == null) return '';
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final date = material.formatMediumDate(created);
    final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(created));
    return '${l10n?.notificationSentAt ?? 'أُرسل في'} $date • $time';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
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
              if (imageUrl != null) ...[
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
                          l10n?.notificationBroadcast ?? 'إشعار عام',
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
              Container(
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
                      notification.title,
                      style: TextStyle(
                        fontFamily: 'Zain',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        notification.body,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}