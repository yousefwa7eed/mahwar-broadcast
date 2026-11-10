import 'package:flutter/material.dart';
import '../../../core/theme/surface_palette.dart';

class SelectTypeHeader extends StatelessWidget {
  final SurfacePalette palette;
  final bool isDarkMode;
  final String currentLang;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLang;

  const SelectTypeHeader({
    super.key,
    required this.palette,
    required this.isDarkMode,
    required this.currentLang,
    required this.onToggleTheme,
    required this.onToggleLang,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = currentLang == 'ar';

    return Row(
      children: [
        // App Badge Logo with authentic app_icon.png
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B00).withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/app_icon.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          isArabic ? 'مِحْوَر' : 'Mahwar',
          style: TextStyle(
            fontFamily: isArabic ? 'Zain' : 'Poppins',
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: palette.textPrimary,
          ),
        ),
        const Spacer(),

        // أزرار بلا خلفية: أيقونات سميكة فقط، لونها يتبع الثيم (أسود ↔ أبيض)
        _HeaderIconButton(
          tooltip: isArabic ? 'Switch to English' : 'التبديل إلى العربية',
          color: palette.textPrimary,
          onTap: onToggleLang,
          child: Icon(
            Icons.translate_rounded,
            color: palette.textPrimary,
            size: 26,
          ),
        ),
        const SizedBox(width: 2),
        _HeaderIconButton(
          tooltip: isDarkMode ? 'Light Mode' : 'Dark Mode',
          color: palette.textPrimary,
          onTap: onToggleTheme,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: animation,
                child: RotationTransition(
                  turns: Tween<double>(begin: 0.75, end: 1.0).animate(curved),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.7, end: 1.0).animate(curved),
                    child: child,
                  ),
                ),
              );
            },
            child: Icon(
              isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey<bool>(isDarkMode),
              color: palette.textPrimary,
              size: 26,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  final Widget child;

  const _HeaderIconButton({
    required this.tooltip,
    required this.color,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        containedInkWell: true,
        highlightShape: BoxShape.circle,
        splashColor: color.withValues(alpha: 0.10),
        highlightColor: color.withValues(alpha: 0.06),
        child: Padding(padding: const EdgeInsets.all(8), child: child),
      ),
    );
  }
}
