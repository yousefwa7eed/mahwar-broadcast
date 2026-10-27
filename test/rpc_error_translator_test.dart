import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/errors/rpc_error_translator.dart';
import 'package:mahwar/l10n/app_localizations_en.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException _pg(String message, {String? code}) =>
    PostgrestException(message: message, code: code);

void main() {
  group('RpcErrorTranslator — custom Postgres raise codes (P0001)', () {
    test('maps a known custom code from the message', () {
      final error = _pg('PROVIDER_UNAVAILABLE', code: 'P0001');
      expect(
        RpcErrorTranslator.translate(error, null),
        contains('لم يعد هذا المزوّد متاحاً'),
      );
      expect(
        RpcErrorTranslator.translate(error, AppLocalizationsEn()),
        contains('no longer available'),
      );
    });

    test('maps PHONE_NOT_VERIFIED in both languages', () {
      final error = _pg('PHONE_NOT_VERIFIED', code: 'P0001');
      expect(
        RpcErrorTranslator.translate(error, null),
        contains('تأكيد رقم هاتفك'),
      );
      expect(
        RpcErrorTranslator.translate(error, AppLocalizationsEn()),
        contains('verify your phone number'),
      );
    });

    test('maps PHONE_CHANGE_REQUIRES_OTP in both languages', () {
      final error = _pg('PHONE_CHANGE_REQUIRES_OTP', code: 'P0001');
      expect(
        RpcErrorTranslator.translate(error, null),
        contains('لتغيير رقم الهاتف'),
      );
      expect(
        RpcErrorTranslator.translate(error, AppLocalizationsEn()),
        contains('Changing your phone number'),
      );
    });

    test('maps OWNER_NATIONAL_ID_MISSING in both languages', () {
      final error = _pg('OWNER_NATIONAL_ID_MISSING', code: 'P0001');
      expect(
        RpcErrorTranslator.translate(error, null),
        contains('رقم قومي صحيح'),
      );
      expect(
        RpcErrorTranslator.translate(error, AppLocalizationsEn()),
        contains('national ID is required'),
      );
    });
  });

  group('RpcErrorTranslator — Postgrest codes', () {
    test('23505 maps to the pending-request message', () {
      final error = _pg(
        'duplicate key value violates unique constraint',
        code: '23505',
      );
      expect(
        RpcErrorTranslator.translate(error, null),
        contains('طلب قيد الانتظار بالفعل'),
      );
      expect(
        RpcErrorTranslator.translate(error, AppLocalizationsEn()),
        contains('already have a pending request'),
      );
    });

    test('an unmapped Postgrest code falls back to the raw message code', () {
      // P0001 is not in our table, but the message is a known custom code.
      final error = _pg('NOT_AUTHENTICATED', code: 'P0001');
      expect(
        RpcErrorTranslator.translate(error, null),
        contains('انتهت الجلسة'),
      );
    });
  });

  group('RpcErrorTranslator — vehicle codes', () {
    test('maps VEHICLE_NOT_FOUND in both languages', () {
      final error = _pg('VEHICLE_NOT_FOUND', code: 'P0001');
      expect(
        RpcErrorTranslator.translate(error, null),
        contains('لم يتم العثور على السيارة'),
      );
      expect(
        RpcErrorTranslator.translate(error, AppLocalizationsEn()),
        contains('Pick another car'),
      );
    });

    test('maps catalog validation codes instead of the generic message', () {
      for (final code in [
        'VEHICLE_TRIM_NOT_FOUND',
        'INVALID_MODEL_YEAR',
        'VEHICLE_COLOR_NOT_FOUND',
        'INVALID_PLATE',
      ]) {
        final translated = RpcErrorTranslator.translate(
          _pg(code, code: 'P0001'),
          null,
        );
        expect(translated, isNot('حدث خطأ في الاتصال، حاول مرة أخرى.'));
      }
    });
  });

  group('RpcErrorTranslator — unknown errors', () {
    test('returns a generic message per language', () {
      expect(
        RpcErrorTranslator.translate(Exception('boom'), null),
        'حدث خطأ في الاتصال، حاول مرة أخرى.',
      );
      expect(
        RpcErrorTranslator.translate(Exception('boom'), AppLocalizationsEn()),
        'Something went wrong. Please try again.',
      );
    });

    test('extracts a custom code from a plain string error', () {
      expect(
        RpcErrorTranslator.translate(
          'PostgrestException: TOO_MANY_ATTACHMENTS',
          null,
        ),
        contains('الحد الأقصى 10 صور'),
      );
    });
  });
}
