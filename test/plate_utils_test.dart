import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/utils/plate_utils.dart';

void main() {
  group('PlateUtils.isValidPlate', () {
    test('accepts the classic 3 letters and 3-4 digits', () {
      expect(PlateUtils.isValidPlate('أبج', '123'), isTrue);
      expect(PlateUtils.isValidPlate('أبج', '1234'), isTrue);
    });

    test('accepts irregular plates: any count from 1 to the max', () {
      expect(PlateUtils.isValidPlate('دك', '12'), isTrue);
      expect(PlateUtils.isValidPlate('دكل', '1'), isTrue);
      expect(PlateUtils.isValidPlate('دكلصف', '1234567'), isTrue);
    });

    test('accepts repeated letters back to back', () {
      expect(PlateUtils.isValidPlate('ددك', '123'), isTrue);
    });

    test('accepts any Arabic letter, not only the 17 official ones', () {
      for (final letter in ['ت', 'ث', 'ح', 'خ', 'ذ', 'ز', 'ش', 'ض', 'ظ', 'غ']) {
        expect(
          PlateUtils.isValidPlate('$letter$letter$letter', '123'),
          isTrue,
          reason: letter,
        );
      }
    });

    test('accepts both alef maqsura and yaa', () {
      expect(PlateUtils.isValidPlate('ىيى', '123'), isTrue);
    });

    test('rejects empty, over-long, non-Arabic and diacritics', () {
      expect(PlateUtils.isValidPlate('', '123'), isFalse);
      expect(PlateUtils.isValidPlate(null, '123'), isFalse);
      expect(PlateUtils.isValidPlate('دكلصفم', '123'), isFalse);
      expect(PlateUtils.isValidPlate('abc', '123'), isFalse);
      expect(PlateUtils.isValidPlate('د ك ل', '123'), isFalse);
      expect(PlateUtils.isValidPlate('دَكَل', '123'), isFalse);
    });

    test('rejects empty or over-long digits', () {
      expect(PlateUtils.isValidPlate('دكل', ''), isFalse);
      expect(PlateUtils.isValidPlate('دكل', null), isFalse);
      expect(PlateUtils.isValidPlate('دكل', '12345678'), isFalse);
      expect(PlateUtils.isValidPlate('دكل', '12a'), isFalse);
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

  group('PlateUtils.toArabicIndic', () {
    test('converts Latin digits for display on the plate', () {
      expect(PlateUtils.toArabicIndic('1234'), '١٢٣٤');
    });

    test('keeps already-Arabic-Indic digits', () {
      expect(PlateUtils.toArabicIndic('١٢٣'), '١٢٣');
    });
  });

  group('PlateUtils.normalizeDigitsInput', () {
    test('converts typed Latin digits to Arabic-Indic', () {
      expect(PlateUtils.normalizeDigitsInput('4821'), '٤٨٢١');
    });

    test('drops non-digits', () {
      expect(PlateUtils.normalizeDigitsInput('12أ3'), '١٢٣');
    });

    test('caps the length at maxDigits', () {
      expect(PlateUtils.normalizeDigitsInput('123456789'), '١٢٣٤٥٦٧');
    });
  });
}
