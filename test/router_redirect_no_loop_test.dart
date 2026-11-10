// إثبات أن /splash يوجّه للرئيسية بلا حلقة توجيه مع حارس الدور في appRedirect،
// وأن الإقلاع البارد من إشعار دفع لا يمرّ بـ /splash أصلًا.
//
// الحلقة تظهر عمليًا كرمي GoRouter لـ "Too many redirects" بعد 100 محاولة،
// ولذلك يكفي أن تستقر الشاشة على المسار الصحيح مع عدّاد قراءات الدور = 1.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mahwar/core/auth/auth_cubit.dart' hide AuthState;
import 'package:mahwar/core/router/app_router.dart';
import 'package:mahwar/features/splash_onboarding/splash_screen.dart';
import 'package:mahwar/l10n/app_localizations.dart';

import 'fakes/fake_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  User user(String role) => User(
    id: 'fake-user-id',
    appMetadata: const {},
    userMetadata: {'role': role},
    aud: 'authenticated',
    createdAt: 'now',
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// يبني GoRouter بالحارس الحقيقي [appRedirect] — لا نسخة مبسّطة منه.
  (Widget, GoRouter, _SplashCounter) buildApp(
    FakeAuthService service, {
    String initialLocation = '/splash',
  }) {
    final splashCounter = _SplashCounter();
    final router = GoRouter(
      initialLocation: initialLocation,
      redirect: appRedirect,
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) {
            splashCounter.count++;
            return const SplashScreen(roleFetchTimeout: Duration(seconds: 2));
          },
        ),
        GoRoute(
          path: '/select-user-type',
          builder: (context, state) =>
              const Scaffold(body: Text('SELECT', key: Key('select'))),
        ),
        GoRoute(
          path: '/home/owner',
          builder: (context, state) =>
              const Scaffold(body: Text('OWNER', key: Key('owner'))),
        ),
        GoRoute(
          path: '/home/provider',
          builder: (context, state) =>
              const Scaffold(body: Text('PROVIDER', key: Key('provider'))),
        ),
        GoRoute(
          path: '/otp-verify',
          builder: (context, state) =>
              const Scaffold(body: Text('OTP', key: Key('otp'))),
        ),
        GoRoute(
          path: '/notification/detail',
          builder: (context, state) => Scaffold(
            body: Text(
              'NOTIFICATION ${state.uri.queryParameters['notificationId']}',
              key: const Key('notification-detail'),
            ),
          ),
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
    return (app, router, splashCounter);
  }

  String currentPath(GoRouter router) {
    final matches = router.routerDelegate.currentConfiguration.matches;
    return matches.isEmpty
        ? router.routerDelegate.currentConfiguration.uri.path
        : matches.last.matchedLocation;
  }

  testWidgets('/splash يوجّه إلى رئيسية الدور الخادمي دون حلقة', (
    tester,
  ) async {
    final fake = FakeAuthService()
      ..user = user('car_owner')
      ..serverUser = user('car_owner')
      ..serverRole = 'car_owner';
    final (app, router, splash) = buildApp(fake, initialLocation: '/splash');

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('owner')), findsOneWidget);
    expect(currentPath(router), '/home/owner');
    // الحلقة كانت ستعيد بناء /splash أو تعيد قراءة الدور مرارًا.
    expect(splash.count, 1);
    expect(fake.serverRoleCount, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('رئيسية الدور الخطأ تُعاد إلى رئيسية الدور الفعلي مرة واحدة', (
    tester,
  ) async {
    final fake = FakeAuthService()
      ..user = user('provider')
      ..serverUser = user('provider')
      ..serverRole = 'provider';
    final (app, router, splash) = buildApp(
      fake,
      initialLocation: '/home/owner',
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(currentPath(router), '/home/provider');
    expect(find.byKey(const Key('provider')), findsOneWidget);
    expect(splash.count, 0);
    expect(fake.serverRoleCount, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('إقلاع بارد من إشعار (التطبيق مقفول) لا يمرّ بـ /splash ولا يدور', (
    tester,
  ) async {
    final fake = FakeAuthService()
      ..user = user('provider')
      ..serverUser = user('provider')
      ..serverRole = 'provider';
    final (app, router, splash) = buildApp(
      fake,
      initialLocation: '/notification/detail?notificationId=n-1',
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notification-detail')), findsOneWidget);
    expect(find.text('NOTIFICATION n-1'), findsOneWidget);
    expect(currentPath(router), '/notification/detail');
    // مسار الإشعار ليس مسار رئيسية → الحارس لا يتدخّل، والإقلاع لا يعرض splash.
    expect(splash.count, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('إقلاع بارد ثم فتح إشعار دفع: splash مرة واحدة ثم شاشة الإشعار', (
    tester,
  ) async {
    final fake = FakeAuthService()
      ..user = user('provider')
      ..serverUser = user('provider')
      ..serverRole = 'provider';
    final (app, router, splash) = buildApp(fake, initialLocation: '/splash');

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('provider')), findsOneWidget);

    // هذا ما يفعله PushNotificationService._openNotificationDetail للإشعار
    // الأصلي بعد الإقلاع (handleInitialMessage).
    router.push('/notification/detail?notificationId=n-2');
    await tester.pumpAndSettle();

    expect(find.text('NOTIFICATION n-2'), findsOneWidget);
    expect(splash.count, 1);
    expect(fake.serverRoleCount, 1);
    await tester.pumpWidget(const SizedBox());
  });
}

class _SplashCounter {
  int count = 0;
}
