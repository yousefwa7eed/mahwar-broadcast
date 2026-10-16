import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../services/app_messenger.dart';
import '../../l10n/app_localizations.dart';
import 'auth_cubit.dart';
import 'auth_service.dart';
import 'role_hint_cache.dart';

/// منسّق تسجيل الخروج الموحّد — بديل عن الكتل المكررة الثلاث (رئيسيتا
/// المالك/المزوّد وشاشة الملف الشخصي) التي كانت تنادي `AuthService.signOut`
/// مباشرة وتكرر نفس منطق الفشل والانتقال.
///
/// القواعد (خروج فوري أولًا محليًا):
/// 1) تنظيف الخادم (مسح fcm_token + device_id وفصل FCM + إبطال الجلسة القديمة
///    عبر `signOut` غلوبال يلتقط توكنها متزامنًا) يبدأ في الخلفية فورًا وبلا
///    انتظار، قبل سحب الجلسة المحلية، حتى يلتقط طلب fcm_token رمز الوصول
///    الصالح. تُعرض رسالة نجاح الخروج فقط عند اكتمال ذلك بنجاح؛ أي فشل خلفي
///    يُبتلع بلا رسالة خطأ (الخروج المحلي تم فعلًا).
/// 2) التنظيف المحلي يحدث فورًا ولا ينتظر الشبكة إطلاقًا: سحب الجلسة المحلية
///    احتياطيًا، تفريغ [RoleHintCache]، إعادة ضبط حالة الملف عبر [resetProfile]،
///    وبثّ [AuthUnauthenticated] — ثم الانتقال فورًا إلى `/select-user-type`.
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

  /// حالة تشغيل مشتركة لكل مواقع الخروج: تُرفع عند بدء الخروج (لعرض spinner
  /// على الزر ومنع إعادة النقر) وتُنزَل فور اكتمال الخروج المحلي والانتقال.
  /// لم تعد تُنتظر الشبكة، فتبقى مُفعَّلة لزمن الانتقال المحلي الفوري فقط.
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
    final l10n = AppLocalizations.of(context);
    try {
      // نلتقط هوية الجلسة القديمة قبل أي تنظيف — يذهب إلى الخلفية ويبقى
      // صالحًا لتنظيف FCM حتى بعد سحب الجلسة محليًا.
      final oldUserId = _authService.currentUser?.id;
      final authCubit = context.read<AuthCubit>();

      // 1) الخلفية بلا انتظار — تُستدعى أولًا (قبل سحب الجلسة المحلية) حتى
      //    يلتقط طلب fcm_token رمز الوصول الصالح. رسالة الخروج تُعرض فقط عند
      //    اكتمال ناجح؛ أي فشل يُبتلع بصمت لأن الخروج المحلي تم فعلًا.
      unawaited(
        _authService
            .signOutInBackground(oldUserId)
            .then((_) => AppMessenger.showText(
                  l10n?.signOutSuccess ?? 'تم تسجيل الخروج',
                ))
            .catchError((Object _) {}),
      );

      // 2) محلي فورًا — لا يُنتظر أي استدعاء شبكي قبل الانتقال.
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
