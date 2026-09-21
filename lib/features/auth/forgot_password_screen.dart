import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_cubit.dart';
import '../../core/auth/otp_error_mapper.dart';
import '../../core/auth/phone_utils.dart';
import '../../core/constants/app_colors.dart';
import '../../core/settings/app_settings_cubit.dart';
import 'widgets/error_dialog.dart';

/// استعادة كلمة المرور عبر SMS: يدخل المستخدم رقم هاتفه المصري، يُرسل GoTrue
/// كود دخول OTP إلى الرقم (signInWithOtp / shouldCreateUser: false فلا تُنشأ
/// حسابات جديدة)، ثم تفتح شاشة [OtpScreen] لاستقبال الكود، وبعد نجاح التحقق
/// ينتقل إلى شاشة تعيين كلمة مرور جديدة مباشرة. الأخطاء المتعلقة برقم غير
/// مسجّل أو حساب غير مكتمل التفعيل تُرسم برسالة واحدة لا تكشف حالة الرقم.
class ForgotPasswordScreen extends StatefulWidget {
  final String role;
  const ForgotPasswordScreen({super.key, this.role = 'car_owner'});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _submitting = false;

  bool get _isProvider => widget.role == 'provider';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final normalized = PhoneUtils.normalize(_phoneController.text.trim());
    setState(() => _submitting = true);
    try {
      await context.read<AuthCubit>().requestForgotPasswordOtp(normalized);
      if (!mounted) return;
      setState(() => _submitting = false);
      await context.push(
          '/otp-verify?mode=forgot&phone=$normalized&role=${widget.role}');
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final isArabic =
          context.read<AppSettingsCubit>().state.locale.languageCode == 'ar';
      showErrorDialog(
          context, mapRecoverySendError(e, isArabic: isArabic));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final isArabic =
          context.read<AppSettingsCubit>().state.locale.languageCode == 'ar';
      showErrorDialog(
          context, mapRecoverySendError(e, isArabic: isArabic));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final isArabic =
          context.read<AppSettingsCubit>().state.locale.languageCode == 'ar';
      showErrorDialog(context,
          mapRecoverySendError(e, isArabic: isArabic));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic =
        context.watch<AppSettingsCubit>().state.locale.languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final Color primaryColor = _isProvider
        ? (isDark ? AppColors.orangePrimary : const Color(0xFF1E1E1E))
        : AppColors.orangePrimary;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.key_rounded, color: primaryColor, size: 32),
                ),
                const SizedBox(height: 20),
                Text(
                  isArabic ? 'استعادة كلمة المرور' : 'Reset Password',
                  style: TextStyle(
                    fontFamily: isArabic ? 'Cairo' : 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isArabic
                      ? 'أدخل رقم الهاتف المرتبط بحسابك. سنرسل إليه رمز تحقق عبر رسالة نصية (SMS).'
                      : 'Enter the phone number linked to your account. We will send a verification code via SMS.',
                  style: TextStyle(
                    fontFamily: isArabic ? 'Cairo' : 'Poppins',
                    fontSize: 14,
                    height: 1.6,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  decoration: InputDecoration(
                    labelText: isArabic ? 'رقم الهاتف' : 'Phone number',
                    hintText: '01012345678',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    prefixIcon:
                        Icon(Icons.phone_android_rounded, color: primaryColor),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                  ),
                  validator: (value) {
                    final input = value?.trim() ?? '';
                    if (input.isEmpty) {
                      return isArabic
                          ? 'يرجى إدخال رقم الهاتف'
                          : 'Please enter your phone number';
                    }
                    if (!PhoneUtils.isValidEgyptianMobile(input)) {
                      return isArabic
                          ? 'رقم هاتف مصري غير صحيح (مثال: 01012345678)'
                          : 'Invalid Egyptian phone number (e.g. 01012345678)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            isArabic ? 'إرسال رمز التحقق' : 'Send Code',
                            style: TextStyle(
                              fontFamily: isArabic ? 'Cairo' : 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}