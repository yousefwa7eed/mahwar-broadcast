// سياسة جلب الإشعارات: لا نعيد جلب القائمة عند كل فتح للشاشة.
//  - أول تحميل يجلب دائمًا.
//  - داخل مدة الحداثة لا يجلب (Realtime يغطي الجديد).
//  - بعد المدة يجلب، والجلب الصريح (سحب/إعادة محاولة) يجلب دائمًا.

import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/notifications/notification_cubit.dart';

void main() {
  final now = DateTime(2026, 11, 10, 12, 0);

  test('أول تحميل بلا سجل سابق يجلب فورًا', () {
    expect(
      NotificationCubit.shouldFetch(
        force: false,
        hasLoaded: false,
        lastLoadedAt: null,
        now: now,
      ),
      isTrue,
    );
  });

  test('داخل مدة الحداثة لا يُعاد الجلب عند فتح الشاشة', () {
    expect(
      NotificationCubit.shouldFetch(
        force: false,
        hasLoaded: true,
        lastLoadedAt: now.subtract(const Duration(seconds: 10)),
        now: now,
      ),
      isFalse,
    );
  });

  test('بعد مدة الحداثة يجلب', () {
    expect(
      NotificationCubit.shouldFetch(
        force: false,
        hasLoaded: true,
        lastLoadedAt: now.subtract(NotificationCubit.refreshTtl),
        now: now,
      ),
      isTrue,
    );
  });

  test('الجلب الصريح (force) يتخطى المدة دائمًا', () {
    expect(
      NotificationCubit.shouldFetch(
        force: true,
        hasLoaded: true,
        lastLoadedAt: now,
        now: now,
      ),
      isTrue,
    );
  });

  test('حالة التحميل القديمة جدًا (مع تخصيص مدة) تُحدَّث', () {
    expect(
      NotificationCubit.shouldFetch(
        force: false,
        hasLoaded: true,
        lastLoadedAt: now.subtract(const Duration(seconds: 5)),
        now: now,
        ttl: const Duration(seconds: 3),
      ),
      isTrue,
    );
  });
}
