part of '../vehicle_picker_screen.dart';

// ---------------------------------------------------------------------------
// 3) Year — الجيل يُستنتج من السنة، فلا خطوة مستقلة له.
// ---------------------------------------------------------------------------

class _YearStep extends StatelessWidget {
  const _YearStep({
    super.key,
    required this.years,
    required this.selectedYear,
    required this.onSelected,
  });

  final List<int> years;
  final int? selectedYear;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        Text(
          l10n?.vehicleYearHint ?? 'اختر سنة صنع سيارتك',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final year in years)
              ChoiceChip(
                label: Text(
                  '$year',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: year == selectedYear
                        ? Colors.white
                        : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary),
                  ),
                ),
                selected: year == selectedYear,
                selectedColor: AppColors.orangePrimary,
                backgroundColor:
                    isDark ? AppColors.darkCard : AppColors.lightSurface,
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                onSelected: (_) => onSelected(year),
              ),
          ],
        ),
      ],
    );
  }
}
