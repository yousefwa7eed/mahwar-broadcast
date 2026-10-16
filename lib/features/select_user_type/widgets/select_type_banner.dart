import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class SelectTypeBanner extends StatelessWidget {
  final bool isDarkMode;
  final bool isArabic;

  const SelectTypeBanner({
    super.key,
    required this.isDarkMode,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AspectRatio(
      aspectRatio: 700 / 300,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B00).withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Primary Banner Image: assets/user_type_banner.png matching 700x300 ratio
              Image.asset(
                'assets/user_type_banner.png',
                fit: BoxFit.fill,
                errorBuilder: (context, error, stackTrace) {
                  // Secondary Fallback Banner Image: assets/banners/banner1.png
                  return Image.asset(
                    'assets/banners/banner1.png',
                    fit: BoxFit.fill,
                    errorBuilder: (context, err1, stack1) {
                      // Tertiary Fallback Banner Image: assets/banner.png
                      return Image.asset(
                        'assets/banner.png',
                        fit: BoxFit.fill,
                        errorBuilder: (context, err2, stack2) {
                          // Stylized Hero Gradient Card Fallback
                          return Container(
                            decoration: const BoxDecoration(
                              gradient: AppColors.orangeGradient,
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.car_repair_rounded,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n?.topRoadsideAssistance ?? 'شبكة طوارئ السيارات الأولى',
                                        style: TextStyle(
                                          fontFamily: isArabic ? 'Zain' : 'Poppins',
                                          fontSize: isArabic ? 24 : 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        l10n?.fastSafeRoadside24_7 ??
                                            'خدمة سريعة وآمنة على كافة الطرق 24/7',
                                        style: TextStyle(
                                          fontFamily: isArabic ? 'Cairo' : 'Poppins',
                                          fontSize: 12,
                                          color: Colors.white.withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),

              // Subtle Depth Gradient Overlay
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.08),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
