import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/vehicle_selection.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../l10n/app_localizations.dart';

/// بطاقة اختيار سيارة: تعرض الشعار والماركة/الموديل/السنة والحالة الفارغة،
/// وتفتح معالج الاختيار عند الضغط. تُستخدم في التسجيل والملف الشخصي.
class VehicleSelectionCard extends StatelessWidget {
  const VehicleSelectionCard({
    super.key,
    required this.selection,
    required this.onTap,
    this.placeholder,
  });

  final VehicleSelection? selection;
  final VoidCallback onTap;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic =
        Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context);
    final selected = selection;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected == null
                  ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                  : AppColors.orangePrimary.withValues(alpha: 0.55),
              width: selected == null ? 1 : 1.5,
            ),
          ),
          child: Row(
            children: [
              if (selected != null)
                BrandLogo(brand: selected.brand, size: 48)
              else
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.orangePrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_car_rounded,
                    color: AppColors.orangePrimary,
                    size: 26,
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected == null
                          ? (placeholder ??
                              l10n?.selectVehicleTitle ?? 'اختيار السيارة')
                          : '${selected.brand.name(isArabic)} '
                              '${selected.model.name(isArabic)} '
                              '${selected.modelYear}',
                      style: TextStyle(
                        fontFamily: isArabic ? 'Cairo' : 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: selected == null
                            ? (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary)
                            : (isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary),
                      ),
                    ),
                    if (selected != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        [
                          selected.trim.name(isArabic),
                          selected.color.name(isArabic),
                          if (selected.plateNumber.isNotEmpty)
                            selected.plateNumber,
                        ].join(' · '),
                        style: TextStyle(
                          fontFamily: isArabic ? 'Cairo' : 'Poppins',
                          fontSize: 12.5,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ] else if (!isArabic) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Tap to pick brand, model, trim and plate',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected == null
                    ? (isArabic
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded)
                    : Icons.edit_rounded,
                color: AppColors.orangePrimary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
