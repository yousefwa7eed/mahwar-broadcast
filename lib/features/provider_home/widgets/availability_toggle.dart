import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class AvailabilityToggle extends StatelessWidget {
  final bool isOnline;
  final ValueChanged<bool> onToggle;

  const AvailabilityToggle({
    super.key,
    required this.isOnline,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOnline
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isOnline ? AppColors.success : AppColors.error,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOnline ? Icons.check_rounded : Icons.close_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? 'أنا متاح للخدمة الآن' : 'غير متاح حالياً',
                  style: TextStyle(
                    fontFamily: 'Zain',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  isOnline
                      ? 'ستتلقى الطلبات القريبة من موقعك'
                      : 'لن تتلقى أي طلبات حالياً',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isOnline,
            activeTrackColor: AppColors.success,
            inactiveTrackColor: AppColors.error.withValues(alpha: 0.5),
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}
