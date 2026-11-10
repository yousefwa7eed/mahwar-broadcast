/// قواعد وأدوات لوحة السيارة المصرية.
///
/// اللوحات ليست دائمًا 3 حروف + 3 أو 4 أرقام: هناك لوحات شاذة بحرفين أو بخمسة،
/// وبحرف مكرر («ددك»)، وبعدد أرقام مختلف. لذلك نسمح بأي حرف عربي وبالتكرار،
/// ونخزّن الأرقام لاتينية بينما نعرضها عربية-هندية على اللوحة.
class PlateUtils {
  PlateUtils._();

  /// الأبجدية العربية كاملة — لا نحبس المستخدم على الحروف الرسمية السبعة عشر.
  static const List<String> letters = [
    'أ',
    'ب',
    'ت',
    'ث',
    'ج',
    'ح',
    'خ',
    'د',
    'ذ',
    'ر',
    'ز',
    'س',
    'ش',
    'ص',
    'ض',
    'ط',
    'ظ',
    'ع',
    'غ',
    'ف',
    'ق',
    'ك',
    'ل',
    'م',
    'ن',
    'ه',
    'و',
    'ى',
    'ي',
  ];

  static const int maxLetters = 5;
  static const int maxDigits = 7;

  static const String _arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  static const String _extendedArabicIndic = '۰۱۲۳۴۵۶۷۸۹';

  /// الحروف العربية فقط (U+0621..U+064A) بلا تشكيل ولا أرقام، والتكرار مسموح.
  static final RegExp _lettersPattern = RegExp(r'^[\u0621-\u064A]{1,5}$');
  static final RegExp _digitsPattern = RegExp(r'^\d{1,7}$');

  static bool isValidLetters(String? value) =>
      value != null && _lettersPattern.hasMatch(value);

  static bool isValidDigits(String? value) =>
      value != null && _digitsPattern.hasMatch(value);

  static bool isValidPlate(String? letters, String? digits) =>
      isValidLetters(letters) && isValidDigits(digits);

  static String format(String lettersPart, String digitsPart) =>
      '$lettersPart $digitsPart';

  /// تحويل الأرقام العربية-الهندية إلى لاتينية قبل التحقق أو الحفظ.
  static String toWesternDigits(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      final index = _arabicIndic.indexOf(char);
      if (index >= 0) {
        buffer.write(index);
        continue;
      }
      final extendedIndex = _extendedArabicIndic.indexOf(char);
      if (extendedIndex >= 0) {
        buffer.write(extendedIndex);
        continue;
      }
      buffer.write(char);
    }
    return buffer.toString();
  }

  /// تحويل الأرقام اللاتينية إلى عربية-هندية للعرض على اللوحة.
  static String toArabicIndic(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      final digit = int.tryParse(char);
      buffer.write(digit != null ? _arabicIndic[digit] : char);
    }
    return buffer.toString();
  }

  /// تنقية إدخال الأرقام على اللوحة: أرقام فقط، عربية-هندية، بحد [maxDigits].
  static String normalizeDigitsInput(String value) {
    final western = toWesternDigits(value);
    final buffer = StringBuffer();
    for (final rune in western.runes) {
      final code = rune;
      if (code < 0x30 || code > 0x39) continue;
      buffer.write(_arabicIndic[code - 0x30]);
      if (buffer.length == maxDigits) break;
    }
    return buffer.toString();
  }
}
