/// Shared Egyptian national ID validation.
///
/// The exact same rules are enforced server-side by the Postgres function
/// `public.is_valid_egyptian_national_id(text)` (migration
/// `20261009010000_national_id_validation.sql`). Keep the two in sync:
///   * Fold Arabic-Indic (٠-٩) and Extended Arabic-Indic (۰-۹) digits to Latin.
///   * Exactly 14 digits.
///   * First digit 2 (born 1900-1999) or 3 (born 2000-2099).
///   * Digits 2-7 are YYMMDD and must form a real calendar date.
///   * That birth date must not be in the future.
///   * Digits 8-9 are a governorate code in
///     {01-04, 11-19, 21-29, 31-35, 88}.
///   * No checksum is invented.
class NationalIdUtils {
  NationalIdUtils._();

  static const Map<int, int> _arabicDigitsToLatin = {
    0x0660: 0x30, 0x0661: 0x31, 0x0662: 0x32, 0x0663: 0x33,
    0x0664: 0x34, 0x0665: 0x35, 0x0666: 0x36, 0x0667: 0x37,
    0x0668: 0x38, 0x0669: 0x39,
    0x06F0: 0x30, 0x06F1: 0x31, 0x06F2: 0x32, 0x06F3: 0x33,
    0x06F4: 0x34, 0x06F5: 0x35, 0x06F6: 0x36, 0x06F7: 0x37,
    0x06F8: 0x38, 0x06F9: 0x39,
  };

  static const int _century1900 = 1900;
  static const int _century2000 = 2000;

  static const Set<int> _governorateCodes = {
    1, 2, 3, 4,
    11, 12, 13, 14, 15, 16, 17, 18, 19,
    21, 22, 23, 24, 25, 26, 27, 28, 29,
    31, 32, 33, 34, 35, 88,
  };

  /// Folds Arabic-Indic / Extended Arabic-Indic digits into Latin and trims.
  static String normalize(String input) => String.fromCharCodes(
        input.trim().runes.map((r) => _arabicDigitsToLatin[r] ?? r),
      );

  /// Returns true when [input] is a valid Egyptian national ID.
  ///
  /// Empty / null values are invalid here (callers that treat the ID as
  /// optional must check for empty before calling).
  static bool isValid(String? input) {
    if (input == null) return false;
    final id = normalize(input);
    if (!RegExp(r'^[0-9]{14}$').hasMatch(id)) return false;

    final century = id[0];
    if (century != '2' && century != '3') return false;

    final year = (century == '2' ? _century1900 : _century2000) +
        int.parse(id.substring(1, 3));
    final month = int.parse(id.substring(3, 5));
    final day = int.parse(id.substring(5, 7));

    final birthDate = _realDate(year, month, day);
    if (birthDate == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (birthDate.isAfter(today)) return false;

    final governorate = int.parse(id.substring(7, 9));
    return _governorateCodes.contains(governorate);
  }

  /// Builds a [DateTime] only when (y, m, d) is a real calendar date; returns
  /// null for impossible dates such as 2001-02-31 or month 13.
  static DateTime? _realDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }
}
