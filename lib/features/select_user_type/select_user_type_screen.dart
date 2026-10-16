import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/settings/app_settings_cubit.dart';
import '../../core/settings/app_settings_state.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/emergency_support_tile.dart';
import 'widgets/feature_highlights_bar.dart';
import 'widgets/select_type_banner.dart';
import 'widgets/select_type_footer.dart';
import 'widgets/select_type_header.dart';
import 'widgets/user_type_card.dart';

class SelectUserTypeScreen extends StatelessWidget {
  const SelectUserTypeScreen({super.key});

  void _onSelectRole(BuildContext context, String role) {
    context.go('/login?role=$role');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocBuilder<AppSettingsCubit, AppSettingsState>(
      builder: (context, settings) {
        final isDarkMode = settings.themeMode == ThemeMode.dark;
        final currentLang = settings.locale.languageCode;

        final backgroundColor = isDarkMode
            ? AppColors.darkBackground
            : AppColors.lightBackground;
        final primaryTextColor = isDarkMode
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary;
        final secondaryTextColor = isDarkMode
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary;

        final isArabic = currentLang == 'ar';

        return Scaffold(
          backgroundColor: backgroundColor,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row (App Logo + Language Switcher + Theme Toggle)
                  SelectTypeHeader(
                    isDarkMode: isDarkMode,
                    currentLang: currentLang,
                    onToggleTheme: () {
                      context.read<AppSettingsCubit>().toggleTheme();
                    },
                    onToggleLang: () {
                      context.read<AppSettingsCubit>().toggleLocale();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Top Hero Banner (700x300 AspectRatio)
                  SelectTypeBanner(
                    isDarkMode: isDarkMode,
                    isArabic: isArabic,
                  ),
                  const SizedBox(height: 14),

                  // Feature Highlights Pills Bar
                  FeatureHighlightsBar(
                    isDarkMode: isDarkMode,
                    isArabic: isArabic,
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Welcoming Title Section
                          Text(
                            l10n?.welcomeToMahwar ?? 'أهلاً بك في محور',
                            style: TextStyle(
                              fontFamily: isArabic ? 'Zain' : 'Poppins',
                              fontSize: isArabic ? 32 : 26,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n?.chooseAccountTypeSubtitle ??
                                'اختر نوع حسابك للبدء في استخدام التطبيق واستكشاف الخدمات المتاحة',
                            style: TextStyle(
                              fontFamily: isArabic ? 'Cairo' : 'Poppins',
                              fontSize: 13,
                              color: secondaryTextColor,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Car Owner Selection Card
                          UserTypeCard(
                            title: l10n?.carOwner ?? (isArabic ? 'مالك السيارة' : 'Car Owner'),
                            subtitle: l10n?.carOwnerDesc ??
                                (isArabic
                                    ? 'اطلب أقرب خدمات الطوارئ لسيارتك من الونش والإطارات والبنزين والبطاريات بكل سهولة'
                                    : 'Request nearby emergency roadside assistance easily for tow truck, tires, fuel, and batteries'),
                            iconData: Icons.directions_car_rounded,
                            gradient: AppColors.orangeGradient,
                            shadowColor: const Color(0xFFFF6B00),
                            onTap: () => _onSelectRole(context, 'car_owner'),
                          ),
                          const SizedBox(height: 16),

                          // Service Provider Selection Card
                          UserTypeCard(
                            title: l10n?.serviceProvider ?? (isArabic ? 'مقدم الخدمة' : 'Service Provider'),
                            subtitle: l10n?.serviceProviderDesc ??
                                (isArabic
                                    ? 'استقبل طلبات الطوارئ الجغرافية من العملاء في نطاقك وقدم عروض الأسعار مباشرة'
                                    : 'Receive location-based emergency requests from customers in your area and quote prices directly'),
                            iconData: Icons.build_circle_rounded,
                            gradient: AppColors.darkGradient,
                            shadowColor: const Color(0xFF1E1E1E),
                            onTap: () => _onSelectRole(context, 'provider'),
                          ),
                          const SizedBox(height: 16),

                          // Emergency Support Tile
                          EmergencySupportTile(
                            isDarkMode: isDarkMode,
                            isArabic: isArabic,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Footer Links
                  SelectTypeFooter(
                    isDarkMode: isDarkMode,
                    onTermsTap: () => context.push('/terms'),
                    onPrivacyTap: () => context.push('/privacy'),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
