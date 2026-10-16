import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class EmergencySupportTile extends StatelessWidget {
  final bool isDarkMode;
  final bool isArabic;

  const EmergencySupportTile({
    super.key,
    required this.isDarkMode,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF1E1E1E)
            : const Color(0xFFFFF7F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFF6B00).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Color(0xFFFF6B00),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.needUrgentRoadsideHelp ?? 'هل تحتاج مساعدة عاجلة في الطريق؟',
                  style: TextStyle(
                    fontFamily: isArabic ? 'Zain' : 'Poppins',
                    fontSize: isArabic ? 18 : 14,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                ),
                Text(
                  l10n?.supportTeamReady24_7 ?? 'فريق الدعم الفني جاهز لمساعدتك 24 ساعة',
                  style: TextStyle(
                    fontFamily: isArabic ? 'Cairo' : 'Poppins',
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    l10n?.mahwarHotlineAvailable ?? 'خط طوارئ محور: 19xxx جاهز في جميع المحافظات',
                  ),
                  backgroundColor: const Color(0xFFFF6B00),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF6B00),
            ),
            child: Text(
              l10n?.callNow ?? 'اتصل الآن',
              style: TextStyle(
                fontFamily: isArabic ? 'Cairo' : 'Poppins',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
