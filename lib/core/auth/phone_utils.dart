/// Utilities for normalizing Egyptian phone numbers consistently across
/// signup and login so the stored format always matches what login searches for.
class PhoneUtils {
  PhoneUtils._();

  static const Map<int, int> _arabicDigitsToLatin = {
    0x0660: 0x30, 0x0661: 0x31, 0x0662: 0x32, 0x0663: 0x33,
    0x0664: 0x34, 0x0665: 0x35, 0x0666: 0x36, 0x0667: 0x37,
    0x0668: 0x38, 0x0669: 0x39,
    0x06F0: 0x30, 0x06F1: 0x31, 0x06F2: 0x32, 0x06F3: 0x33,
    0x06F4: 0x34, 0x06F5: 0x35, 0x06F6: 0x36, 0x06F7: 0x37,
    0x06F8: 0x38, 0x06F9: 0x39,
  };

  static String _toLatinDigits(String input) => String.fromCharCodes(
        input.runes.map((r) => _arabicDigitsToLatin[r] ?? r),
      );

  /// Strips separators (spaces, dashes, parentheses), folds Arabic-Indic digits
  /// (٠-٩ / ۰-۹) into Latin (0-9), and folds country codes (+20 / 0020) into a
  /// leading 0, e.g.:
  ///  +20 101 234 5678 -> 01012345678
  ///  00201012345678    -> 01012345678
  ///  ٠١٥٥ ٤٧٧ ٥٩٦٦    -> 01554775966
  ///  01012345678       -> 01012345678
  static String normalize(String input) {
    var phone = _toLatinDigits(input.replaceAll(RegExp(r'[\s\-\(\)]'), ''));
    if (phone.startsWith('+20')) {
      phone = '0${phone.substring(3)}';
    } else if (phone.startsWith('0020')) {
      phone = '0${phone.substring(4)}';
    }
    return phone;
  }

  /// Returns true when the normalized value is a valid Egyptian mobile number
  /// (11 digits starting with 010/011/012/015).
  static bool isValidEgyptianMobile(String input) {
    final phone = normalize(input);
    return RegExp(r'^01[0125][0-9]{8}$').hasMatch(phone);
  }
}