import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/profile_cubit.dart';
import '../../../core/auth/role_gate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/avatar_config.dart';
import '../../../core/widgets/profile_name_text.dart';
import '../../../core/widgets/support_dialog.dart';
import '../../../l10n/app_localizations.dart';
import 'widgets/avatar_picker_grid.dart';
import 'widgets/cars_section.dart';
import 'widgets/change_password_form.dart';
import 'widgets/personal_info_form.dart';

/// صفحة واحدة لتعديل كل ما يخص الحساب: الصورة الرمزية، البيانات الشخصية،
/// السيارات، وكلمة المرور — بلا تنقل لشاشات فرعية.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final profileState = context.watch<ProfileCubit>().state;
    final AppRole? role = profileState is ProfileLoaded
        ? AppRole.tryParse(profileState.profile.role)
        : null;
    final String? avatarId =
        profileState is ProfileLoaded ? profileState.profile.avatarId : null;
    final String? photoUrl =
        profileState is ProfileLoaded ? profileState.profile.avatarUrl : null;

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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Column(
                children: [
                  AvatarWidget(
                    avatarId: avatarId,
                    role: role?.dbValue ?? '',
                    size: 96,
                    photoUrl: photoUrl,
                  ),
                  const SizedBox(height: 14),
                  ProfileNameText(
                    emptyFallback: l10n?.myAccount ?? 'حسابي',
                    skeletonWidth: 180,
                    skeletonHeight: 32,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Zain',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            if (role != null)
              _buildSection(
                isDark: isDark,
                title: l10n?.profilePhoto ?? 'الصورة الرمزية',
                child: AvatarPickerGrid(
                  role: role.dbValue,
                  initialAvatarId: avatarId,
                ),
              ),

            _buildSection(
              isDark: isDark,
              title: l10n?.editPersonalInfo ?? 'تعديل البيانات الشخصية',
              child: const PersonalInfoForm(),
            ),

            if (role == AppRole.carOwner)
              _buildSection(
                isDark: isDark,
                title: l10n?.manageCars ?? 'إدارة السيارات',
                child: const CarsSection(),
              ),

            _buildSection(
              isDark: isDark,
              title: l10n?.changePassword ?? 'تغيير كلمة المرور',
              child: const ChangePasswordForm(),
            ),

            _buildFooter(context, isDark, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required bool isDark,
    required String title,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Zain',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    bool isDark,
    AppLocalizations? l10n,
  ) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final linkColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    Widget link(String label, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: isArabic ? 'Cairo' : 'Poppins',
            fontSize: 12.5,
            color: linkColor,
            decoration: TextDecoration.underline,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 10),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            link(
              l10n?.supportLink ?? 'الدعم',
              () => showSupportDialog(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '•',
                style: TextStyle(color: linkColor.withValues(alpha: 0.5)),
              ),
            ),
            link(
              l10n?.privacyPolicy ?? 'سياسة الخصوصية',
              () => context.push('/privacy'),
            ),
          ],
        ),
      ),
    );
  }
}
