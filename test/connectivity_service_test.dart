// اختبارات فحص الاتصال الذي يحدد نوع رسالة الفشل: «لا يوجد اتصال» أم خطأ
// تحميل عام. لا تلمس الشبكة الحقيقية — يُستبدل الفحص بدالة وهمية.

import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/services/connectivity_service.dart';

void main() {
  final service = ConnectivityService.instance;

  setUp(service.resetForTesting);
  tearDown(service.resetForTesting);

  group('ConnectivityService.isOnline', () {
    test('يرجع true عندما ينجح فحص الشبكة', () async {
      service.probeOverride = () async => true;
      expect(await service.isOnline(), isTrue);
    });

    test('يرجع false عندما يفشل فحص الشبكة', () async {
      service.probeOverride = () async => false;
      expect(await service.isOnline(), isFalse);
    });

    test('أي استثناء أثناء الفحص يُعتبر انقطاعًا لا كراش', () async {
      service.probeOverride = () async => throw Exception('dns down');
      expect(await service.isOnline(), isFalse);
    });

    test('يخزّن النتيجة لثوانٍ قليلة بدل تكرار الفحص', () async {
      var calls = 0;
      service.probeOverride = () async {
        calls++;
        return true;
      };

      await service.isOnline();
      await service.isOnline();

      expect(calls, 1);
    });

    test('resetForTesting يمسح الذاكرة فيُعاد الفحص من جديد', () async {
      var calls = 0;
      service.probeOverride = () async {
        calls++;
        return true;
      };

      await service.isOnline();
      service.resetForTesting();
      service.probeOverride = () async {
        calls++;
        return true;
      };
      await service.isOnline();

      expect(calls, 2);
    });
  });

  group('classifyLoadFailure', () {
    test('بلا شبكة → LoadFailure.offline', () async {
      service.probeOverride = () async => false;
      expect(await classifyLoadFailure(), LoadFailure.offline);
    });

    test('الشبكة تعمل وفشل الطلب → LoadFailure.failed', () async {
      service.probeOverride = () async => true;
      expect(await classifyLoadFailure(), LoadFailure.failed);
    });
  });
}
