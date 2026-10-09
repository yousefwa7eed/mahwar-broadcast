import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../auth/profile_cubit.dart';
import '../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'shimmer_box.dart';

/// يعرض اسم المستخدم من حالة [ProfileCubit] مع معالجة كامل الحالات:
/// - تحميل/بدائي: هيكل شيمر متحرك مكان الاسم (لا نص مؤقت بديل).
/// - خطأ: رسالة قصيرة + زر إعادة محاولة (لا شيمر لا نهائي).
/// - محمّل: الاسم الفعلي، أو fallback إن كان الاسم فارغاً.
///
/// الألوان والخطوط تأتي من الثيم، فينسجم مع الوضع الداكن تلقائياً.
class ProfileNameText extends StatelessWidget {
  final ProfileState? state;
  final VoidCallback? onRetry;
  final String? prefix;
  final String emptyFallback;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int maxLines;
  final TextOverflow overflow;
  final double? skeletonWidth;
  final double? skeletonHeight;

  const ProfileNameText({
    super.key,
    this.state,
    this.onRetry,
    this.prefix,
    this.emptyFallback = '',
    this.style,
    this.textAlign,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
    this.skeletonWidth,
    this.skeletonHeight,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ProfileState effectiveState = state ??
        (context.watch<ProfileCubit>().state);

    switch (effectiveState) {
      case ProfileLoaded(:final profile):
        final name = profile.fullName.trim();
        final text = name.isNotEmpty
            ? (prefix == null ? name : '$prefix $name')
            : emptyFallback;
        return Text(
          text,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
          style: style,
        );

      case ProfileError():
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 16,
              color: AppColors.error,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                l10n?.profileLoadFailed ?? 'تعذّر تحميل بياناتك الشخصية',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: AppColors.error,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: onRetry ??
                  () => context.read<ProfileCubit>().refreshProfile(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColors.orangePrimary,
              ),
              child: Text(
                l10n?.retry ?? 'إعادة المحاولة',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );

      case ProfileInitial():
      case ProfileLoading():
      default:
        final fontSize = style?.fontSize ?? 16;
        return ShimmerBox(
          width: skeletonWidth ?? 140,
          height: skeletonHeight ?? fontSize * 1.5,
          borderRadius: 8,
        );
    }
  }
}