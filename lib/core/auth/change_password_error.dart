import 'package:supabase_flutter/supabase_flutter.dart';

/// يُرمى عند محاولة تغيير كلمة المرور لحساب بلا بريد إلكتروني مرتبط — لا يمكن
/// التحقق من كلمة المرور الحالية عبر تسجيل دخول العميل المعزول في هذه الحالة.
class ChangePasswordNoEmailException implements Exception {
  const ChangePasswordNoEmailException();
}

/// يُرمى عند فشل حذف الحساب من دالة `delete-account` الخادمية، حاملًا رمز
/// الخطأ الذي أعاده الخادم (مثل PASSWORD_REQUIRED / INVALID_PASSWORD).
class DeleteAccountException implements Exception {
  final String code;

  const DeleteAccountException(this.code);

  @override
  String toString() => 'DeleteAccountException($code)';
}

/// أنواع فشل تغيير كلمة المرور التي تُرسم لها رسائل مخصّصة في الواجهة.
enum ChangePasswordError {
  /// كلمة المرور الحالية غير صحيحة.
  currentIncorrect,

  /// كلمة المرور الجديدة مطابقة للحالية.
  sameAsCurrent,

  /// كلمة المرور الجديدة ضعيفة (أقل من الحد المسموح).
  weak,

  /// يتطلّب الخادم إعادة مصادقة حديثة (تفعيل "Secure password change").
  reauthenticationRequired,

  /// تجاوز عدد المحاولات المسموح به (429 / over_request_rate_limit).
  rateLimited,

  /// الحساب بلا بريد إلكتروني مرتبط.
  noEmail,

  /// فشل غير معروف (شبكة/خادم).
  unknown,
}

/// يحوّل استثناء الخدمة إلى نوع خطأ قابل للترجمة في الواجهة. يعتمد على رمز
/// GoTrue ([AuthException.code]) الذي يعيده الخادم: `invalid_credentials` عند
/// خطأ كلمة المرور الحالية (من العميل المعزول)، و`same_password` /
/// `weak_password` / `reauthentication_needed` من نداء `updateUser` على العميل
/// الرئيسي. يُترجم `invalid_credentials` فقط إلى [ChangePasswordError.currentIncorrect]،
/// و`over_request_rate_limit` (أو أي رد 429) إلى [ChangePasswordError.rateLimited]،
/// وأي رمز آخر إلى [ChangePasswordError.unknown] بدل افتراض خطأ كلمة المرور.
ChangePasswordError mapChangePasswordError(Object error) {
  if (error is ChangePasswordNoEmailException) {
    return ChangePasswordError.noEmail;
  }
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return ChangePasswordError.currentIncorrect;
      case 'same_password':
        return ChangePasswordError.sameAsCurrent;
      case 'weak_password':
        return ChangePasswordError.weak;
      case 'reauthentication_needed':
        return ChangePasswordError.reauthenticationRequired;
    }
    if (error.code == 'over_request_rate_limit' ||
        error.statusCode == '429') {
      return ChangePasswordError.rateLimited;
    }
  }
  return ChangePasswordError.unknown;
}

/// يستخرج رمز خطأ حذف الحساب من أي استثناء: يعالج [DeleteAccountException]
/// (خدمة الإنتاج) و[FunctionException] (رمي `functions.invoke` مباشرة) بالشكل
/// نفسه، حتى تتمكّن الواجهة من تمييز `INVALID_PASSWORD` عن بقية الأخطاء. عند
/// غياب رمز صريح يعود لـ `INVALID_PASSWORD` لرد 403، وإلّا للرمز العام.
String deleteAccountErrorCode(Object error) {
  if (error is DeleteAccountException) return error.code;
  if (error is FunctionException) {
    final details = error.details;
    if (details is Map) {
      final code = details['code'];
      if (code is String && code.isNotEmpty) return code;
      final message = details['error'];
      if (message is String && message.isNotEmpty) return message;
    }
    if (error.status == 403) return 'INVALID_PASSWORD';
  }
  return 'DELETE_ACCOUNT_FAILED';
}
