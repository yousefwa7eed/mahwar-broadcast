/// Client-side mapping for server-side signup error codes raised by the
/// Supabase `handle_new_user` trigger (e.g. "MISSING_WORKSHOP_NAME: ..." or
/// "`ACCOUNT_EXISTS_AS:<role>`"). Extracts the code token (the part before the
/// first `:`) and maps it to a clear, user-facing message via ARB. Unknown
/// codes/formats fall back to a generic message so raw English error
/// text never reaches the user.
library;

import 'role_gate.dart';
import '../../l10n/app_localizations.dart';

const List<String> _knownCodes = [
  'MISSING_WORKSHOP_NAME',
  'MISSING_NATIONAL_ID',
  'MISSING_ADDRESS',
  'MISSING_LATITUDE',
  'MISSING_LONGITUDE',
  'INVALID_LOCATION',
  'INVALID_LATITUDE',
  'INVALID_LONGITUDE',
  'MISSING_SPECIALIZATION',
  'MISSING_ROLE',
  'INVALID_ROLE',
  // Legacy duplicate codes — still raised by the live trigger and understood by
  // older app builds; kept for rollback safety until the role-locked migration
  // lands.
  'DUPLICATE_PHONE',
  'DUPLICATE_NATIONAL_ID',
  // New code raised after the role-locked migration: duplicate national ID,
  // without revealing the existing role and never echoing the submitted value.
  'NATIONAL_ID_EXISTS',
];

// New (role-locked) format raised by the migration: "ACCOUNT_EXISTS_AS:<role>",
// where <role> is car_owner | provider. Exposes only the existing account's
// role. Matches the bare code and GoTrue-prefixed forms.
final RegExp _accountExistsPattern = RegExp(r'ACCOUNT_EXISTS_AS:([A-Za-z_]+)');

String mapSignupError(String rawMessage, AppLocalizations? l10n) {
  final message = rawMessage.trim();
  if (message.isEmpty) return _generic(l10n);

  // New format takes precedence: "ACCOUNT_EXISTS_AS:<role>".
  final conflict = _accountExistsPattern.firstMatch(message);
  if (conflict != null) {
    return _accountExistsMessage(conflict.group(1), l10n);
  }

  // The trigger raises "CODE: message", so the code is the token before the
  // first colon.
  final colonIndex = message.indexOf(':');
  final leadingToken = colonIndex == -1
      ? message
      : message.substring(0, colonIndex).trim();
  final direct = _messageForCode(leadingToken, l10n);
  if (direct != null) return direct;

  // GoTrue may prefix the raw message (e.g. "Database error saving new user:
  // MISSING_...: ..."). As a fallback, scan the message for any known code.
  for (final code in _knownCodes) {
    if (message.contains(code)) {
      final mapped = _messageForCode(code, l10n);
      if (mapped != null) return mapped;
    }
  }

  // Postgres unique violation (one of the canonical phone/national-id indexes)
  // surfaced by GoTrue with the constraint message or the 23505 code.
  if (_isUniqueViolation(message)) {
    return l10n?.signupUniqueViolation ?? 'رقم الهاتف أو الرقم القومي مسجّل بالفعل';
  }

  return _generic(l10n);
}

String? _messageForCode(String code, AppLocalizations? l10n) {
  switch (code) {
    case 'MISSING_WORKSHOP_NAME':
      return l10n?.signupMissingWorkshopName ?? 'من فضلك أدخل اسم الورشة';
    case 'MISSING_NATIONAL_ID':
      return l10n?.signupMissingNationalId ?? 'من فضلك أدخل الرقم القومي';
    case 'MISSING_ADDRESS':
      return l10n?.signupMissingAddress ?? 'من فضلك أدخل العنوان';
    case 'MISSING_LATITUDE':
    case 'MISSING_LONGITUDE':
    case 'INVALID_LOCATION':
    case 'INVALID_LATITUDE':
    case 'INVALID_LONGITUDE':
      return l10n?.signupMissingLocation ?? 'من فضلك حدد موقعك على الخريطة';
    case 'MISSING_SPECIALIZATION':
      return l10n?.signupMissingSpecialization ?? 'من فضلك اختر تخصص واحد على الأقل';
    case 'MISSING_ROLE':
    case 'INVALID_ROLE':
      return l10n?.signupInvalidRole ?? 'حدث خطأ في نوع الحساب، حاول التسجيل مرة أخرى';
    case 'DUPLICATE_PHONE':
      return l10n?.signupDuplicatePhone ?? 'رقم الهاتف مسجّل بالفعل';
    case 'DUPLICATE_NATIONAL_ID':
    case 'NATIONAL_ID_EXISTS':
      return l10n?.signupDuplicateNationalId ?? 'الرقم القومي مسجّل بالفعل';
    default:
      return null;
  }
}

/// يكتشف انتهاكات قيد التفرّد من Postgres/GoTrue (رمز 23505 أو نصوص
/// "duplicate key" / "already registered" / "already exists") لرسمها كرسالة
/// تكرار واضحة بدلًا من الخطأ العام.
bool _isUniqueViolation(String message) {
  final lower = message.toLowerCase();
  return lower.contains('23505') ||
      lower.contains('duplicate key') ||
      lower.contains('already registered') ||
      lower.contains('already exists');
}

String _accountExistsMessage(String? rawRole, AppLocalizations? l10n) {
  final role = AppRole.tryParse(rawRole);
  if (role == AppRole.provider) {
    return l10n?.signupAccountExistsProvider ??
        'رقم الهاتف أو الرقم القومي مسجّل بالفعل في حساب مزوّد. يرجى تسجيل الدخول من صفحة تسجيل دخول المزوّد.';
  }
  if (role == AppRole.carOwner) {
    return l10n?.signupAccountExistsCustomer ??
        'رقم الهاتف أو الرقم القومي مسجّل بالفعل في حساب عميل. يرجى تسجيل الدخول من صفحة تسجيل دخول العميل.';
  }
  return l10n?.signupAccountExistsUnknown ??
      'رقم الهاتف أو الرقم القومي مسجّل بالفعل في حساب آخر. يرجى تسجيل الدخول بالحساب الموجود.';
}

String _generic(AppLocalizations? l10n) =>
    l10n?.signupGenericError ?? 'حدث خطأ أثناء إنشاء الحساب، حاول مرة أخرى';
