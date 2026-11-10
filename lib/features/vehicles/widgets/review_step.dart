part of '../vehicle_picker_screen.dart';

// ---------------------------------------------------------------------------
// 7) Review (مراجعة البيانات قبل الحفظ)
// ---------------------------------------------------------------------------

/// ملخّص كامل للسيارة بعد انتهاء المعالج؛ كل بند معه «تعديل» يعود لخطوته.
class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    super.key,
    required this.brand,
    required this.model,
    required this.year,
    required this.trim,
    required this.color,
    required this.plateLetters,
    required this.plateDigits,
    required this.isArabic,
    required this.onEdit,
  });

  final VehicleBrand? brand;
  final VehicleModel? model;
  final int? year;
  final VehicleTrim? trim;
  final VehicleColor? color;

  /// الحروف متصلة كما تُخزَّن؛ تُعرض منفصلة مثل اللوحة.
  final String plateLetters;

  /// أرقام غربية كما تُخزَّن؛ تُعرض عربية-هندية.
  final String plateDigits;
  final bool isArabic;
  final ValueChanged<int> onEdit;

  String _plateValue(AppLocalizations? l10n) {
    final letters = plateLetters.runes.map(String.fromCharCode).join(' ');
    final digits = PlateUtils.toArabicIndic(plateDigits);
    final parts = [
      if (letters.trim().isNotEmpty) letters,
      if (digits.trim().isNotEmpty) digits,
    ];
    if (parts.isEmpty) {
      return l10n?.vehiclePlateNone ?? 'لم تُضف (اختياري)';
    }
    return parts.join('   ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final editLabel = l10n?.vehicleEdit ?? 'تعديل';

    Widget divider() =>
        Divider(height: 1, color: border, indent: 14, endIndent: 14);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          l10n?.vehicleReviewTitle ?? 'راجع بيانات سيارتك',
          style: TextStyle(
            fontFamily: 'Zain',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n?.vehicleReviewHint ??
              'تأكد من بيانات السيارة، ويمكنك تعديل أي بند على حدة قبل الحفظ.',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            height: 1.6,
            color: secondary,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              _ReviewRow(
                leading: brand == null
                    ? Icon(
                        Icons.directions_car_rounded,
                        size: 20,
                        color: secondary,
                      )
                    : BrandLogo(brand: brand!, size: 34, padding: 4),
                label: l10n?.vehicleStepBrand ?? 'الماركة',
                value: brand?.name(isArabic) ?? '—',
                editLabel: editLabel,
                onEdit: () => onEdit(0),
              ),
              divider(),
              _ReviewRow(
                leading: Icon(
                  Icons.directions_car_outlined,
                  size: 20,
                  color: secondary,
                ),
                label: l10n?.vehicleStepModel ?? 'الموديل',
                value: model?.name(isArabic) ?? '—',
                editLabel: editLabel,
                onEdit: () => onEdit(1),
              ),
              divider(),
              _ReviewRow(
                leading: Icon(
                  Icons.calendar_month_rounded,
                  size: 20,
                  color: secondary,
                ),
                label: l10n?.vehicleStepYear ?? 'سنة الصنع',
                value: year == null ? '—' : '$year',
                editLabel: editLabel,
                onEdit: () => onEdit(2),
              ),
              divider(),
              _ReviewRow(
                leading: Icon(Icons.tune_rounded, size: 20, color: secondary),
                label: l10n?.vehicleStepTrim ?? 'الفئة',
                value: trim?.name(isArabic) ?? '—',
                editLabel: editLabel,
                onEdit: () => onEdit(3),
              ),
              divider(),
              _ReviewRow(
                leading: color == null
                    ? Icon(Icons.palette_outlined, size: 20, color: secondary)
                    : _ColorDot(hex: color!.hex),
                label: l10n?.vehicleStepColor ?? 'اللون',
                value: color?.name(isArabic) ?? '—',
                editLabel: editLabel,
                onEdit: () => onEdit(4),
              ),
              divider(),
              _ReviewRow(
                leading: Icon(Icons.pin_outlined, size: 20, color: secondary),
                label: l10n?.vehicleStepPlate ?? 'لوحة السيارة',
                value: _plateValue(l10n),
                muted: plateLetters.isEmpty && plateDigits.isEmpty,
                editLabel: editLabel,
                onEdit: () => onEdit(5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.leading,
    required this.label,
    required this.value,
    required this.editLabel,
    required this.onEdit,
    this.muted = false,
  });

  final Widget leading;
  final String label;
  final String value;
  final String editLabel;
  final VoidCallback onEdit;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          SizedBox(width: 34, child: Center(child: leading)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    color: secondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: muted
                        ? secondary
                        : (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.orangePrimary,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(
              editLabel,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.hex});

  final String hex;

  Color get _color {
    final parsed = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return parsed == null ? Colors.grey : Color(0xFF000000 | parsed);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
    );
  }
}
