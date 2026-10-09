import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/auth/national_id_utils.dart';

void main() {
  group('NationalIdUtils.isValid — valid IDs', () {
    test('accepts a century-2 (1900s) ID', () {
      expect(NationalIdUtils.isValid('29901011234567'), isTrue);
    });

    test('accepts a century-3 (2000s) ID', () {
      expect(NationalIdUtils.isValid('30707071202296'), isTrue);
    });

    test('accepts Arabic-Indic digits typed as numbers', () {
      expect(NationalIdUtils.isValid('٣٠٧٠٧٠٧١٢٠٢٢٩٦'), isTrue);
    });

    test('accepts Extended Arabic-Indic digits', () {
      expect(NationalIdUtils.isValid('۳۰۷۰۷۰۷۱۲۰۲۲۹۶'), isTrue);
    });

    test('accepts surrounding whitespace', () {
      expect(NationalIdUtils.isValid('  30707071202296 '), isTrue);
    });
  });

  group('NationalIdUtils.isValid — invalid IDs', () {
    test('rejects null and empty', () {
      expect(NationalIdUtils.isValid(null), isFalse);
      expect(NationalIdUtils.isValid(''), isFalse);
      expect(NationalIdUtils.isValid('   '), isFalse);
    });

    test('rejects wrong length', () {
      expect(NationalIdUtils.isValid('3070707120229'), isFalse);
      expect(NationalIdUtils.isValid('307070712022960'), isFalse);
    });

    test('rejects century digit other than 2/3', () {
      expect(NationalIdUtils.isValid('40707071202296'), isFalse);
      expect(NationalIdUtils.isValid('10707071202296'), isFalse);
    });

    test('rejects impossible calendar dates', () {
      expect(NationalIdUtils.isValid('30102311234567'), isFalse); // Feb 31
      expect(NationalIdUtils.isValid('30113011234567'), isFalse); // month 13
      expect(NationalIdUtils.isValid('30100111234567'), isFalse); // month 00
      expect(NationalIdUtils.isValid('30110001123456'), isFalse); // day 00
    });

    test('rejects a future birth date', () {
      expect(NationalIdUtils.isValid('35001011234567'), isFalse); // year 2050
    });

    test('rejects unknown governorate codes', () {
      expect(NationalIdUtils.isValid('30707079912345'), isFalse); // gov 99
      expect(NationalIdUtils.isValid('30707070012345'), isFalse); // gov 00
      expect(NationalIdUtils.isValid('30707070512345'), isFalse); // gov 05
    });

    test('rejects a 14-digit string birth date 29 Feb on a non-leap year', () {
      // 299910... -> 1999-02-29 does not exist.
      expect(NationalIdUtils.isValid('29902291234567'), isFalse);
    });

    test('accepts 29 Feb on a leap year (year 2000)', () {
      expect(NationalIdUtils.isValid('30002291234567'), isTrue);
    });

    test('rejects non-digit characters', () {
      expect(NationalIdUtils.isValid('3070707120A296'), isFalse);
    });
  });

  group('NationalIdUtils.normalize', () {
    test('folds Arabic-Indic and Extended Arabic-Indic digits', () {
      expect(NationalIdUtils.normalize('٣٠٧٠٧٠٧١٢٠٢٢٩٦'), '30707071202296');
      expect(NationalIdUtils.normalize('۳۰۷۰۷۰۷۱۲۰۲۲۹۶'), '30707071202296');
      expect(NationalIdUtils.normalize('30707٠71202296'), '30707071202296');
    });

    test('trims surrounding whitespace', () {
      expect(NationalIdUtils.normalize(' 30707071202296 '), '30707071202296');
    });

    test('leaves already-Latin digits unchanged', () {
      expect(NationalIdUtils.normalize('30707071202296'), '30707071202296');
    });
  });
}