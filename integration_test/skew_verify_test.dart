import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mahwar/core/services/server_clock.dart';
import 'package:mahwar/core/models/notification_model.dart';
import 'package:mahwar/core/utils/supabase_time.dart';
import 'package:mahwar/main.dart' as app;

const String kPhone = '01554775966';
const String kPassword = '123456';

/// برنامج التحقق من إصلاح ساعة الجهاز (ServerClock):
/// 1) يسجّل الدخول بحساب حقيقي.
/// 2) يفتح تبويب الإشعارات.
/// 3) يقرأ أحدث إشعار ويحسب التسمية المتوقعة بزمن الخادم (server_now).
/// 4) يقارنها بما يظهر فعلاً على الشاشة، ويطبع أيضاً ما كانت ستعرضه ساعة
///    الجهاز (DateTime.now) للتوضيح.
void main() {
  patrolTest(
    'server_clock_on_device_check',
    ($) async {
      app.main();

      // 1) تهيئة الحالة: إما Onboarding (حالة نظيفة) أو جلسة قديمة.
      final t0 = DateTime.now();
      var atOnboarding = false;
      while (DateTime.now().difference(t0) < const Duration(seconds: 25)) {
        try {
          await $.pump(const Duration(milliseconds: 250));
        } catch (_) {}
        try {
          if (find.text('تخطي').hitTestable().evaluate().isNotEmpty) {
            atOnboarding = true;
            break;
          }
        } catch (_) {}
      }

      if (!atOnboarding) {
        // جلسة قديمة → سجّل الخروج من تبويب "حسابي".
        var loggedHome = false;
        final w = DateTime.now();
        while (DateTime.now().difference(w) < const Duration(seconds: 20)) {
          try {
            if (find.text('ونش S.O.S').hitTestable().evaluate().isNotEmpty) {
              loggedHome = true;
              break;
            }
            await $.pump(const Duration(milliseconds: 250));
          } catch (_) {}
        }
        if (loggedHome) {
          await $.tap(
            find.byIcon(Icons.person_outline_rounded),
            visibleTimeout: const Duration(seconds: 15),
            settlePolicy: SettlePolicy.noSettle,
          );
          await $.tap(
            find.text('تسجيل الخروج'),
            visibleTimeout: const Duration(seconds: 15),
            settlePolicy: SettlePolicy.noSettle,
          );
        }
        await $.pump(const Duration(seconds: 2));
      } else {
        await $.tap(find.text('تخطي'), settlePolicy: SettlePolicy.noSettle);
        await $.pump(const Duration(seconds: 2));
      }

      // 2) شاشة اختيار نوع الحساب → مالك السيارة → تسجيل الدخول بحساب موجود.
      var mix = await _waitForAny($, [find.text('مالك السيارة')], timeout: 30);
      if (mix) {
        await $.tap(find.text('مالك السيارة'), settlePolicy: SettlePolicy.noSettle);
        mix = await _waitForAny($, [find.text('تسجيل الدخول')], timeout: 20);
        if (mix) {
          await $.tap(find.text('تسجيل الدخول'), settlePolicy: SettlePolicy.noSettle);
        }
      }

      await _waitForAny($, [find.text('رقم الهاتف أو البريد الإلكتروني')], timeout: 30);
      await $.enterText(
        find.widgetWithText(TextFormField, 'رقم الهاتف أو البريد الإلكتروني'),
        kPhone,
        hideKeyboard: true,
        visibleTimeout: const Duration(seconds: 60),
      );
      await $.enterText(
        find.widgetWithText(TextFormField, 'كلمة المرور'),
        kPassword,
        hideKeyboard: true,
        visibleTimeout: const Duration(seconds: 60),
      );
      await $.tap(
        find.widgetWithText(ElevatedButton, 'تسجيل الدخول'),
        visibleTimeout: const Duration(seconds: 20),
        settlePolicy: SettlePolicy.noSettle,
      );

      final ok = await _waitForAny($, [find.text('ونش S.O.S')], timeout: 60);
      if (!ok) {
        await _dumpVisibleTexts($);
        throw StateError('فشل تسجيل الدخول');
      }
      await $.pump(const Duration(seconds: 3));

      // 3) قياس انحراف ساعة الجهاز عن ساعة الخادم.
      await ServerClock.instance.refresh();
      final serverNow = ServerClock.instance.now;
      final deviceNow = DateTime.now().toUtc();
      final skew = deviceNow.difference(serverNow).inSeconds;

      // 3أ) أحدث إشعار في قاعدة البيانات + زمن الخادم الحقيقي.
      final client = Supabase.instance.client;
      final newestRows = await client
          .from('notifications')
          .select('created_at')
          .order('created_at', ascending: false)
          .limit(1);
      final serverRpcStr = await client.rpc('server_now');
      final serverRpc = (serverRpcStr is String)
          ? parseSupabaseTimestamp(serverRpcStr) ?? DateTime.now().toUtc()
          : DateTime.now().toUtc();

      // 3ب) التسمية الصحيحة (بزمن الخادم) مقابل تسمية الجهاز (السيناريو القديم).
      String expectedLabel = '';
      String buggyLabel = '(لا يوجد إشعار سابق)';
      if (newestRows.isNotEmpty) {
        final n = NotificationModel.fromJson({
          'id': 'probe',
          'user_id': 'probe',
          'type': 'probe',
          'created_at': newestRows.first['created_at'],
        });
        expectedLabel = n.timeAgo(serverRpc);
        buggyLabel = n.timeAgo(deviceNow);
      }

      debugPrint('SKEW1 deviceUtcNow=$deviceNow');
      debugPrint('SKEW1 serverNow(cached)=$serverNow');
      debugPrint('SKEW1 serverNow(rpc)=$serverRpc');
      debugPrint('SKEW1 device-vs-server seconds=$skew');
      debugPrint('SKEW1 newest created_at=${newestRows.isEmpty ? 'none' : newestRows.first['created_at']}');
      debugPrint('SKEW1 expected(server)=$expectedLabel');
      debugPrint('SKEW1 buggyIfDeviceClock=$buggyLabel');

      // 4) تبويب الإشعارات.
      await $.tap(
        find.byIcon(Icons.notifications_outlined),
        visibleTimeout: const Duration(seconds: 20),
        settlePolicy: SettlePolicy.noSettle,
      );
      final notifTab = await _waitForAny(
        $,
        [find.text('لا توجد إشعارات جديدة'), find.byType(ListView)],
        timeout: 30,
      );
      if (!notifTab) await _dumpVisibleTexts($);
      await $.pump(const Duration(seconds: 3));

      // 5) طباعة ما هو مرئي فعلاً على الشاشة + التحقق من التسمية المتوقعة.
      await _dumpVisibleTexts($);

      if (expectedLabel.isNotEmpty) {
        final found = find.text(expectedLabel).hitTestable();
        if (found.evaluate().isEmpty) {
          debugPrint('SKEW1 ASSERT-FAIL expected on screen: "$expectedLabel"');
        } else {
          debugPrint('SKEW1 ASSERT-PASS on screen shows server-anchored "$expectedLabel"');
        }
      }

      // 5أ) الحكم الحاسم: على جهاز متقدم ساعته ~58 دقيقة، التسمية الصحيحة يجب
      //     أن تكون صغيرة (الآن / منذ دقائق قليلة) بينما ساعة الجهاز كانت
      //     ستُظهر "منذ ~60 دقيقة". نرفض أي تسمية على الشاشة تطابق نسخة الجهاز.
      if (newestRows.isNotEmpty && expectedLabel != buggyLabel) {
        var hasBuggy = false;
        for (final w in $.tester.widgetList<Text>(find.byType(Text))) {
          final t = w.data ?? w.textSpan?.toPlainText();
          if (t == buggyLabel) {
            hasBuggy = true;
            break;
          }
        }
        final hasExpected = find.text(expectedLabel).hitTestable().evaluate().isNotEmpty;
        debugPrint('SKEW1 DECISIVE expected(server)=$expectedLabel '
            'buggy(device)=$buggyLabel hasExpectedOnScreen=$hasExpected '
            'hasBuggyOnScreen=$hasBuggy');
        if (hasExpected && !hasBuggy) {
          debugPrint('SKEW1 DECISIVE-PASS: server-anchored label shown, device label absent');
        } else if (hasBuggy) {
          throw StateError('حاسمة: الشاشة تعرض تسمية ساعة الجهاز: $buggyLabel');
        } else {
          debugPrint('SKEW1 DECISIVE-WARN: expected not found on screen, see SKEW1-ON-SCREEN');
        }
      }

      // 6) السلامة: نطبع رقم الانحراف للتقرير.
      debugPrint('SKEW1 DONE deviceSkewSeconds=$skew');
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

Future<bool> _waitForAny(
  PatrolIntegrationTester $,
  List<Finder> finders, {
  required int timeout,
}) async {
  final end = DateTime.now().add(Duration(seconds: timeout));
  while (DateTime.now().isBefore(end)) {
    try {
      await $.pump(const Duration(milliseconds: 250));
    } catch (_) {}
    for (final f in finders) {
      try {
        if (f.hitTestable().evaluate().isNotEmpty) return true;
      } catch (_) {}
    }
  }
  return false;
}

Future<void> _dumpVisibleTexts(PatrolIntegrationTester $) async {
  try {
    await $.pump(const Duration(milliseconds: 500));
  } catch (_) {}
  try {
    final texts = <String>[];
    for (final w in $.tester.widgetList<Text>(find.byType(Text))) {
      texts.add('"${w.data ?? w.textSpan?.toPlainText()}"');
    }
    debugPrint('SKEW1-ON-SCREEN (${texts.length}): ${texts.join(' , ')}');
  } catch (e) {
    debugPrint('SKEW1-ON-SCREEN dump failed: $e');
  }
}