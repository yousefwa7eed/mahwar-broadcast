import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mahwar/core/auth/change_password_error.dart';

void main() {
  test('ChangePasswordNoEmailException → noEmail', () {
    expect(
      mapChangePasswordError(const ChangePasswordNoEmailException()),
      ChangePasswordError.noEmail,
    );
  });

  test('invalid_credentials (كلمة المرور الحالية خاطئة) → currentIncorrect', () {
    expect(
      mapChangePasswordError(
        const AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
      ),
      ChangePasswordError.currentIncorrect,
    );
  });

  test('same_password → sameAsCurrent', () {
    expect(
      mapChangePasswordError(
        const AuthApiException(
          'New password should be different',
          statusCode: '422',
          code: 'same_password',
        ),
      ),
      ChangePasswordError.sameAsCurrent,
    );
  });

  test('weak_password → weak', () {
    expect(
      mapChangePasswordError(
        const AuthApiException(
          'Password is too weak',
          statusCode: '422',
          code: 'weak_password',
        ),
      ),
      ChangePasswordError.weak,
    );
  });

  test('reauthentication_needed → reauthenticationRequired', () {
    expect(
      mapChangePasswordError(
        const AuthApiException(
          'Reauthentication required',
          statusCode: '422',
          code: 'reauthentication_needed',
        ),
      ),
      ChangePasswordError.reauthenticationRequired,
    );
  });

  test('over_request_rate_limit (429) → rateLimited لا currentIncorrect', () {
    expect(
      mapChangePasswordError(
        const AuthApiException(
          'Too many requests',
          statusCode: '429',
          code: 'over_request_rate_limit',
        ),
      ),
      ChangePasswordError.rateLimited,
    );
  });

  test('رد 429 بلا رمز → rateLimited (بالاعتماد على الحالة)', () {
    expect(
      mapChangePasswordError(
        const AuthApiException('Too many requests', statusCode: '429'),
      ),
      ChangePasswordError.rateLimited,
    );
  });

  test('فشل الشبكة (AuthRetryableFetchException) → unknown لا currentIncorrect', () {
    expect(
      mapChangePasswordError(
        AuthRetryableFetchException(message: 'network down'),
      ),
      ChangePasswordError.unknown,
    );
  });

  test('FieldError/غير معروف → unknown', () {
    expect(
      mapChangePasswordError(Exception('network down')),
      ChangePasswordError.unknown,
    );
    expect(
      mapChangePasswordError(
        const AuthApiException('boom', statusCode: '500'),
      ),
      ChangePasswordError.unknown,
    );
  });
}
