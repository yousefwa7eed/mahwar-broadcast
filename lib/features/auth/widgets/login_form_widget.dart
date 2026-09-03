import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/settings/app_settings_cubit.dart';

class LoginFormWidget extends StatefulWidget {
  final String role;
  final Function(String identifier, String password) onSubmit;
  final VoidCallback onSignupTap;

  const LoginFormWidget({
    super.key,
    required this.role,
    required this.onSubmit,
    required this.onSignupTap,
  });

  @override
  State<LoginFormWidget> createState() => _LoginFormWidgetState();
}

class _LoginFormWidgetState extends State<LoginFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final Color primaryColor = isProvider
        ? (isDark ? AppColors.orangePrimary : const Color(0xFF1E1E1E))
        : AppColors.orangePrimary;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // حقل واحد يقبل رقم الهاتف أو البريد الإلكتروني، أيًا كان اللي
          // سجّل بيه المستخدم حسابه من الأول - النظام بيتعرف عليه تلقائيًا.
          TextFormField(
            controller: _identifierController,
            keyboardType: TextInputType.text,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: isArabic ? 'رقم الهاتف أو البريد الإلكتروني' : 'Phone or Email',
              hintText: isArabic ? '01xxxxxxxxx أو example@domain.com' : '01xxxxxxxxx or example@domain.com',
              hintStyle: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              prefixIcon: Icon(Icons.person_rounded, color: primaryColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return isArabic ? 'يرجى إدخال رقم الهاتف أو البريد الإلكتروني' : 'Please enter your phone or email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: isArabic ? 'كلمة المرور' : 'Password',
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
                return isArabic ? 'يرجى إدخال كلمة المرور' : 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),

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
              onPressed: _submit,
              child: Text(
                isArabic ? 'تسجيل الدخول' : 'Login',
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
                isArabic ? 'ليس لديك حساب؟ ' : "Don't have an account? ",
                style: TextStyle(
                  fontFamily: isArabic ? 'Cairo' : 'Poppins',
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              GestureDetector(
                onTap: widget.onSignupTap,
                child: Text(
                  isArabic ? 'إنشاء حساب جديد' : 'Create Account',
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