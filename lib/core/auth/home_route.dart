import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'role_gate.dart';

/// المسار الجذري للرئيسية حسب دور المستخدم في قاعدة البيانات.
/// أسماء الأدوار الفعلية (car_owner / provider) تُترجَم إلى المسارات المسجَّلة
/// في الـ router (/home/owner و /home/provider).
///
/// تُرجع null لأي دور غير معروف أو غائب — لا يوجد افتراضي: سابقًا كان أي دور
/// غير provider يُوجَّه بصمت إلى رئيسية مالك السيارة، وهو ما وجّه المزوّد
/// (حين كان دوره غير معروف لحظيًا) إلى الشاشة الخاطئة.
String? homeRouteForRole(String? role) => AppRole.tryParse(role)?.homeRoute;

/// حارس الدور على مسارات الرئيسية: إذا فُتحت رئيسية دور بجلسة دور آخر
/// (بعد تبديل حسابات على نفس الجهاز، أو تنقّل قديم) نعيد التوجيه إلى رئيسية
/// الدور الفعلي من `profiles.role`. الدور غير المعروف يُمرَّر (null) — لا
/// يُفترض أي دور بديل، والحارس الخادمي هو الفاصل.
///
/// دالة نقية خارج الـ router حتى تُختبر بلا بناء GoRouter.
String? roleHomeRedirectFor({required String path, required String? role}) {
  final actual = AppRole.tryParse(role);
  if (actual == null) return null;
  if (path == AppRole.carOwner.homeRoute && actual != AppRole.carOwner) {
    return actual.homeRoute;
  }
  if (path == AppRole.provider.homeRoute && actual != AppRole.provider) {
    return actual.homeRoute;
  }
  return null;
}

/// مسار الرجوع الآمن من شاشة تتبّع طلب: دور الخادم أولًا (مصدر الحقيقة)، ثم/// عضوية الطلب كاحتياط، و null إذا لم يُعرف أي منهما — عندها لا نتنقّل بدل
/// إرسال المستخدم إلى رئيسية الدور الخاطئ (كان `order == null` يُعامَل كمالك
/// فتظهر رئيسية المالك داخل حساب المزوّد).
String? trackingBackRouteFor({
  required String? serverRole,
  required String? userId,
  required String? ownerId,
  required String? providerId,
}) {
  final home = homeRouteForRole(serverRole);
  if (home != null) return home;
  if (userId == null) return null;
  if (userId == ownerId) return AppRole.carOwner.homeRoute;
  if (userId == providerId) return AppRole.provider.homeRoute;
  return null;
}

/// يتحقق من مسار رجوع داخلي قادم من رابط خارجي (مثل `next` في رابط QR).
///
/// يرفض أي قيمة فيها مخطط (`javascript:`، `https:`)، أو سلطة (`//evil`)، أو
/// شرطة مائلة معكوسة — فلا يمكن استخدام شاشة الدخول كقفزة إلى خارج التطبيق.
String? safeInternalRoute(String? raw) {
  if (raw == null) return null;
  final value = raw.trim();
  if (value.isEmpty || !value.startsWith('/') || value.startsWith('//')) {
    return null;
  }
  if (value.contains('\\')) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  return value;
}

/// رابط صفحة دخول تعيد المستخدم إلى [next] بعد النجاح — يُستخدم لروابط QR
/// التي تصل بدون جلسة.
String loginRouteWithNext({required AppRole role, required String next}) =>
    '${role.loginRoute}&next=${Uri.encodeQueryComponent(next)}';

/// هل المسار الحالي في أعلى حزمة التنقل (topmost route) هو [path]؟
/// يُستخدم لمنع أكثر من شاشة من الاستجابة لنفس حدث AuthAuthenticated: شاشة
/// OTP هي المسؤولة الوحيدة عن التنقل بعد التحقق الناجح، وشاشات الدخول
/// والتسجيل أدناها لا تتنقل إلا إذا كانت هي الشاشة الظاهرة فعلًا (التوبموست).
///
/// ملاحظة مهمة: لا نعتمد على `currentConfiguration.uri.path` هنا لأن
/// go_router لا يحدّثه عند استخدام `push` — الشاشة المدفوعة (مثل OTP فوق شاشة
/// الدخول) تُحصى في `currentConfiguration.matches` وليس في `uri`، لذلك نقرأ
/// التوبموست من `matches.last.matchedLocation` وننسحب إلى `uri.path` في حال
/// كانت القائمة فارغة (مثل مواقف ما قبل أول تطابق).
bool isTopmostRoute(BuildContext context, String path) {
  final currentConfiguration = GoRouter.of(
    context,
  ).routerDelegate.currentConfiguration;
  final matches = currentConfiguration.matches;
  if (matches.isNotEmpty) {
    return matches.last.matchedLocation == path;
  }
  return currentConfiguration.uri.path == path;
}
