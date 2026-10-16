import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';

/// ترجمة أكواد أخطاء RPC المعروفة (تلك التي تطلقها دوال Postgres، أو أكواد
/// Postgrest مثل 23505) إلى رسائل واضحة للمستخدم عبر ARB، مع رسالة عامة عند
/// أي خطأ غير متوقع.
class RpcErrorTranslator {
  /// أكواد الأخطاء المعروفة التي نترجمها (ما عداها يُترك للرسالة العامة).
  static const Set<String> _knownCodes = {
    'ORDER_NOT_FOUND',
    'NOT_OWNER',
    'ORDER_NOT_PENDING',
    'NOT_ASSIGNED',
    'NOT_PROVIDER',
    'INVALID_PRICE',
    'NOT_PRICED_OR_NOT_OWNER',
    'NOT_CONFIRMED_OR_NOT_PROVIDER',
    'INVALID_RATING',
    'ORDER_NOT_COMPLETED',
    'ALREADY_RATED',
    'ORDER_NOT_FOUND_OR_FORBIDDEN',
    'OWNER_NATIONAL_ID_MISSING',
    'OWNER_NATIONAL_ID_INVALID',
    '23505',
    'PROVIDER_UNAVAILABLE',
    'TOO_MANY_ATTACHMENTS',
    'INVALID_ATTACHMENT_URL',
    'NOT_AUTHENTICATED',
    'PHONE_NOT_VERIFIED',
    'PHONE_CHANGE_REQUIRES_OTP',
  };

  /// ترجمة أي خطأ Supabase معكوس من دالة RPC إلى رسالة واضحة حسب [l10n].
  static String translate(Object error, AppLocalizations? l10n) {
    final code = _extractCode(error);
    if (code != null) {
      final message = _messageFor(code, l10n);
      if (message != null) return message;
    }
    return l10n?.rpcErrorGeneric ?? 'حدث خطأ في الاتصال، حاول مرة أخرى.';
  }

  static String? _messageFor(String code, AppLocalizations? l10n) {
    switch (code) {
      case 'ORDER_NOT_FOUND':
        return l10n?.rpcErrorOrderNotFound ?? 'الطلب غير موجود أو تم حذفه.';
      case 'NOT_OWNER':
        return l10n?.rpcErrorNotOwner ??
            'ليس لديك صلاحية للقيام بهذا الإجراء على هذا الطلب.';
      case 'ORDER_NOT_PENDING':
        return l10n?.rpcErrorOrderNotPending ??
            'لم يعد الطلب متاحاً، ربما تمت معالجته أو إلغاؤه.';
      case 'NOT_ASSIGNED':
        return l10n?.rpcErrorNotAssigned ?? 'الطلب لم يُسنَد لأي مزوّد بعد.';
      case 'NOT_PROVIDER':
        return l10n?.rpcErrorNotProvider ??
            'ليس لديك صلاحية للتعامل مع هذا الطلب.';
      case 'INVALID_PRICE':
        return l10n?.rpcErrorInvalidPrice ??
            'السعر المُدخل غير صالح، تأكد من إدخال مبلغ صحيح أكبر من صفر.';
      case 'NOT_PRICED_OR_NOT_OWNER':
        return l10n?.rpcErrorNotPricedOrNotOwner ??
            'لا يوجد عرض سعر سارٍ لهذا الطلب، أو أنك لست صاحب الطلب.';
      case 'NOT_CONFIRMED_OR_NOT_PROVIDER':
        return l10n?.rpcErrorNotConfirmedOrNotProvider ??
            'الطلب غير مؤكد، أو أنك لست المزوّد المسند للمهمة.';
      case 'INVALID_RATING':
        return l10n?.rpcErrorInvalidRating ??
            'قيمة التقييم غير صالحة (يجب أن تكون بين 1 و5).';
      case 'ORDER_NOT_COMPLETED':
        return l10n?.rpcErrorOrderNotCompleted ??
            'لا يمكن تقييم الطلب قبل اكتماله.';
      case 'ALREADY_RATED':
        return l10n?.rpcErrorAlreadyRated ?? 'تم تقييم هذا الطلب من قبل.';
      case 'ORDER_NOT_FOUND_OR_FORBIDDEN':
        return l10n?.rpcErrorOrderNotFoundOrForbidden ??
            'الطلب غير موجود، أو ليس لك صلاحية للوصول إليه.';
      case 'OWNER_NATIONAL_ID_MISSING':
        return l10n?.rpcErrorOwnerNationalIdMissing ??
            'مطلوب إضافة رقم قومي صحيح لإتمام الطلب. يرجى تحديث بياناتك الشخصية.';
      case 'OWNER_NATIONAL_ID_INVALID':
        return l10n?.rpcErrorOwnerNationalIdInvalid ??
            'الرقم القومي المسجّل في حسابك غير صحيح. يرجى تحديثه من البيانات الشخصية.';
      case '23505':
        return l10n?.rpcErrorDuplicatePendingOrder ??
            'لديك طلب قيد الانتظار بالفعل. يمكنك إلغاؤه أو انتظاره قبل إنشاء طلب جديد.';
      case 'PROVIDER_UNAVAILABLE':
        return l10n?.rpcErrorProviderUnavailable ??
            'لم يعد هذا المزوّد متاحاً لاستقبال الطلب. جرّب مزوّداً آخر.';
      case 'TOO_MANY_ATTACHMENTS':
        return l10n?.rpcErrorTooManyAttachments ??
            'عدد الصور كبير جداً (الحد الأقصى 10 صور).';
      case 'INVALID_ATTACHMENT_URL':
        return l10n?.rpcErrorInvalidAttachmentUrl ??
            'تعذّر التحقق من إحدى الصور المرفقة. يرجى المحاولة مرة أخرى.';
      case 'NOT_AUTHENTICATED':
        return l10n?.rpcErrorNotAuthenticated ??
            'انتهت الجلسة، يرجى تسجيل الدخول من جديد.';
      case 'PHONE_NOT_VERIFIED':
        return l10n?.rpcErrorPhoneNotVerified ??
            'يجب تأكيد رقم هاتفك أولًا لإتمام هذا الإجراء.';
      case 'PHONE_CHANGE_REQUIRES_OTP':
        return l10n?.rpcErrorPhoneChangeRequiresOtp ??
            'لتغيير رقم الهاتف يجب التحقق منه برمز SMS. استخدم زر تغيير الرقم.';
      default:
        return null;
    }
  }

  /// يستخرج رمز الخطأ: يفضّر كود Postgrest (مثل 23505) إن كان معروفاً لدينا،
  /// وإلا يعود لرسالة الاستثناء (كود مخصّص تطلقه دوال Postgres مثل P0001).
  static String? _extractCode(Object error) {
    if (error is PostgrestException) {
      final postgrestCode = error.code;
      if (postgrestCode != null && _knownCodes.contains(postgrestCode)) {
        return postgrestCode;
      }
      if (error.message.isNotEmpty) {
        return error.message;
      }
    }
    final raw = error.toString();
    final match = RegExp(r'([A-Z][A-Z_]+)').firstMatch(raw);
    return match?.group(1);
  }
}
