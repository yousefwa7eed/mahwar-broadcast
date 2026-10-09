import 'package:supabase_flutter/supabase_flutter.dart';

/// ترجمة أكواد أخطاء RPC المعروفة (تلك التي تطلقها دوال Postgres) إلى رسائل
/// عربية واضحة للمستخدم، مع رسالة عامة عند أي خطأ غير متوقع.
class RpcErrorTranslator {
  static const Map<String, String> _messages = {
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
  };

  /// ترجمة أي خطأ Supabase معكوس من دالة RPC إلى رسالة عربية.
  static String translate(Object error) {
    final code = _extractCode(error);
    if (code != null && _messages.containsKey(code)) {
      return _messages[code]!;
    }
    return 'حدث خطأ في الاتصال، حاول مرة أخرى.';
  }

  /// يستخرج رمز الخطأ من PostgrestException أو من نص الاستثناء.
  static String? _extractCode(Object error) {
    if (error is PostgrestException && error.message.isNotEmpty) {
      return error.message;
    }
    final raw = error.toString();
    final match = RegExp(r'([A-Z][A-Z_]+)').firstMatch(raw);
    return match?.group(1);
  }
}