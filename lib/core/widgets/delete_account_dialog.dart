import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../auth/auth_service.dart';
import '../auth/change_password_error.dart';
import '../constants/app_colors.dart';

/// يعرض حوار تأكيد حذف الحساب برمز تحقق يُرسل إلى هاتف المستخدم. يعيد `true`
/// عند نجاح الحذف (ليتولّى المستدعي التوجيه)، و`null` عند الإلغاء/الإغلاق.
Future<bool?> showDeleteAccountDialog(
  BuildContext context, {
  required AuthService authService,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => DeleteAccountDialog(authService: authService),
  );
}

/// حوار تأكيد حذف الحساب — مشترك بين شاشة الملف الشخصي ورئيسية المزوّد.
///
/// كل الحسابات هاتفية (دخول OTP بلا كلمة مرور)، فالتأكيد يتم برمز يُرسل إلى
/// رقم المستخدم نفسه: زر «إرسال رمز التحقق» ثم حقل الرمز ثم «حذف». التحقق
/// النهائي من الرمز يقع على الخادم داخل دالة `delete-account`، ولا يُقبل مجرد
/// إثبات العميل. الخدمة قابلة للحقن لتسهيل الاختبار.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key, required this.authService});

  final AuthService authService;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  static const int _codeLength = 6;
  static const int _resendSeconds = 60;

  final _codeController = TextEditingController();
  String? _errorText;
  bool _sendingOtp = false;
  bool _submitting = false;
  bool _codeSent = false;
  Timer? _ticker;
  int _cooldown = 0;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    super.dispose();
  }

  String get _phone => widget.authService.currentUser?.phone ?? '';

  /// يخفي أول أرقام الرقم ويكشف آخر أربعة — للعرض فقط، لا يُرسل شيء.
  String get _maskedPhone {
    final digits = _phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return '••••';
    return '•••• ••• ${digits.substring(digits.length - 4)}';
  }

  void _onCodeChanged() {
    if (!mounted) return;
    setState(() {
      if (_codeController.text.isNotEmpty) _errorText = null;
    });
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _cooldown = _cooldown > 0 ? _cooldown - 1 : 0);
      if (_cooldown == 0) {
        _ticker?.cancel();
        _ticker = null;
      }
    });
  }

  Future<void> _sendCode(AppLocalizations? l10n) async {
    if (_sendingOtp || _submitting) return;
    setState(() {
      _sendingOtp = true;
      _errorText = null;
    });
    try {
      await widget.authService.requestDeleteAccountOtp();
      if (!mounted) return;
      setState(() {
        _sendingOtp = false;
        _codeSent = true;
        _cooldown = _resendSeconds;
      });
      _startTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sendingOtp = false;
        _errorText = _mapError(e, l10n);
      });
    }
  }

  Future<void> _submit(AppLocalizations? l10n) async {
    if (_submitting || _sendingOtp) return;
    final otp = _codeController.text.trim();
    if (otp.length != _codeLength) {
      setState(
        () => _errorText =
            l10n?.deleteAccountOtpIncomplete ?? 'أدخل رمز التحقق المكوّن من 6 أرقام',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await widget.authService.deleteAccount(otp: otp);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = _mapError(e, l10n);
      });
    }
  }

  String _mapError(Object error, AppLocalizations? l10n) {
    switch (deleteAccountErrorCode(error)) {
      case 'INVALID_OTP':
        return l10n?.deleteAccountInvalidOtp ??
            'رمز التحقق غير صحيح أو منتهي الصلاحية. اطلب رمزًا جديدًا.';
      case 'RATE_LIMITED':
        return l10n?.deleteAccountRateLimited ??
            'محاولات كثيرة في وقت قصير. حاول بعد قليل.';
      case 'PHONE_REQUIRED':
      case 'PHONE_VERIFICATION_UNAVAILABLE':
        return l10n?.deleteAccountPhoneMissing ??
            'لا يوجد رقم هاتف مرتبط بالحساب. تواصل مع الدعم لحذف الحساب.';
    }
    return l10n?.deleteAccountFailed ?? 'تعذّر حذف الحساب. حاول مرة أخرى.';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bodyColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final hintColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final busy = _sendingOtp || _submitting;

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
              height: 1.6,
              color: bodyColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _codeSent
                ? (l10n?.deleteAccountOtpSentTo(_maskedPhone) ??
                    'أدخل الرمز المكوّن من 6 أرقام المرسل إلى $_maskedPhone')
                : (l10n?.deleteAccountOtpPrompt ??
                    'لتأكيد الحذف سنرسل رمز تحقق إلى رقم هاتفك المسجّل.'),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              height: 1.6,
              color: hintColor,
            ),
          ),
          if (_codeSent) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _codeController,
              enabled: !busy,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_codeLength),
              ],
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 22,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                labelText: l10n?.deleteAccountOtpLabel ?? 'رمز التحقق',
                prefixIcon: const Icon(Icons.password_rounded),
                errorText: _errorText,
                errorMaxLines: 3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _cooldown > 0
                  ? Text(
                      l10n?.resendCodeIn(_cooldown) ??
                          'إعادة الإرسال بعد $_cooldown ثانية',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: hintColor,
                      ),
                    )
                  : TextButton(
                      onPressed: busy ? null : () => _sendCode(l10n),
                      child: Text(
                        l10n?.resendCode ?? 'إعادة إرسال الرمز',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: AppColors.orangePrimary,
                        ),
                      ),
                    ),
            ),
          ] else if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorText!,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: Text(
            l10n?.cancel ?? 'إلغاء',
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: AppColors.lightTextSecondary,
            ),
          ),
        ),
        if (!_codeSent)
          TextButton(
            onPressed: busy ? null : () => _sendCode(l10n),
            child: _sendingOtp
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.orangePrimary,
                    ),
                  )
                : Text(
                    l10n?.deleteAccountSendOtp ?? 'إرسال رمز التحقق',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.orangePrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          )
        else
          TextButton(
            onPressed: busy ? null : () => _submit(l10n),
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
