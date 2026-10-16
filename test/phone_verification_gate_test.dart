import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mahwar/core/auth/auth_cubit.dart' hide AuthState;
import 'package:mahwar/core/router/app_router.dart';
import 'package:mahwar/l10n/app_localizations.dart';

import 'fakes/fake_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  User user() => User(
        id: 'fake-user-id',
        appMetadata: const {},
        userMetadata: const {'role': 'car_owner'},
        aud: 'authenticated',
        createdAt: 'now',
      );

  (Widget, GoRouter) buildApp(FakeAuthService service, String initial) {
    final router = GoRouter(
      initialLocation: initial,
      redirect: phoneVerificationRedirect,
      routes: [
        GoRoute(
          path: '/home/owner',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('OWNER_HOME', key: Key('owner_home'))),
          ),
        ),
        GoRoute(
          path: '/otp-verify',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text(
                'OTP:${state.uri.queryParameters['mode'] ?? ''}',
                key: const Key('otp_placeholder'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('LOGIN', key: Key('login_placeholder'))),
          ),
        ),
      ],
    );

    final app = BlocProvider<AuthCubit>(
      create: (_) => AuthCubit(service: service),
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

  testWidgets('جلسة غير موثّقة تُحوَّل من الرئيسية إلى /otp-verify',
      (tester) async {
    final fake = FakeAuthService()
      ..user = user()
      ..phoneVerified = false;
    final (app, router) = buildApp(fake, '/home/owner');

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(currentPath(router), '/otp-verify');
    expect(find.text('OTP:signup'), findsOneWidget);
    expect(find.byKey(const Key('owner_home')), findsNothing);
    expect(fake.phoneVerifiedCount, 1);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('جلسة موثّقة تبقى على الرئيسية', (tester) async {
    final fake = FakeAuthService()
      ..user = user()
      ..phoneVerified = true;
    final (app, router) = buildApp(fake, '/home/owner');

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(currentPath(router), '/home/owner');
    expect(find.byKey(const Key('owner_home')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('فشل قراءة التوثيق يفتح البوابة (fail-open) ويبقي المستخدم',
      (tester) async {
    final fake = FakeAuthService()
      ..user = user()
      ..phoneVerifiedError = Exception('network down');
    final (app, router) = buildApp(fake, '/home/owner');

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(currentPath(router), '/home/owner');
    expect(find.byKey(const Key('owner_home')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('بلا جلسة لا تتدخّل البوابة', (tester) async {
    final fake = FakeAuthService(); // user = null
    final (app, router) = buildApp(fake, '/home/owner');

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(currentPath(router), '/home/owner');
    expect(fake.phoneVerifiedCount, 0);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('المسارات العامة لا تخضع للبوابة', (tester) async {
    final fake = FakeAuthService()
      ..user = user()
      ..phoneVerified = false;
    final (app, router) = buildApp(fake, '/login');

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(currentPath(router), '/login');
    expect(fake.phoneVerifiedCount, 0);

    await tester.pumpWidget(const SizedBox());
  });

  test('isPhoneGatePublicPath يطابق المسارات العامة فقط', () {
    expect(isPhoneGatePublicPath('/login'), isTrue);
    expect(isPhoneGatePublicPath('/otp-verify'), isTrue);
    expect(isPhoneGatePublicPath('/home/owner'), isFalse);
    expect(isPhoneGatePublicPath('/home/provider'), isFalse);
    expect(isPhoneGatePublicPath('/profile'), isFalse);
    expect(isPhoneGatePublicPath('/notifications'), isFalse);
  });
}
