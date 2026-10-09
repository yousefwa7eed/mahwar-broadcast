import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mahwar/core/auth/auth_cubit.dart' hide AuthState;
import 'package:mahwar/core/settings/app_settings_cubit.dart';
import 'package:mahwar/features/auth/login_screen.dart';
import 'package:mahwar/l10n/app_localizations.dart';

import 'fakes/fake_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  (Widget, GoRouter) buildApp(FakeAuthService service,
      {String loginRole = 'car_owner'}) {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (context, state) => LoginScreen(role: loginRole)),
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

  // ملاحظة مهمة: لا نقرأ من `currentConfiguration.uri` هنا لأن go_router لا
  // يُحدّثه عند `router.push` — الشاشة المدفوعة (مثل OTP فوق شاشة الدخول)
  // تُحصى في `currentConfiguration.matches` وليس في `uri`. لذلك نقرأ أعلى
  // شاشة من `matches.last.matchedLocation` لنطابق سلوك البوابة في الإنتاج.
  String currentPath(GoRouter router) {
    final matches = router.routerDelegate.currentConfiguration.matches;
    return matches.isEmpty
        ? router.routerDelegate.currentConfiguration.uri.path
        : matches.last.matchedLocation;
  }

  AuthState signedInFor(User user) => AuthState(
        AuthChangeEvent.signedIn,
        Session(accessToken: 'fake-access-token', tokenType: 'bearer', user: user),
      );

  User ownerUser() => User(
        id: 'fake-user-id',
        appMetadata: const {},
        userMetadata: const {'role': 'car_owner'},
        aud: 'authenticated',
        createdAt: 'now',
      );

  User providerUser() => User(
        id: 'fake-user-id',
        appMetadata: const {},
        userMetadata: const {'role': 'provider'},
        aud: 'authenticated',
        createdAt: 'now',
      );

  testWidgets(
      'شاشة الدخول لا تتنقل حين تكون شاشة OTP أعلى منها، وتنتقل فقط حين تكون هي الأعلى',
      (tester) async {
    final fake = FakeAuthService();
    final (app, router) = buildApp(fake);

    await tester.pumpWidget(app);
    expect(currentPath(router), '/login');

    // ندفع شاشة OTP فوق شاشة الدخول (كما يحدث فعلًا أثناء تدفق التسجيل).
    router.push('/otp-verify');
    await tester.pumpAndSettle();
    expect(currentPath(router), '/otp-verify');

    // نُجهّز جلسة دخول حقيقية (يماثل GoTrue بعد إدخال OTP صحيح).
    fake.user = ownerUser();
    fake.serverRole = 'car_owner';

    // بث حدث signedIn → AuthCubit يبث AuthAuthenticated، وشاشة الدخول
    // تحتهما مركّبة — لكنها لا تتحرك لأنها ليست الشاشة الأعلى.
    fake.authStateController.add(signedInFor(fake.user!));
    await tester.pumpAndSettle();
    expect(currentPath(router), '/otp-verify');

    // نُنهي الجلسة بينما شاشة OTP ما زالت في الأعلى: حالة AuthCubit تنتقل إلى
    // AuthUnauthenticated (تغيير حقيقي لأن Equatable يدمج بث نفس حالة
    // AuthAuthenticated). ثم نعود لشاشة الدخول ونعاود البث signedIn → يصبح
    // AuthAuthenticated تغييرًا حقيقيًا، وعندها فقط تنتقل لرئيسية مالك السيارة.
    fake.authStateController.add(AuthState(AuthChangeEvent.signedOut, null));
    await tester.pumpAndSettle();
    expect(currentPath(router), '/otp-verify');

    router.pop();
    await tester.pumpAndSettle();
    expect(currentPath(router), '/login');

    fake.authStateController.add(signedInFor(fake.user!));
    await tester.pumpAndSettle();
    expect(currentPath(router), '/home/owner');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'مزوّد يحاول الدخول من صفحة دخول العميل: يُرفض، يُخرج من الجلسة، ولا ينتقل',
      (tester) async {
    final fake = FakeAuthService();
    final (app, router) = buildApp(fake);

    await tester.pumpWidget(app);
    expect(currentPath(router), '/login');

    // جلسة حساب مزوّد حقيقي لكن نقطة الدخول مقيّدة بالعميل.
    fake.user = providerUser();
    fake.serverRole = 'provider';
    fake.authStateController.add(signedInFor(fake.user!));
    await tester.pumpAndSettle();

    // لا تنقّل لأي شاشة رئيسية، ويظهر حوار الخطأ، وتُلغى الجلسة.
    expect(currentPath(router), '/login');
    expect(find.text('خطأ'), findsOneWidget);
    expect(fake.user, isNull);
    expect(find.byKey(const Key('owner_home')), findsNothing);
    expect(find.byKey(const Key('provider_home')), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'عميل سيارة يحاول الدخول من صفحة دخول المزوّد: يُرفض، يُخرج من الجلسة، ولا ينتقل',
      (tester) async {
    final fake = FakeAuthService();
    final (app, router) = buildApp(fake, loginRole: 'provider');

    await tester.pumpWidget(app);
    expect(currentPath(router), '/login');

    // جلسة حساب مالك سيارة حقيقي لكن نقطة الدخول مقيّدة بالمزوّد.
    fake.user = ownerUser();
    fake.serverRole = 'car_owner';
    fake.authStateController.add(signedInFor(fake.user!));
    await tester.pumpAndSettle();

    // لا تنقّل لأي شاشة رئيسية، ويظهر حوار الخطأ برسالة عدم التطابق، وتُلغى الجلسة.
    expect(currentPath(router), '/login');
    expect(find.text('خطأ'), findsOneWidget);
    expect(
      find.text('هذا الحساب مسجّل كعميل. يرجى تسجيل الدخول من صفحة تسجيل دخول العميل.'),
      findsOneWidget,
    );
    expect(fake.user, isNull);
    expect(find.byKey(const Key('owner_home')), findsNothing);
    expect(find.byKey(const Key('provider_home')), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}