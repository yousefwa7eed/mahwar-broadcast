import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/profile_cubit.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/avatar_config.dart';
import '../../../core/widgets/profile_name_text.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../../l10n/app_localizations.dart';

class HomeHeader extends StatelessWidget {
  final String? locationText;
  final bool isLocatingLocation;
  final VoidCallback? onLocationTap;
  final int unreadNotifications;
  final VoidCallback? onNotificationTap;
  final String role;

  const HomeHeader({
    super.key,
    this.locationText,
    this.isLocatingLocation = false,
    this.onLocationTap,
    this.unreadNotifications = 0,
    this.onNotificationTap,
    this.role = 'car_owner',
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileState = context.watch<ProfileCubit>().state;
    final profile = profileState is ProfileLoaded ? profileState.profile : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.push('/profile/avatar?role=$role'),
            child: profile != null
                ? AvatarWidget(
                    avatarId: profile.avatarId,
                    role: role,
                    size: 40,
                    photoUrl: profile.avatarUrl,
                  )
                : const ShimmerBox(
                    width: 40,
                    height: 40,
                    circle: true,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // أثناء تحميل الملف الشخصي نعرض هيكل شيمر مكان الاسم، ولا
                // نعرض نصاً مؤقتاً يبدو وكأنه الاسم الحقيقي.
                ProfileNameText(
                  prefix: l10n?.welcomeUser ?? 'مرحباً',
                  emptyFallback:
                      (l10n?.welcomeUser ?? 'مرحباً،').replaceAll('،', '').trim(),
                  style: TextStyle(
                    fontFamily: 'Zain',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  skeletonWidth: 130,
                  skeletonHeight: 30,
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onLocationTap,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppColors.orangePrimary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          isLocatingLocation
                              ? 'جاري تحديد الموقع...'
                              : (locationText ?? (l10n?.setLocation ?? 'تحديد الموقع...')),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Stack(
            children: [
              IconButton(
                onPressed: onNotificationTap,
                icon: Icon(
                  Icons.notifications_outlined,
                  size: 28,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              if (unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
