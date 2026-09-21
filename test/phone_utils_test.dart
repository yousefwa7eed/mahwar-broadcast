import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/auth/phone_utils.dart';

void main() {
  group('PhoneUtils.normalize', () {
    test('keeps a plain Egyptian number unchanged', () {
      expect(PhoneUtils.normalize('01554775966'), '01554775966');
    });

    test('strips spaces and dashes', () {
      expect(PhoneUtils.normalize('0155 477 5966'), '01554775966');
      expect(PhoneUtils.normalize('0155-477-5966'), '01554775966');
    });

    test('folds +20 and 0020 into a leading 0', () {
      expect(PhoneUtils.normalize('+201554775966'), '01554775966');
      expect(PhoneUtils.normalize('00201554775966'), '01554775966');
      expect(PhoneUtils.normalize('+20 155 477 5966'), '01554775966');
    });

    test('folds Arabic-Indic digits (٠-٩) into Latin', () {
      expect(PhoneUtils.normalize('٠١٥٥٤٧٧٥٩٦٦'), '01554775966');
      expect(PhoneUtils.normalize('٠١٥٥ ٤٧٧ ٥٩٦٦'), '01554775966');
    });

    test('folds Eastern Arabic-Indic digits (۰-۹) into Latin', () {
      expect(PhoneUtils.normalize('۰۱۵۵۴۷۷۵۹۶۶'), '01554775966');
    });

    test('folds a mix of Latin and Arabic digits', () {
      expect(PhoneUtils.normalize('0155٤٧٧٥٩٦٦'), '01554775966');
    });
  });

  group('PhoneUtils.isValidEgyptianMobile', () {
    test('accepts valid Egyptian mobile numbers in Latin digits', () {
      expect(PhoneUtils.isValidEgyptianMobile('01554775966'), isTrue);
      expect(PhoneUtils.isValidEgyptianMobile('01012345678'), isTrue);
      expect(PhoneUtils.isValidEgyptianMobile('01112345678'), isTrue);
      expect(PhoneUtils.isValidEgyptianMobile('01212345678'), isTrue);
    });

    test('accepts the same numbers typed in Arabic-Indic digits', () {
      expect(PhoneUtils.isValidEgyptianMobile('٠١٥٥٤٧٧٥٩٦٦'), isTrue);
    });

    test('rejects invalid numbers', () {
      expect(PhoneUtils.isValidEgyptianMobile('0212345678'), isFalse);
      expect(PhoneUtils.isValidEgyptianMobile('0101234567'), isFalse);
    });
  });
}