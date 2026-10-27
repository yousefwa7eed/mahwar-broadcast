import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/models/vehicle.dart';
import 'package:mahwar/core/models/vehicle_catalog.dart';
import 'package:mahwar/core/models/vehicle_selection.dart';

VehicleCatalog _catalog() {
  return VehicleCatalog(
    fetchedAt: DateTime.utc(2026, 10, 27),
    brands: [
      VehicleBrand(
        id: 'toyota',
        nameAr: 'تويوتا',
        nameEn: 'Toyota',
        isPopular: true,
        models: [
          VehicleModel(
            id: 'corolla',
            nameAr: 'كورولا',
            nameEn: 'Corolla',
            bodyType: 'sedan',
            generations: [
              VehicleGeneration(
                id: 'corolla-2020-2026',
                yearFrom: 2020,
                yearTo: 2026,
                nameAr: 'الجيل الحالي',
                nameEn: 'Current generation',
                trims: const [
                  VehicleTrim(
                    id: 'corolla-2020-16-std',
                    nameAr: '1.6 استاندر',
                    nameEn: '1.6 Standard',
                    engineCc: 1600,
                    fuel: 'petrol',
                    transmission: 'automatic',
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
      VehicleColor(id: 'white', nameAr: 'أبيض', nameEn: 'White', hex: '#FFFFFF'),
    ],
  );
}

void main() {
  group('VehicleCatalog lookups', () {
    test('resolves brand/model/generation/trim/color from a trim id', () {
      final catalog = _catalog();

      expect(catalog.trim('corolla-2020-16-std')?.nameAr, '1.6 استاندر');
      expect(catalog.generationOfTrim('corolla-2020-16-std')?.yearFrom, 2020);
      expect(catalog.modelOfTrim('corolla-2020-16-std')?.id, 'corolla');
      expect(catalog.brandOfTrim('corolla-2020-16-std')?.id, 'toyota');
      expect(catalog.color('white')?.nameAr, 'أبيض');
    });

    test('unknown ids resolve to null instead of throwing', () {
      final catalog = _catalog();
      expect(catalog.trim('missing'), isNull);
      expect(catalog.brandOfTrim('missing'), isNull);
      expect(catalog.color(null), isNull);
    });
  });

  group('VehicleGeneration.years', () {
    test('lists years newest-first within the generation', () {
      final generation = _catalog().generation('corolla-2020-2026')!;
      expect(generation.years.first, 2026);
      expect(generation.years.last, 2020);
      expect(generation.years.length, 7);
    });

    test('open-ended generation falls back to the current year', () {
      final generation = VehicleGeneration(
        id: 'open',
        yearFrom: DateTime.now().year - 2,
        yearTo: null,
        nameAr: '',
        nameEn: '',
      );
      expect(generation.years.first, DateTime.now().year);
    });
  });

  group('VehicleSummary and signup metadata', () {
    final catalog = _catalog();
    final vehicle = Vehicle(
      id: 'v1',
      userId: 'u1',
      trimId: 'corolla-2020-16-std',
      modelYear: 2024,
      colorId: 'white',
      plateLetters: 'أبج',
      plateDigits: '1234',
    );

    test('resolves catalog names and plate into a display summary', () {
      final summary = vehicle.resolve(catalog);
      expect(summary.title(true), 'تويوتا كورولا 2024');
      expect(summary.subtitle(true), '1.6 استاندر · أبيض · أبج 1234');
      expect(summary.trim?.fuel, 'petrol');
    });

    test('toSignupMetadata emits the keys handle_new_user reads', () {
      final selection = VehicleSelection(
        brand: catalog.brand('toyota')!,
        model: catalog.model('corolla')!,
        generation: catalog.generation('corolla-2020-2026')!,
        trim: catalog.trim('corolla-2020-16-std')!,
        modelYear: 2024,
        color: catalog.color('white')!,
        plateLetters: 'أبج',
        plateDigits: '1234',
      );

      expect(selection.toSignupMetadata(), {
        'vehicle_trim_id': 'corolla-2020-16-std',
        'vehicle_model_year': 2024,
        'vehicle_color_id': 'white',
        'vehicle_plate_letters': 'أبج',
        'vehicle_plate_digits': '1234',
      });
      expect(selection.toInsertJson(), {
        'trim_id': 'corolla-2020-16-std',
        'model_year': 2024,
        'color_id': 'white',
        'plate_letters': 'أبج',
        'plate_digits': '1234',
      });
    });

    test('plate-less vehicle omits plate from the subtitle', () {
      final summary = const Vehicle(
        id: 'v2',
        userId: 'u1',
        trimId: 'corolla-2020-16-std',
        modelYear: 2024,
        colorId: 'white',
      ).resolve(catalog);
      expect(summary.subtitle(true), '1.6 استاندر · أبيض');
    });
  });
}
