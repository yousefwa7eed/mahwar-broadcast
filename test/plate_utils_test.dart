import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/utils/plate_utils.dart';

void main() {
  group('PlateUtils.isValidPlate', () {
    test('accepts 3 Arabic letters and 3 or 4 digits', () {
      expect(PlateUtils.isValidPlate('أ', 'ب', 'ج', '123'), isTrue);
      expect(PlateUtils.isValidPlate('أ', 'ب', 'ج', '1234'), isTrue);
    });

    test('rejects missing letters, unknown letters and wrong digit counts', () {
      expect(PlateUtils.isValidPlate(null, 'ب', 'ج', '123'), isFalse);
      expect(PlateUtils.isValidPlate('أ', 'ز', 'ج', '123'), isFalse);
      expect(PlateUtils.isValidPlate('أ', 'ب', 'ج', '12'), isFalse);
      expect(PlateUtils.isValidPlate('أ', 'ب', 'ج', '12345'), isFalse);
      expect(PlateUtils.isValidPlate('أ', 'ب', 'ج', null), isFalse);
    });
  });

  group('PlateUtils.toWesternDigits', () {
    test('converts Arabic-Indic digits', () {
      expect(PlateUtils.toWesternDigits('١٢٣٤'), '1234');
    });

    test('converts extended Arabic-Indic digits', () {
      expect(PlateUtils.toWesternDigits('۱۲۳'), '123');
    });

    test('leaves other characters untouched', () {
      expect(PlateUtils.toWesternDigits('أبج 12'), 'أبج 12');
    });
  });
}
