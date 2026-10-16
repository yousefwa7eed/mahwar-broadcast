import 'package:supabase_flutter/supabase_flutter.dart';

/// ترجمة أكواد أخطاء RPC المعروفة (تلك التي تطلقها دوال Postgres، أو أكواد
/// Postgrest مثل 23505) إلى رسائل عربية/إنجليزية واضحة للمستخدم، مع رسالة
/// عامة عند أي خطأ غير متوقع.
class RpcErrorTranslator {
  static const Map<String, String> _messagesAr = {
    'ORDER_NOT_FOUND': 'الطلب غير موجود أو تم حذفه.',
    'NOT_OWNER': 'ليس لديك صلاحية للقيام بهذا الإجراء على هذا الطلب.',
    'ORDER_NOT_PENDING': 'لم يعد الطلب متاحاً، ربما تمت معالجته أو إلغاؤه.',
    'NOT_ASSIGNED': 'الطلب لم يُسنَد لأي مزوّد بعد.',
    'NOT_PROVIDER': 'ليس لديك صلاحية للتعامل مع هذا الطلب.',
    'INVALID_PRICE': 'السعر المُدخل غير صالح، تأكد من إدخال مبلغ صحيح أكبر من صفر.',
    'NOT_PRICED_OR_NOT_OWNER':
        'لا يوجد عرض سعر سارٍ لهذا الطلب، أو أنك لست صاحب الطلب.',
    'NOT_CONFIRMED_OR_NOT_PROVIDER':
        'الطلب غير مؤكد، أو أنك لست المزوّد المسند للمهمة.',
    'INVALID_RATING': 'قيمة التقييم غير صالحة (يجب أن تكون بين 1 و5).',
    'ORDER_NOT_COMPLETED': 'لا يمكن تقييم الطلب قبل اكتماله.',
    'ALREADY_RATED': 'تم تقييم هذا الطلب من قبل.',
    'ORDER_NOT_FOUND_OR_FORBIDDEN':
        'الطلب غير موجود، أو ليس لك صلاحية للوصول إليه.',
    'OWNER_NATIONAL_ID_MISSING':
        'مطلوب إضافة رقم قومي صحيح لإتمام الطلب. يرجى تحديث بياناتك الشخصية.',
    'OWNER_NATIONAL_ID_INVALID':
        'الرقم القومي المسجّل في حسابك غير صحيح. يرجى تحديثه من البيانات الشخصية.',
    '23505':
        'لديك طلب قيد الانتظار بالفعل. يمكنك إلغاؤه أو انتظاره قبل إنشاء طلب جديد.',
    'PROVIDER_UNAVAILABLE':
        'لم يعد هذا المزوّد متاحاً لاستقبال الطلب. جرّب مزوّداً آخر.',
    'TOO_MANY_ATTACHMENTS': 'عدد الصور كبير جداً (الحد الأقصى 10 صور).',
    'INVALID_ATTACHMENT_URL':
        'تعذّر التحقق من إحدى الصور المرفقة. يرجى المحاولة مرة أخرى.',
    'NOT_AUTHENTICATED': 'انتهت الجلسة، يرجى تسجيل الدخول من جديد.',
    'PHONE_NOT_VERIFIED':
        'يجب تأكيد رقم هاتفك أولًا لإتمام هذا الإجراء.',
    'PHONE_CHANGE_REQUIRES_OTP':
        'لتغيير رقم الهاتف يجب التحقق منه برمز SMS. استخدم زر تغيير الرقم.',
  };

  static const Map<String, String> _messagesEn = {
    'ORDER_NOT_FOUND': 'This request no longer exists.',
    'NOT_OWNER':
        'You do not have permission to perform this action on this request.',
    'ORDER_NOT_PENDING':
        'This request is no longer available; it may have been processed or cancelled.',
    'NOT_ASSIGNED': 'This request has not been assigned to a provider yet.',
    'NOT_PROVIDER': 'You do not have permission to handle this request.',
    'INVALID_PRICE': 'Invalid price. Enter an amount greater than zero.',
    'NOT_PRICED_OR_NOT_OWNER':
        'There is no valid quote for this request, or you are not its owner.',
    'NOT_CONFIRMED_OR_NOT_PROVIDER':
        'The request is not confirmed, or you are not the assigned provider.',
    'INVALID_RATING': 'Invalid rating value (must be between 1 and 5).',
    'ORDER_NOT_COMPLETED':
        'You can only rate a request after it is completed.',
    'ALREADY_RATED': 'This request has already been rated.',
    'ORDER_NOT_FOUND_OR_FORBIDDEN':
        'The request does not exist, or you do not have access to it.',
    'OWNER_NATIONAL_ID_MISSING':
        'A valid national ID is required to complete the request. Please update your profile.',
    'OWNER_NATIONAL_ID_INVALID':
        'The national ID on your account is invalid. Please update it in your profile.',
    '23505':
        'You already have a pending request. Cancel it or wait for it before creating a new one.',
    'PROVIDER_UNAVAILABLE':
        'This provider is no longer available for this request. Please try another provider.',
    'TOO_MANY_ATTACHMENTS': 'Too many photos (maximum is 10).',
    'INVALID_ATTACHMENT_URL':
        'One of the attached photos could not be verified. Please try again.',
    'NOT_AUTHENTICATED': 'Your session has expired. Please sign in again.',
    'PHONE_NOT_VERIFIED':
        'Please verify your phone number first to complete this action.',
    'PHONE_CHANGE_REQUIRES_OTP':
        'Changing your phone number requires SMS verification. Use the Change number button.',
  };

  /// ترجمة أي خطأ Supabase معكوس من دالة RPC إلى رسالة واضحة.
  /// [arabic] يحدّد اللغة (افتراضياً العربية).
  static String translate(Object error, {bool arabic = true}) {
    final code = _extractCode(error);
    final messages = arabic ? _messagesAr : _messagesEn;
    if (code != null && messages.containsKey(code)) {
      return messages[code]!;
    }
    return arabic
        ? 'حدث خطأ في الاتصال، حاول مرة أخرى.'
        : 'Something went wrong. Please try again.';
  }

  /// يستخرج رمز الخطأ: يفضّل كود Postgrest (مثل 23505) إن كان معروفاً لدينا،
  /// وإلا يعود لرسالة الاستثناء (كود مخصّص تطلقه دوال Postgres مثل P0001).
  static String? _extractCode(Object error) {
    if (error is PostgrestException) {
      final postgrestCode = error.code;
      if (postgrestCode != null && _messagesAr.containsKey(postgrestCode)) {
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
