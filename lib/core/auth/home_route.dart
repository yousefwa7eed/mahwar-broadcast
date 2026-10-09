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