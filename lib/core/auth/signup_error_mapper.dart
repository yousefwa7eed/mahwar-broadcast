/// Client-side mapping for server-side signup error codes raised by the
/// Supabase `handle_new_user` trigger (e.g. "MISSING_WORKSHOP_NAME: ..." or
/// "`ACCOUNT_EXISTS_AS:<role>`"). Extracts the code token (the part before the
/// first `:`) and maps it to a clear Arabic, user-facing message. Unknown
/// codes/formats fall back to a generic Arabic message so raw English error
/// text never reaches the user.
library;

import 'role_gate.dart';

const String _signupGenericError = 'حدث خطأ أثناء إنشاء الحساب، حاول مرة أخرى';

const Map<String, String> _signupErrorMessages = {
  'MISSING_WORKSHOP_NAME': 'من فضلك أدخل اسم الورشة',
  'MISSING_NATIONAL_ID': 'من فضلك أدخل الرقم القومي',
  'MISSING_ADDRESS': 'من فضلك أدخل العنوان',
  'MISSING_LATITUDE': 'من فضلك حدد موقعك على الخريطة',
  'MISSING_LONGITUDE': 'من فضلك حدد موقعك على الخريطة',
  'INVALID_LOCATION': 'من فضلك حدد موقعك على الخريطة',
  'INVALID_LATITUDE': 'من فضلك حدد موقعك على الخريطة',
  'INVALID_LONGITUDE': 'من فضلك حدد موقعك على الخريطة',
  'MISSING_SPECIALIZATION': 'من فضلك اختر تخصص واحد على الأقل',
  'MISSING_ROLE': 'حدث خطأ في نوع الحساب، حاول التسجيل مرة أخرى',
  'INVALID_ROLE': 'حدث خطأ في نوع الحساب، حاول التسجيل مرة أخرى',
  // Legacy duplicate codes — kept while the role-locked migration is on hold.
  'DUPLICATE_PHONE': 'رقم الهاتف مسجّل بالفعل',
  'DUPLICATE_NATIONAL_ID': 'الرقم القومي مسجّل بالفعل',
};

// New (role-locked) format raised by the migration: "ACCOUNT_EXISTS_AS:<role>",
// where <role> is car_owner | provider. Exposes only the existing account's
// role. Matches the bare code and GoTrue-prefixed forms.
final RegExp _accountExistsPattern = RegExp(r'ACCOUNT_EXISTS_AS:([A-Za-z_]+)');

const String _accountExistsCustomer =
    'رقم الهاتف أو الرقم القومي مسجّل بالفعل في حساب عميل. يرجى تسجيل الدخول من صفحة تسجيل دخول العميل.';
const String _accountExistsProvider =
    'رقم الهاتف أو الرقم القومي مسجّل بالفعل في حساب مزوّد. يرجى تسجيل الدخول من صفحة تسجيل دخول المزوّد.';
const String _accountExistsUnknown =
    'رقم الهاتف أو الرقم القومي مسجّل بالفعل في حساب آخر. يرجى تسجيل الدخول بالحساب الموجود.';

String mapSignupError(String rawMessage) {
  final message = rawMessage.trim();
  if (message.isEmpty) return _signupGenericError;

  // New format takes precedence: "ACCOUNT_EXISTS_AS:<role>".
  final conflict = _accountExistsPattern.firstMatch(message);
  if (conflict != null) {
    return _accountExistsMessage(conflict.group(1));
  }

  // The trigger raises "CODE: message", so the code is the token before the
  // first colon.
  final colonIndex = message.indexOf(':');
  final leadingToken = colonIndex == -1
      ? message
      : message.substring(0, colonIndex).trim();
  final direct = _signupErrorMessages[leadingToken];
  if (direct != null) return direct;

  // GoTrue may prefix the raw message (e.g. "Database error saving new user:
  // MISSING_...: ..."). As a fallback, scan the message for any known code.
  for (final entry in _signupErrorMessages.entries) {
    if (message.contains(entry.key)) return entry.value;
  }

  return _signupGenericError;
}

String _accountExistsMessage(String? rawRole) {
  final role = AppRole.tryParse(rawRole);
  if (role == AppRole.provider) return _accountExistsProvider;
  if (role == AppRole.carOwner) return _accountExistsCustomer;
  return _accountExistsUnknown;
}