import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/settings/app_settings_cubit.dart';
import '../../../l10n/app_localizations.dart';

class SelectTypeFooter extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  const SelectTypeFooter({
    super.key,
    required this.isDarkMode,
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = context.watch<AppSettingsCubit>().state.locale.languageCode == 'ar';

    final textColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.55);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onTermsTap,
          child: Text(
            l10n?.termsAndConditions ?? (isArabic ? 'شروط الاستخدام' : 'Terms & Conditions'),
            style: TextStyle(
              fontFamily: isArabic ? 'Cairo' : 'Poppins',
              fontSize: 12,
              color: textColor,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '•',
            style: TextStyle(color: textColor.withValues(alpha: 0.5)),
          ),
        ),
        GestureDetector(
          onTap: onPrivacyTap,
          child: Text(
            l10n?.privacyPolicy ?? (isArabic ? 'سياسة الخصوصية' : 'Privacy Policy'),
            style: TextStyle(
              fontFamily: isArabic ? 'Cairo' : 'Poppins',
              fontSize: 12,
              color: textColor,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
