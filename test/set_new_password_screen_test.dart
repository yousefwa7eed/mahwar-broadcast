import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mahwar/core/auth/auth_cubit.dart';
import 'package:mahwar/core/settings/app_settings_cubit.dart';
import 'package:mahwar/features/auth/set_new_password_screen.dart';
import 'package:mahwar/l10n/app_localizations.dart';

import 'fakes/fake_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  User recoveryUser() => User(
        id: 'fake-user-id',
        appMetadata: const {},
        userMetadata: const {'role': 'car_owner'},
        aud: 'authenticated',
        createdAt: 'now',
        email: 'owner@example.com',
      );

  (Widget, GoRouter, FakeAuthService) buildApp({bool withSession = true}) {
    final fake = FakeAuthService();
    if (withSession) fake.user = recoveryUser();

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SetNewPasswordScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('LOGIN', key: Key('login_placeholder'))),
          ),
        ),
      ],
    );

    final app = MultiBlocProvider(
      providers: [
        BlocProvider<AppSettingsCubit>(create: (_) => AppSettingsCubit()),
        BlocProvider<AuthCubit>(
          create: (_) => AuthCubit(service: fake),
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
    return (app, router, fake);
  }

  Finder passwordField() => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'كلمة المرور الجديدة',
      );
  Finder confirmField() => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'تأكيد كلمة المرور',
      );

  testWidgets('بجلسة استعادة: يضبط كلمة المرور، يخرج، ويعود للدخول', (tester) async {
    final (app, _, fake) = buildApp();
    await tester.pumpWidget(app);

    expect(find.text('تعيين كلمة مرور جديدة'), findsOneWidget);

    await tester.enterText(passwordField(), 'newpass123');
    await tester.enterText(confirmField(), 'newpass123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'تغيير كلمة المرور'));
    await tester.pumpAndSettle();

    expect(fake.setPasswordCount, 1);
    expect(fake.lastSetPassword, 'newpass123');
    expect(fake.user, isNull);
    expect(find.byKey(const Key('login_placeholder')), findsOneWidget);
    expect(
      find.textContaining('تم تغيير كلمة المرور بنجاح'),
      findsOneWidget,
    );
  });

  testWidgets('كلمتا المرور غير متطابقتين: يُرفض', (tester) async {
    final (app, _, fake) = buildApp();
    await tester.pumpWidget(app);

    await tester.enterText(passwordField(), 'newpass123');
    await tester.enterText(confirmField(), 'different1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'تغيير كلمة المرور'));
    await tester.pumpAndSettle();

    expect(fake.setPasswordCount, 0);
    expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
  });

  testWidgets('كلمة مرور أقل من 6 أحرف: يُرفض', (tester) async {
    final (app, _, fake) = buildApp();
    await tester.pumpWidget(app);

    await tester.enterText(passwordField(), '12345');
    await tester.enterText(confirmField(), '12345');
    await tester.tap(find.widgetWithText(ElevatedButton, 'تغيير كلمة المرور'));
    await tester.pumpAndSettle();

    expect(fake.setPasswordCount, 0);
    expect(find.text('كلمة المرور يجب أن لا تقل عن 6 أحرف'), findsOneWidget);
  });

  testWidgets('بدون جلسة استعادة: يُعرض رابط غير صالح وزر العودة', (tester) async {
    final (app, _, fake) = buildApp(withSession: false);
    await tester.pumpWidget(app);

    expect(find.text('الرابط غير صالح أو منتهي'), findsOneWidget);

    await tester.tap(find.text('العودة لتسجيل الدخول'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_placeholder')), findsOneWidget);
  });
}