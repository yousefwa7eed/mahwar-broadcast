import '../../l10n/app_localizations.dart';

/// دور المستخدم القياسي في التطبيق — يطابق القيم المخزّنة في
/// `public.profiles.role` و`user_metadata.role`.
///
/// هذا هو المصدر الوحيد لتحويل الدور إلى مساحة المسارات في التطبيق. لا يوجد
/// أي افتراضي هنا عن قصد: [tryParse] تُرجع null لأي قيمة null أو غير معروفة،
/// حتى لا يستطيع أي مستوى أن يسقط بصمت إلى `car_owner` (وهو ما كان السبب في
/// توجيه المزوّد إلى رئيسية مالك السيارة).
enum AppRole {
  carOwner('car_owner', '/home/owner'),
  provider('provider', '/home/provider');

  const AppRole(this.dbValue, this.homeRoute);

  /// القيمة كما تُخزَّن في قاعدة البيانات / user_metadata.
  final String dbValue;

  /// المسار الجذري المسجَّل في [appRouter] لهذا الدور.
  final String homeRoute;

  /// مسار صفحة الدخول الخاصة بهذا الدور (نقطة دخول مقيّدة بالدور).
  String get loginRoute => '/login?role=$dbValue';

  /// مسار صفحة إنشاء الحساب الخاصة بهذا الدور.
  String get signupRoute => '/signup?role=$dbValue';

  /// تحوّل نص الدور القادم من قاعدة البيانات أو user_metadata إلى [AppRole].
  /// تُرجع null لأي قيمة null أو غير معروفة — بلا أي افتراضي.
  static AppRole? tryParse(String? raw) {
    switch (raw) {
      case 'car_owner':
        return AppRole.carOwner;
      case 'provider':
        return AppRole.provider;
      default:
        return null;
    }
  }
}

/// رسالة تظهر عند محاولة الدخول من صفحة لا تطابق دور الحساب الفعلي.
/// تذكر فقط دور الحساب الحقيقي (عميل/مزوّد) وتوجّه لصفحة الدخول الصحيحة —
/// دون أي بيانات إضافية عن الحساب.
String roleMismatchMessage({
  required AppRole actualRole,
  required AppLocalizations? l10n,
}) {
  final isProvider = actualRole == AppRole.provider;
  if (isProvider) {
    return l10n?.roleMismatchProvider ??
        'هذا الحساب مسجّل كمزوّد. يرجى تسجيل الدخول من صفحة تسجيل دخول المزوّد.';
  }
  return l10n?.roleMismatchCustomer ??
      'هذا الحساب مسجّل كعميل. يرجى تسجيل الدخول من صفحة تسجيل دخول العميل.';
}

/// رسالة تُعرض إذا تعذّر تحديد دور الحساب بعد اكتمال تسجيل الدخول أو عند
/// الإقلاع (فشل قراءة `profiles.role` أو انتهاء المهلة). نُظهرها مع خيارَي
/// إعادة المحاولة وتسجيل الخروج بدل ترك المستخدم في شاشة عالقة بلا أي رسالة.
/// لا تُقرأ الـ `user_metadata` على الإطلاق في مسار التحديد.
String roleUnresolvedMessage({required AppLocalizations? l10n}) {
  return l10n?.roleUnresolved ??
      'تعذّر تحديد نوع الحساب بعد تسجيل الدخول. يرجى المحاولة مرة أخرى.';
}
