import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/models/order.dart';
import 'package:mahwar/features/orders_history/orders_history_screen.dart';
import 'package:mahwar/features/request_tracking/widgets/transaction_summary_card.dart';

Order _order(
  OrderStatus status, {
  DateTime? createdAt,
  DateTime? updatedAt,
  double? price,
  String? providerId,
}) {
  return Order(
    id: 'order-1',
    carOwnerId: 'owner-1',
    providerId: providerId,
    serviceTypeId: 'roadside',
    status: status,
    offeredPrice: price,
    ownerPhone: '01000000000',
    latitude: 30.0,
    longitude: 31.0,
    carMake: 'Toyota',
    carModel: 'Corolla',
    carYear: 2022,
    createdAt: createdAt ?? DateTime.utc(2026, 9, 10, 10, 0),
    updatedAt: updatedAt,
  );
}

void main() {
  group('buildTransactionPath — مسار المعاملة', () {
    test('طلبا مكتمل: كل أحداث الاكتمال بالترتيب', () {
      final created = DateTime.utc(2026, 9, 10, 9);
      final closed = DateTime.utc(2026, 9, 10, 12);
      final events = buildTransactionPath(
        _order(OrderStatus.completed,
            createdAt: created, updatedAt: closed, price: 500, providerId: 'p1'),
      );

      expect(events.first.label, 'تم إرسال الطلب');
      expect(events.first.time, created);
      expect(
        events.map((e) => e.label),
        containsAll([
          'استلم المزوّد الطلب',
          'قدّم المزوّد عرض السعر (500 EGP)',
          'تم تأكيد العرض',
          'تم إتمام المعاملة',
        ]),
      );
      expect(events.last.kind, TransactionEventKind.success);
      expect(events.last.time, closed);
    });

    test('رفض من العميل: آخر حدث failure والسبب يوضّح الجهة', () {
      final events = buildTransactionPath(
        _order(OrderStatus.rejectedByOwner,
            price: 500, providerId: 'p1', updatedAt: DateTime.utc(2026, 9, 10, 11)),
      );

      expect(events.last.label, 'رفض العميل عرض السعر');
      expect(events.last.kind, TransactionEventKind.failure);
      expect(transactionFailureReason(_order(OrderStatus.rejectedByOwner)),
          'رفض من جهة العميل');
    });

    test('رفض من المزوّد بلا عرض سعر سابق: مسار قصير وسبب واضح', () {
      final events = buildTransactionPath(
        _order(OrderStatus.rejectedByProvider, providerId: 'p1'),
      );

      expect(events.last.label, 'رفض المزوّد المعاملة');
      expect(
        events.map((e) => e.label),
        isNot(contains('قدّم المزوّد عرض السعر')),
      );
      expect(transactionFailureReason(_order(OrderStatus.rejectedByProvider)),
          'رفض من جهة المزوّد');
    });

    test('الإلغاء: إلغاء تلقائي (مهلة الاستجابة)', () {
      final events = buildTransactionPath(_order(OrderStatus.cancelled));
      expect(events.last.label, 'أُلغي الطلب (انتهت مهلة الاستجابة)');
      expect(transactionFailureReason(_order(OrderStatus.cancelled)),
          'إلغاء تلقائي (انتهت مهلة الاستجابة)');
    });

    test('الطلبات غير المنتهية لا تحمل حدث ختامي', () {
      for (final s in [OrderStatus.pending, OrderStatus.priced, OrderStatus.confirmed]) {
        final events = buildTransactionPath(_order(s));
        expect(
          events.last.kind,
          isNot(anyOf(TransactionEventKind.success, TransactionEventKind.failure)),
          reason: 'الحالة $s يجب ألا تعطي حدث ختامي',
        );
      }
    });
  });

  group('TransactionSummaryCard — بطاقة الملخص', () {
    testWidgets('مكتمل: عنوان، شارة النجاح، اسم المزوّد والمسار', (tester) async {
      final order = _order(OrderStatus.completed,
          price: 500, providerId: 'p1', updatedAt: DateTime.utc(2026, 9, 10, 12));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionSummaryCard(
              order: order,
              providerName: 'ورشة أحمد',
              workshopName: 'ورشة أحمد',
            ),
          ),
        ),
      );

      expect(find.text('ملخّص المعاملة'), findsOneWidget);
      expect(find.text('تمت المعاملة بنجاح'), findsOneWidget);
      expect(find.text('ورشة أحمد'), findsOneWidget);
      expect(find.text('مسار المعاملة'), findsOneWidget);
      expect(find.text('تم إتمام المعاملة'), findsOneWidget);
      expect(find.text('تاريخ المعاملة'), findsOneWidget);
      expect(find.text('تاريخ الإنهاء'), findsOneWidget);
    });

    testWidgets('رفض من العميل: شارة فشل + توضيح الجهة الرافضة', (tester) async {
      final order = _order(OrderStatus.rejectedByOwner,
          price: 500, providerId: 'p1', updatedAt: DateTime.utc(2026, 9, 10, 11));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionSummaryCard(
              order: order,
              providerName: 'ورشة أحمد',
            ),
          ),
        ),
      );

      expect(find.text('لم تُنجز المعاملة'), findsOneWidget);
      expect(find.text('رفض من جهة العميل'), findsOneWidget);
      expect(find.text('رفض العميل عرض السعر'), findsOneWidget);
    });
  });

  group('orderMatchesDay — فلترة التاريخ', () {
    final order = _order(OrderStatus.completed,
        createdAt: DateTime.utc(2026, 9, 10, 20, 30));

    test('يطابق نفس اليوم المحلي', () {
      expect(orderMatchesDay(order, DateTime.utc(2026, 9, 10)), isTrue);
    });

    test('لا يطابق يوماً آخر', () {
      expect(orderMatchesDay(order, DateTime.utc(2026, 9, 11)), isFalse);
      expect(orderMatchesDay(order, DateTime.utc(2026, 8, 10)), isFalse);
    });
  });
}