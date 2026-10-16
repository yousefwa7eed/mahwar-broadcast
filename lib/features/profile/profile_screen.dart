import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/logout_coordinator.dart';
import '../../../core/auth/profile_cubit.dart';
import '../../../core/auth/role_gate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/avatar_config.dart';
import '../../../core/settings/app_settings_cubit.dart';
import '../../../core/widgets/delete_account_dialog.dart';
import '../../../core/widgets/profile_name_text.dart';
import '../../../l10n/app_localizations.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsCubit = context.watch<AppSettingsCubit>();
    final isArabic = settingsCubit.state.locale.languageCode == 'ar';
    final l10n = AppLocalizations.of(context);

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
            BlocBuilder<ProfileCubit, ProfileState>(
              builder: (context, state) {
                // الدور يأتي من profile فقط — لا افتراضي car_owner. بدون دور
                // صالح نعطّل فتح شاشة اختيار الصورة بدل توجيه خاطئ.
                final AppRole? role = state is ProfileLoaded
                    ? AppRole.tryParse(state.profile.role)
                    : null;
                final String? avatarId =
                    state is ProfileLoaded ? state.profile.avatarId : null;
                final String? photoUrl =
                    state is ProfileLoaded ? state.profile.avatarUrl : null;
                return GestureDetector(
                  onTap: role == null
                      ? null
                      : () =>
                          context.push('/profile/avatar?role=${role.dbValue}'),
                  child: AvatarWidget(
                    avatarId: avatarId,
                    role: role?.dbValue ?? '',
                    size: 100,
                    photoUrl: photoUrl,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // أثناء تحميل الملف الشخصي نعرض شيمر مكان الاسم مع إعادة
            // محاولة عند الخطأ — لا نص مؤقت من user_metadata.
            ProfileNameText(
              emptyFallback: l10n?.myAccount ?? 'حسابي',
              skeletonWidth: 180,
              skeletonHeight: 36,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Zain',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.editPersonalInfo ?? 'اضغط على الصورة لتغييرها',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
              icon: Icons.lock_outline_rounded,
              title: l10n?.changePassword ?? 'تغيير كلمة المرور',
              isDark: isDark,
              onTap: () => context.push('/profile/change-password'),
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
              child: ListenableBuilder(
                listenable: LogoutCoordinator.isRunning,
                builder: (context, _) => OutlinedButton(
                  onPressed: LogoutCoordinator.isRunning.value
                      ? null
                      : () => LogoutCoordinator().logout(
                            context: context,
                            resetProfile:
                                () => context.read<ProfileCubit>().reset(),
                          ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: LogoutCoordinator.isRunning.value
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.error,
                          ),
                        )
                      : Text(
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
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _showDeleteAccountDialog(context),
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

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final deleted = await showDeleteAccountDialog(
      context,
      authService: SupabaseAuthService(),
    );
    if (deleted == true && context.mounted) {
      context.go('/select-user-type');
    }
  }
}
