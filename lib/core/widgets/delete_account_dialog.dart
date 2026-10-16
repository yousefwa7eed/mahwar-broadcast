import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../auth/auth_service.dart';
import '../auth/change_password_error.dart';
import '../constants/app_colors.dart';

/// يعرض حوار تأكيد حذف الحساب بكلمة المرور الحالية. يعيد `true` عند نجاح
/// الحذف (ليتولّى المستدعي التوجيه)، و`null` عند الإلغاء/الإغلاق.
Future<bool?> showDeleteAccountDialog(
  BuildContext context, {
  required AuthService authService,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => DeleteAccountDialog(authService: authService),
  );
}

/// حوار تأكيد حذف الحساب — مشترك بين شاشة الملف الشخصي ورئيسية المزوّد بدل
/// تكراره في كل شاشة. تُمرَّر كلمة المرور إلى [AuthService.deleteAccount]
/// للتحقق منها خادميًا؛ رمز `INVALID_PASSWORD` يُرسم كخطأ حقل، وبقية الأخطاء
/// برسالة عامة. الخدمة قابلة للحقن لتسهيل الاختبار.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key, required this.authService});

  final AuthService authService;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  String? _errorText;
  bool _submitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations? l10n) async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(
        () => _errorText =
            l10n?.enterCurrentPassword ?? 'يرجى إدخال كلمة المرور الحالية',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await widget.authService.deleteAccount(currentPassword: password);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = deleteAccountErrorCode(e) == 'INVALID_PASSWORD'
            ? (l10n?.currentPasswordIncorrect ?? 'كلمة المرور الحالية غير صحيحة')
            : (l10n?.changePasswordFailed ?? 'تعذّر حذف الحساب. حاول مرة أخرى.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        l10n?.deleteAccount ?? 'حذف الحساب',
        style: const TextStyle(
          fontFamily: 'Zain',
          fontSize: 20,
          color: AppColors.error,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.deleteAccountConfirm ??
                'هل أنت متأكد من حذف حسابك نهائياً؟ لن تتمكن من استعادته.',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.deleteAccountPasswordPrompt ??
                'أدخل كلمة المرور الحالية لتأكيد حذف الحساب',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            enabled: !_submitting,
            decoration: InputDecoration(
              labelText: l10n?.currentPasswordLabel ?? 'كلمة المرور الحالية',
              prefixIcon: const Icon(Icons.lock_rounded),
              errorText: _errorText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: Text(
            l10n?.cancel ?? 'إلغاء',
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: AppColors.lightTextSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: _submitting ? null : () => _submit(l10n),
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.error,
                  ),
                )
              : Text(
                  l10n?.delete ?? 'حذف',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }
}
