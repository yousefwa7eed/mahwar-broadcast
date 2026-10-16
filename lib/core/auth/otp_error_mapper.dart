import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';

/// يرسم أخطاء GoTrue/الشبكة الخاصة بمسار التحقق من رقم الهاتف إلى رسائل
/// واضحة للمستخدم عبر ARB. القيمة الافتراضية رسالة عامة حتى لا يصل
/// أي نص خطأ خام من الخادم إلى المستخدم.
String mapOtpError(Object error, AppLocalizations? l10n) {
  if (error is AuthApiException) {
    switch (error.code) {
      case 'otp_expired':
        return l10n?.otpErrorExpired ??
            'الرمز غير صحيح أو منتهي الصلاحية. حاول مرة أخرى.';
      case 'over_sms_send_rate_limit':
      case 'over_request_rate_limit':
        return l10n?.otpErrorRateLimited ??
            'تم تجاوز عدد المحاولات. يرجى الانتظار قليلاً ثم إعادة المحاولة.';
      case 'sms_send_failed':
      case 'hook_timeout':
      case 'hook_timeout_after_retry':
        return l10n?.otpErrorSendFailed ?? 'تعذّر إرسال الرمز. حاول مرة أخرى لاحقاً.';
      case 'phone_exists':
        return l10n?.otpErrorPhoneExists ?? 'رقم الهاتف مسجّل بالفعل في حساب آخر.';
      case 'phone_not_confirmed':
        return l10n?.otpErrorPhoneNotConfirmed ??
            'لم يتم تأكيد رقم الهاتف بعد. حاول إدخال الرمز مرة أخرى.';
      case 'reauthentication_needed':
      case 'reauthentication_not_valid':
        return l10n?.otpErrorReauth ?? 'يرجى تسجيل الدخول مرة أخرى للمتابعة.';
      case 'user_not_found':
        return l10n?.otpErrorUserNotFound ??
            'تعذّر إرسال رمز التحقق. تأكد من صحة رقم الهاتف ثم أعد المحاولة.';
      default:
        return _generic(l10n);
    }
  }

  return _generic(l10n);
}

/// يرسم أخطاء إرسال كود استعادة كلمة المرور (signInWithOtp) إلى رسائل
/// واضحة. لا يكشف للمستخدم ما إذا كان الرقم مسجّلًا: رموز
/// [user_not_found] و [phone_not_confirmed] (و [phone_only_account_blocked] من
/// رفض send-sms-hook) كلها تُرسم برسالة واحدة محايدة، فلا يمكن تمييز "رقم لا
/// يخص حسابًا" عن "حساب غير مكتمل التفعيل". كل الأخطاء الأخرى تُفوَّض إلى
/// [mapOtpError].
String mapRecoverySendError(Object error, AppLocalizations? l10n) {
  if (error is AuthApiException) {
    const nonRevealingCodes = {
      'user_not_found',
      'phone_not_confirmed',
      'phone_only_account_blocked',
    };
    if (nonRevealingCodes.contains(error.code)) {
      return l10n?.recoveryNeutralError ??
          'تعذّر إرسال رمز التحقق. تأكد من صحة رقم الهاتف ثم أعد المحاولة.';
    }
  }
  return mapOtpError(error, l10n);
}

/// يرسم فشل الفحص المسبق لتفرّد الرقم في مسار تغيير الرقم (RPC
/// `get_email_by_phone`) — السياسة «فشل مُغلق»: أي خطأ في الفحص يمنع إرسال
/// الكود، فلا يُربط رقم لم يتحقق الخادم من تفرّده. يفرّق بين الحدّ المعدّل
/// ([_isThrottleError]) ورسالة عامة، ولا يكشف أي بيانات عن الرقم/الحساب.
String mapChangePhoneLookupError(Object error, AppLocalizations? l10n) {
  if (_isThrottleError(error)) {
    return l10n?.changePhoneThrottleError ??
        'تم تجاوز عدد المحاولات. حاول مرة أخرى لاحقاً.';
  }
  return l10n?.changePhoneLookupFailed ??
      'تعذّر التحقق من رقم الهاتف. حاول مرة أخرى.';
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

String _generic(AppLocalizations? l10n) =>
    l10n?.otpErrorGeneric ?? 'حدث خطأ ما. تحقق من اتصالك وحاول مرة أخرى.';
