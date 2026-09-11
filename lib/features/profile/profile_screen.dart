import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/profile_cubit.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/settings/app_settings_cubit.dart';
import '../../../l10n/app_localizations.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsCubit = context.watch<AppSettingsCubit>();
    final isArabic = settingsCubit.state.locale.languageCode == 'ar';
    final l10n = AppLocalizations.of(context);
    final profileState = context.watch<ProfileCubit>().state;

    String userName = '';
    if (profileState is ProfileLoaded) {
      userName = profileState.profile.fullName;
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n?.profile ?? 'الملف الشخصي',
          style: TextStyle(
            fontFamily: 'Zain',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.orangePrimary.withValues(alpha: 0.15),
              child: const Icon(Icons.person_rounded, size: 50, color: AppColors.orangePrimary),
            ),
            const SizedBox(height: 16),
            Text(
              userName.isNotEmpty ? userName : (l10n?.myAccount ?? 'حسابي'),
              style: TextStyle(
                fontFamily: 'Zain',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 32),
            _buildProfileOption(
              context,
              icon: Icons.person_outline_rounded,
              title: l10n?.editPersonalInfo ?? 'تعديل البيانات الشخصية',
              isDark: isDark,
              onTap: () => context.push('/profile/edit'),
            ),
            _buildProfileOption(
              context,
              icon: Icons.directions_car_outlined,
              title: l10n?.manageCars ?? 'إدارة السيارات',
              isDark: isDark,
              onTap: () => context.push('/profile/cars'),
            ),
            _buildProfileOption(
              context,
              icon: Icons.language_rounded,
              title: '${l10n?.languageLabel ?? 'اللغة'}: ${l10n?.currentLanguage ?? (isArabic ? 'العربية' : 'English')}',
              isDark: isDark,
              onTap: () => settingsCubit.toggleLocale(),
            ),
            _buildProfileOption(
              context,
              icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              title: isArabic ? (l10n?.lightMode ?? 'الوضع الفاتح') : (l10n?.darkMode ?? 'الوضع الداكن'),
              isDark: isDark,
              onTap: () => settingsCubit.toggleTheme(),
            ),
            _buildProfileOption(
              context,
              icon: Icons.description_outlined,
              title: l10n?.termsOfUse ?? 'شروط الاستخدام',
              isDark: isDark,
              onTap: () => context.push('/terms'),
            ),
            _buildProfileOption(
              context,
              icon: Icons.privacy_tip_outlined,
              title: l10n?.privacyPolicy ?? 'سياسة الخصوصية',
              isDark: isDark,
              onTap: () => context.push('/privacy'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () async {
                  await AuthService().signOut();
                  if (context.mounted) context.go('/select-user-type');
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  l10n?.logout ?? 'تسجيل الخروج',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _showDeleteAccountDialog(context, l10n),
              child: Text(
                l10n?.deleteAccount ?? 'حذف الحساب',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.orangePrimary),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        onTap: onTap,
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AppLocalizations? l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n?.deleteAccount ?? 'حذف الحساب',
          style: TextStyle(
            fontFamily: 'Zain',
            fontSize: 20,
            color: AppColors.error,
          ),
        ),
        content: Text(
          l10n?.deleteAccountConfirm ?? 'هل أنت متأكد من حذف حسابك نهائياً؟ لن تتمكن من استعادته.',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n?.cancel ?? 'إلغاء',
              style: const TextStyle(fontFamily: 'Cairo', color: AppColors.lightTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await AuthService().deleteAccount();
                if (context.mounted) context.go('/select-user-type');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('حدث خطأ: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'حذف',
              style: TextStyle(fontFamily: 'Cairo', color: AppColors.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
