import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mahwar/core/auth/auth_cubit.dart' hide AuthState;

import 'fakes/fake_auth_service.dart';

void main() {
  test('attachPhone يرسل مرة واحدة عند التكرار الفوري لنفس الرقم', () async {
    final fake = FakeAuthService();
    final cubit = AuthCubit(service: fake);

    await cubit.attachPhone('01000000000');
    await cubit.attachPhone('01000000000');
    await cubit.attachPhone('01000000000');

    expect(fake.attachCount, 1);
    expect(fake.attachedPhone, '01000000000');
  });

  test('attachPhone لرقم مختلف يتجاوز الحارس ويُرسل بشكل طبيعي', () async {
    final fake = FakeAuthService();
    final cubit = AuthCubit(service: fake);

    await cubit.attachPhone('01000000000');
    await cubit.attachPhone('01111111111');

    expect(fake.attachCount, 2);
    expect(fake.attachedPhone, '01111111111');
  });

  test('فشل attachPhone يُعاد له ويمكن إعادة المحاولة بعدها', () async {
    final fake = FakeAuthService()
      ..attachError = Exception('network down');
    final cubit = AuthCubit(service: fake);

    await expectLater(cubit.attachPhone('01000000000'), throwsException);
    expect(fake.attachCount, 1);

    fake.attachError = null;
    await cubit.attachPhone('01000000000');
    expect(fake.attachCount, 2);
    expect(fake.attachedPhone, '01000000000');
  });

  test('requestForgotPasswordOtp يمرر الرقم مباشرة للخدمة', () async {
    final fake = FakeAuthService()..confirmedPhones.add('01012345678');
    final cubit = AuthCubit(service: fake);

    await cubit.requestForgotPasswordOtp('01012345678');

    expect(fake.forgotOtpCount, 1);
    expect(fake.lastForgotOtpPhone, '01012345678');
  });

  test('verifyForgotPasswordOtp يمرر الرقم والكود للخدمة', () async {
    final fake = FakeAuthService();
    final cubit = AuthCubit(service: fake);

    await cubit.verifyForgotPasswordOtp(localPhone: '01012345678', otp: '123456');

    expect(fake.forgotVerifyCount, 1);
    expect(fake.lastForgotVerifiedPhone, '01012345678');
    expect(fake.verifiedForgotOtps, ['123456']);
  });

  test('resendForgotPasswordOtp يمرر الرقم مباشرة للخدمة', () async {
    final fake = FakeAuthService()..confirmedPhones.add('01012345678');
    final cubit = AuthCubit(service: fake);

    await cubit.resendForgotPasswordOtp('01012345678');

    expect(fake.forgotResendCount, 1);
    expect(fake.lastForgotResendPhone, '01012345678');
  });

  test('requestForgotPasswordOtp لرقم غير مسجّل يعيد خطأ user_not_found من الخدمة', () async {
    final fake = FakeAuthService(); // confirmedPhones فارغة
    final cubit = AuthCubit(service: fake);

    await expectLater(
      cubit.requestForgotPasswordOtp('01000000000'),
      throwsA(
        isA<AuthApiException>()
            .having((e) => e.code, 'code', 'user_not_found'),
      ),
    );
  });

  test('requestForgotPasswordOtp يعيد إرسال خطأ الشبكة من الخدمة كما هو', () async {
    final fake = FakeAuthService()..forgotOtpError = Exception('network down');
    final cubit = AuthCubit(service: fake);

    await expectLater(
      cubit.requestForgotPasswordOtp('01012345678'),
      throwsException,
    );
  });

  test('setNewPassword يضبط كلمة المرور ثم يخرج من الجلسة', () async {
    final fake = FakeAuthService()
      ..user = User(
        id: 'fake-user-id',
        appMetadata: const {},
        userMetadata: const {'role': 'car_owner'},
        aud: 'authenticated',
        createdAt: 'now',
        email: 'owner@example.com',
      );
    final cubit = AuthCubit(service: fake);
    expect(cubit.state, isA<AuthAuthenticated>());

    await cubit.setNewPassword('newpass123');

    expect(fake.setPasswordCount, 1);
    expect(fake.lastSetPassword, 'newpass123');
    expect(fake.user, isNull);
    expect(cubit.state, isA<AuthUnauthenticated>());
  });

  test('setNewPassword يفشل ينتشر الخطأ ولا يخرج من الجلسة', () async {
    final fake = FakeAuthService()
      ..user = User(
        id: 'fake-user-id',
        appMetadata: const {},
        userMetadata: const {'role': 'car_owner'},
        aud: 'authenticated',
        createdAt: 'now',
        email: 'owner@example.com',
      )
      ..setPasswordError = AuthApiException('weak password', code: 'weak');
    final cubit = AuthCubit(service: fake);

    await expectLater(cubit.setNewPassword('123'), throwsA(isA<AuthException>()));
    expect(fake.setPasswordCount, 1);
    expect(fake.user, isNotNull);
  });

  test('close يلغي الاشتراك في تدفق المصادقة (لا مستمعين معلّقين)', () async {
    final fake = FakeAuthService();
    final cubit = AuthCubit(service: fake);

    // الباني يشترك فورًا في onAuthStateChange.
    expect(fake.authStateController.hasListener, isTrue);

    await cubit.close();

    expect(fake.authStateController.hasListener, isFalse);
  });

  group('ensurePhoneVerified — بوابة توثيق الهاتف', () {
    User user() => User(
          id: 'fake-user-id',
          appMetadata: const {},
          userMetadata: const {'role': 'car_owner'},
          aud: 'authenticated',
          createdAt: 'now',
        );

    test('بلا جلسة يعيد true بلا سؤال الخادم', () async {
      final fake = FakeAuthService(); // user = null
      final cubit = AuthCubit(service: fake);

      expect(await cubit.ensurePhoneVerified(), isTrue);
      expect(fake.phoneVerifiedCount, 0);
    });

    test('جلسة غير موثّقة → false ويخزّن الناتج (سؤال واحد فقط)', () async {
      final fake = FakeAuthService()
        ..user = user()
        ..phoneVerified = false;
      final cubit = AuthCubit(service: fake);

      expect(await cubit.ensurePhoneVerified(), isFalse);
      expect(cubit.knownPhoneVerified, isFalse);
      expect(await cubit.ensurePhoneVerified(), isFalse);
      expect(fake.phoneVerifiedCount, 1);
    });

    test('جلسة موثّقة → true', () async {
      final fake = FakeAuthService()
        ..user = user()
        ..phoneVerified = true;
      final cubit = AuthCubit(service: fake);

      expect(await cubit.ensurePhoneVerified(), isTrue);
      expect(cubit.knownPhoneVerified, isTrue);
    });

    test('فشل الشبكة يفتح البوابة (fail-open) ولا يخزّن الناتج', () async {
      final fake = FakeAuthService()
        ..user = user()
        ..phoneVerifiedError = Exception('network down');
      final cubit = AuthCubit(service: fake);

      expect(await cubit.ensurePhoneVerified(), isTrue);
      expect(cubit.knownPhoneVerified, isNull);
      // لا تخزين → إعادة المحاولة تسأل الخادم مجددًا.
      await cubit.ensurePhoneVerified();
      expect(fake.phoneVerifiedCount, 2);
    });

    test('نجاح verifyPhoneOtp يضبط الحالة موثّقة فورًا', () async {
      final fake = FakeAuthService()
        ..user = user()
        ..phoneVerified = false;
      final cubit = AuthCubit(service: fake);

      expect(await cubit.ensurePhoneVerified(), isFalse);
      await cubit.verifyPhoneOtp(localPhone: '01012345678', otp: '123456');
      expect(cubit.knownPhoneVerified, isTrue);
    });

    test('حدث signedOut يصفّر حالة التوثيق المخزّنة', () async {
      final fake = FakeAuthService()
        ..user = user()
        ..phoneVerified = false;
      final cubit = AuthCubit(service: fake);
      addTearDown(cubit.close);

      expect(await cubit.ensurePhoneVerified(), isFalse);
      fake.authStateController.add(AuthState(AuthChangeEvent.signedOut, null));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.knownPhoneVerified, isNull);
    });
  });
}