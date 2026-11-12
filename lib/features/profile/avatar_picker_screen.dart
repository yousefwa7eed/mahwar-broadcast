import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/profile_cubit.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/avatar_picker_grid.dart';

class AvatarPickerScreen extends StatelessWidget {
  const AvatarPickerScreen({super.key, required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final profileState = context.watch<ProfileCubit>().state;
    final String? avatarId =
        profileState is ProfileLoaded ? profileState.profile.avatarId : null;

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
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.chooseAvatarTitle ?? 'اختر صورتك الرمزية',
              style: TextStyle(
                fontFamily: 'Zain',
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n?.chooseAvatarSubtitle ?? 'ستظهر هذه الصورة في ملفك الشخصي وطلباتك',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            AvatarPickerGrid(
              role: role,
              initialAvatarId: avatarId,
              onSaved: () => context.pop(true),
            ),
          ],
        ),
      ),
    );
  }
}
