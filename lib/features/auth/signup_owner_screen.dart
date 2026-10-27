import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_cubit.dart';
import '../../core/auth/home_route.dart';
import '../../core/auth/phone_utils.dart';
import '../../core/auth/signup_error_mapper.dart';
import '../../core/settings/app_settings_cubit.dart';
import '../../core/settings/app_settings_state.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/owner_signup_form_widget.dart';
import 'widgets/error_dialog.dart';
import 'otp_navigation.dart';

class SignupOwnerScreen extends StatelessWidget {
  const SignupOwnerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          // الحارس يضمن أن شاشة التسجيل ليست هي التي تتحرك أثناء/بعد فتح
          // شاشة OTP فوقها — شاشة OTP هي المسؤولة عن التنقل بعد التحقق.
          if (!isTopmostRoute(context, '/signup')) return;
          continueToPhoneVerification(
            context,
            'car_owner',
            state.user.userMetadata?['phone_number'] as String?,
          );
        } else if (state is AuthError) {
          showErrorDialog(context, mapSignupError(state.message, AppLocalizations.of(context)));
        }
      },
      child: BlocBuilder<AppSettingsCubit, AppSettingsState>(
        builder: (context, settings) {
          final isArabic = settings.locale.languageCode == 'ar';
          final isDarkMode = settings.themeMode == ThemeMode.dark;
          final l10n = AppLocalizations.of(context);

          return Scaffold(
            backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
            appBar: AppBar(
              backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_rounded,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E1E1E),
                ),
                onPressed: () => context.pop(),
              ),
              title: Text(
                l10n?.signupOwnerTitle ?? 'حساب مالك سيارة جديد',
                style: TextStyle(
                  fontFamily: isArabic ? 'Cairo' : 'Poppins',
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E1E1E),
                ),
              ),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.signup ?? 'إنشاء حساب جديد',
                      style: TextStyle(
                        fontFamily: isArabic ? 'Zain' : 'Poppins',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFF6B00),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n?.signupOwnerSubtitle ??
                          'سجل بياناتك وسيارتك لتتمكن من طلب خدمات الطوارئ',
                      style: TextStyle(
                        fontFamily: isArabic ? 'Cairo' : 'Poppins',
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    OwnerSignupFormWidget(
                      onSubmit: (fullName, phone, email, nationalId, vehicle, password) {
                        final normalizedPhone = PhoneUtils.normalize(phone);
                        final emailToUse = email ?? '$normalizedPhone@mahwar.app';
                        context.read<AuthCubit>().signUp(
                          email: emailToUse,
                          password: password,
                          fullName: fullName,
                          phoneNumber: normalizedPhone,
                          role: 'car_owner',
                          nationalId: nationalId,
                          vehicle: vehicle,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
