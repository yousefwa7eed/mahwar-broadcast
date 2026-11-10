import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/features/request_tracking/provider_alert_status.dart';
import 'package:mahwar/features/request_tracking/widgets/provider_offline_alert_card.dart';

Widget _harness(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('حصة متاحة: نص الاقتراح + زر الإرسال يستدعي onSend', (
    tester,
  ) async {
    var sendTaps = 0;
    await tester.pumpWidget(
      _harness(
        ProviderOfflineAlertCard(
          reason: ProviderAlertReason.ok,
          canSend: true,
          isSending: false,
          sent: false,
          onSend: () => sendTaps++,
          onDismiss: () {},
        ),
      ),
    );

    expect(find.text('المزوّد غير متصل حاليًا'), findsOneWidget);
    expect(find.text('إرسال رسالة تنبيه'), findsOneWidget);

    await tester.tap(find.text('إرسال رسالة تنبيه'));
    expect(sendTaps, 1);
  });

  testWidgets('بعد الإرسال: تأكيد بلا زر إرسال', (tester) async {
    await tester.pumpWidget(
      _harness(
        ProviderOfflineAlertCard(
          reason: ProviderAlertReason.ok,
          canSend: false,
          isSending: false,
          sent: true,
          onSend: () {},
          onDismiss: () {},
        ),
      ),
    );

    expect(find.text('تم إرسال التنبيه'), findsOneWidget);
    expect(find.text('إرسال رسالة تنبيه'), findsNothing);
  });

  testWidgets('نفاد الحصة الشهرية: رسالة توضيحية بلا زر', (tester) async {
    await tester.pumpWidget(
      _harness(
        ProviderOfflineAlertCard(
          reason: ProviderAlertReason.monthlyQuotaUsed,
          canSend: false,
          isSending: false,
          sent: false,
          onSend: () {},
          onDismiss: () {},
        ),
      ),
    );

    expect(
      find.text('تم استخدام رسالة التنبيه الشهرية لهذا المزوّد.'),
      findsOneWidget,
    );
    expect(find.text('إرسال رسالة تنبيه'), findsNothing);
  });

  testWidgets('السقف اليومي: رسالة توضيحية بلا زر', (tester) async {
    await tester.pumpWidget(
      _harness(
        ProviderOfflineAlertCard(
          reason: ProviderAlertReason.dailyCapReached,
          canSend: false,
          isSending: false,
          sent: false,
          onSend: () {},
          onDismiss: () {},
        ),
      ),
    );

    expect(
      find.text('تعذّر إرسال تنبيه إضافي الآن، حاول لاحقًا.'),
      findsOneWidget,
    );
    expect(find.text('إرسال رسالة تنبيه'), findsNothing);
  });

  testWidgets('أثناء الإرسال: الزر معطّل ويستدعي onDismiss عند الإغلاق', (
    tester,
  ) async {
    var dismissTaps = 0;
    await tester.pumpWidget(
      _harness(
        ProviderOfflineAlertCard(
          reason: ProviderAlertReason.ok,
          canSend: true,
          isSending: true,
          sent: false,
          onSend: () {},
          onDismiss: () => dismissTaps++,
        ),
      ),
    );

    final button = tester.widget<OutlinedButton>(
      find.byWidgetPredicate((widget) => widget is OutlinedButton),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(dismissTaps, 1);
  });
}
