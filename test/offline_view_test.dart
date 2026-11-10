// رسائل ما بعد فشل التحميل (البند 6): أوفلاين بلا نص استثناء خام + إعادة محاولة.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/widgets/offline_view.dart';

void main() {
  testWidgets('OfflineView يعرض رسالة انقطاع الشبكة وزر إعادة محاولة يعمل', (
    tester,
  ) async {
    var retries = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OfflineView(onRetry: () => retries++)),
      ),
    );

    expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
    expect(find.text('تحقّق من اتصالك بالشبكة ثم أعد المحاولة'), findsOneWidget);

    await tester.tap(find.text('إعادة المحاولة'));
    expect(retries, 1);
  });

  testWidgets('LoadFailedView يعرض الرسالة الممرَّرة (لا نص الخادم) وزر المحاولة', (
    tester,
  ) async {
    var retries = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoadFailedView(
            message: 'تعذّر تحميل الطلبات',
            onRetry: () => retries++,
          ),
        ),
      ),
    );

    expect(find.text('تعذّر تحميل الطلبات'), findsOneWidget);

    await tester.tap(find.text('إعادة المحاولة'));
    expect(retries, 1);
  });
}
