import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/car_detail.dart';
import '../../../l10n/app_localizations.dart';

class CarSelectorWidget extends StatelessWidget {
  final List<CarDetail> cars;
  final CarDetail? selectedCar;
  final ValueChanged<CarDetail?> onCarSelected;

  const CarSelectorWidget({
    super.key,
    required this.cars,
    this.selectedCar,
    required this.onCarSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.brokenDownCar ?? 'السيارة المتعطلة',
          style: TextStyle(
            fontFamily: 'Zain',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (cars.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n?.noCarAdded ?? 'لم تقم بإضافة سيارة بعد. أضف سيارة من الملف الشخصي أولاً.',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CarDetail>(
                value: selectedCar,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.orangePrimary),
                hint: Text(
                  l10n?.selectCar ?? 'اختر السيارة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                items: cars.map((car) {
                  return DropdownMenuItem<CarDetail>(
                    value: car,
                    child: Row(
                      children: [
                        const Icon(Icons.directions_car_rounded, size: 20, color: AppColors.orangePrimary),
                        const SizedBox(width: 8),
                        Text(
                          car.displayName,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: onCarSelected,
              ),
            ),
          ),
      ],
    );
  }
}
