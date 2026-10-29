import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mahwar/core/auth/auth_cubit.dart' hide AuthState;
import 'package:mahwar/core/auth/phone_availability_params.dart';

import 'fakes/fake_auth_service.dart';

void main() {
  group('buildIsPhoneAvailableParams', () {
    test('contains exactly the server-required key p_phone', () {
      final params = buildIsPhoneAvailableParams(phone: '01123456789');

      expect(params.keys.toSet(), {'p_phone'});
      expect(params['p_phone'], '01123456789');
    });
  });

  group('AuthCubit.isPhoneAvailable', () {
    test('متاح: يعيد true ويمرّر الرقم المحلي كما هو', () async {
      final fake = FakeAuthService();
      final cubit = AuthCubit(service: fake);
      addTearDown(cubit.close);

      expect(await cubit.isPhoneAvailable('01123456789'), isTrue);
      expect(fake.isPhoneAvailableCount, 1);
      expect(fake.lastIsPhoneAvailablePhone, '01123456789');
    });

    test('غير متاح: يعيد false كما قرّر الخادم', () async {
      final fake = FakeAuthService()
        ..phoneAvailability['01123456789'] = false;
      final cubit = AuthCubit(service: fake);
      addTearDown(cubit.close);

      expect(await cubit.isPhoneAvailable('01123456789'), isFalse);
    });

    test('أخطاء الخادم تُعاد كما هي ولا تُفسَّر كـ«متاح»', () async {
      final errors = <Object>[
        const PostgrestException(
          message: 'TOO_MANY_LOOKUPS: slow down',
          code: 'P0001',
        ),
        const PostgrestException(
          message: 'INVALID_PHONE: bad number',
          code: 'P0001',
        ),
        const PostgrestException(
          message: 'NOT_AUTHENTICATED: no session',
          code: 'P0001',
        ),
      ];

      for (final error in errors) {
        final fake = FakeAuthService()..isPhoneAvailableError = error;
        final cubit = AuthCubit(service: fake);
        addTearDown(cubit.close);

        await expectLater(
          cubit.isPhoneAvailable('01123456789'),
          throwsA(same(error)),
        );
        expect(fake.isPhoneAvailableCount, 1);
      }
    });
  });
}
