import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/auth/availability_check_guard.dart';

void main() {
  const phone = '01012345678';
  const otherPhone = '01199999999';

  group('AvailabilityCheckGuard.isPhoneAvailable', () {
    test('يفحص الرقم مرة واحدة ويخزّن النتيجة للجلسة', () async {
      var calls = 0;
      final guard = AvailabilityCheckGuard();

      final first = await guard.isPhoneAvailable(phone, (p) async {
        calls++;
        expect(p, phone);
        return true;
      });
      final second = await guard.isPhoneAvailable(phone, (p) async {
        calls++;
        return false;
      });

      expect(first, isTrue);
      expect(second, isTrue); // الكاش، لا نتيجة المرة الثانية
      expect(calls, 1);
    });

    test('الطلبات المتزامنة على نفس الرقم = مكالمة RPC واحدة', () async {
      var calls = 0;
      final guard = AvailabilityCheckGuard();

      Future<bool> fetch(String p) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return true;
      }

      final results = await Future.wait([
        guard.isPhoneAvailable(phone, fetch),
        guard.isPhoneAvailable(phone, fetch),
        guard.isPhoneAvailable(phone, fetch),
      ]);

      expect(results, [true, true, true]);
      expect(calls, 1);
    });

    test('الرقم غير المكتمل لا يصل إلى الخادم إطلاقًا', () async {
      var calls = 0;
      final guard = AvailabilityCheckGuard();

      expect(
        () => guard.isPhoneAvailable('010123', (p) async {
          calls++;
          return true;
        }),
        throwsA(isA<FormatException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(calls, 0);
    });

    test('فشل الفحص لا يُخزَّن؛ تُعاود المحاولة استعلامًا جديدًا', () async {
      var calls = 0;
      final guard = AvailabilityCheckGuard();

      Future<bool> failingFetch(String p) async {
        calls++;
        throw StateError('network down');
      }

      await expectLater(
        guard.isPhoneAvailable(phone, failingFetch),
        throwsA(isA<StateError>()),
      );
      final retried = await guard.isPhoneAvailable(phone, (p) async {
        calls++;
        return true;
      });

      expect(retried, isTrue);
      expect(calls, 2);
    });

    test('ttl منتهي = استعلام جديد، ورقم مختلف = مفاتيح مستقلة', () async {
      var calls = 0;
      final guard = AvailabilityCheckGuard(ttl: Duration.zero);

      Future<bool> fetch(String p) async {
        calls++;
        return true;
      }

      await guard.isPhoneAvailable(phone, fetch);
      await guard.isPhoneAvailable(phone, fetch);
      await guard.isPhoneAvailable(otherPhone, fetch);
      expect(calls, 3);
    });

    test('clear() يُسقط الكاش', () async {
      var calls = 0;
      final guard = AvailabilityCheckGuard();

      Future<bool> fetch(String p) async {
        calls++;
        return true;
      }

      await guard.isPhoneAvailable(phone, fetch);
      guard.clear();
      await guard.isPhoneAvailable(phone, fetch);
      expect(calls, 2);
    });
  });

  group('AvailabilityCheckGuard.emailForPhone', () {
    test('نتيجة null (رقم غير مسجل) تُخزَّن ولا تُعاد استعلامتها', () async {
      var calls = 0;
      final guard = AvailabilityCheckGuard();

      final first = await guard.emailForPhone(phone, (p) async {
        calls++;
        return null;
      });
      final second = await guard.emailForPhone(phone, (p) async {
        calls++;
        return 'owner@example.com';
      });

      expect(first, isNull);
      expect(second, isNull);
      expect(calls, 1);
    });

    test('البريد الموجود يُخزَّن ويُعاد في المحاولة التالية', () async {
      var calls = 0;
      final guard = AvailabilityCheckGuard();

      final email = await guard.emailForPhone(phone, (p) async {
        calls++;
        return 'owner@example.com';
      });
      final again = await guard.emailForPhone(phone, (p) async {
        calls++;
        return null;
      });

      expect(email, 'owner@example.com');
      expect(again, 'owner@example.com');
      expect(calls, 1);
    });

    test('الرقم غير المكتمل لا يُرسل للفحص', () async {
      var calls = 0;
      final guard = AvailabilityCheckGuard();

      expect(
        () => guard.emailForPhone('0101', (p) async {
          calls++;
          return 'x@y.z';
        }),
        throwsA(isA<FormatException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(calls, 0);
    });
  });
}
