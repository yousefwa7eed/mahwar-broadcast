import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mahwar/core/auth/auth_cubit.dart';
import 'package:mahwar/core/auth/otp_error_mapper.dart';
import 'package:mahwar/core/settings/app_settings_cubit.dart';
import 'package:mahwar/features/auth/otp_cooldown_store.dart';
import 'package:mahwar/features/auth/otp_screen.dart';
import 'package:mahwar/l10n/app_localizations.dart';

import 'fakes/fake_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OtpCooldownStore.now = DateTime.now;
    OtpCooldownStore.clear('01000000000');
    OtpCooldownStore.clear('01110000000');
    OtpCooldownStore.clear('01111111111');
    OtpCooldownStore.clear('01123456789');
  });

  tearDown(() {
    OtpCooldownStore.now = DateTime.now;
    OtpCooldownStore.clear('01000000000');
    OtpCooldownStore.clear('01110000000');
    OtpCooldownStore.clear('01111111111');
    OtpCooldownStore.clear('01123456789');
  });

  (Widget, GoRouter) buildApp(
    FakeAuthService service, {
    OtpMode mode = OtpMode.signup,
    String? phone,
    String? role,
  }) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => OtpScreen(
            mode: mode,
            phone: phone,
            role: role,
          ),
        ),
        GoRoute(
          path: '/home/owner',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('OWNER_HOME', key: Key('home_placeholder'))),
          ),
        ),
        GoRoute(
          path: '/home/provider',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('PROVIDER_HOME', key: Key('home_provider_placeholder'))),
          ),
        ),
        GoRoute(
          path: '/set-new-password',
          builder: (context, state) => const Scaffold(
            body: Center(
              child: Text(
                'SET_NEW_PASSWORD',
                key: Key('set_new_password_placeholder'),
              ),
            ),
          ),
        ),
      ],
    );

    final app = MultiBlocProvider(
      providers: [
        BlocProvider<AppSettingsCubit>(create: (_) => AppSettingsCubit()),
        BlocProvider<AuthCubit>(
          create: (_) => AuthCubit(service: service),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(useMaterial3: true),
      ),
    );
    return (app, router);
  }

  Finder otpHiddenField() => find.byKey(const ValueKey('otp_hidden_field'));

  String currentPath(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  testWidgets('وضع التسجيل يعرض عنوانًا ورقمًا مقنّعًا وعدّاد إعادة الإرسال',
      (tester) async {
    final fake = FakeAuthService();
    final (app, _) = buildApp(
      fake,
      phone: '01000000000',
      role: 'car_owner',
    );

    await tester.pumpWidget(app);

    expect(find.text('تأكيد رقم الهاتف'), findsWidgets);
    expect(
      find.text('أدخل رمز التحقق المكوّن من 6 أرقام الذي أُرسل إلى •••• ••• 0000'),
      findsOneWidget,
    );
    expect(find.textContaining('إعادة الإرسال بعد'), findsOneWidget);
    expect(find.text('إعادة إرسال الرمز'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('كود خاطئ يعرض رسالة خطأ ولا ينتقل للرئيسية', (tester) async {
    final fake = FakeAuthService();
    final (app, router) = buildApp(
      fake,
      phone: '01000000000',
      role: 'car_owner',
    );

    await tester.pumpWidget(app);
    await tester.enterText(otpHiddenField(), '000000');
    await tester.pump();
    await tester.pump();

    expect(
      find.text('الرمز غير صحيح أو منتهي الصلاحية. حاول مرة أخرى.'),
      findsOneWidget,
    );
    expect(fake.verifyCount, 1);
    expect(currentPath(router), '/');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('كود صحيح ينتقل للرئيسية ويزامن الرقم', (tester) async {
    final fake = FakeAuthService();
    final (app, router) = buildApp(
      fake,
      phone: '01000000000',
      role: 'car_owner',
    );

    await tester.pumpWidget(app);
    await tester.enterText(otpHiddenField(), '123456');
    await tester.pump();
    await tester.pump();

    expect(currentPath(router), '/home/owner');
    expect(fake.verifyCount, 1);
    expect(fake.lastVerifiedPhone, '01000000000');
    expect(fake.syncedPhone, '01000000000');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('العدّاد يستمر بعد مغادرة الشاشة والعودة إليها', (tester) async {
    final fake = FakeAuthService();
    const phone = '01110000000';
    OtpCooldownStore.start(phone);

    final (app, _) = buildApp(
      fake,
      phone: phone,
      role: 'car_owner',
    );

    await tester.pumpWidget(app);
    expect(find.textContaining('إعادة الإرسال بعد'), findsOneWidget);
    expect(find.text('إعادة إرسال الرمز'), findsNothing);

    // مغادرة الشاشة ثم العودة لنفس الرقم دون إعادة تعيين العدّاد.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app);
    expect(find.textContaining('إعادة الإرسال بعد'), findsOneWidget);
    expect(find.text('إعادة إرسال الرمز'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('بعد انتهاء المهلة تُعاد الإرسال ويعود العدّاد', (tester) async {
    var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
    OtpCooldownStore.now = () => fakeNow;
    const phone = '01111111111';
    OtpCooldownStore.start(phone);
    fakeNow = DateTime(2026, 1, 1, 12, 0, 1);

    final fake = FakeAuthService();
    final (app, _) = buildApp(
      fake,
      phone: phone,
      role: 'car_owner',
    );
    await tester.pumpWidget(app);
    expect(find.textContaining('إعادة الإرسال بعد'), findsOneWidget);

    fakeNow = DateTime(2026, 1, 1, 12, 1, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('إعادة إرسال الرمز'), findsOneWidget);

    await tester.ensureVisible(find.text('إعادة إرسال الرمز'));
    await tester.tap(find.text('إعادة إرسال الرمز'));
    await tester.pump();
    await tester.pump();

    expect(fake.resendCount, 1);
    expect(find.textContaining('إعادة الإرسال بعد'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('فشل إعادة الإرسال يعرض رسالة خطأ', (tester) async {
    var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
    OtpCooldownStore.now = () => fakeNow;
    const phone = '01111111111';
    OtpCooldownStore.start(phone);
    fakeNow = DateTime(2026, 1, 1, 12, 0, 1);

    final fake = FakeAuthService()
      ..resendError = AuthApiException(
        'sms error',
        statusCode: '422',
        code: 'sms_send_failed',
      );
    final (app, router) = buildApp(
      fake,
      phone: phone,
      role: 'car_owner',
    );
    await tester.pumpWidget(app);

    fakeNow = DateTime(2026, 1, 1, 12, 1, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('إعادة إرسال الرمز'), findsOneWidget);

    await tester.ensureVisible(find.text('إعادة إرسال الرمز'));
    await tester.tap(find.text('إعادة إرسال الرمز'));
    await tester.pump();
    await tester.pump();

    expect(fake.resendCount, 1);
    expect(find.text('تعذّر إرسال الرمز. حاول مرة أخرى لاحقاً.'), findsOneWidget);
    expect(currentPath(router), '/');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('استخدام رقم آخر: تحقق من رقم مصري صالح ثم العودة لإدخال الكود',
      (tester) async {
    final fake = FakeAuthService();
    final (app, router) = buildApp(
      fake,
      phone: '01000000000',
      role: 'car_owner',
    );

    await tester.pumpWidget(app);
    await tester.ensureVisible(find.text('استخدام رقم آخر'));
    await tester.tap(find.text('استخدام رقم آخر'));
    await tester.pump();

    expect(find.text('تغيير رقم الهاتف'), findsOneWidget);

    // رقم غير صالح.
    await tester.enterText(find.byType(TextField), '123');
    await tester.ensureVisible(find.text('إرسال الرمز'));
    await tester.tap(find.text('إرسال الرمز'));
    await tester.pump();
    expect(find.text('أدخل رقم هاتف مصري صحيح'), findsOneWidget);

    // رقم صالح يربط الرقم ويعود إلى شاشة الكود.
    await tester.enterText(find.byType(TextField), '01123456789');
    await tester.tap(find.text('إرسال الرمز'));
    await tester.pump();
    await tester.pump();

    expect(fake.attachCount, 1);
    expect(fake.attachedPhone, '01123456789');
    expect(
      find.text('أدخل رمز التحقق المكوّن من 6 أرقام الذي أُرسل إلى •••• ••• 6789'),
      findsOneWidget,
    );

    await tester.enterText(otpHiddenField(), '123456');
    await tester.pump();
    await tester.pump();
    expect(currentPath(router), '/home/owner');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('كود صحيح بدور مزوّد (provider) ينتقل لمنزل المزوّد', (tester) async {
    final fake = FakeAuthService();
    final (app, router) = buildApp(
      fake,
      phone: '01000000000',
      role: 'provider',
    );

    await tester.pumpWidget(app);
    await tester.enterText(otpHiddenField(), '123456');
    await tester.pump();
    await tester.pump();

    // نص الدور الفعلي في قاعدة البيانات (provider) يُترجَم للمسار المسجّل.
    expect(currentPath(router), '/home/provider');
    expect(fake.verifyCount, 1);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('وضع تغيير رقم الهاتف يبدأ بشاشة إدخال الرقم الجديد', (tester) async {
    final fake = FakeAuthService();
    final (app, _) = buildApp(fake, mode: OtpMode.changeNumber);

    await tester.pumpWidget(app);

    expect(find.text('تغيير رقم الهاتف'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('وضع الاستعادة: كود صحيح ينتقل لتعيين كلمة مرور بدون مزامنة',
      (tester) async {
    final fake = FakeAuthService();
    final (app, router) = buildApp(
      fake,
      mode: OtpMode.forgot,
      phone: '01110000000',
      role: 'car_owner',
    );

    await tester.pumpWidget(app);
    expect(find.text('أدخل رمز التحقق المكوّن من 6 أرقام الذي أُرسل إلى •••• ••• 0000'),
        findsOneWidget);

    await tester.enterText(otpHiddenField(), '123456');
    await tester.pump();
    await tester.pump();

    expect(fake.forgotVerifyCount, 1);
    expect(fake.lastForgotVerifiedPhone, '01110000000');
    expect(fake.syncedPhone, isNull);
    expect(currentPath(router), '/set-new-password');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('وضع الاستعادة: بعد انتهاء المهلة يعيد إرسال كود الاستعادة',
      (tester) async {
    var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
    OtpCooldownStore.now = () => fakeNow;
    const phone = '01123456789';
    OtpCooldownStore.start(phone);
    fakeNow = DateTime(2026, 1, 1, 12, 0, 1);

    final fake = FakeAuthService()..confirmedPhones.add(phone);
    final (app, _) = buildApp(fake, mode: OtpMode.forgot, phone: phone);
    await tester.pumpWidget(app);
    expect(find.textContaining('إعادة الإرسال بعد'), findsOneWidget);

    fakeNow = DateTime(2026, 1, 1, 12, 1, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('إعادة إرسال الرمز'), findsOneWidget);

    await tester.ensureVisible(find.text('إعادة إرسال الرمز'));
    await tester.tap(find.text('إعادة إرسال الرمز'));
    await tester.pump();
    await tester.pump();

    expect(fake.forgotResendCount, 1);
    expect(fake.lastForgotResendPhone, phone);
    expect(find.textContaining('إعادة الإرسال بعد'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('وضع الاستعادة: استخدام رقم آخر يرسل كود استعادة لا يربط الرقم',
      (tester) async {
    final fake = FakeAuthService()
      ..confirmedPhones.addAll({'01110000000', '01099999999'});
    final (app, router) = buildApp(
      fake,
      mode: OtpMode.forgot,
      phone: '01110000000',
      role: 'car_owner',
    );

    await tester.pumpWidget(app);
    await tester.ensureVisible(find.text('استخدام رقم آخر'));
    await tester.tap(find.text('استخدام رقم آخر'));
    await tester.pump();

    expect(find.text('استعادة كلمة المرور'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '01099999999');
    await tester.tap(find.text('إرسال الرمز'));
    await tester.pump();
    await tester.pump();

    expect(fake.forgotOtpCount, 1);
    expect(fake.lastForgotOtpPhone, '01099999999');
    expect(fake.attachCount, 0);
    expect(find.text('أدخل رمز التحقق المكوّن من 6 أرقام الذي أُرسل إلى •••• ••• 9999'),
        findsOneWidget);

    // التحقق من الرقم الجديد ينتهي في شاشة تعيين كلمة المرور.
    await tester.enterText(otpHiddenField(), '123456');
    await tester.pump();
    await tester.pump();
    expect(currentPath(router), '/set-new-password');

    await tester.pumpWidget(const SizedBox());
  });

  test('mapRecoverySendError لا يكشف حالة الرقم ويفوض البقية لـ mapOtpError', () {
    const neutral =
        'تعذّر إرسال رمز التحقق. تأكد من صحة رقم الهاتف ثم أعد المحاولة.';

    expect(
      mapRecoverySendError(
        AuthApiException('no user', code: 'user_not_found'),
        isArabic: true,
      ),
      neutral,
    );
    expect(
      mapRecoverySendError(
        AuthApiException('not confirmed', code: 'phone_not_confirmed'),
        isArabic: true,
      ),
      neutral,
    );
    expect(
      mapRecoverySendError(
        AuthApiException('blocked', code: 'phone_only_account_blocked'),
        isArabic: true,
      ),
      neutral,
    );
    expect(
      mapRecoverySendError(
        AuthApiException('sms error', code: 'sms_send_failed'),
        isArabic: true,
      ),
      'تعذّر إرسال الرمز. حاول مرة أخرى لاحقاً.',
    );
    expect(
      mapRecoverySendError(Exception('raw'), isArabic: true),
      'حدث خطأ ما. تحقق من اتصالك وحاول مرة أخرى.',
    );
  });

  test('mapOtpError يترجم أكواد GoTrue الشائعة لعربية', () {
    expect(
      mapOtpError(
        AuthApiException('sms error', code: 'sms_send_failed'),
        isArabic: true,
      ),
      'تعذّر إرسال الرمز. حاول مرة أخرى لاحقاً.',
    );
    expect(
      mapOtpError(
        AuthApiException('otp expired', code: 'otp_expired'),
        isArabic: true,
      ),
      'الرمز غير صحيح أو منتهي الصلاحية. حاول مرة أخرى.',
    );
    expect(
      mapOtpError(Exception('raw'), isArabic: true),
      'حدث خطأ ما. تحقق من اتصالك وحاول مرة أخرى.',
    );
  });
}