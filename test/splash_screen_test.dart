import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mahwar/core/auth/auth_cubit.dart' hide AuthState;
import 'package:mahwar/core/auth/role_hint_cache.dart';
import 'package:mahwar/features/splash_onboarding/splash_screen.dart';
import 'package:mahwar/l10n/app_localizations.dart';

import 'fakes/fake_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const hintKey = 'auth_role_hint';

  User user(String role) => User(
        id: 'fake-user-id',
        appMetadata: const {},
        userMetadata: {'role': role},
        aud: 'authenticated',
        createdAt: 'now',
      );

  (Widget, GoRouter) buildApp(
    FakeAuthService service, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) =>
              SplashScreen(roleFetchTimeout: timeout),
        ),
        GoRoute(
          path: '/select-user-type',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('SELECT', key: Key('select')))),
        ),
        GoRoute(
          path: '/home/owner',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('OWNER', key: Key('owner')))),
        ),
        GoRoute(
          path: '/home/provider',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('PROVIDER', key: Key('provider')))),
        ),
      ],
    );

    final app = MultiBlocProvider(
      providers: [
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

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('جلسة مزوّد صالحة → /home/provider', (tester) async {
    final fake = FakeAuthService()
      ..user = user('provider')
      ..serverUser = user('provider')
      ..serverRole = 'provider';
    final (app, router) = buildApp(fake);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(currentPath(router), '/home/provider');
    expect(find.byKey(const Key('provider')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('جلسة عميل صالحة → /home/owner', (tester) async {
    final fake = FakeAuthService()
      ..user = user('car_owner')
      ..serverUser = user('car_owner')
      ..serverRole = 'car_owner';
    final (app, router) = buildApp(fake);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(currentPath(router), '/home/owner');
    expect(find.byKey(const Key('owner')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('جلسة منتهية (getUser يرمي AuthException) → خروج + تفريغ الـ hint + /select-user-type',
      (tester) async {
    SharedPreferences.setMockInitialValues({hintKey: 'car_owner'});
    final fake = FakeAuthService()
      ..user = user('car_owner')
      ..serverUserError = AuthApiException('token expired', code: 'session_expired');
    final (app, router) = buildApp(fake);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(currentPath(router), '/select-user-type');
    expect(fake.signOutCount, 1);
    expect(await RoleHintCache().read(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('فشل قراءة الدور (null) → حالة خطأ مع إعادة المحاولة وتسجيل الخروج',
      (tester) async {
    final fake = FakeAuthService()
      ..user = user('provider')
      ..serverUser = user('provider')
      ..serverRole = null; // فشل/غياب الدور من profiles
    final (app, router) = buildApp(fake);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(currentPath(router), '/splash');
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.text('تسجيل الخروج'), findsOneWidget);
    expect(find.byKey(const Key('provider')), findsNothing);
    expect(find.byKey(const Key('owner')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('انتهاء مهلة قراءة الدور → حالة خطأ مع إعادة المحاولة', (tester) async {
    final fake = FakeAuthService()
      ..user = user('provider')
      ..serverUser = user('provider')
      ..serverRole = 'provider'
      ..serverRoleDelay = const Duration(milliseconds: 120);
    final (app, router) = buildApp(fake, timeout: const Duration(milliseconds: 40));

    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(currentPath(router), '/splash');
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.text('تسجيل الخروج'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('تثبيت جديد (لا جلسة، hint فارغ) → /select-user-type', (tester) async {
    final fake = FakeAuthService(); // user/serverUser كلاهما null
    final (app, router) = buildApp(fake);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(currentPath(router), '/select-user-type');
    expect(await RoleHintCache().read(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('hint مخزّن != الدور الخادمي → التوجيه بالدور الخادمي وتحديث الـ hint',
      (tester) async {
    SharedPreferences.setMockInitialValues({hintKey: 'car_owner'});
    final fake = FakeAuthService()
      ..user = user('provider')
      ..serverUser = user('provider')
      ..serverRole = 'provider';
    final (app, router) = buildApp(fake);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(currentPath(router), '/home/provider');
    expect((await RoleHintCache().read())?.dbValue, 'provider');
    await tester.pumpWidget(const SizedBox());
  });
}
