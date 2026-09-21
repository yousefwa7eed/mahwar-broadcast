import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// المسار الجذري للرئيسية حسب دور المستخدم في قاعدة البيانات.
/// أسماء الأدوار الفعلية في قاعدة البيانات (car_owner / provider) تُترجَم إلى
/// المسارات المسجَّلة في الـ router (/home/owner و /home/provider) — أي قيمة
/// أخرى نتعامل معها كمالك سيارة بأمان بدلاً من بناء مسار غير موجود يرمي
/// GoException: no routes for location.
String homeRouteForRole(String role) =>
    role == 'provider' ? '/home/provider' : '/home/owner';

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
  final currentConfiguration =
      GoRouter.of(context).routerDelegate.currentConfiguration;
  final matches = currentConfiguration.matches;
  if (matches.isNotEmpty) {
    return matches.last.matchedLocation == path;
  }
  return currentConfiguration.uri.path == path;
}