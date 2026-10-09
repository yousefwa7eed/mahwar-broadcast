import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mahwar/core/auth/auth_cubit.dart' hide AuthState;
import 'package:mahwar/core/auth/logout_coordinator.dart';
import 'package:mahwar/core/auth/role_hint_cache.dart';
import 'package:mahwar/core/services/app_messenger.dart';

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

/// [RoleHintCache] يتتبّع متى نُفِّذ تنظيفه حتى نتحقق من ترتيب تنظيفه قبل
/// الانتقال إلى شاشة اختيار نوع المستخدم.
class TrackingRoleHintCache extends RoleHintCache {
  bool cleared = false;

  @override
  Future<void> clear() async {
    cleared = true;
    await super.clear();
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

  (Widget, GoRouter, AuthCubit) buildApp(
    FakeAuthService service, {
    required VoidCallback onResetProfile,
    RoleHintCache? roleHintCache,
    VoidCallback? onSelectBuilt,
  }) {
    final authCubit = AuthCubit(service: service);
    final coordinator = LogoutCoordinator(
      authService: service,
      roleHintCache: roleHintCache,
    );
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
          builder: (context, state) {
            onSelectBuilt?.call();
            return const Scaffold(
              body: Center(child: Text('SELECT', key: Key('select'))),
            );
          },
        ),
      ],
    );

    final app = MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(create: (_) => authCubit),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        scaffoldMessengerKey: AppMessenger.messengerKey,
        theme: ThemeData(useMaterial3: true),
      ),
    );
    return (app, router, authCubit);
  }

  String currentPath(GoRouter router) {
    final matches = router.routerDelegate.currentConfiguration.matches;
    return matches.isEmpty
        ? router.routerDelegate.currentConfiguration.uri.path
        : matches.last.matchedLocation;
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> tapLogout(WidgetTester tester, {bool settle = true}) async {
    await tester.tap(find.byKey(const Key('logout-button')));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  /// يُخلي الباند الناجح («تم تسجيل الخروج») حتى لا يبقى مؤقّت
  /// auto-dismiss معلّقًا عند نهاية الاختبار.
  Future<void> clearSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('الانتقال يحدث فورًا ورسالة الخروج تظهر بعد اكتمال الخلفية البطيئة',
      (tester) async {
    final fake = FakeAuthService()
      ..user = user('car_owner')
      ..signOutDelay = const Duration(seconds: 5);
    var resetProfileCalls = 0;
    final (app, router, _) = buildApp(
      fake,
      onResetProfile: () => resetProfileCalls++,
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tapLogout(tester, settle: false);
    // نُعيد فحصًا قبل انتهاء الخلفية: التنقل والمحلي تمّا فورًا والرسالة لم تظهر
    // (الخلفية ما زالت معلّقة على تأخيرها المُصطنع).
    expect(resetProfileCalls, 1);
    expect(fake.user, isNull);
    expect(fake.signOutInBackgroundCount, 1);
    expect(find.text('تم تسجيل الخروج'), findsNothing);

    await tester.pumpAndSettle();
    expect(currentPath(router), '/select-user-type');
    expect(find.byKey(const Key('select')), findsOneWidget);
    expect(router.canPop(), isFalse);
    expect(fake.signOutCount, 0);

    // بعد انقضاء تأخير الخلفية تظهر رسالة النجاح.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('تم تسجيل الخروج'), findsOneWidget);

    await clearSnackBar(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('التنظيف المحلي (جلسة + Hint + إعادة ضبط) يكتمل قبل الانتقال',
      (tester) async {
    SharedPreferences.setMockInitialValues({hintKey: 'car_owner'});
    final tracking = TrackingRoleHintCache();
    final fake = FakeAuthService()..user = user('car_owner');
    var resetProfileCalls = 0;
    Object? userAtSelect;
    bool hintClearedAtSelect = false;
    final (app, router, cubit) = buildApp(
      fake,
      onResetProfile: () => resetProfileCalls++,
      roleHintCache: tracking,
      onSelectBuilt: () {
        userAtSelect = fake.user;
        hintClearedAtSelect = tracking.cleared;
      },
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tapLogout(tester);

    expect(currentPath(router), '/select-user-type');
    // لحظة بناء شاشة اختيار النوع كانت الجلسة المحلية مسحوبة والـ Hint مفروغًا.
    expect(userAtSelect, isNull);
    expect(hintClearedAtSelect, isTrue);
    expect(resetProfileCalls, 1);
    // التنظيف الخلفي استُدعي ومنفصل عن المحلي (لا signOut على الحالة الحالية).
    expect(fake.clearLocalSessionCount, 1);
    expect(fake.signOutInBackgroundCount, 1);
    expect(fake.signOutCount, 0);
    // البثّ المحلي وحده أنزَل حالة الدخول.
    expect(cubit.state, isA<AuthUnauthenticated>());
    expect(await RoleHintCache().read(), isNull);

    await clearSnackBar(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('فشل إبطال الجلسة في الخلفية → خروج محلي كامل بلا أي رسالة خطأ',
      (tester) async {
    final fake = FakeAuthService()
      ..user = user('provider')
      ..signOutInBackgroundError = Exception('server down');
    var resetProfileCalls = 0;
    final (app, router, _) = buildApp(
      fake,
      onResetProfile: () => resetProfileCalls++,
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tapLogout(tester);

    // الفشل الخلفي لا يوقف الخروج المحلي والانتقال.
    expect(currentPath(router), '/select-user-type');
    expect(router.canPop(), isFalse);
    expect(fake.clearLocalSessionCount, 1);
    expect(resetProfileCalls, 1);
    expect(fake.user, isNull);
    // لا رسالة نجاح لأن الخلفية فشلت، ولا رسالة خطأ خروج تُعرض للمستخدم.
    expect(find.text('تم تسجيل الخروج'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('فشل clearLocalSession وحده لا يمنع الخروج المحلي والانتقال',
      (tester) async {
    SharedPreferences.setMockInitialValues({hintKey: 'car_owner'});
    final fake = FakeAuthService()
      ..user = user('car_owner')
      ..clearLocalSessionError = Exception('storage locked');
    var resetProfileCalls = 0;
    final (app, router, _) = buildApp(
      fake,
      onResetProfile: () => resetProfileCalls++,
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tapLogout(tester);

    expect(currentPath(router), '/select-user-type');
    expect(router.canPop(), isFalse);
    expect(fake.clearLocalSessionCount, 1);
    expect(await RoleHintCache().read(), isNull);
    expect(resetProfileCalls, 1);

    await clearSnackBar(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('إعادة الدخول بعد الخروج لا تُبطَل جلسة المستخدم الجديد من الخلفية',
      (tester) async {
    final fake = FakeAuthService()..user = user('car_owner');
    final gate = Completer<void>();
    fake.signOutInBackgroundGate = gate;
    var resetProfileCalls = 0;
    final (app, router, _) = buildApp(
      fake,
      onResetProfile: () => resetProfileCalls++,
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tapLogout(tester);
    expect(currentPath(router), '/select-user-type');
    // الخلفية التقطت هوية الجلسة القديمة قبل أي تنظيف.
    expect(fake.lastBackgroundUserId, 'fake-user-id');

    // مستخدم جديد يسجّل دخولًا أثناء انشغال الخلفية.
    final newUser = User(
      id: 'new-user-id',
      appMetadata: const {},
      userMetadata: const {'role': 'car_owner'},
      aud: 'authenticated',
      createdAt: 'now',
    );
    fake.user = newUser;

    gate.complete();
    await tester.pumpAndSettle();

    // الخلفية لم تلمس جلسة/مستخدم الحالة الحالية.
    expect(fake.user, same(newUser));
    expect(fake.signOutCount, 0);
    expect(fake.lastBackgroundUserId, 'fake-user-id');

    await clearSnackBar(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('النقر المزدوج على زر الخروج يُنفَّذ مرة واحدة فقط', (tester) async {
    final fake = FakeAuthService()..user = user('car_owner');
    final gate = Completer<void>();
    fake.clearLocalSessionGate = gate;
    var resetProfileCalls = 0;
    final (app, router, _) = buildApp(
      fake,
      onResetProfile: () => resetProfileCalls++,
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pump();

    // اللمسة الثانية تجاهلها الحارس المشترك — التنظيف لم يتكرر.
    expect(fake.clearLocalSessionCount, 1);
    expect(fake.signOutInBackgroundCount, 1);
    expect(resetProfileCalls, 0);

    gate.complete();
    await tester.pumpAndSettle();

    expect(currentPath(router), '/select-user-type');
    expect(resetProfileCalls, 1);

    await clearSnackBar(tester);
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

    await tapLogout(tester);
    expect(currentPath(router), '/select-user-type');

    // نظام Android يعالج الضغط على زر الرجوع: لا يُهبط لأي شاشة مسجّلة دخول.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(currentPath(router), '/select-user-type');
    expect(find.byKey(const Key('select')), findsOneWidget);
    expect(resetProfileCalls, 1);

    await clearSnackBar(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('تنظيف FCM يستخدم هوية الجلسة القديمة حتى بعد سحب المحلية',
      (tester) async {
    final fake = FakeAuthService()..user = user('car_owner');
    var resetProfileCalls = 0;
    final (app, router, _) = buildApp(
      fake,
      onResetProfile: () => resetProfileCalls++,
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tapLogout(tester);

    expect(currentPath(router), '/select-user-type');
    // الجلسة المحلية أُسقطت، ومع ذلك نقّي FCM بهوية الجلسة القديمة الملتقَطة.
    expect(fake.user, isNull);
    expect(fake.signOutInBackgroundCount, 1);
    expect(fake.lastBackgroundUserId, 'fake-user-id');

    await clearSnackBar(tester);
    await tester.pumpWidget(const SizedBox());
  });
}