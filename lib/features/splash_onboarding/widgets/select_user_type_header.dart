import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/settings/app_settings_cubit.dart';
import '../../../core/settings/app_settings_state.dart';
import '../../../l10n/app_localizations.dart';

class SelectUserTypeHeader extends StatelessWidget {
  const SelectUserTypeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<AppSettingsCubit, AppSettingsState>(
      builder: (context, settings) {
        final isArabic = settings.locale.languageCode == 'ar';
        final isDark = settings.themeMode == ThemeMode.dark;

        return Row(
          children: [
            _SettingsToggleButton(
              tooltip: isDark ? l10n.lightTheme : l10n.darkTheme,
              icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              onPressed: () => context.read<AppSettingsCubit>().toggleTheme(),
            ),
            const SizedBox(width: 8),
            _SettingsToggleButton(
              tooltip: isArabic ? l10n.switchToEnglish : l10n.switchToArabic,
              label: isArabic ? 'EN' : 'ع',
              onPressed: () => context.read<AppSettingsCubit>().toggleLocale(),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsToggleButton extends StatelessWidget {
  final String tooltip;
  final IconData? icon;
  final String? label;
  final VoidCallback onPressed;

  const _SettingsToggleButton({
    required this.tooltip,
    this.icon,
    this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
              ),
            ),
            child: icon != null
                ? Icon(icon, size: 22)
                : Text(
                    label!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
