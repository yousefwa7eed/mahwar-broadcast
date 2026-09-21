import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/auth/auth_cubit.dart';
import '../../core/auth/home_route.dart';
import '../../core/auth/signup_error_mapper.dart';
import '../../core/settings/app_settings_cubit.dart';
import '../../core/settings/app_settings_state.dart';
import 'widgets/login_header_widget.dart';
import 'widgets/provider_signup_form_widget.dart';
import 'widgets/error_dialog.dart';
import 'otp_navigation.dart';

class SignupProviderScreen extends StatelessWidget {
  const SignupProviderScreen({super.key});

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
            'provider',
            state.user.userMetadata?['phone_number'] as String?,
          );
        } else if (state is AuthError) {
          showErrorDialog(context, mapSignupError(state.message));
        }
      },
      child: BlocBuilder<AppSettingsCubit, AppSettingsState>(
        builder: (context, settings) {
          final isDarkMode = settings.themeMode == ThemeMode.dark;
          final isArabic = settings.locale.languageCode == 'ar';

          return Scaffold(
            backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF9F9FB),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LoginHeaderWidget(role: 'provider'),
                    const SizedBox(height: 28),
                    Text(
                      isArabic ? 'انضم لشبكة مزودي خدمة محور' : 'Join Mahwar Provider Network',
                      style: TextStyle(
                        fontFamily: isArabic ? 'Zain' : 'Poppins',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isArabic
                          ? 'سجل بيانات ورشتك أو خدماتك لتلقي طلبات طوارئ الطرق في نطاقك المباشر'
                          : 'Register your workshop or service details to receive roadside emergency requests in your area',
                      style: TextStyle(
                        fontFamily: isArabic ? 'Cairo' : 'Poppins',
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const ProviderSignupFormWidget(),
                    ),
                    const SizedBox(height: 20),
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
