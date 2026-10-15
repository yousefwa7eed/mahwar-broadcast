import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/features/provider_home/provider_heartbeat.dart';

void main() {
  const shortInterval = Duration(milliseconds: 20);

  group('ProviderHeartbeat scheduling', () {
    test('sends nothing while offline', () async {
      var count = 0;
      final hb = ProviderHeartbeat(
        sendBeat: () async { count++; },
        interval: shortInterval,
      );

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(count, 0);

      hb.dispose();
    });

    test('going online fires an immediate beat then repeats every interval', () async {
      var count = 0;
      final hb = ProviderHeartbeat(
        sendBeat: () async { count++; },
        interval: shortInterval,
      );

      hb.setOnline(true);
      // النبضة الفورية تُنفَّذ تزامنياً داخل setOnline.
      expect(count, 1);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(count, greaterThanOrEqualTo(3));

      hb.dispose();
    });

    test('background pauses the loop; foreground resumes with an immediate beat', () async {
      var count = 0;
      final hb = ProviderHeartbeat(
        sendBeat: () async { count++; },
        interval: shortInterval,
      );

      hb.setOnline(true);
      expect(count, 1);

      hb.setForeground(false);
      final paused = count;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(count, paused);

      hb.setForeground(true);
      expect(count, paused + 1);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(count, greaterThan(paused + 1));

      hb.dispose();
    });

    test('going offline stops the loop', () async {
      var count = 0;
      final hb = ProviderHeartbeat(
        sendBeat: () async { count++; },
        interval: shortInterval,
      );

      hb.setOnline(true);
      expect(count, 1);

      hb.setOnline(false);
      final stopped = count;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(count, stopped);

      hb.dispose();
    });

    test('dispose cancels the loop and ignores later updates', () async {
      var count = 0;
      final hb = ProviderHeartbeat(
        sendBeat: () async { count++; },
        interval: shortInterval,
      );

      hb.setOnline(true);
      expect(count, 1);

      hb.dispose();
      final afterDispose = count;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(count, afterDispose);

      // بعد الإغلاق: لا تفعيل ولا جدولة إطلاقاً.
      hb.setOnline(false);
      hb.setForeground(false);
      final afterUpdates = count;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(count, afterUpdates);
      expect(hb.isEligible, isFalse);
    });

    test('a failing beat is swallowed and never breaks scheduling', () async {
      var count = 0;
      final hb = ProviderHeartbeat(
        sendBeat: () async {
          count++;
          throw StateError('boom');
        },
        interval: shortInterval,
      );

      hb.setOnline(true);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(count, greaterThanOrEqualTo(3));

      hb.dispose();
    });

    test('a synchronous throw in sendBeat is swallowed', () async {
      var calls = 0;
      final hb = ProviderHeartbeat(
        sendBeat: () {
          calls++;
          throw StateError('sync boom');
        },
        interval: shortInterval,
      );

      hb.setOnline(true);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      // لا استثناء غير مُلتقط يهدم الاختبار، والجدولة تستمر.
      expect(calls, greaterThanOrEqualTo(2));

      hb.dispose();
    });

    test('does not overlap: a tick is skipped while a beat is in flight', () async {
      var started = 0;
      final completer = Completer<void>();
      final hb = ProviderHeartbeat(
        sendBeat: () {
          started++;
          return completer.future;
        },
        interval: shortInterval,
      );

      hb.setOnline(true);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(started, 1);

      completer.complete();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(started, greaterThan(1));

      hb.dispose();
    });
  });
}
