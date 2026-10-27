/// قواعد وأدوات لوحة السيارة المصرية: 3 حروف عربية + 3 أو 4 أرقام.
class PlateUtils {
  PlateUtils._();

  /// الحروف المستخدمة في اللوحات المصرية، مرتبة أبجديًا.
  static const List<String> letters = [
    'أ', 'ب', 'ج', 'د', 'ر', 'س', 'ص', 'ط',
    'ع', 'ق', 'ك', 'ل', 'م', 'ن', 'ه', 'و', 'ى',
  ];

  static final RegExp _digitsPattern = RegExp(r'^\d{3,4}$');

  static bool isValidLetters(String? value) =>
      value != null && letters.contains(value);

  static bool isValidDigits(String? value) =>
      value != null && _digitsPattern.hasMatch(value);

  static bool isValidPlate(String? letter1, String? letter2,
      String? letter3, String? digits) {
    return isValidLetters(letter1) &&
        isValidLetters(letter2) &&
        isValidLetters(letter3) &&
        isValidDigits(digits);
  }

  static String format(String lettersPart, String digitsPart) =>
      '$lettersPart $digitsPart';

  /// تحويل الأرقام العربية-الهندية إلى لاتينية قبل التحقق.
  static String toWesternDigits(String value) {
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const extendedArabicIndic = '۰۱۲۳۴۵۶۷۸۹';
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      final index = arabicIndic.indexOf(char);
      if (index >= 0) {
        buffer.write(index);
        continue;
      }
      final extendedIndex = extendedArabicIndic.indexOf(char);
      if (extendedIndex >= 0) {
        buffer.write(extendedIndex);
        continue;
      }
      buffer.write(char);
    }
    return buffer.toString();
  }
}
