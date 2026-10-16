import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/settings/app_settings_cubit.dart';
import '../../../l10n/app_localizations.dart';

class LoginHeaderWidget extends StatelessWidget {
  final String role;
  const LoginHeaderWidget({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final bool isProvider = role == 'provider';
    final isArabic = context.watch<AppSettingsCubit>().state.locale.languageCode == 'ar';
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final Color accentColor = isProvider
        ? (isDark ? AppColors.orangePrimary : const Color(0xFF1E1E1E))
        : AppColors.orangePrimary;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            isProvider ? 'assets/provider_banner.png' : 'assets/owner_banner.png',
            height: 140,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 140,
                color: isProvider
                    ? (isDark ? AppColors.darkCard : const Color(0xFF1E1E1E))
                    : AppColors.orangePrimary,
                child: const Center(
                  child: Icon(Icons.directions_car_rounded, size: 60, color: Colors.white),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isProvider
                    ? (isDark ? AppColors.darkCard : const Color(0xFF1E1E1E))
                    : AppColors.orangePrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isProvider ? Icons.build_rounded : Icons.directions_car_rounded,
                    size: 16,
                    color: isProvider ? Colors.white : AppColors.orangePrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isProvider
                        ? (l10n?.serviceProvider ?? 'مقدم الخدمة')
                        : (l10n?.carOwner ?? 'مالك السيارة'),
                    style: TextStyle(
                      fontFamily: isArabic ? 'Cairo' : 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isProvider ? Colors.white : AppColors.orangePrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          l10n?.loginHeaderTitle ?? 'سجل دخول',
          style: TextStyle(
            fontFamily: isArabic ? 'Zain' : 'Poppins',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n?.loginWelcome ??
              'مرحباً بعودتك، يرجى إدخال بيانات حسابك للمتابعة',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: isArabic ? 'Cairo' : 'Poppins',
            fontSize: 14,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
