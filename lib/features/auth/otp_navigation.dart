import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_cubit.dart';
import '../../core/auth/home_route.dart';
import '../../core/auth/otp_error_mapper.dart';
import '../../core/auth/phone_utils.dart';
import '../../core/config/app_config.dart';
import '../../core/settings/app_settings_cubit.dart';
import 'widgets/error_dialog.dart';

/// قبل توجيه المستخدم للرئيسية بعد التسجيل، يربط رقم هاتفه بالحساب (يرسل
/// GoTrue كود OTP تلقائيًا) ويعرض شاشة التحقق. في وضع التطوير مع
/// [AppConfig.otpBypass] يقفز مباشرة للرئيسية.
Future<void> continueToPhoneVerification(
  BuildContext context,
  String role,
  String? phone,
) async {
  if (AppConfig.otpBypass) {
    final homeRoute = homeRouteForRole(role);
    if (homeRoute != null) context.go(homeRoute);
    return;
  }

  final normalized = phone == null || phone.isEmpty ? '' : PhoneUtils.normalize(phone);
  if (normalized.isEmpty) {
    // لا يوجد رقم للتفعيل — لا نحجب المستخدم عن التطبيق.
    final homeRoute = homeRouteForRole(role);
    if (homeRoute != null) context.go(homeRoute);
    return;
  }

  final isArabic = context.read<AppSettingsCubit>().state.locale.languageCode == 'ar';
  final cubit = context.read<AuthCubit>();
  try {
    await cubit.attachPhone(normalized);
  } catch (e) {
    if (!context.mounted) return;
    showErrorDialog(context, mapOtpError(e, isArabic: isArabic));
    return;
  }

  if (!context.mounted) return;
  context.push('/otp-verify?mode=signup&phone=$normalized&role=$role');
}