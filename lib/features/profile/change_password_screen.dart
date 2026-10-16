import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/change_password_error.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../auth/widgets/error_dialog.dart';

/// شاشة تغيير كلمة المرور للمستخدم المسجّل (صاحب حساب/مقدّم خدمة). تتحقق من
/// كلمة المرور الحالية عبر عميل معزول ثم تضبط الجديدة على الجلسة الحالية، ولا
/// تُخرج المستخدم من حسابه.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.service});

  /// حقن الخدمة للاختبارات؛ الافتراضي هو العميل الحقيقي.
  final AuthService? service;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;

  late final AuthService _service = widget.service ?? SupabaseAuthService();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await _service.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      _showSuccess();
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showErrorDialog(context, _messageFor(mapChangePasswordError(e)));
    }
  }

  String _messageFor(ChangePasswordError error) {
    final l10n = AppLocalizations.of(context)!;
    switch (error) {
      case ChangePasswordError.currentIncorrect:
        return l10n.currentPasswordIncorrect;
      case ChangePasswordError.sameAsCurrent:
        return l10n.newPasswordSameAsCurrent;
      case ChangePasswordError.weak:
        return l10n.passwordTooShort;
      case ChangePasswordError.reauthenticationRequired:
        return l10n.reauthenticationRequired;
      case ChangePasswordError.rateLimited:
        return l10n.changePasswordRateLimited;
      case ChangePasswordError.noEmail:
        return l10n.changePasswordNoEmail;
      case ChangePasswordError.unknown:
        return l10n.changePasswordFailed;
    }
  }

  void _showSuccess() {
    final l10n = AppLocalizations.of(context)!;
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
                l10n.passwordChangedSuccess,
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
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = AppColors.orangePrimary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.changePassword,
          style: TextStyle(
            fontFamily: isArabic ? 'Cairo' : 'Poppins',
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
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
                  child: Icon(Icons.password_rounded,
                      color: primaryColor, size: 32),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.changePasswordSubtitle,
                  style: TextStyle(
                    fontFamily: isArabic ? 'Cairo' : 'Poppins',
                    fontSize: 14,
                    height: 1.6,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),
                _buildField(
                  controller: _currentController,
                  label: l10n.currentPasswordLabel,
                  icon: Icons.lock_rounded,
                  obscure: _obscureCurrent,
                  onToggle: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                  primaryColor: primaryColor,
                  validator: (value) {
                    if ((value ?? '').isEmpty) {
                      return l10n.enterCurrentPassword;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _newController,
                  label: l10n.newPasswordLabel,
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscureNew,
                  onToggle: () => setState(() => _obscureNew = !_obscureNew),
                  primaryColor: primaryColor,
                  validator: (value) {
                    final pass = value ?? '';
                    if (pass.isEmpty) return l10n.enterNewPassword;
                    if (pass.length < 6) return l10n.passwordTooShort;
                    if (pass == _currentController.text) {
                      return l10n.newPasswordSameAsCurrent;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _confirmController,
                  label: l10n.confirmNewPasswordLabel,
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscureConfirm,
                  onToggle: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  primaryColor: primaryColor,
                  validator: (value) {
                    if ((value ?? '').isEmpty) return l10n.enterConfirmPassword;
                    if (value != _newController.text) {
                      return l10n.passwordsDoNotMatch;
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
                            l10n.changePassword,
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
    required Color primaryColor,
    required String? Function(String?) validator,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      validator: validator,
    );
  }
}
