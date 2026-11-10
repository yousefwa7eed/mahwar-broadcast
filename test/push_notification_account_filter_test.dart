import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/services/push_notification_service.dart';

void main() {
  group('pushTargetsUser — منع تسريب إشعار حساب آخر على جهاز مشترك', () {
    test('إشعار يحمل user_id لحساب الجلسة يُفتح', () {
      expect(
        PushNotificationService.pushTargetsUser({
          'user_id': 'user-a',
        }, 'user-a'),
        isTrue,
      );
    });

    test('إشعار حساب آخر يُرفض حتى لو كان على نفس الجهاز', () {
      expect(
        PushNotificationService.pushTargetsUser({
          'user_id': 'user-b',
        }, 'user-a'),
        isFalse,
      );
    });

    test('بلا جلسة لا يُفتح أي إشعار', () {
      expect(
        PushNotificationService.pushTargetsUser({'user_id': 'user-a'}, null),
        isFalse,
      );
    });

    test('رسالة قديمة بلا user_id تُمرَّر لفحص الملكية في قاعدة البيانات', () {
      expect(
        PushNotificationService.pushTargetsUser(const {}, 'user-a'),
        isTrue,
      );
      expect(
        PushNotificationService.pushTargetsUser({'user_id': ''}, 'user-a'),
        isTrue,
      );
    });
  });

  group('فحص ملكية الإشعار عند فشل الشبكة (أوفلاين)', () {
    test('تعذّر الفحص (null) → لا يُفتح الإشعار بأمان', () {
      // null تعني أن الاستعلام نفسه فشل (أوفلاين/خطأ) لا أن الإشعار لملك
      // حسابًا آخر — في الحالتين لا نتنقّل.
      expect(PushNotificationService.ownershipConfirmed(null), isFalse);
    });

    test('إشعار مؤكَّد أنه ليس لهذا الحساب → لا يُفتح', () {
      expect(PushNotificationService.ownershipConfirmed(false), isFalse);
    });

    test('إشعار مؤكَّد ملكيته للحساب → يُفتح', () {
      expect(PushNotificationService.ownershipConfirmed(true), isTrue);
    });

    test('استعلام الملكية دون تهيئة Supabase لا يرمي ويُرجع null', () async {
      // في بيئة الاختبار Supabase غير مهيّأ — أي خطأ داخل الاستعلام (كفشل
      // الشبكة تمامًا) يجب أن يُبتلع ويُرجع null بدل الكراش.
      final owned = await PushNotificationService.notificationBelongsToUser(
        'notification-1',
        'user-a',
      );
      expect(owned, isNull);
    });
  });
}
