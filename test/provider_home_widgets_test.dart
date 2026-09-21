// اختبارات الـ widgets الجديدة لبطاقة الطلب النشط في لوحة تحكم المزوّد:
//  1. شريط التقدّم (OrderProgressStepper) يعكس المرحلة الصحيحة حسب حالة الطلب
//  2. بطاقة الطلب النشط (ActiveOrderCard) تعرض زر الإتمام عند التأكيد فقط
//  3. الشارة الحيّة (OrderLiveBadge) — دائرة خضراء + مدة الطلب

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/constants/app_colors.dart';
import 'package:mahwar/core/models/order.dart';
import 'package:mahwar/features/provider_home/widgets/active_order_card.dart';
import 'package:mahwar/features/provider_home/widgets/order_live_badge.dart';
import 'package:mahwar/features/provider_home/widgets/order_progress_stepper.dart';

void main() {
  group('OrderProgressStepper — المراحل حسب الحالة', () {
    testWidgets('after priced shows stage 1 of 4 (عرض السعر) reached', (tester) async {
      await tester.pumpWidget(OrderProgressStepperWrapper(status: OrderStatus.priced));

      // الاسناد مكتمل ✓، والباقي قادم.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('الاسناد'), findsOneWidget);
      expect(find.text('عرض السعر'), findsOneWidget);
      expect(find.text('التأكيد'), findsOneWidget);
      expect(find.text('الإتمام'), findsOneWidget);
    });

    testWidgets('after confirmed shows stage 2 of 4 (التأكيد) reached', (tester) async {
      await tester.pumpWidget(OrderProgressStepperWrapper(status: OrderStatus.confirmed));

      // الاسناد + عرض السعر مكتملان ✓✓.
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    });

    testWidgets('boundary statuses keep the first stage', (tester) async {
      await tester.pumpWidget(OrderProgressStepperWrapper(status: OrderStatus.completed));
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
    });
  });

  group('ActiveOrderCard — المرحلة والإجراء النهائي', () {
    Widget buildCard(OrderStatus status, {VoidCallback? onComplete}) {
      return MaterialApp(
        home: Scaffold(
          body: ActiveOrderCard(
            customerName: 'أحمد',
            carMake: 'Toyota',
            carModel: 'Corolla',
            carYear: 2020,
            issueType: 'ونش',
            address: 'شارع التحرير',
            status: status,
            statusLabel: status == OrderStatus.confirmed ? 'مؤكد' : 'تم تقديم عرض',
            offeredPrice: 500,
            onComplete: status == OrderStatus.confirmed ? onComplete ?? () {} : null,
          ),
        ),
      );
    }

    testWidgets('priced shows waiting message and NO complete button', (tester) async {
      await tester.pumpWidget(buildCard(OrderStatus.priced));

      expect(find.text('بانتظار تأكيد العميل للعرض'), findsOneWidget);
      expect(find.text('إتمام الطلب'), findsNothing);
      expect(find.text('تم تقديم عرض'), findsOneWidget);
    });

    testWidgets('confirmed shows the complete button that fires onComplete', (tester) async {
      var completed = false;
      await tester.pumpWidget(
        buildCard(OrderStatus.confirmed, onComplete: () => completed = true),
      );

      expect(find.text('مؤكد'), findsOneWidget);
      final button = find.text('إتمام الطلب');
      expect(button, findsOneWidget);

      await tester.tap(button);
      expect(completed, isTrue);
    });

    testWidgets('يعرض دائرة خضراء + مدة الطلب كدلالة على أنه جديد وحالي', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveOrderCard(
              customerName: 'أحمد',
              carMake: 'Toyota',
              carModel: 'Corolla',
              carYear: 2020,
              issueType: 'ونش',
              address: 'شارع التحرير',
              status: OrderStatus.priced,
              statusLabel: 'تم تقديم عرض',
              createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 4)),
            ),
          ),
        ),
      );

      expect(find.text('منذ 4 دقيقة'), findsOneWidget);
      expect(
        tester.widget<OrderLiveBadge>(find.byType(OrderLiveBadge)).dotColor,
        AppColors.success,
      );

      // إفراغ الشجرة لإيقاف المؤقّت الحي قبل نهاية الاختبار
      await tester.pumpWidget(const SizedBox());
    });
  });
}

class OrderProgressStepperWrapper extends StatelessWidget {
  final OrderStatus status;
  const OrderProgressStepperWrapper({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Scaffold(body: OrderProgressStepper(status: status)));
  }
}