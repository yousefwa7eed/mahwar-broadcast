import 'package:flutter/material.dart';

class SelectTypeHeader extends StatelessWidget {
  final bool isDarkMode;
  final String currentLang;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLang;

  const SelectTypeHeader({
    super.key,
    required this.isDarkMode,
    required this.currentLang,
    required this.onToggleTheme,
    required this.onToggleLang,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1E1E1E);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // App Badge Logo with authentic app_icon.png
        Row(
          children: [
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
                    child: const Icon(Icons.hub_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              currentLang == 'ar' ? 'مِحْوَر' : 'Mahwar',
              style: TextStyle(
                fontFamily: currentLang == 'ar' ? 'Zain' : 'Poppins',
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),

        // Action Toggles (Language & Theme)
        Row(
          children: [
            // Language Switcher Chip
            InkWell(
              onTap: onToggleLang,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.language_rounded,
                      size: 18,
                      color: textColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      currentLang == 'ar' ? 'English' : 'العربية',
                      style: TextStyle(
                        fontFamily: currentLang == 'ar' ? 'Poppins' : 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Theme Switcher Button
            Container(
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: IconButton(
                onPressed: onToggleTheme,
                icon: Icon(
                  isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                  color: isDarkMode ? Colors.amber : const Color(0xFF1E1E1E),
                  size: 20,
                ),
                tooltip: isDarkMode ? 'Light Mode' : 'Dark Mode',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
