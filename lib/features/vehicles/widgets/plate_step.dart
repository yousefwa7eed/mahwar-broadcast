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

  /// تسلسل الحروف كما اخترها المستخدم؛ التكرار مسموح.
  final List<String> letters;
  final TextEditingController digitsController;
  final ValueChanged<List<String>> onLettersChanged;
  final VoidCallback onClear;

  void _addLetter(String letter) {
    if (letters.length >= PlateUtils.maxLetters) return;
    onLettersChanged([...letters, letter]);
  }

  void _removeLastLetter() {
    if (letters.isEmpty) return;
    onLettersChanged(letters.sublist(0, letters.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lettersLabel = l10n?.vehiclePlateLetters ?? 'الحروف';
    final full = letters.length >= PlateUtils.maxLetters;

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
              'اكتب الأرقام داخل اللوحة، واختَر الحروف بالترتيب — الأول على اليمين. الحرف يتكرر عادي، والعدد غير ثابت.',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            height: 1.6,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 20),
        EgyptianPlate(
          letters: letters,
          digitsController: digitsController,
          height: 190,
          lettersHint: lettersLabel,
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: digitsController,
          builder: (context, value, _) {
            if (letters.isEmpty && value.text.trim().isEmpty) {
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
        Row(
          children: [
            _SectionTitle(lettersLabel),
            const SizedBox(width: 8),
            Text(
              '${letters.length} / ${PlateUtils.maxLetters}',
              // الاتجاه الصريح يمنع عكس «3 / 5» داخل واجهة عربية.
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: letters.isEmpty ? null : _removeLastLetter,
              tooltip: l10n?.vehiclePlateBackspace ?? 'حذف آخر حرف',
              icon: const Icon(Icons.backspace_outlined, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final letter in PlateUtils.letters)
              _LetterChip(
                letter: letter,
                used: letters.contains(letter),
                enabled: !full,
                onTap: () => _addLetter(letter),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          l10n?.vehiclePlateSequenceHint ??
              'الحرف الأول الذي تنقره يظهر على يمين اللوحة',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }
}

class _LetterChip extends StatelessWidget {
  const _LetterChip({
    required this.letter,
    required this.used,
    required this.enabled,
    required this.onTap,
  });

  final String letter;

  /// هل الحرف مستخدم حاليًا على اللوحة (قد يكون مكررًا أكثر من مرة).
  final bool used;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = used
        ? AppColors.orangePrimary
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
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: used
                ? AppColors.orangePrimary.withValues(alpha: 0.12)
                : (isDark ? AppColors.darkCard : AppColors.lightCard),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: used ? AppColors.orangePrimary : borderColor,
              width: used ? 2 : 1,
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
