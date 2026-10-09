import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mahwar/core/auth/logout_coordinator.dart';
import 'package:mahwar/core/auth/role_hint_cache.dart';

import 'fakes/fake_auth_service.dart';

/// شاشة اختبار تحتوي زرًا واحدًا يمرّر إلى [LogoutCoordinator] — تحاكي زر
/// تسجيل الخروج في الشاشات الثلاث الحقيقية دون الحاجة لبناء الشاشة الكاملة
/// (التي تتطلب Supabase/Realtime/خدمات الموقع).
class LogoutHarnessScreen extends StatelessWidget {
  final LogoutCoordinator coordinator;
  final VoidCallback onResetProfile;

  const LogoutHarnessScreen({
    super.key,
    required this.coordinator,
    required this.onResetProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const Key('logout-button'),
          onPressed: () => coordinator.logout(
            context: context,
            resetProfile: onResetProfile,
          ),
          child: const Text('LOGOUT'),
        ),
      ),
    );
  }
}

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

  (Widget, GoRouter, LogoutHarnessScreen) buildApp(
    FakeAuthService service, {
    required VoidCallback onResetProfile,
  }) {
    final coordinator = LogoutCoordinator(authService: service);
    final harness = LogoutHarnessScreen(
      coordinator: coordinator,
      onResetProfile: onResetProfile,
    );

    final router = GoRouter(
      initialLocation: '/harness',
      routes: [
        GoRoute(path: '/harness', builder: (context, state) => harness),
        GoRoute(
          path: '/select-user-type',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('SELECT', key: Key('select'))),
          ),
        ),
      ],
    );

    final app = MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(useMaterial3: true),
    );
    return (app, router, harness);
  }

  String currentPath(GoRouter router) {
    final matches = router.routerDelegate.currentConfiguration.matches;
    return matches.isEmpty
        ? router.routerDelegate.currentConfiguration.uri.path
        : matches.last.matchedLocation;
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> tapLogout(WidgetTester tester, GoRouter router) async {
    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('خروج ناجح → تنظيف محلي كامل + انتقال لاختيار نوع المستخدم',
      (tester) async {
    SharedPreferences.setMockInitialValues({hintKey: 'car_owner'});
    final fake = FakeAuthService()..user = user('car_owner');
    var resetProfileCalls = 0;
    final (app, router, _) = buildApp(
      fake,
      onResetProfile: () => resetProfileCalls++,
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tapLogout(tester, router);

    // التنقل تم باستبدال المكدّس.
    expect(currentPath(router), '/select-user-type');
    expect(find.byKey(const Key('select')), findsOneWidget);
    // زر الرجوع لا يعيد شاشة مسجّل دخول (لا يوجد ما يُـهبط إليه).
    expect(router.canPop(), isFalse);
    // الخدمة استُدعيت، بلا حاجة لاحتياط clearLocalSession عند النجاح.
    expect(fake.signOutCount, 1);
    expect(fake.clearLocalSessionCount, 0);
    // التنظيف المحلي (RoleHintCache + إعادة ضبط الحالة) تم رغمًا عن كل شيء.
    expect(await RoleHintCache().read(), isNull);
    expect(resetProfileCalls, 1);
    expect(fake.user, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('فشل signOut الشبكي → تنظيف محلي + انتقال يحدثان دومًا',
      (tester) async {
    SharedPreferences.setMockInitialValues({hintKey: 'provider'});
    final fake = FakeAuthService()
      ..user = user('provider')
      ..signOutError = Exception('network down');
    var resetProfileCalls = 0;
    final (app, router, _) = buildApp(
      fake,
      onResetProfile: () => resetProfileCalls++,
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tapLogout(tester, router);

    // الفشل الشبكي لا يُبقي المستخدم على شاشة مسجّل دخول.
    expect(currentPath(router), '/select-user-type');
    expect(find.byKey(const Key('select')), findsOneWidget);
    expect(router.canPop(), isFalse);
    // signOut رُمي خطأه، فتحرك الاحتياط المحلي، ثم التنظيف المحلي اكتمل.
    expect(fake.signOutCount, 1);
    expect(fake.clearLocalSessionCount, 1);
    expect(await RoleHintCache().read(), isNull);
    expect(resetProfileCalls, 1);
    // السحب المحلي أزال الجلسة المحلية.
    expect(fake.user, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('فشل signOut و clearLocalSession معًا → خروج محلي + انتقال يحدثان',
      (tester) async {
    SharedPreferences.setMockInitialValues({hintKey: 'car_owner'});
    final fake = FakeAuthService()
      ..user = user('car_owner')
      ..signOutError = Exception('network down')
      ..clearLocalSessionError = Exception('storage locked');
    var resetProfileCalls = 0;
    final (app, router, _) = buildApp(
      fake,
      onResetProfile: () => resetProfileCalls++,
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tapLogout(tester, router);

    expect(currentPath(router), '/select-user-type');
    expect(router.canPop(), isFalse);
    expect(fake.signOutCount, 1);
    expect(fake.clearLocalSessionCount, 1);
    expect(await RoleHintCache().read(), isNull);
    expect(resetProfileCalls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('زر الرجوع لا يعيد شاشة مسجّل دخول بعد الخروج', (tester) async {
    final fake = FakeAuthService()..user = user('car_owner');
    var resetProfileCalls = 0;
    final (app, router, _) = buildApp(
      fake,
      onResetProfile: () => resetProfileCalls++,
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tapLogout(tester, router);
    expect(currentPath(router), '/select-user-type');

    // نظام Android يعالج الضغط على زر الرجوع: لا يُهبط لأي شاشة مسجّلة دخول.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(currentPath(router), '/select-user-type');
    expect(find.byKey(const Key('select')), findsOneWidget);
    expect(resetProfileCalls, 1);
    await tester.pumpWidget(const SizedBox());
  });
}