import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/vehicle.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../l10n/app_localizations.dart';

/// اختيار السيارة المتعطلة من سيارات المستخدم المسجّلة في الكتالوج.
class CarSelectorWidget extends StatelessWidget {
  const CarSelectorWidget({
    super.key,
    required this.vehicles,
    this.selectedVehicle,
    required this.onVehicleSelected,
    this.loadFailed = false,
    required this.onRetry,
    required this.onManageCars,
  });

  final List<VehicleSummary> vehicles;
  final VehicleSummary? selectedVehicle;
  final ValueChanged<VehicleSummary?> onVehicleSelected;
  final bool loadFailed;
  final VoidCallback onRetry;
  final VoidCallback onManageCars;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n?.brokenDownCar ?? 'السيارة المتعطلة',
                style: TextStyle(
                  fontFamily: 'Zain',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onManageCars,
              icon: const Icon(Icons.tune_rounded, size: 17),
              label: Text(
                l10n?.manageCars ?? 'إدارة السيارات',
                style: TextStyle(
                  fontFamily: isArabic ? 'Cairo' : 'Poppins',
                  fontSize: 12.5,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.orangePrimary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (loadFailed)
          _NoticeCard(
            icon: Icons.cloud_off_rounded,
            color: AppColors.error,
            message: l10n?.vehicleCatalogLoadFailed ??
                'تعذّر تحميل كتالوج السيارات، تحقق من الاتصال وحاول مرة أخرى',
            actionLabel: l10n?.retry ?? 'إعادة المحاولة',
            onAction: onRetry,
          )
        else if (vehicles.isEmpty)
          _NoticeCard(
            icon: Icons.info_outline,
            color: AppColors.warning,
            message: l10n?.noCarAdded ??
                'لم تقم بإضافة سيارة بعد. أضف سيارة من الملف الشخصي أولاً.',
            actionLabel: l10n?.manageCars ?? 'إدارة السيارات',
            onAction: onManageCars,
          )
        else
          _SelectedVehicleTile(
            vehicle: selectedVehicle,
            isArabic: isArabic,
            onTap: () => _showVehicleSheet(context, isArabic),
          ),
      ],
    );
  }

  Future<void> _showVehicleSheet(BuildContext context, bool isArabic) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<VehicleSummary>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.selectCar ?? 'اختر السيارة',
                  style: TextStyle(
                    fontFamily: isArabic ? 'Zain' : 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: vehicles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final summary = vehicles[index];
                      final isSelected =
                          summary.vehicle.id == selectedVehicle?.vehicle.id;
                      return InkWell(
                        onTap: () => Navigator.pop(ctx, summary),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.orangePrimary.withValues(alpha: 0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.orangePrimary.withValues(alpha: 0.5)
                                  : (isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder),
                            ),
                          ),
                          child: Row(
                            children: [
                              if (summary.brand != null)
                                BrandLogo(brand: summary.brand!, size: 40)
                              else
                                const Icon(
                                  Icons.directions_car_rounded,
                                  color: AppColors.orangePrimary,
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      summary.title(isArabic),
                                      style: TextStyle(
                                        fontFamily:
                                            isArabic ? 'Cairo' : 'Poppins',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    if (summary.subtitle(isArabic) != null)
                                      Text(
                                        summary.subtitle(isArabic)!,
                                        style: TextStyle(
                                          fontFamily:
                                              isArabic ? 'Cairo' : 'Poppins',
                                          fontSize: 12,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.orangePrimary,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) onVehicleSelected(selected);
  }
}

class _SelectedVehicleTile extends StatelessWidget {
  const _SelectedVehicleTile({
    required this.vehicle,
    required this.isArabic,
    required this.onTap,
  });

  final VehicleSummary? vehicle;
  final bool isArabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final selected = vehicle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              if (selected?.brand != null)
                BrandLogo(brand: selected!.brand!, size: 44)
              else
                const Icon(
                  Icons.directions_car_rounded,
                  color: AppColors.orangePrimary,
                  size: 26,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected?.title(isArabic) ??
                          (l10n?.selectCar ?? 'اختر السيارة'),
                      style: TextStyle(
                        fontFamily: isArabic ? 'Cairo' : 'Poppins',
                        fontSize: 14,
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
                    if (selected?.subtitle(isArabic) != null)
                      Text(
                        selected!.subtitle(isArabic)!,
                        style: TextStyle(
                          fontFamily: isArabic ? 'Cairo' : 'Poppins',
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                isArabic
                    ? Icons.keyboard_arrow_left_rounded
                    : Icons.keyboard_arrow_right_rounded,
                color: AppColors.orangePrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.color,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color color;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
