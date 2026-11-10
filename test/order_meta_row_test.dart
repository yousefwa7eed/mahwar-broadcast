// اختبارات الاتجاه والمرونة لصف البيانات الوصفية الموحّد ولطبقة السجل
// المستخرجة: الشارة في بداية اتجاه القراءة والذيل في نهايته (RTL/LTR)،
// ولا فيض على عرض ضيق مع خط كبير، والبطاقة تعمل ببيانات محقونة بلا Supabase.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/models/order.dart';
import 'package:mahwar/core/widgets/order_history_card.dart';
import 'package:mahwar/core/widgets/order_meta_row.dart';
import 'package:mahwar/features/provider_home/widgets/active_order_card.dart';
import 'package:mahwar/features/provider_home/widgets/order_live_badge.dart';
import 'package:mahwar/l10n/app_localizations.dart';

Widget _wrap(Widget child, {required Locale locale, double width = 320}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

Widget _metaRow({double scale = 1.0}) {
  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: OrderMetaRow(
      badge: Container(
        color: Colors.orange,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: const Text(
          'بانتظار رد المزوّد على الطلب',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: Container(
        color: Colors.green,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: const Text(
          'السبت ٨ نوفمبر ٢٠٢٦ • ١٢:٣٠ م',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );
}

void main() {
  group('OrderMetaRow — الاتجاه', () {
    testWidgets('LTR: الشارة يساراً والذيل يميناً', (tester) async {
      await tester.pumpWidget(_wrap(_metaRow(), locale: const Locale('en')));
      await tester.pumpAndSettle();

      final badge = tester.getRect(find.text('بانتظار رد المزوّد على الطلب'));
      final trailing = tester.getRect(find.text('السبت ٨ نوفمبر ٢٠٢٦ • ١٢:٣٠ م'));
      expect(badge.left, lessThan(trailing.left));
      expect(tester.takeException(), isNull);
    });

    testWidgets('RTL: الشارة يميناً والذيل يساراً', (tester) async {
      await tester.pumpWidget(_wrap(_metaRow(), locale: const Locale('ar')));
      await tester.pumpAndSettle();

      final badge = tester.getRect(find.text('بانتظار رد المزوّد على الطلب'));
      final trailing = tester.getRect(find.text('السبت ٨ نوفمبر ٢٠٢٦ • ١٢:٣٠ م'));
      expect(badge.right, greaterThan(trailing.right));
      expect(tester.takeException(), isNull);
    });
  });

  group('OrderMetaRow — المرونة', () {
    for (final scale in [1.0, 1.6]) {
      testWidgets('عرض 280 مع خط $scale لا يفيض (ar)', (tester) async {
        await tester.pumpWidget(
          _wrap(_metaRow(scale: scale), locale: const Locale('ar'), width: 280),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('OrderMetaRow — Middle على 320x568 بخط 1.3', () {
    // متطلب Stage 3: الشارة الحيّة (middle) لا تفجّر الصف على أصغر
    // شاشة مستهدفة مع خط النظام الكبير — تُقتطع بـ ellipsis ولا تختفي.
    Future<void> pumpCard(WidgetTester tester, Locale locale) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: ActiveOrderCard(
                  customerName: 'أحمد محمود عبدالرحمن',
                  carMake: 'Toyota',
                  carModel: 'Corolla',
                  carYear: 2020,
                  issueType: 'ونش إنقاذ',
                  address: 'شارع التحرير، وسط البلد، القاهرة',
                  status: OrderStatus.priced,
                  statusLabel: 'تم تقديم عرض السعر بانتظار التأكيد',
                  offeredPrice: 123456,
                  createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 4)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    bool liveBadgeTruncated(WidgetTester tester) {
      final badgeFinder = find.byType(OrderLiveBadge);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: badgeFinder, matching: find.byType(Text)).first,
      );
      return paragraph.didExceedMaxLines;
    }

    testWidgets('ar: لا فيض، والشارة الحيّة ظاهرة (مقتطعة إن لزم)', (tester) async {
      await pumpCard(tester, const Locale('ar'));
      expect(tester.takeException(), isNull);
      expect(find.byType(OrderLiveBadge), findsOneWidget);
      debugPrint('320x568@1.3 ar — live badge truncated: ${liveBadgeTruncated(tester)}');
    });

    testWidgets('en: لا فيض، والشارة الحيّة ظاهرة (مقتطعة إن لزم)', (tester) async {
      await pumpCard(tester, const Locale('en'));
      expect(tester.takeException(), isNull);
      expect(find.byType(OrderLiveBadge), findsOneWidget);
      debugPrint('320x568@1.3 en — live badge truncated: ${liveBadgeTruncated(tester)}');
    });
  });

  group('OrderHistoryCard — بيانات محقونة', () {
    final order = Order(
      id: 'order-1',
      carOwnerId: 'owner-1',
      serviceTypeId: 'crane',
      status: OrderStatus.priced,
      offeredPrice: 123456,
      latitude: 30.0,
      longitude: 31.0,
      carMake: 'Toyota',
      carModel: 'Corolla',
      carYear: 2022,
      createdAt: DateTime.utc(2026, 11, 8, 10, 30),
    );

    testWidgets('تعرض البيانات وتستدعي onTap بلا أي Supabase', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          OrderHistoryCard(order: order, onTap: () => tapped = true),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Toyota Corolla 2022'), findsOneWidget);
      expect(find.textContaining('123456'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(InkWell).first);
      expect(tapped, isTrue);
    });
  });
}