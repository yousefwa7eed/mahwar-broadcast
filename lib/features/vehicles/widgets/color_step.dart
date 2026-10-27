part of '../vehicle_picker_screen.dart';

// ---------------------------------------------------------------------------
// 5) Color
// ---------------------------------------------------------------------------

class _ColorStep extends StatelessWidget {
  const _ColorStep({
    super.key,
    required this.colors,
    required this.selectedId,
    required this.isArabic,
    required this.onSelected,
  });

  final List<VehicleColor> colors;
  final String? selectedId;
  final bool isArabic;
  final ValueChanged<VehicleColor> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      itemCount: colors.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) {
        final color = colors[index];
        final selected = color.id == selectedId;
        final swatch = _parseColor(color.hex);
        return InkWell(
          onTap: () => onSelected(color),
          borderRadius: BorderRadius.circular(14),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: swatch,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? AppColors.orangePrimary
                        : (isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder),
                    width: selected ? 3 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        size: 24,
                        color: _contrastColor(swatch),
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                color.name(isArabic),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _parseColor(String hex) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return value == null ? Colors.grey : Color(0xFF000000 | value);
  }

  Color _contrastColor(Color color) =>
      color.computeLuminance() > 0.6 ? Colors.black87 : Colors.white;
}
