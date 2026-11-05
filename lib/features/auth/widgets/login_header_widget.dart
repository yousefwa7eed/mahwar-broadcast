import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/surface_palette.dart';
import '../../../l10n/app_localizations.dart';

/// رأس شاشة الدخول: رسمة الدور في إطار ناعم بلمعة خفيفة، شارة الدور، ثم
/// العنوان والوصف. كل ألوانه من [palette] فتتدرّج بسلاسة مع تغيير الثيم.
class LoginHeaderWidget extends StatelessWidget {
  final String role;
  final SurfacePalette palette;
  final bool isArabic;

  const LoginHeaderWidget({
    super.key,
    required this.role,
    required this.palette,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isProvider = role == 'provider';

    // الرسمة نظيفة بلا إطار أو ظل أو تعتيم، وبحجم أكبر.
    final artSize = (MediaQuery.sizeOf(context).width * 0.66).clamp(
      200.0,
      320.0,
    );

    final chipBackground = isProvider
        ? Color.lerp(
            const Color(0xFF1E1E1E),
            Colors.white.withValues(alpha: 0.10),
            palette.themeT,
          )!
        : AppColors.orangePrimary.withValues(alpha: 0.10);
    final chipForeground = isProvider ? Colors.white : AppColors.orangePrimary;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            isProvider
                ? 'assets/provider_banner.png'
                : 'assets/owner_banner.png',
            width: artSize,
            height: artSize,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: artSize,
                height: artSize,
                decoration: const BoxDecoration(
                  gradient: AppColors.orangeGradient,
                ),
                child: Icon(
                  isProvider
                      ? Icons.build_rounded
                      : Icons.directions_car_rounded,
                  size: 54,
                  color: Colors.white,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: chipBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isProvider ? Icons.build_rounded : Icons.directions_car_rounded,
                size: 17,
                color: chipForeground,
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
                  color: chipForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n?.loginHeaderTitle ?? 'سجل دخول',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: isArabic ? 'Zain' : 'Poppins',
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: palette.textPrimary,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n?.loginWelcome ??
              'مرحباً بعودتك، يرجى إدخال بيانات حسابك للمتابعة',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: isArabic ? 'Cairo' : 'Poppins',
            fontSize: 14,
            color: palette.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
