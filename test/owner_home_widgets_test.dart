// اختبارات شاشة المالك الجديدة:
//  1. شريط التقدّم العمودي (OrderProgressStepper) بملصقات العميل
//  2. بطاقة الطلب النشط (ActiveOrderWidget) — المحتوى وفتح التتبع عند النقر
// لا تتطلب أي plugin (Firebase/Supabase) لتشغيلها.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/constants/app_colors.dart';
import 'package:mahwar/core/models/order.dart';
import 'package:mahwar/features/owner_home/widgets/active_order_widget.dart';
import 'package:mahwar/features/owner_home/widgets/provider_rating_dialog.dart';
import 'package:mahwar/features/provider_home/widgets/order_live_badge.dart';
import 'package:mahwar/features/provider_home/widgets/order_progress_stepper.dart';

Order orderWith(OrderStatus status, {double? price, int elapsedMinutes = 0}) {
  return Order.fromJson({
    'id': '00000000-0000-0000-0000-000000000001',
    'car_owner_id': '00000000-0000-0000-0000-000000000002',
    'provider_id': '00000000-0000-0000-0000-000000000003',
    'service_type_id': 'crane',
    'status': _statusWire(status),
    'offered_price': price,
    'owner_phone': '01000000000',
    'latitude': 30.0,
    'longitude': 31.0,
    'car_make': 'Toyota',
    'car_model': 'Corolla',
    'car_year': 2020,
    'created_at':
        DateTime.now().toUtc().subtract(Duration(minutes: elapsedMinutes)).toIso8601String(),
  });
}

String _statusWire(OrderStatus status) {
  switch (status) {
    case OrderStatus.priced:
      return 'priced';
    case OrderStatus.confirmed:
      return 'confirmed';
    case OrderStatus.completed:
      return 'completed';
    case OrderStatus.rejectedByProvider:
      return 'rejected_by_provider';
    case OrderStatus.rejectedByOwner:
      return 'rejected_by_owner';
    case OrderStatus.cancelled:
      return 'cancelled';
    case OrderStatus.pending:
      return 'pending';
  }
}

void main() {
  group('OrderProgressStepper — النسخة العمودية بملصقات العميل', () {
    Widget buildStepper(OrderStatus status) {
      return OrderProgressStepperWrapper(status: status);
    }

    testWidgets('يعرض المراحل الأربع بترتيب العميل', (tester) async {
      await tester.pumpWidget(buildStepper(OrderStatus.pending));

      expect(find.text('تم الإرسال'), findsOneWidget);
      expect(find.text('استجابة المزوّد'), findsOneWidget);
      expect(find.text('التأكيد'), findsOneWidget);
      expect(find.text('الإتمام'), findsOneWidget);
    });

    testWidgets('استجابة المزوّد (priced) تعتبر المرحلة الأولى مكتملة', (tester) async {
      await tester.pumpWidget(buildStepper(OrderStatus.priced));

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('التأكيد (confirmed) يعتبر أول مرحلتين مكتملتين', (tester) async {
      await tester.pumpWidget(buildStepper(OrderStatus.confirmed));

      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    });
  });

  group('ActiveOrderWidget — بطاقة حالة الطلب النشط', () {
    testWidgets('يعرض بيانات الطلب والسعر وشريط التقدّم العمودي', (tester) async {
      final order = orderWith(OrderStatus.priced, price: 500);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ActiveOrderWidget(order: order))),
      );

      expect(find.text('تم تقديم عرض'), findsOneWidget);
      expect(find.text('Toyota Corolla 2020'), findsOneWidget);
      expect(find.text('500 EGP'), findsOneWidget);
      expect(find.text('تم الإرسال'), findsOneWidget);
      expect(find.text('استجابة المزوّد'), findsOneWidget);
      expect(find.text('التأكيد'), findsOneWidget);
      expect(find.text('الإتمام'), findsOneWidget);

      // إفراغ الشجرة لإيقاف المؤقّت الحي قبل نهاية الاختبار
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('يعرض الكرة الصفراء + التوقيت أثناء الانتظار', (tester) async {
      final order = orderWith(OrderStatus.priced, price: 500, elapsedMinutes: 3);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ActiveOrderWidget(order: order))),
      );

      expect(find.text('منذ 3 دقيقة'), findsOneWidget);
      expect(
        tester.widget<OrderLiveBadge>(find.byType(OrderLiveBadge)).dotColor,
        AppColors.warning,
      );

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('تتحوّل الكرة إلى خضراء عند التأكيد (خطوة قبل الإتمام) والاكتمال',
        (tester) async {
      for (final status in [OrderStatus.confirmed, OrderStatus.completed]) {
        final order = orderWith(status, price: 500, elapsedMinutes: 3);
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: ActiveOrderWidget(order: order))),
        );

        expect(
          tester.widget<OrderLiveBadge>(find.byType(OrderLiveBadge)).dotColor,
          AppColors.success,
        );
      }

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('النقر على البطاقة يستدعي فتح التتبع', (tester) async {
      final order = orderWith(OrderStatus.confirmed, price: 500);
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveOrderWidget(order: order, onTap: () => tapped = true),
          ),
        ),
      );

      await tester.tap(find.byType(ActiveOrderWidget));
      expect(tapped, isTrue);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('عرض السعر يعرض أزرار قبول/رفض في البطاقة مباشرة', (tester) async {
      final order = orderWith(OrderStatus.priced, price: 500);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ActiveOrderWidget(order: order))),
      );

      expect(find.text('قبول العرض'), findsOneWidget);
      expect(find.text('رفض العرض'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('بانر العرض يوضّح أن السعر من المزوّد ويتغيّر بعد التأكيد',
        (tester) async {
      final priced = orderWith(OrderStatus.priced, price: 500);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ActiveOrderWidget(order: priced))),
      );

      // أثناء انتظار القرار: رسالة «رد المزوّد» مع السعر
      expect(find.text('ردّ المزوّد على طلبك بعرض سعر'), findsOneWidget);
      expect(find.text('500 EGP'), findsOneWidget);
      expect(find.byIcon(Icons.request_quote_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox());

      final confirmed = orderWith(OrderStatus.confirmed, price: 500);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ActiveOrderWidget(order: confirmed))),
      );

      // بعد التأكيد: «السعر المتفق عليه» بعلامة توثيق
      expect(find.text('السعر المُتفق عليه'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('التأكيد يخفي أزرار القبول/الرفض', (tester) async {
      final order = orderWith(OrderStatus.confirmed, price: 500);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ActiveOrderWidget(order: order))),
      );

      expect(find.text('قبول العرض'), findsNothing);
      expect(find.text('رفض العرض'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('النقر على قبول يستدعي onAccept', (tester) async {
      final order = orderWith(OrderStatus.priced, price: 500);
      var accepted = false;
      var rejected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveOrderWidget(
              order: order,
              onAccept: () async => accepted = true,
              onReject: () async => rejected = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('قبول العرض'));
      await tester.pump();

      expect(accepted, isTrue);
      expect(rejected, isFalse);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('النقر على رفض يستدعي onReject دون قبول', (tester) async {
      final order = orderWith(OrderStatus.priced, price: 500);
      var accepted = false;
      var rejected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveOrderWidget(
              order: order,
              onAccept: () async => accepted = true,
              onReject: () async => rejected = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('رفض العرض'));
      await tester.pump();

      expect(rejected, isTrue);
      expect(accepted, isFalse);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('OrderLiveBadge — الدائرة والتوقيت الحي', () {
    test('تنسيق المدة المنقضية', () {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      expect(OrderLiveBadge.formatElapsed(null), '');
      expect(OrderLiveBadge.formatElapsed(now, asOf: now), 'الآن');
      expect(
        OrderLiveBadge.formatElapsed(now.subtract(const Duration(seconds: 30)), asOf: now),
        'الآن',
      );
      expect(
        OrderLiveBadge.formatElapsed(now.subtract(const Duration(minutes: 5)), asOf: now),
        'منذ 5 دقيقة',
      );
      expect(
        OrderLiveBadge.formatElapsed(now.subtract(const Duration(hours: 2)), asOf: now),
        'منذ 2 ساعة',
      );
      expect(
        OrderLiveBadge.formatElapsed(now.subtract(const Duration(days: 3)), asOf: now),
        'منذ 3 يوم',
      );
    });

    testWidgets('تظهر مدة مثل «منذ 4 دقيقة» للطلب المنشأ حديثاً', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderLiveBadge(
              createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 4)),
              dotColor: AppColors.success,
            ),
          ),
        ),
      );

      expect(find.text('منذ 4 دقيقة'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('ProviderRatingDialog — نافذة تقييم المزوّد', () {
    testWidgets('تعرض العنوان والنجوم وحقل التعليق والأزرار', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const ProviderRatingDialog(
                      orderId: '00000000-0000-0000-0000-000000000001',
                      providerName: 'أحمد',
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('قيّم تجربتك مع المزوّد'), findsOneWidget);
      expect(find.text('كيف كانت خدمة «أحمد»؟'), findsOneWidget);
      expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(5));
      expect(find.text('أضف تعليقاً (اختياري)...'), findsOneWidget);
      expect(find.text('إرسال التقييم'), findsOneWidget);
      expect(find.text('التقييم لاحقاً'), findsOneWidget);
    });

    testWidgets('اختيار نجمة يملؤها، و«التقييم لاحقاً» يغلق النافذة', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const ProviderRatingDialog(
                      orderId: '00000000-0000-0000-0000-000000000001',
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_rounded), findsNothing);

      // اختر النجمة الثالثة
      await tester.tap(find.byIcon(Icons.star_border_rounded).at(2));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));

      // إغلاق النافذة بدون إرسال
      await tester.tap(find.text('التقييم لاحقاً'));
      await tester.pumpAndSettle();
      expect(find.text('قيّم تجربتك مع المزوّد'), findsNothing);
    });
  });
}

class OrderProgressStepperWrapper extends StatelessWidget {
  final OrderStatus status;
  const OrderProgressStepperWrapper({super.key, required this.status});

  static const List<String> _ownerLabels = [
    'تم الإرسال',
    'استجابة المزوّد',
    'التأكيد',
    'الإتمام',
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: OrderProgressStepper(
          status: status,
          direction: Axis.vertical,
          labels: _ownerLabels,
        ),
      ),
    );
  }
}