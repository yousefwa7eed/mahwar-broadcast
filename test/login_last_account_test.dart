import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mahwar/core/auth/auth_cubit.dart' hide AuthState;
import 'package:mahwar/core/settings/app_settings_cubit.dart';
import 'package:mahwar/features/auth/login_screen.dart';
import 'package:mahwar/l10n/app_localizations.dart';

import 'fakes/fake_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  (Widget, GoRouter) buildApp(
    FakeAuthService service, {
    String loginRole = 'car_owner',
  }) {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => LoginScreen(role: loginRole),
        ),
        GoRoute(
          path: '/otp-verify',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('OTP', key: Key('otp_placeholder'))),
          ),
        ),
        GoRoute(
          path: '/home/owner',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('OWNER_HOME', key: Key('owner_home'))),
          ),
        ),
        GoRoute(
          path: '/home/provider',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('PROVIDER_HOME', key: Key('provider_home'))),
          ),
        ),
      ],
    );

    final app = MultiBlocProvider(
      providers: [
        BlocProvider<AppSettingsCubit>(create: (_) => AppSettingsCubit()),
        BlocProvider<AuthCubit>(create: (_) => AuthCubit(service: service)),
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

  String currentPath(GoRouter router) {
    final matches = router.routerDelegate.currentConfiguration.matches;
    return matches.isEmpty
        ? router.routerDelegate.currentConfiguration.uri.path
        : matches.last.matchedLocation;
  }

  void seedLastAccount({String role = 'car_owner'}) {
    SharedPreferences.setMockInitialValues({
      'last_account_v1': jsonEncode({
        'name': 'يوسف',
        'phone': '01012345678',
        'role': role,
      }),
    });
  }

  testWidgets('تلميح العودة إلى حسابك يظهر بالاسم والرقم ويفتح صفحة OTP',
      (tester) async {
    seedLastAccount();
    final fake = FakeAuthService()..confirmedPhones.add('01012345678');
    final (app, router) = buildApp(fake);

    await tester.pumpWidget(app);
    await tester.pump();
    await tester.pump();

    expect(find.text('العودة إلى حسابك'), findsOneWidget);
    expect(find.text('يوسف · 010••••5678'), findsOneWidget);

    await tester.ensureVisible(find.text('العودة إلى حسابك'));
    await tester.tap(find.text('العودة إلى حسابك'));
    await tester.pump();
    await tester.pump();

    // أُرسل كود دخول للحساب المحفوظ ثم فُتحت شاشة OTP العادية.
    expect(fake.loginOtpCount, 1);
    expect(fake.lastLoginOtpPhone, '01012345678');
    expect(currentPath(router), '/otp-verify');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('لا يظهر تلميح حساب من دور آخر', (tester) async {
    seedLastAccount(role: 'provider');
    final (app, _) = buildApp(FakeAuthService());

    await tester.pumpWidget(app);
    await tester.pump();
    await tester.pump();

    expect(find.text('العودة إلى حسابك'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('فشل إرسال كود التلميح يعرض رسالة محايدة ولا يفتح OTP',
      (tester) async {
    seedLastAccount();
    // الرقم لم يُعلَن كحساب مؤكد → الخدمة الوهمية ترمي user_not_found.
    final fake = FakeAuthService();
    final (app, router) = buildApp(fake);

    await tester.pumpWidget(app);
    await tester.pump();
    await tester.pump();

    await tester.ensureVisible(find.text('العودة إلى حسابك'));
    await tester.tap(find.text('العودة إلى حسابك'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('تعذّر إرسال رمز التحقق. تأكد من صحة رقم الهاتف ثم أعد المحاولة.'),
      findsOneWidget,
    );
    expect(currentPath(router), '/login');

    await tester.pumpWidget(const SizedBox());
  });
}
