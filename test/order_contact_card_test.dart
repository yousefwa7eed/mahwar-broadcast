import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/features/orders/widgets/order_contact_card.dart';

void main() {
  group('OrderContactCard — بوابة الحالة', () {
    testWidgets('غير مؤكّد (pending): لا يعرض البطاقة ولا يستدعي الـ RPC',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: OrderContactCard(orderId: 'o1', status: 'pending'),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('رقم الهاتف'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('عرض السعر (priced): لا يعرض البطاقة', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: OrderContactCard(orderId: 'o1', status: 'priced'),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('مؤكّد بلا اتصال بالخادم: لا ينهار ويعرض لا شيء', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: OrderContactCard(orderId: 'o1', status: 'confirmed'),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('رقم الهاتف'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });
  });
}
