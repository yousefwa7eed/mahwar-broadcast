part of '../vehicle_picker_screen.dart';

// ---------------------------------------------------------------------------
// 6) Plate (اختياري)
// ---------------------------------------------------------------------------

class _PlateStep extends StatelessWidget {
  const _PlateStep({
    super.key,
    required this.letters,
    required this.digitsController,
    required this.onLettersChanged,
    required this.onClear,
  });

  final List<String?> letters;
  final TextEditingController digitsController;
  final ValueChanged<List<String?>> onLettersChanged;
  final VoidCallback onClear;

  void _toggleLetter(String letter) {
    final selected = letters.whereType<String>().toList();
    final index = selected.indexOf(letter);
    if (index >= 0) {
      selected.removeAt(index);
    } else {
      if (selected.length == 3) return;
      selected.add(letter);
    }
    onLettersChanged([
      for (var i = 0; i < 3; i++) i < selected.length ? selected[i] : null,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lettersLabel = l10n?.vehiclePlateLetters ?? 'الحروف';
    final hasSelectedLetters = letters.any((letter) => letter != null);
    final hasEmptySlot = letters.contains(null);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          l10n?.vehiclePlateOptionalTitle ?? 'لوحة السيارة (اختياري)',
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
          l10n?.vehiclePlateEditableHint ??
              'اكتب الأرقام داخل اللوحة، واختَر الحروف بالترتيب — الحرف الأول على اليمين',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            height: 1.6,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 22),
        EgyptianPlate(
          letters: letters,
          digitsController: digitsController,
          height: 150,
          lettersHint: lettersLabel,
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: digitsController,
          builder: (context, value, _) {
            if (!hasSelectedLetters && value.text.trim().isEmpty) {
              return const SizedBox(height: 14);
            }
            return Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_rounded, size: 18),
                label: Text(
                  l10n?.vehiclePlateClear ?? 'مسح',
                  style: const TextStyle(fontFamily: 'Cairo'),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        _SectionTitle(lettersLabel),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final letter in PlateUtils.letters)
              _LetterChip(
                letter: letter,
                position: letters.indexOf(letter) + 1,
                enabled: hasEmptySlot || letters.contains(letter),
                onTap: () => _toggleLetter(letter),
              ),
          ],
        ),
      ],
    );
  }
}

class _LetterChip extends StatelessWidget {
  const _LetterChip({
    required this.letter,
    required this.position,
    required this.enabled,
    required this.onTap,
  });

  /// ترتيب الحرف على اللوحة (1..3)، أو صفر إن لم يُختر بعد.
  final String letter;
  final int position;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = position > 0;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = selected
        ? Colors.white
        : enabled
        ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.orangePrimary
                : (isDark ? AppColors.darkCard : AppColors.lightCard),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.orangePrimary : borderColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            letter,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: textColor.withValues(alpha: enabled ? 1 : 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
