import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import '../../../core/auth/auth_cubit.dart';
import '../../../core/auth/phone_utils.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/settings/app_settings_cubit.dart';
import '../../../l10n/app_localizations.dart';

class LoginFormWidget extends StatefulWidget {
  final String role;

  /// يعكس انشغال الشاشة (تحديد الدور/الرفض) بعد نجاح المصادقة — يُبقي زر
  /// الدخول في حالة تحميل حتى نتّخذ قرار التوجيه أو الرفض.
  final bool isBusy;
  final Function(String identifier, String password) onSubmit;
  final VoidCallback onSignupTap;
  final VoidCallback onForgotPasswordTap;

  const LoginFormWidget({
    super.key,
    required this.role,
    this.isBusy = false,
    required this.onSubmit,
    required this.onSignupTap,
    required this.onForgotPasswordTap,
  });

  @override
  State<LoginFormWidget> createState() => _LoginFormWidgetState();
}

class _LoginFormWidgetState extends State<LoginFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isPhoneMode = true; // true = phone, false = email

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  TextInputType get _identifierKeyboardType => _isPhoneMode ? TextInputType.phone : TextInputType.emailAddress;

  List<TextInputFormatter> get _identifierInputFormatters {
    if (_isPhoneMode) {
      return [FilteringTextInputFormatter.digitsOnly];
    }
    return [];
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onSubmit(
        _identifierController.text.trim(),
        _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isProvider = widget.role == 'provider';
    final isArabic = context.watch<AppSettingsCubit>().state.locale.languageCode == 'ar';
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final Color primaryColor = isProvider
        ? (isDark ? AppColors.orangePrimary : const Color(0xFF1E1E1E))
        : AppColors.orangePrimary;

    final bool isAuthLoading =
        context.watch<AuthCubit>().state is AuthLoading || widget.isBusy;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // حقل الدخول: رقم الهاتف أو البريد الإلكتروني مع toggle للتبديل
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n?.loginMethod ?? 'طريقة الدخول',
                      style: TextStyle(
                        fontFamily: isArabic ? 'Cairo' : 'Poppins',
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  ToggleButtons(
                    isSelected: [_isPhoneMode, !_isPhoneMode],
                    onPressed: (index) => setState(() => _isPhoneMode = index == 0),
                    borderRadius: BorderRadius.circular(8),
                    selectedColor: Colors.white,
                    fillColor: primaryColor,
                    color: primaryColor,
                    constraints: const BoxConstraints(minHeight: 36, minWidth: 90),
                    children: [
                      Text(
                        l10n?.phoneTab ?? 'هاتف',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        l10n?.emailTab ?? 'بريد',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _identifierController,
                keyboardType: _identifierKeyboardType,
                inputFormatters: _identifierInputFormatters,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: _isPhoneMode
                      ? (l10n?.phoneNumber ?? 'رقم الهاتف')
                      : (l10n?.emailLabel ?? 'البريد الإلكتروني'),
                  hintText: _isPhoneMode
                      ? (isArabic ? '01xxxxxxxxx' : '01xxxxxxxxx')
                      : (isArabic ? 'example@domain.com' : 'example@domain.com'),
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  prefixIcon: Icon(_isPhoneMode ? Icons.phone_android_rounded : Icons.email_rounded, color: primaryColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return _isPhoneMode
                        ? (l10n?.enterPhonePrompt ?? 'يرجى إدخال رقم الهاتف')
                        : (l10n?.enterEmailPrompt ?? 'يرجى إدخال البريد الإلكتروني');
                  }
                  if (_isPhoneMode && !PhoneUtils.isValidEgyptianMobile(value.trim())) {
                    return l10n?.invalidPhoneShort ??
                        'رقم هاتف مصري غير صحيح (مثال: 01012345678)';
                  }
                  if (!_isPhoneMode && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                    return l10n?.invalidEmailFormat ?? 'صيغة البريد الإلكتروني غير صحيحة';
                  }
                  return null;
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: l10n?.password ?? 'كلمة المرور',
              prefixIcon: Icon(Icons.lock_rounded, color: primaryColor),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n?.enterPasswordPrompt ?? 'يرجى إدخال كلمة المرور';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),

          // Forgot Password Link
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: widget.onForgotPasswordTap,
              child: Text(
                l10n?.forgotPassword ?? 'نسيت كلمة المرور؟',
                style: TextStyle(
                  fontFamily: isArabic ? 'Cairo' : 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Submit Button
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
              onPressed: isAuthLoading ? null : _submit,
              child: isAuthLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      l10n?.login ?? 'تسجيل الدخول',
                      style: TextStyle(
                        fontFamily: isArabic ? 'Cairo' : 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Signup Redirect Link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n?.dontHaveAccount ?? 'ليس لديك حساب؟ ',
                style: TextStyle(
                  fontFamily: isArabic ? 'Cairo' : 'Poppins',
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              GestureDetector(
                onTap: widget.onSignupTap,
                child: Text(
                  l10n?.signup ?? 'إنشاء حساب جديد',
                  style: TextStyle(
                    fontFamily: isArabic ? 'Cairo' : 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    decoration: TextDecoration.underline,
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