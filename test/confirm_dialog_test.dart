import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/constants/app_colors.dart';
import 'package:mahwar/core/widgets/confirm_dialog.dart';

void main() {
  Widget harness(VoidCallback callback) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: callback,
              child: const Text('فتح'),
            ),
          ),
        ),
      );

  testWidgets('showConfirmDialog يعرض العنوان والرسالة والأزرار', (tester) async {
    await tester.pumpWidget(
      harness(() {
        showConfirmDialog(
          tester.element(find.byType(TextButton)),
          title: 'إتمام الطلب؟',
          message: 'ستُعتبر الخدمة مكتملة.',
          confirmLabel: 'إتمام الطلب',
          confirmColor: AppColors.success,
        );
      }),
    );
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();

    expect(find.text('إتمام الطلب؟'), findsOneWidget);
    expect(find.text('ستُعتبر الخدمة مكتملة.'), findsOneWidget);
    expect(find.text('تراجع'), findsOneWidget);
    expect(find.text('إتمام الطلب'), findsWidgets);
  });

  testWidgets('التراجع يُرجع false ويمنع تنفيذ الإجراء', (tester) async {
    var acted = false;
    await tester.pumpWidget(
      harness(() {
        showConfirmDialog(
          tester.element(find.byType(TextButton)),
          title: 'رفض الطلب؟',
          message: 'سيتم إلغاء الطلب.',
          confirmLabel: 'نعم، رفض',
        ).then((ok) {
          if (ok) acted = true;
        });
      }),
    );
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('تراجع'));
    await tester.pumpAndSettle();
    expect(acted, isFalse);
  });

  testWidgets('التأكيد يُرجع true فيُنفَّذ الإجراء', (tester) async {
    var acted = false;
    await tester.pumpWidget(
      harness(() {
        showConfirmDialog(
          tester.element(find.byType(TextButton)),
          title: 'إتمام الطلب؟',
          message: 'ستُعتبر الخدمة مكتملة.',
          confirmLabel: 'إتمام الطلب',
        ).then((ok) {
          if (ok) acted = true;
        });
      }),
    );
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'إتمام الطلب'));
    await tester.pumpAndSettle();
    expect(acted, isTrue);
  });
}