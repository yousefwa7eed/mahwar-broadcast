import 'package:supabase_flutter/supabase_flutter.dart';

/// يرسم أخطاء GoTrue/الشبكة الخاصة بمسار التحقق من رقم الهاتف إلى رسائل
/// عربية/إنجليزية واضحة للمستخدم. القيمة الافتراضية رسالة عامة حتى لا يصل
/// أي نص خطأ خام من الخادم إلى المستخدم.
String mapOtpError(Object error, {required bool isArabic}) {
  String message(String en, String ar) => isArabic ? ar : en;

  if (error is AuthApiException) {
    switch (error.code) {
      case 'otp_expired':
        return message(
          'The code is incorrect or has expired. Try again.',
          'الرمز غير صحيح أو منتهي الصلاحية. حاول مرة أخرى.',
        );
      case 'over_sms_send_rate_limit':
      case 'over_request_rate_limit':
        return message(
          'Too many attempts. Wait a moment and try again.',
          'تم تجاوز عدد المحاولات. يرجى الانتظار قليلاً ثم إعادة المحاولة.',
        );
      case 'sms_send_failed':
      case 'hook_timeout':
      case 'hook_timeout_after_retry':
        return message(
          "We couldn't send the code. Try again later.",
          'تعذّر إرسال الرمز. حاول مرة أخرى لاحقاً.',
        );
      case 'phone_exists':
        return message(
          'This phone number is already registered to another account.',
          'رقم الهاتف مسجّل بالفعل في حساب آخر.',
        );
      case 'phone_not_confirmed':
        return message(
          'The phone number is not confirmed. Try the code again.',
          'لم يتم تأكيد رقم الهاتف بعد. حاول إدخال الرمز مرة أخرى.',
        );
      case 'reauthentication_needed':
      case 'reauthentication_not_valid':
        return message(
          'Please sign in again to continue.',
          'يرجى تسجيل الدخول مرة أخرى للمتابعة.',
        );
      case 'user_not_found':
        return message(
          "We couldn't send a code. Check the phone number and try again.",
          'تعذّر إرسال رمز التحقق. تأكد من صحة رقم الهاتف ثم أعد المحاولة.',
        );
      default:
        return _generic(isArabic);
    }
  }

  return _generic(isArabic);
}

/// يرسم أخطاء إرسال كود استعادة كلمة المرور (signInWithOtp) إلى رسائل
/// عربية/إنجليزية. لا يكشف للمستخدم ما إذا كان الرقم مسجّلًا: رموز
/// [user_not_found] و [phone_not_confirmed] (و [phone_only_account_blocked] من
/// رفض send-sms-hook) كلها تُرسم برسالة واحدة محايدة، فلا يمكن تمييز "رقم لا
/// يخص حسابًا" عن "حساب غير مكتمل التفعيل". كل الأخطاء الأخرى تُفوَّض إلى
/// [mapOtpError].
String mapRecoverySendError(Object error, {required bool isArabic}) {
  if (error is AuthApiException) {
    const nonRevealingCodes = {
      'user_not_found',
      'phone_not_confirmed',
      'phone_only_account_blocked',
    };
    if (nonRevealingCodes.contains(error.code)) {
      return isArabic
          ? 'تعذّر إرسال رمز التحقق. تأكد من صحة رقم الهاتف ثم أعد المحاولة.'
          : "We couldn't send a code. Check the phone number and try again.";
    }
  }
  return mapOtpError(error, isArabic: isArabic);
}

/// يرسم فشل الفحص المسبق لتفرّد الرقم في مسار تغيير الرقم (RPC
/// `get_email_by_phone`) — السياسة «فشل مُغلق»: أي خطأ في الفحص يمنع إرسال
/// الكود، فلا يُربط رقم لم يتحقق الخادم من تفرّده. يفرّق بين الحدّ المعدّل
/// ([_isThrottleError]) ورسالة عامة، ولا يكشف أي بيانات عن الرقم/الحساب.
String mapChangePhoneLookupError(Object error, {required bool isArabic}) {
  if (_isThrottleError(error)) {
    return isArabic
        ? 'تم تجاوز عدد المحاولات. حاول مرة أخرى لاحقاً.'
        : 'Too many attempts. Please try again later.';
  }
  return isArabic
      ? 'تعذّر التحقق من رقم الهاتف. حاول مرة أخرى.'
      : "Couldn't verify the phone number. Please try again.";
}

/// يميّز خطأ الحدّ المعدّل عن الفشل العام: إمّا رفض خادمي من RPC الفحص
/// (`get_email_by_phone` يرمي `TOO_MANY_LOOKUPS` بعد 5 محاولات/ساعة/رقم)، أو
/// رمز حدّ معدّل من GoTrue.
bool _isThrottleError(Object error) {
  if (error is PostgrestException) {
    if (error.code == 'TOO_MANY_LOOKUPS') return true;
    return error.message.toUpperCase().contains('TOO_MANY_LOOKUPS');
  }
  if (error is AuthApiException) {
    return error.code == 'over_request_rate_limit' ||
        error.code == 'over_sms_send_rate_limit';
  }
  return false;
}

String _generic(bool isArabic) => isArabic
    ? 'حدث خطأ ما. تحقق من اتصالك وحاول مرة أخرى.'
    : 'Something went wrong. Check your connection and try again.';