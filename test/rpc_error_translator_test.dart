import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/errors/rpc_error_translator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException _pg(String message, {String? code}) =>
    PostgrestException(message: message, code: code);

void main() {
  group('RpcErrorTranslator — custom Postgres raise codes (P0001)', () {
    test('maps a known custom code from the message', () {
      final error = _pg('PROVIDER_UNAVAILABLE', code: 'P0001');
      expect(
        RpcErrorTranslator.translate(error),
        contains('لم يعد هذا المزوّد متاحاً'),
      );
      expect(
        RpcErrorTranslator.translate(error, arabic: false),
        contains('no longer available'),
      );
    });

    test('maps OWNER_NATIONAL_ID_MISSING in both languages', () {
      final error = _pg('OWNER_NATIONAL_ID_MISSING', code: 'P0001');
      expect(
        RpcErrorTranslator.translate(error),
        contains('رقم قومي صحيح'),
      );
      expect(
        RpcErrorTranslator.translate(error, arabic: false),
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
        RpcErrorTranslator.translate(error),
        contains('طلب قيد الانتظار بالفعل'),
      );
      expect(
        RpcErrorTranslator.translate(error, arabic: false),
        contains('already have a pending request'),
      );
    });

    test('an unmapped Postgrest code falls back to the raw message code', () {
      // P0001 is not in our table, but the message is a known custom code.
      final error = _pg('NOT_AUTHENTICATED', code: 'P0001');
      expect(
        RpcErrorTranslator.translate(error),
        contains('انتهت الجلسة'),
      );
    });
  });

  group('RpcErrorTranslator — unknown errors', () {
    test('returns a generic message per language', () {
      expect(
        RpcErrorTranslator.translate(Exception('boom')),
        'حدث خطأ في الاتصال، حاول مرة أخرى.',
      );
      expect(
        RpcErrorTranslator.translate(Exception('boom'), arabic: false),
        'Something went wrong. Please try again.',
      );
    });

    test('extracts a custom code from a plain string error', () {
      expect(
        RpcErrorTranslator.translate('PostgrestException: TOO_MANY_ATTACHMENTS'),
        contains('الحد الأقصى 10 صور'),
      );
    });
  });
}
