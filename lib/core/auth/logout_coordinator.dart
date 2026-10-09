import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../services/app_messenger.dart';
import 'auth_cubit.dart';
import 'auth_service.dart';
import 'role_hint_cache.dart';

/// منسّق تسجيل الخروج الموحّد — بديل عن الكتل المكررة الثلاث (رئيسيتا
/// المالك/المزوّد وشاشة الملف الشخصي) التي كانت تنادي `AuthService.signOut`
/// مباشرة وتكرر نفس منطق الفشل والانتقال.
///
/// القواعد:
/// 1) تنظيف الخادم (مسح fcm_token + device_id + إبطال الجلسة القديمة عبر
///    `signOut` غلوبال يلتقط توكنها متزامنًا) يُنفَّذ ويُنتظَر قبل سحب الجلسة
///    المحلية، حتى يُضمن قطع ارتباط الجهاز فعليًا. كل خطوة خلفها مهلة قصيرة
///    (3 ثوانٍ) فلا تعلّق الواجهة عند بطء الشبكة/انقطاعها. تُعرض رسالة نجاح
///    الخروج فقط عند اكتماله بنجاح؛ أي فشل خلفي يُبتلع بلا رسالة خطأ.
/// 2) سحب الجلسة المحلية احتياطيًا، تفريغ [RoleHintCache]، إعادة ضبط حالة
///    الملف عبر [resetProfile]، وبثّ [AuthUnauthenticated] — ثم الانتقال فورًا
///    إلى `/select-user-type`.
/// 3) الانتقال بـ `context.go` (استبدال كامل للمكدّس) حتى لا يعيد زر الرجوع
///    شاشة مسجّل دخول.
/// 4) حارس ضد النقر المزدوج: مواقع الاستدعاء الثلاثة تُنشئ نسخة جديدة من
///    المنسّق عند كل نقرة، فالعلامة المشتركة static وحدها تكفل تجاهل اللمسة
///    الثانية حتى انتهاء الأولى.
class LogoutCoordinator {
  final AuthService _authService;
  final RoleHintCache _roleHintCache;

  /// حارس النقر المزدوج المشترك بين جميع نسخ المنسّق (كل نقرة تُنشئ نسخة).
  static bool _loggingOut = false;

  /// حالة تشغيل مشتركة لكل مواقع الخروج: تنظيف الخادم يُنتظَر (حتى ~15 ثانية)
  /// قبل سحب الجلسة محليًا، فيعرض زر الخروج spinner ويمنع إعادة النقر أثناءه.
  static final ValueNotifier<bool> isRunning = ValueNotifier(false);

  LogoutCoordinator({
    AuthService? authService,
    RoleHintCache? roleHintCache,
  })  : _authService = authService ?? SupabaseAuthService(),
        _roleHintCache = roleHintCache ?? RoleHintCache();

  Future<void> logout({
    required BuildContext context,
    required VoidCallback resetProfile,
  }) async {
    if (_loggingOut) return;
    _loggingOut = true;
    isRunning.value = true;
    try {
      // نلتقط هوية الجلسة القديمة قبل أي تنظيف — يذهب إلى الخلفية ويبقى
      // صالحًا لتنظيف FCM حتى بعد سحب الجلسة محليًا.
      final oldUserId = _authService.currentUser?.id;
      final authCubit = context.read<AuthCubit>();

      // 1) تنظيف الخادم منتَظَر — يُنفَّذ أولًا (قبل سحب الجلسة المحلية) حتى
      //    يلتقط طلب fcm_token رمز الوصول الصالح وتُقطع فعليًا أسواء الجهاز/
      //    الجلسة. كل خطوة خلفها مهلة داخلية؛ نضيف مهلة إجمالية إضافية كحدّ
      //    أقصى فلا تتوقف الواجهة. رسالة الخروج تُعرض فقط عند اكتمال ناجح؛
      //    أي فشل يُبتلع بصمت لأن السحب المحلي يحدث على كل حال.
      try {
        await _authService
            .signOutInBackground(oldUserId)
            .timeout(const Duration(seconds: 15));
        AppMessenger.showText('تم تسجيل الخروج');
      } catch (e) {
        debugPrint('[LogoutCoordinator] background cleanup failed: $e');
      }

      // 2) سحب الجلسة المحلية بعد اكتمال التنظيف — ثم الانتقال فورًا.
      try {
        await _authService.clearLocalSession();
      } catch (e) {
        debugPrint('[LogoutCoordinator] clearLocalSession failed: $e');
      }
      try {
        await _roleHintCache.clear();
      } catch (e) {
        debugPrint('[LogoutCoordinator] RoleHintCache.clear failed: $e');
      }
      resetProfile();
      authCubit.markUnauthenticated();
      if (context.mounted) context.go('/select-user-type');
    } finally {
      _loggingOut = false;
      isRunning.value = false;
    }
  }
}