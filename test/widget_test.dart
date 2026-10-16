// اختبارات الوحدة/الـ widgets للميزات المضافة:
//  1. تحليل orders.respond_deadline في Order.fromJson
//  2. عرض عداد مدة الاستجابة في NearbyRequestCard
// لا تتطلب أي plugin (Firebase/Supabase) لتشغيلها.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/models/notification_model.dart';
import 'package:mahwar/core/models/order.dart';
import 'package:mahwar/core/utils/supabase_time.dart';
import 'package:mahwar/features/notifications/notification_detail_screen.dart';
import 'package:mahwar/features/provider_home/widgets/nearby_request_card.dart';
import 'package:mahwar/features/request_tracking/widgets/provider_offer_card.dart';

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
      expect(order.autoCancel, isTrue);
    });

    test('يقرأ auto_cancel عند إرساله صراحةً', () {
      final order = Order.fromJson({
        'id': '00000000-0000-0000-0000-000000000007',
        'car_owner_id': '00000000-0000-0000-0000-000000000002',
        'service_type_id': 'crane',
        'status': 'pending',
        'owner_phone': '01000000000',
        'latitude': 30.0,
        'longitude': 31.0,
        'car_make': 'Toyota',
        'car_model': 'Corolla',
        'car_year': 2020,
        'auto_cancel': false,
      });

      expect(order.autoCancel, isFalse);
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
            distanceMeters: 1500,
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

    testWidgets('لا يعرض رسالة مهلة ثابتة عندما تكون المهلة في الماضي', (tester) async {
      final deadline = DateTime.now().subtract(const Duration(seconds: 5));
      await tester.pumpWidget(buildCard(deadline));

      expect(find.textContaining('متبقي'), findsNothing);
      expect(find.textContaining('انتهت المهلة'), findsNothing);
    });

    testWidgets('لا يعرض عداداً عندما لا توجد مهلة', (tester) async {
      await tester.pumpWidget(buildCard(null));

      expect(find.textContaining('متبقي'), findsNothing);
      expect(find.textContaining('انتهت المهلة'), findsNothing);
    });
  });

  group('supabase_time — تحليل UTC ومرجع "منذ ..." للخادم', () {
    test('يعتبر الخيط بلا منطقة زمنية توقيت UTC لا محلي', () {
      final dt = parseSupabaseTimestamp('2026-09-15T10:30:00.000000');
      expect(dt, isNotNull);
      expect(dt!.isUtc, isTrue);
      expect(dt.toUtc(), DateTime.utc(2026, 9, 15, 10, 30));
    });

    test('يحافظ على المنطقة الزمنية عندما تكون موجودة', () {
      final dt = parseSupabaseTimestamp('2026-09-15T13:30:00+03:00');
      expect(dt, isNotNull);
      expect(dt!.isUtc, isTrue);
      expect(dt.toUtc(), DateTime.utc(2026, 9, 15, 10, 30));
    });

    test('يحسب Order.created_at كـ UTC قياسي (لا toLocal عند التحليل)', () {
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
        'created_at': '2026-09-15T10:30:00+00:00',
      });

      expect(order.createdAt, isNotNull);
      expect(order.createdAt!.isUtc, isTrue);
      expect(order.createdAt!.toUtc(), DateTime.utc(2026, 9, 15, 10, 30));
    });

    test('timeAgo يُحسب ضد مرجع asOf (زمن الخادم) لا ضد ساعة الجهاز', () {
      const asOf = '2026-09-15T11:30:00+00:00';
      final notification = NotificationModel.fromJson({
        'id': '00000000-0000-0000-0000-000000000001',
        'user_id': '00000000-0000-0000-0000-000000000002',
        'type': 'new_order',
        'created_at': '2026-09-15T10:30:00+00:00',
      });

      // قبل ساعة كاملة من زمن الخادم — بغض النظر عن الساعة الفعلية للجهاز.
      expect(notification.timeAgo(DateTime.parse(asOf)), 'منذ 1 ساعة');
    });

    test('timeAgo يرجع الآن عندما يحل حدث للتو', () {
      final notification = NotificationModel.fromJson({
        'id': '00000000-0000-0000-0000-000000000001',
        'user_id': '00000000-0000-0000-0000-000000000002',
        'type': 'new_message',
        'created_at': '2026-09-15T10:30:00+00:00',
      });

      expect(notification.timeAgo(DateTime.parse('2026-09-15T10:30:12+00:00')),
          'الآن');
    });
  });

  group('NotificationModel — إشعار عام (broadcast)', () {
    const base = {
      'id': '00000000-0000-0000-0000-000000000001',
      'user_id': '00000000-0000-0000-0000-000000000002',
    };

    test('لا يحمل order_id ويقرأ العنوان والنص من metadata', () {
      final notification = NotificationModel.fromJson({
        ...base,
        'type': 'broadcast',
        'metadata': {
          'title': 'صيانة مجدولة',
          'body': 'نص الإشعار العام الكامل',
        },
      });

      expect(notification.orderId, isNull);
      expect(notification.type, 'broadcast');
      expect(notification.localizedTitle(null), 'صيانة مجدولة');
      expect(notification.localizedBody(null), 'نص الإشعار العام الكامل');
    });
  });

  group('NotificationDetailScreen — تفاصيل الإشعار العام', () {
    testWidgets('يعرض العنوان والنص الكاملين ووقت الإرسال', (tester) async {
      final notification = NotificationModel.fromJson({
        'id': '00000000-0000-0000-0000-000000000001',
        'user_id': '00000000-0000-0000-0000-000000000002',
        'type': 'broadcast',
        'metadata': {
          'title': 'إشعار صيانة مجدولة',
          'body': 'هذا هو النص الكامل الطويل للإشعار العام الموضوع في الصفحة',
        },
        'created_at': '2026-09-15T10:30:00+00:00',
      });

      await tester.pumpWidget(
        MaterialApp(home: NotificationDetailScreen(notification: notification)),
      );

      // شارة "إشعار عام" + العنوان + النص الكامل + "أُرسل في ...".
      expect(find.text('إشعار عام'), findsOneWidget);
      expect(find.text('إشعار صيانة مجدولة'), findsOneWidget);
      expect(find.textContaining('النص الكامل الطويل'), findsOneWidget);
      expect(find.textContaining('أُرسل في'), findsOneWidget);
    });
  });

  group('NearbyRequestCard — تنسيق المسافة الموحّد', () {
    Widget buildCard({required double? distanceMeters}) {
      return MaterialApp(
        home: Scaffold(
          body: NearbyRequestCard(
            carMake: 'Toyota',
            carModel: 'Corolla',
            carYear: 2020,
            issueType: 'ونش',
            distanceMeters: distanceMeters,
            address: 'شارع التحرير',
            deadline: null,
          ),
        ),
      );
    }

    testWidgets('distanceMeters 3500 يعرض "≈ 3.5" ولا يعرض "3500"', (tester) async {
      await tester.pumpWidget(buildCard(distanceMeters: 3500));

      // المُنسّق يُنتج "≈ 3.5 كم" (أو "≈ 3.5 km" بالإنجليزية)
      expect(find.textContaining('≈ 3.5'), findsOneWidget);
      expect(find.textContaining('3500'), findsNothing);
    });

    testWidgets('distanceMeters null يعرض شرطة محايدة', (tester) async {
      await tester.pumpWidget(buildCard(distanceMeters: null));

      // لا مسافة رقمية — فقط الشرطة
      expect(find.textContaining('—'), findsOneWidget);
      expect(find.textContaining('≈'), findsNothing);
    });
  });

  group('ProviderOfferCard — إخفاء شريحة المسافة عند غيابها', () {
    Widget buildCard({required double? distanceMeters}) {
      return MaterialApp(
        home: Scaffold(
          body: ProviderOfferCard(
            providerName: 'أحمد علي',
            workshopName: 'ورشة المحور',
            distanceMeters: distanceMeters,
            price: 500,
            currency: 'EGP',
            estimatedMinutes: 15,
          ),
        ),
      );
    }

    testWidgets('عند distanceMeters null لا تظهر شريحة المسافة', (tester) async {
      await tester.pumpWidget(buildCard(distanceMeters: null));

      // شريحة الوقت تبقى، المسافة تختفي
      expect(find.textContaining('دقيقة'), findsOneWidget);
      expect(find.textContaining('≈'), findsNothing);
      expect(find.textContaining('كم'), findsNothing);
    });

    testWidgets('عند distanceMeters 3500 تظهر المسافة المنسّقة', (tester) async {
      await tester.pumpWidget(buildCard(distanceMeters: 3500));

      expect(find.textContaining('≈ 3.5'), findsOneWidget);
    });
  });
}