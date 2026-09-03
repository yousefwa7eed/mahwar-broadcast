/// Utilities for normalizing Egyptian phone numbers consistently across
/// signup and login so the stored format always matches what login searches for.
class PhoneUtils {
  PhoneUtils._();

  /// Strips separators (spaces, dashes, parentheses) and folds country codes
  /// (+20 / 0020) into a leading 0, e.g.:
  ///  +20 101 234 5678 -> 01012345678
  ///  00201012345678    -> 01012345678
  ///  01012345678       -> 01012345678
  static String normalize(String input) {
    var phone = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');
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