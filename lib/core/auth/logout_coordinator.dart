import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'auth_service.dart';
import 'role_hint_cache.dart';

/// منسّق تسجيل الخروج الموحّد — بديل عن الكتل المكررة الثلاث (رئيسيتا
/// المالك/المزوّد وشاشة الملف الشخصي) التي كانت تنادي `AuthService.signOut`
/// مباشرة وتكرر نفس منطق الفشل والانتقال.
///
/// القواعد (خطوة S7):
/// 1) الجزء الشبكي (فصل FCM + سحب الجلسة لدى الخادم) جهدُ بذل الأفضل بمهلة
///    قصيرة — فشله أو انقطاع شبكته لا يمنع الخروج المحلي أبدًا.
/// 2) التنظيف المحلي يحدث دومًا مهما كانت نتيجة الخطوة السابقة: سحب الجلسة
///    المحلية احتياطيًا، تفريغ [RoleHintCache]، وإعادة ضبط حالة الملف عبر
///    [resetProfile].
/// 3) الانتقال إلى `/select-user-type` بـ `context.go` (استبدال كامل للمكدّس)
///    حتى لا يعيد زر الرجوع شاشة مسجّل دخول.
class LogoutCoordinator {
  final AuthService _authService;
  final RoleHintCache _roleHintCache;

  /// مهلة الـ best-effort للجزء الشبكي. بعد انقضائها يمضي الخروج محليًا
  /// بغضّ النظر عن النتيجة، حتى لو بقي طلب الخروج معلّقًا في الخلفية.
  final Duration remoteTimeout;

  LogoutCoordinator({
    AuthService? authService,
    RoleHintCache? roleHintCache,
    this.remoteTimeout = const Duration(seconds: 5),
  })  : _authService = authService ?? SupabaseAuthService(),
        _roleHintCache = roleHintCache ?? RoleHintCache();

  Future<void> logout({
    required BuildContext context,
    required VoidCallback resetProfile,
  }) async {
    try {
      await _authService.signOut().timeout(remoteTimeout);
    } catch (e) {
      // الشبكة/المهلة فشلت: لا نمنع الخروج المحلي أبدًا، ونحاول سحب الجلسة
      // محليًا كاحتياط (لا ضرر إن كانت قد سُحبت فعلًا).
      debugPrint('[LogoutCoordinator] signOut best-effort failed: $e');
      try {
        await _authService.clearLocalSession();
      } catch (e) {
        debugPrint('[LogoutCoordinator] clearLocalSession failed: $e');
      }
    }

    await _roleHintCache.clear();
    resetProfile();
    if (context.mounted) context.go('/select-user-type');
  }
}