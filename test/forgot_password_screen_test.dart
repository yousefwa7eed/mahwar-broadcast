import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mahwar/core/auth/auth_cubit.dart';
import 'package:mahwar/core/settings/app_settings_cubit.dart';
import 'package:mahwar/features/auth/forgot_password_screen.dart';
import 'package:mahwar/l10n/app_localizations.dart';

import 'fakes/fake_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  (Widget, GoRouter) buildApp(FakeAuthService service) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const ForgotPasswordScreen(role: 'car_owner'),
        ),
        GoRoute(
          path: '/otp-verify',
          builder: (context, state) => const Scaffold(
            body: Center(
              child: Text('OTP_VERIFY', key: Key('otp_verify_placeholder')),
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

  Future<void> enterPhone(WidgetTester tester, String value) async {
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'رقم الهاتف',
      ),
      value,
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'إرسال رمز التحقق'));
    await tester.pumpAndSettle();
  }

  const friendlyMessage =
      'تعذّر إرسال رمز التحقق. تأكد من صحة رقم الهاتف ثم أعد المحاولة.';

  testWidgets('رقم مسجّل: يرسل الكود ثم ينتقل لشاشة إدخال الكود', (tester) async {
    final fake = FakeAuthService()..confirmedPhones.add('01012345678');
    final (app, _) = buildApp(fake);
    await tester.pumpWidget(app);

    await enterPhone(tester, '01012345678');

    expect(fake.forgotOtpCount, 1);
    expect(fake.lastForgotOtpPhone, '01012345678');
    expect(find.byKey(const Key('otp_verify_placeholder')), findsOneWidget);
  });

  testWidgets('رقم غير مسجّل: رسالة محايدة ولا ينتقل لشاشة الكود', (tester) async {
    final fake = FakeAuthService(); // confirmedPhones فارغة
    final (app, _) = buildApp(fake);
    await tester.pumpWidget(app);

    await enterPhone(tester, '01000000000');

    expect(fake.forgotOtpCount, 1);
    expect(find.text(friendlyMessage), findsOneWidget);
    expect(find.byKey(const Key('otp_verify_placeholder')), findsNothing);
  });

  testWidgets('حساب غير مكتمل التفعيل: نفس الرسالة المحايدة تمامًا', (tester) async {
    final fake = FakeAuthService()
      ..confirmedPhones.add('01012345678')
      ..forgotOtpError = AuthApiException(
        'Cannot send OTP: phone not confirmed',
        code: 'phone_not_confirmed',
      );
    final (app, _) = buildApp(fake);
    await tester.pumpWidget(app);

    await enterPhone(tester, '01012345678');

    expect(find.text(friendlyMessage), findsOneWidget);
    expect(find.text('لم يتم تأكيد رقم الهاتف بعد. حاول إدخال الرمز مرة أخرى.'),
        findsNothing);
  });

  testWidgets('خطأ شبكة عام: رسالة عامة من الماب لا من الخادم', (tester) async {
    final fake = FakeAuthService()..forgotOtpError = Exception('boom');
    final (app, _) = buildApp(fake);
    await tester.pumpWidget(app);

    await enterPhone(tester, '01012345678');

    expect(find.text('حدث خطأ ما. تحقق من اتصالك وحاول مرة أخرى.'),
        findsOneWidget);
  });

  testWidgets('حقل فارغ: يُرفض ولا يُرسل أي كود', (tester) async {
    final fake = FakeAuthService()..confirmedPhones.add('01012345678');
    final (app, _) = buildApp(fake);
    await tester.pumpWidget(app);

    await tester.tap(find.widgetWithText(ElevatedButton, 'إرسال رمز التحقق'));
    await tester.pumpAndSettle();

    expect(fake.forgotOtpCount, 0);
    expect(find.text('يرجى إدخال رقم الهاتف'), findsOneWidget);
  });

  testWidgets('رقم غير مصري: يُرفض بصيغة خاطئة ولا يُرسل', (tester) async {
    final fake = FakeAuthService();
    final (app, _) = buildApp(fake);
    await tester.pumpWidget(app);

    await enterPhone(tester, '123456');

    expect(fake.forgotOtpCount, 0);
    expect(
      find.text('رقم هاتف مصري غير صحيح (مثال: 01012345678)'),
      findsOneWidget,
    );
  });
}