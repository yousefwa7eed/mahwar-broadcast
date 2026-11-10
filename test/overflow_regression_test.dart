// حارس فيض حقيقي (ليس سكراتش): يضخ الودجتات الفعلية بخطوط التطبيق الحقيقية
// (Cairo/Poppins) لأن خط اختبارات Flutter الافتراضي Ahem عريض جدًا ويظهر فيضًا
// وهميًا. المقاسات: 254 (جهاز ضيق مع تكبير حجم العرض — منها جاءت خلية 64.7×60.5
// في سجل الجهاز) و320/360/412، وأحجام النص داخل حدّ التطبيق 0.9–1.3.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/models/vehicle_catalog.dart';
import 'package:mahwar/core/services/vehicle_catalog_service.dart';
import 'package:mahwar/core/widgets/brand_logo.dart';
import 'package:mahwar/features/owner_home/widgets/services_grid.dart';
import 'package:mahwar/features/vehicles/vehicle_picker_screen.dart';
import 'package:mahwar/l10n/app_localizations.dart';

Future<void> _loadAppFonts() async {
  const families = {
    'Cairo': [
      'assets/fonts/Cairo/Cairo-Regular.ttf',
      'assets/fonts/Cairo/Cairo-SemiBold.ttf',
      'assets/fonts/Cairo/Cairo-Bold.ttf',
    ],
    'Poppins': [
      'assets/fonts/Poppins/Poppins-Regular.ttf',
      'assets/fonts/Poppins/Poppins-Medium.ttf',
      'assets/fonts/Poppins/Poppins-Bold.ttf',
    ],
    'Zain': [
      'assets/fonts/Zain/Zain-Regular.ttf',
      'assets/fonts/Zain/Zain-Bold.ttf',
    ],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

VehicleCatalog _catalog() => VehicleCatalog(
  fetchedAt: DateTime.now().toUtc(),
  brands: const [
    VehicleBrand(id: 'hyundai', nameAr: 'هيونداي', nameEn: 'Hyundai'),
    VehicleBrand(id: 'toyota', nameAr: 'تويوتا', nameEn: 'Toyota'),
    VehicleBrand(id: 'mercedes', nameAr: 'مرسيدس', nameEn: 'Mercedes-Benz'),
    VehicleBrand(id: 'bmw', nameAr: 'بي إم دبليو', nameEn: 'BMW'),
    VehicleBrand(id: 'kia', nameAr: 'كيا', nameEn: 'Kia'),
    VehicleBrand(id: 'nissan', nameAr: 'نيسان', nameEn: 'Nissan'),
  ],
  colors: const [],
);

/// يضخ [child] ويجمع رسائل الفيض الصادرة من الـ framework. لا يفرّغ الشجرة كي
/// يستطيع الاختبار فحص الودجتات بعد الاستدعاء.
Future<List<String>> _pumpAndCollectOverflow(
  WidgetTester tester,
  Widget child, {
  required Locale locale,
  required double scale,
  required double width,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final details = <FlutterErrorDetails>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = details.add;
  try {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: app!,
        ),
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = previousOnError;
  }
  final exception = tester.takeException();
  if (exception != null) {
    details.add(FlutterErrorDetails(exception: exception));
  }
  return details
      .map((d) => d.exception.toString())
      .where((m) => m.contains('overflowed') || m.contains('OVERFLOW'))
      .toList();
}

void main() {
  setUpAll(_loadAppFonts);
  tearDown(() => VehicleCatalogService.instance.setCatalogForTesting(null));

  for (final locale in const [Locale('ar'), Locale('en')]) {
    for (final width in const [254.0, 320.0, 360.0, 412.0]) {
      for (final scale in const [1.0, 1.3]) {
        final tag = '${locale.languageCode} ${width.toInt()} @$scale';

        testWidgets('خطوة الماركة لا تفيض — $tag', (tester) async {
          VehicleCatalogService.instance.setCatalogForTesting(_catalog());
          final overflows = await _pumpAndCollectOverflow(
            tester,
            const VehiclePickerScreen(),
            locale: locale,
            scale: scale,
            width: width,
          );
          expect(find.byType(BrandLogo), findsWidgets);
          expect(overflows, isEmpty, reason: overflows.join('\n'));
        });

        testWidgets('شبكة الخدمات لا تفيض — $tag', (tester) async {
          final overflows = await _pumpAndCollectOverflow(
            tester,
            Scaffold(
              body: SingleChildScrollView(
                child: ServicesGrid(onServiceTap: (_) {}),
              ),
            ),
            locale: locale,
            scale: scale,
            width: width,
          );
          expect(overflows, isEmpty, reason: overflows.join('\n'));
        });
      }
    }
  }
}
