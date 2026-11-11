import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mahwar/core/auth/auth_cubit.dart' hide AuthState;
import 'package:mahwar/core/auth/install_login_store.dart';
import 'package:mahwar/core/router/app_router.dart';
import 'package:mahwar/l10n/app_localizations.dart';

import 'fakes/fake_auth_service.dart';

/// بوابة «النسخة الجديدة»: جلسة صالحة بلا علامة تحقق محلية (أي بعد حذف
/// التطبيق وإعادة تنزيله) تُحوَّل إلى شاشة OTP بإرسال تلقائي للرمز.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  User user({String? phone}) => User(
    id: 'fake-user-id',
    appMetadata: const {},
    userMetadata: const {'role': 'car_owner'},
    aud: 'authenticated',
    createdAt: 'now',
    phone: phone,
  );

  (Widget, GoRouter) buildApp(FakeAuthService service, String initial) {
    final router = GoRouter(
      initialLocation: initial,
      redirect: appRedirect,
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
                'OTP:${state.uri.queryParameters['mode'] ?? ''}'
                ':${state.uri.queryParameters['phone'] ?? ''}'
                ':${state.uri.queryParameters['auto'] ?? ''}'
                ':${state.uri.queryParameters['next'] ?? ''}',
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
        GoRoute(
          path: '/select-user-type',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('SELECT', key: Key('select'))),
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

  testWidgets('نسخة جديدة: جلسة بلا تحقق محلي تُحوَّل إلى OTP بإرسال تلقائي', (
    tester,
  ) async {
    final fake = FakeAuthService()
      ..user = user(phone: '201012345678')
      ..serverRole = 'car_owner';
    final (app, router) = buildApp(fake, '/home/owner');

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(currentPath(router), '/otp-verify');
    // الرقم يُطبَّع للصيغة المحلية، والإرسال التلقائي مفعّل، والوجهة الأصلية
    // محفوظة في next.
    expect(find.text('OTP:login:01012345678:1:/home/owner'), findsOneWidget);
    expect(find.byKey(const Key('owner_home')), findsNothing);
    // الرقم يبقى «قيد التحقق» حتى لو أُغلق التطبيق قبل إدخال الرمز.
    expect(await InstallLoginStore.instance.isPending('01012345678'), isTrue);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('خروج ودخول على نفس النسخة: العلامة المحلية تمنع فرض الرمز', (
    tester,
  ) async {
    await InstallLoginStore.instance.markVerified('01012345678');
    final fake = FakeAuthService()
      ..user = user(phone: '201012345678')
      ..serverRole = 'car_owner';
    final (app, router) = buildApp(fake, '/home/owner');

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(currentPath(router), '/home/owner');
    expect(find.byKey(const Key('owner_home')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('المسارات العامة لا تخضع لبوابة النسخة', (tester) async {
    final fake = FakeAuthService()
      ..user = user(phone: '201012345678')
      ..serverRole = 'car_owner';
    final (app, router) = buildApp(fake, '/login');

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(currentPath(router), '/login');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('حساب بلا رقم هاتف لا تُفرض عليه البوابة', (tester) async {
    final fake = FakeAuthService()
      ..user = user()
      ..serverRole = 'car_owner';
    final (app, router) = buildApp(fake, '/home/owner');

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(currentPath(router), '/home/owner');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('بلا جلسة لا تتدخّل بوابة النسخة', (tester) async {
    final fake = FakeAuthService(); // user = null
    final (app, router) = buildApp(fake, '/home/owner');

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    // حارس الدور يحوّل غير المسجّل إلى اختيار النوع — لا بوابة نسخة ولا OTP.
    expect(currentPath(router), '/select-user-type');
    expect(find.byKey(const Key('otp_placeholder')), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
