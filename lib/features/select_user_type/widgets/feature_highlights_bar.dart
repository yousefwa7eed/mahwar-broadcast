import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class FeatureHighlightsBar extends StatelessWidget {
  final bool isDarkMode;
  final bool isArabic;

  const FeatureHighlightsBar({
    super.key,
    required this.isDarkMode,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final highlights = [
      {
        'icon': Icons.gps_fixed_rounded,
        'title': l10n?.highlightLiveTracking ?? 'تتبع جغرافي حي',
      },
      {
        'icon': Icons.verified_user_outlined,
        'title': l10n?.highlightTransparentPricing ?? 'تسعير شفاف 100%',
      },
      {
        'icon': Icons.bolt_rounded,
        'title': l10n?.highlightFastResponse ?? 'نجدة سريعة 24/7',
      },
    ];

    final textColor = isDarkMode ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E1E1E);
    final bgColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.04);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.06);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: highlights.map((item) {
          final icon = item['icon'] as IconData;
          final title = item['title'] as String;

          return Container(
            margin: const EdgeInsets.only(left: 8, right: 2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: const Color(0xFFFF6B00),
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: isArabic ? 'Cairo' : 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
