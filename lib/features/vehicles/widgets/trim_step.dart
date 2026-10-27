part of '../vehicle_picker_screen.dart';

// ---------------------------------------------------------------------------
// 4) Trim
// ---------------------------------------------------------------------------

class _TrimStep extends StatelessWidget {
  const _TrimStep({
    super.key,
    required this.generation,
    required this.selectedId,
    required this.isArabic,
    required this.onSelected,
    required this.onUnknown,
  });

  final VehicleGeneration generation;
  final String? selectedId;
  final bool isArabic;
  final ValueChanged<VehicleTrim> onSelected;
  final VoidCallback onUnknown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hintStyle = TextStyle(
      fontFamily: 'Cairo',
      fontSize: 13,
      color: isDark
          ? AppColors.darkTextSecondary
          : AppColors.lightTextSecondary,
    );

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      itemCount: generation.trims.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n?.vehicleTrimHint ??
                    'الفئة تعني المحرك ومستوى التجهيز. لو مش متأكد اختر «لا أعرف».',
                style: hintStyle,
              ),
              const SizedBox(height: 6),
              Text(
                l10n?.vehicleMatchedGeneration(generation.name(isArabic)) ??
                    'الجيل المطابق: ${generation.name(isArabic)}',
                style: hintStyle.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.orangePrimary,
                ),
              ),
              const SizedBox(height: 14),
            ],
          );
        }
        if (index == 1) {
          return _OptionTile(
            title: l10n?.vehicleTrimUnknown ?? 'لا أعرف',
            subtitle: l10n?.vehicleTrimUnknownHint ??
                'سنختار الفئة الأساسية، ويمكنك تعديلها لاحقًا',
            selected: false,
            leading: const _StepIcon(icon: Icons.help_outline_rounded),
            onTap: onUnknown,
          );
        }
        final trim = generation.trims[index - 2];
        return _OptionTile(
          title: trim.name(isArabic),
          subtitle: _trimSubtitle(trim, l10n),
          selected: trim.id == selectedId,
          leading: const _StepIcon(icon: Icons.settings_suggest_rounded),
          onTap: () => onSelected(trim),
        );
      },
    );
  }

  String _trimSubtitle(VehicleTrim trim, AppLocalizations? l10n) {
    final parts = <String>[
      if (trim.horsepower != null)
        l10n?.vehicleHorsepower(trim.horsepower!) ?? '${trim.horsepower} حصان',
      vehicleFuelLabel(trim.fuel, l10n),
      vehicleTransmissionLabel(trim.transmission, l10n),
      if (trim.seats != null)
        l10n?.vehicleSeatsCount(trim.seats!) ?? '${trim.seats} مقاعد',
    ];
    return parts.join(' · ');
  }
}
