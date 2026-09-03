// اختبارات الوحدة/الـ widgets للميزات المضافة:
//  1. تحليل orders.respond_deadline في Order.fromJson
//  2. عرض عداد مدة الاستجابة في NearbyRequestCard
// لا تتطلب أي plugin (Firebase/Supabase) لتشغيلها.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/models/order.dart';
import 'package:mahwar/features/provider_home/widgets/nearby_request_card.dart';

void main() {
  group('Order.fromJson — respond_deadline', () {
    test('يقرأ respond_deadline عند وجوده', () {
      final order = Order.fromJson({
        'id': '00000000-0000-0000-0000-000000000001',
        'car_owner_id': '00000000-0000-0000-0000-000000000002',
        'service_type_id': 'crane',
        'status': 'pending',
        'owner_phone': '01000000000',
        'latitude': 30.0,
        'longitude': 31.0,
        'car_make': 'Toyota',
        'car_model': 'Corolla',
        'car_year': 2020,
        'respond_deadline': '2026-08-28T13:33:44.153309+00:00',
      });

      expect(order.respondDeadline, isNotNull);
      expect(
        order.respondDeadline!.toUtc(),
        DateTime.parse('2026-08-28T13:33:44.153309Z').toUtc(),
      );
    });

    test('يبقيه null عندما يكون غائباً أو فارغاً', () {
      final order = Order.fromJson({
        'id': '00000000-0000-0000-0000-000000000003',
        'car_owner_id': '00000000-0000-0000-0000-000000000002',
        'service_type_id': 'crane',
        'status': 'pending',
        'owner_phone': '01000000000',
        'latitude': 30.0,
        'longitude': 31.0,
        'car_make': 'Toyota',
        'car_model': 'Corolla',
        'car_year': 2020,
      });

      expect(order.respondDeadline, isNull);
    });
  });

  group('NearbyRequestCard — عداد مدة الاستجابة', () {
    Widget buildCard(DateTime? deadline) {
      return MaterialApp(
        home: Scaffold(
          body: NearbyRequestCard(
            carMake: 'Toyota',
            carModel: 'Corolla',
            carYear: 2020,
            issueType: 'ونش',
            distance: 1.5,
            address: 'شارع التحرير',
            deadline: deadline,
          ),
        ),
      );
    }

    testWidgets('يعرض الوقت المتبقي عندما تكون المهلة مستقبلية', (tester) async {
      final deadline = DateTime.now().add(const Duration(minutes: 2));
      await tester.pumpWidget(buildCard(deadline));

      expect(find.textContaining('متبقي'), findsOneWidget);
      expect(find.textContaining('انتهت المهلة'), findsNothing);
    });

    testWidgets('يعرض "انتهت المهلة" عندما تكون المهلة في الماضي', (tester) async {
      final deadline = DateTime.now().subtract(const Duration(seconds: 5));
      await tester.pumpWidget(buildCard(deadline));

      expect(find.textContaining('انتهت المهلة'), findsOneWidget);
    });

    testWidgets('لا يعرض عداداً عندما لا توجد مهلة', (tester) async {
      await tester.pumpWidget(buildCard(null));

      expect(find.textContaining('متبقي'), findsNothing);
      expect(find.textContaining('انتهت المهلة'), findsNothing);
    });
  });
}