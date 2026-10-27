import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/models/vehicle_catalog.dart';
import 'package:mahwar/core/models/vehicle_selection.dart';
import 'package:mahwar/core/services/vehicle_catalog_service.dart';
import 'package:mahwar/core/widgets/egyptian_plate.dart';
import 'package:mahwar/features/vehicles/vehicle_picker_screen.dart';
import 'package:mahwar/l10n/app_localizations.dart';

VehicleCatalog _catalog() {
  return VehicleCatalog(
    fetchedAt: DateTime.now().toUtc(),
    brands: [
      VehicleBrand(
        id: 'toyota',
        nameAr: 'تويوتا',
        nameEn: 'Toyota',
        isPopular: true,
        logoAsset: 'brands/toyota.svg',
        models: [
          VehicleModel(
            id: 'corolla',
            nameAr: 'كورولا',
            nameEn: 'Corolla',
            bodyType: 'sedan',
            generations: [
              VehicleGeneration(
                id: 'corolla-2014',
                yearFrom: 2014,
                yearTo: 2019,
                nameAr: '2014 – 2019',
                nameEn: '2014 – 2019',
                trims: const [
                  VehicleTrim(
                    id: 'corolla-2014-18-base',
                    nameAr: 'أساسي 1.8 لتر',
                    nameEn: 'Base 1.8 L',
                    engineCc: 1800,
                    fuel: 'petrol',
                    transmission: 'automatic',
                    horsepower: 140,
                    seats: 5,
                  ),
                ],
              ),
              VehicleGeneration(
                id: 'corolla-2020',
                yearFrom: 2020,
                yearTo: 2026,
                nameAr: '2020 – 2026',
                nameEn: '2020 – 2026',
                trims: const [
                  VehicleTrim(
                    id: 'corolla-2020-16-std',
                    nameAr: 'ستاندرد 1.6 لتر',
                    nameEn: 'Standard 1.6 L',
                    engineCc: 1600,
                    fuel: 'petrol',
                    transmission: 'automatic',
                    horsepower: 122,
                    seats: 5,
                  ),
                  VehicleTrim(
                    id: 'corolla-2020-20-amg',
                    nameAr: 'AMG Line 2.0 لتر',
                    nameEn: 'AMG Line 2.0 L',
                    engineCc: 2000,
                    fuel: 'petrol',
                    transmission: 'automatic',
                    horsepower: 245,
                    seats: 5,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    colors: const [
      VehicleColor(
        id: 'white',
        nameAr: 'أبيض',
        nameEn: 'White',
        hex: '#FFFFFF',
      ),
      VehicleColor(
        id: 'black',
        nameAr: 'أسود',
        nameEn: 'Black',
        hex: '#000000',
      ),
    ],
  );
}

class _PickerHandle {
  VehicleSelection? value;
}

Future<_PickerHandle> _openPicker(WidgetTester tester) async {
  VehicleCatalogService.instance.setCatalogForTesting(_catalog());
  addTearDown(() => VehicleCatalogService.instance.setCatalogForTesting(null));

  final handle = _PickerHandle();
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                handle.value = await Navigator.of(context)
                    .push<VehicleSelection>(
                      MaterialPageRoute(
                        builder: (_) => const VehiclePickerScreen(),
                      ),
                    );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return handle;
}

Future<void> _tap(WidgetTester tester, String label) async {
  final finder = find.text(label).first;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// يختار حرفًا من شبكة الحروف أسفل اللوحة (آخر تطابق، لأن اللوحة قد تعرضه أيضًا).
Future<void> _tapChip(WidgetTester tester, String letter) async {
  final finder = find.text(letter).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('يمشي عبر المعالج ويعيد اختياراً كاملاً', (tester) async {
    final handle = await _openPicker(tester);

    await _tap(tester, 'تويوتا');
    await _tap(tester, 'كورولا');

    // خطوة السنة مباشرة: الجيل يُستنتج تلقائيًا من السنة.
    await tester.tap(find.text('2024'));
    await tester.pumpAndSettle();

    expect(find.text('الجيل المطابق: 2020 – 2026'), findsOneWidget);
    expect(find.text('AMG Line 2.0 لتر'), findsOneWidget);
    expect(find.text('245 حصان · بنزين · أوتوماتيك · 5 مقاعد'), findsOneWidget);

    await _tap(tester, 'ستاندرد 1.6 لتر');
    await _tap(tester, 'أبيض');

    // خطوة اللوحة اختيارية: نحفظ دون إدخالها.
    await _tap(tester, 'حفظ السيارة');

    final result = handle.value;
    expect(result, isNotNull);
    expect(result!.brand.id, 'toyota');
    expect(result.model.id, 'corolla');
    expect(result.generation.id, 'corolla-2020');
    expect(result.trim.id, 'corolla-2020-16-std');
    expect(result.modelYear, 2024);
    expect(result.color.id, 'white');
    expect(result.plateLetters, isNull);
    expect(result.plateDigits, isNull);
  });

  testWidgets('يستنتج الجيل من السنة ويعرض فئاته فقط', (tester) async {
    await _openPicker(tester);

    await _tap(tester, 'تويوتا');
    await _tap(tester, 'كورولا');

    await tester.tap(find.text('2015'));
    await tester.pumpAndSettle();

    expect(find.text('الجيل المطابق: 2014 – 2019'), findsOneWidget);
    expect(find.text('أساسي 1.8 لتر'), findsOneWidget);
    expect(find.text('ستاندرد 1.6 لتر'), findsNothing);
  });

  testWidgets('اختيار «لا أعرف» يأخذ الفئة الأساسية', (tester) async {
    final handle = await _openPicker(tester);

    await _tap(tester, 'تويوتا');
    await _tap(tester, 'كورولا');
    await tester.tap(find.text('2024'));
    await tester.pumpAndSettle();

    // التلميح يحتوي «لا أعرف» داخل نص أطول، لذلك المطابقة هنا للزر وحده.
    await _tap(tester, 'لا أعرف');

    // انتقلنا مباشرة إلى خطوة اللون.
    expect(find.text('أبيض'), findsOneWidget);
    await _tap(tester, 'أبيض');
    await _tap(tester, 'حفظ السيارة');

    final result = handle.value;
    expect(result, isNotNull);
    expect(result!.generation.id, 'corolla-2020');
    expect(result.trim.id, 'corolla-2020-16-std');
  });

  testWidgets('إدخال اللوحة تفاعليًا: حروف من الشبكة وأرقام على اللوحة', (
    tester,
  ) async {
    final handle = await _openPicker(tester);

    await _tap(tester, 'تويوتا');
    await _tap(tester, 'كورولا');
    await tester.tap(find.text('2024'));
    await tester.pumpAndSettle();
    await _tap(tester, 'ستاندرد 1.6 لتر');
    await _tap(tester, 'أبيض');

    expect(find.text('لوحة السيارة (اختياري)'), findsOneWidget);

    // الحروف تُضاف بترتيب النقر، واللوحة تعرضها مباشرة.
    await _tapChip(tester, 'أ');
    await _tapChip(tester, 'ب');
    await _tapChip(tester, 'ج');
    expect(find.text('أبج'), findsOneWidget);

    // الأرقام تُكتب داخل اللوحة نفسها.
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();

    await _tap(tester, 'حفظ السيارة');

    final result = handle.value;
    expect(result, isNotNull);
    expect(result!.plateLetters, 'أبج');
    expect(result.plateDigits, '1234');
  });

  testWidgets('مسح اللوحة يفرغ الحروف والأرقام', (tester) async {
    await _openPicker(tester);

    await _tap(tester, 'تويوتا');
    await _tap(tester, 'كورولا');
    await tester.tap(find.text('2024'));
    await tester.pumpAndSettle();
    await _tap(tester, 'ستاندرد 1.6 لتر');
    await _tap(tester, 'أبيض');

    await _tapChip(tester, 'أ');
    await _tapChip(tester, 'ب');
    await _tapChip(tester, 'ج');
    await tester.enterText(find.byType(TextField), '555');
    await tester.pumpAndSettle();
    expect(find.text('أبج'), findsOneWidget);

    await _tap(tester, 'مسح');

    final plate = tester.widget<EgyptianPlate>(find.byType(EgyptianPlate));
    expect(plate.letters.whereType<String>(), isEmpty);
    expect(find.text('أبج'), findsNothing);
    expect(find.text('555'), findsNothing);
  });
}
