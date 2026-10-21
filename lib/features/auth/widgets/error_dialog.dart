import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

void showErrorDialog(BuildContext context, String message) {
  final colorScheme = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: colorScheme.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.error_outline, color: Color(0xFFE53935), size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            l10n?.errorTitle ?? 'خطأ',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
      content: Text(
        _friendlyMessage(message, l10n),
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          color: colorScheme.onSurface.withValues(alpha: 0.7),
          height: 1.6,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            l10n?.okButton ?? 'حسناً',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF6B00),
              fontSize: 15,
            ),
          ),
        ),
      ],
    ),
  );
}

String _friendlyMessage(String message, AppLocalizations? l10n) {
  final lower = message.toLowerCase();

  if (lower.contains('banned')) {
    return l10n?.errUserBanned ??
        'تم حظرك من استخدام تطبيق محور. إذا كنت تعتقد أن هذا خطأ، يرجى التواصل مع الدعم الفني.';
  }
  if (lower.contains('unexpected_error')) {
    return l10n?.authErrorUnexpected ?? 'حدث خطأ غير متوقع، حاول مرة أخرى.';
  }
  if (lower.contains('no_account_found')) {
    return l10n?.authErrorNoAccount ??
        'لا يوجد حساب مرتبط بهذا الرقم أو البريد الإلكتروني';
  }
  if (lower.contains('network_error')) {
    return l10n?.authErrorNetwork ??
        'لا يوجد اتصال بالإنترنت، تحقق من اتصالك وحاول مجددًا';
  }
  if (lower.contains('sign_out_failed')) {
    return l10n?.authErrorSignOut ?? 'حدث خطأ أثناء تسجيل الخروج';
  }

  if (lower.contains('phone') && (lower.contains('already') || lower.contains('exists') || lower.contains('duplicate') || lower.contains('unique'))) {
    return l10n?.errPhoneDuplicate ??
        'رقم الهاتف مسجل بالفعل في حساب آخر. يرجى استخدام رقم هاتف مختلف أو تسجيل الدخول بالحساب الموجود.';
  }
  if (lower.contains('national_id') && (lower.contains('already') || lower.contains('exists') || lower.contains('duplicate') || lower.contains('unique'))) {
    return l10n?.errNationalIdDuplicate ??
        'الرقم القومي مسجل بالفعل في حساب آخر. إذا كنت تملك حساباً سابقاً، يرجى تسجيل الدخول إليه.';
  }
  if (lower.contains('email') && (lower.contains('already') || lower.contains('exists') || lower.contains('duplicate') || lower.contains('unique') || lower.contains('registered'))) {
    return l10n?.errEmailDuplicate ??
        'البريد الإلكتروني مسجل بالفعل في حساب آخر. يرجى تسجيل الدخول بالحساب الموجود أو استخدام بريد إلكتروني مختلف.';
  }
  if (lower.contains('رقم الهاتف مسجل')) {
    return l10n?.errPhoneDuplicate ??
        'رقم الهاتف مسجل بالفعل في حساب آخر. يرجى استخدام رقم هاتف مختلف أو تسجيل الدخول بالحساب الموجود.';
  }
  if (lower.contains('الرقم القومي مسجل')) {
    return l10n?.errNationalIdDuplicate ??
        'الرقم القومي مسجل بالفعل في حساب آخر. إذا كنت تملك حساباً سابقاً، يرجى تسجيل الدخول إليه.';
  }
  if (lower.contains('invalid login credentials') || lower.contains('invalid')) {
    return l10n?.errInvalidCredentials ??
        'البريد الإلكتروني أو كلمة المرور غير صحيحة. يرجى التحقق من البيانات والمحاولة مرة أخرى.';
  }
  if (lower.contains('email not confirmed') || lower.contains('not confirmed')) {
    return l10n?.errEmailNotConfirmed ??
        'لم يتم تأكيد البريد الإلكتروني بعد. يرجى التحقق من بريدك الإلكتروني والضغط على رابط التأكيد.';
  }
  if (lower.contains('too many requests') || lower.contains('rate limit')) {
    return l10n?.errTooManyRequests ??
        'لقد تجاوزت عدد المحاولات المسموح. يرجى الانتظار قليلاً ثم المحاولة مرة أخرى.';
  }
  if (lower.contains('user not found') || lower.contains('no user')) {
    return l10n?.errUserNotFound ??
        'لا يوجد حساب مرتبط بهذا البريد الإلكتروني. يرجى التسجيل أولاً.';
  }
  if (lower.contains('password')) {
    return l10n?.errInvalidPassword ?? 'كلمة المرور غير صحيحة. يرجى المحاولة مرة أخرى.';
  }

  return message;
}
