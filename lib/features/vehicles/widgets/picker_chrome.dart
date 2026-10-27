part of '../vehicle_picker_screen.dart';

// ---------------------------------------------------------------------------
// Header / summary / bottom bar
// ---------------------------------------------------------------------------

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n?.vehicleStepBrand ?? 'الماركة',
      l10n?.vehicleStepModel ?? 'الموديل',
      l10n?.vehicleStepYear ?? 'سنة الصنع',
      l10n?.vehicleStepTrim ?? 'الفئة',
      l10n?.vehicleStepColor ?? 'اللون',
      l10n?.vehicleStepPlate ?? 'اللوحة',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${step + 1}/$total',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.orangePrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                labels[step],
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (step + 1) / total,
              minHeight: 5,
              backgroundColor:
                  isDark ? AppColors.darkBorder : AppColors.lightBorder,
              color: AppColors.orangePrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({
    required this.brand,
    required this.model,
    required this.year,
    required this.trim,
    required this.color,
    required this.isArabic,
    required this.onTapStep,
  });

  final VehicleBrand? brand;
  final VehicleModel? model;
  final int? year;
  final VehicleTrim? trim;
  final VehicleColor? color;
  final bool isArabic;
  final ValueChanged<int> onTapStep;

  @override
  Widget build(BuildContext context) {
    if (brand == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final chips = <Widget>[
      _SummaryChip(
        label: brand!.name(isArabic),
        onTap: () => onTapStep(0),
      ),
      if (model != null)
        _SummaryChip(
          label: model!.name(isArabic),
          onTap: () => onTapStep(1),
        ),
      if (year != null)
        _SummaryChip(
          label: '$year',
          onTap: () => onTapStep(2),
        ),
      if (trim != null)
        _SummaryChip(
          label: trim!.name(isArabic),
          onTap: () => onTapStep(3),
        ),
      if (color != null)
        _SummaryChip(
          label: color!.name(isArabic),
          onTap: () => onTapStep(4),
        ),
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          BrandLogo(brand: brand!, size: 38, padding: 6),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: chips,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.orangePrimary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.orangePrimary,
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.visible,
    required this.enabled,
    required this.onSave,
  });

  final bool visible;
  final bool enabled;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: visible
            ? SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: enabled ? onSave : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orangePrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    l10n?.vehicleSave ?? 'حفظ السيارة',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            : const SizedBox(height: 52),
      ),
    );
  }
}
