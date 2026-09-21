import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_cubit.dart';
import '../../core/constants/app_colors.dart';
import '../../core/settings/app_settings_cubit.dart';
import 'widgets/error_dialog.dart';

/// شاشة تعيين كلمة مرور جديدة — تُفتح من رابط الاستعادة (deep link) بعد
/// تشغيل جلسة recovery عبر goTrue. عند النجاح يخرج التطبيق تلقائيًا ويعود
/// لشاشة الدخول ليجرب المستخدم كلمة المرور الجديدة.
class SetNewPasswordScreen extends StatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _submitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final isArabic =
        context.read<AppSettingsCubit>().state.locale.languageCode == 'ar';
    setState(() => _submitting = true);
    try {
      await context.read<AuthCubit>().setNewPassword(_passwordController.text);
      if (!mounted) return;
      _showSuccess(isArabic);
      context.go('/login');
    } on AuthSessionMissingException {
      if (!mounted) return;
      setState(() => _submitting = false);
      showErrorDialog(
        context,
        'انتهت صلاحية رابط استعادة كلمة المرور. يرجى طلب رابط جديد.',
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showErrorDialog(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showErrorDialog(
          context, 'حدث خطأ في تعيين كلمة المرور. حاول مرة أخرى.');
    }
  }

  void _showSuccess(bool isArabic) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isArabic
                    ? 'تم تغيير كلمة المرور بنجاح. سجّل الدخول بكلمة المرور الجديدة.'
                    : 'Password changed successfully. Log in with your new password.',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic =
        context.watch<AppSettingsCubit>().state.locale.languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor =
        AppColors.orangePrimary; // استعادة لا تعرف الدور — برتقالي محايد

    // رابط ميّت/منتهي بلا جلسة استعادة → عرض بسيط مع زر العودة للدخول.
    final hasRecoverySession =
        context.watch<AuthCubit>().state is AuthAuthenticated;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: colorScheme.onSurface),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: hasRecoverySession
              ? _buildForm(context, primaryColor, isArabic, colorScheme, isDark)
              : _buildExpiredView(context, primaryColor, isArabic, colorScheme),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, Color primaryColor, bool isArabic,
      ColorScheme colorScheme, bool isDark) {
    return Form(
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
            child: Icon(Icons.password_rounded, color: primaryColor, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            isArabic ? 'تعيين كلمة مرور جديدة' : 'Set a New Password',
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
                ? 'أدخل كلمة مرور جديدة لحسابك (6 أحرف على الأقل).'
                : 'Enter a new password for your account (min 6 characters).',
            style: TextStyle(
              fontFamily: isArabic ? 'Cairo' : 'Poppins',
              fontSize: 14,
              height: 1.6,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: isArabic ? 'كلمة المرور الجديدة' : 'New password',
              prefixIcon: Icon(Icons.lock_rounded, color: primaryColor),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
            validator: (value) {
              final pass = value ?? '';
              if (pass.isEmpty) {
                return isArabic
                    ? 'يرجى إدخال كلمة المرور الجديدة'
                    : 'Please enter a new password';
              }
              if (pass.length < 6) {
                return isArabic
                    ? 'كلمة المرور يجب أن لا تقل عن 6 أحرف'
                    : 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: isArabic ? 'تأكيد كلمة المرور' : 'Confirm password',
              prefixIcon: Icon(Icons.lock_outline_rounded, color: primaryColor),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
            validator: (value) {
              if ((value ?? '').isEmpty) {
                return isArabic
                    ? 'يرجى تأكيد كلمة المرور'
                    : 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return isArabic
                    ? 'كلمتا المرور غير متطابقتين'
                    : 'Passwords do not match';
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
                      isArabic ? 'تغيير كلمة المرور' : 'Change Password',
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
    );
  }

  Widget _buildExpiredView(BuildContext context, Color primaryColor,
      bool isArabic, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.link_off_rounded,
              color: colorScheme.onSurface, size: 32),
        ),
        const SizedBox(height: 20),
        Text(
          isArabic ? 'الرابط غير صالح أو منتهي' : 'Invalid or expired link',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: isArabic ? 'Cairo' : 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isArabic
              ? 'اطلب رابط استعادة جديدًا من شاشة "نسيت كلمة المرور" بالضغط على "نسيت كلمة المرور؟" في شاشة تسجيل الدخول.'
              : 'Request a fresh reset link via "Forgot password?" on the login screen.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: isArabic ? 'Cairo' : 'Poppins',
            fontSize: 14,
            height: 1.6,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () => context.go('/login'),
          child: Text(
            isArabic ? 'العودة لتسجيل الدخول' : 'Back to Login',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}