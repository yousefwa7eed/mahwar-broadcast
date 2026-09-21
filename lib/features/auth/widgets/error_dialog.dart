import 'package:flutter/material.dart';

void showErrorDialog(BuildContext context, String message) {
  final colorScheme = Theme.of(context).colorScheme;

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
            'خطأ',
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
        _friendlyMessage(message),
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
          child: const Text(
            'حسناً',
            style: TextStyle(
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

String _friendlyMessage(String message) {
  final lower = message.toLowerCase();

  if (lower.contains('phone') && (lower.contains('already') || lower.contains('exists') || lower.contains('duplicate') || lower.contains('unique'))) {
    return 'رقم الهاتف مسجل بالفعل في حساب آخر. يرجى استخدام رقم هاتف مختلف أو تسجيل الدخول بالحساب الموجود.';
  }
  if (lower.contains('national_id') && (lower.contains('already') || lower.contains('exists') || lower.contains('duplicate') || lower.contains('unique'))) {
    return 'الرقم القومي مسجل بالفعل في حساب آخر. إذا كنت تملك حساباً سابقاً، يرجى تسجيل الدخول إليه.';
  }
  if (lower.contains('email') && (lower.contains('already') || lower.contains('exists') || lower.contains('duplicate') || lower.contains('unique') || lower.contains('registered'))) {
    return 'البريد الإلكتروني مسجل بالفعل في حساب آخر. يرجى تسجيل الدخول بالحساب الموجود أو استخدام بريد إلكتروني مختلف.';
  }
  if (lower.contains('رقم الهاتف مسجل')) {
    return 'رقم الهاتف مسجل بالفعل في حساب آخر. يرجى استخدام رقم هاتف مختلف أو تسجيل الدخول بالحساب الموجود.';
  }
  if (lower.contains('الرقم القومي مسجل')) {
    return 'الرقم القومي مسجل بالفعل في حساب آخر. إذا كنت تملك حساباً سابقاً، يرجى تسجيل الدخول إليه.';
  }
  if (lower.contains('invalid login credentials') || lower.contains('invalid')) {
    return 'البريد الإلكتروني أو كلمة المرور غير صحيحة. يرجى التحقق من البيانات والمحاولة مرة أخرى.';
  }
  if (lower.contains('email not confirmed') || lower.contains('not confirmed')) {
    return 'لم يتم تأكيد البريد الإلكتروني بعد. يرجى التحقق من بريدك الإلكتروني والضغط على رابط التأكيد.';
  }
  if (lower.contains('too many requests') || lower.contains('rate limit')) {
    return 'لقد تجاوزت عدد المحاولات المسموح. يرجى الانتظار قليلاً ثم المحاولة مرة أخرى.';
  }
  if (lower.contains('user not found') || lower.contains('no user')) {
    return 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني. يرجى التسجيل أولاً.';
  }
  if (lower.contains('password')) {
    return 'كلمة المرور غير صحيحة. يرجى المحاولة مرة أخرى.';
  }

  return message;
}
