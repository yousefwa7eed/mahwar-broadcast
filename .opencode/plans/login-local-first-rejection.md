# Plan: Local-first cross-role login rejection

Status: APPROVED spec, NOT APPLIED (edit tool blocked by permission policy
`edit` = deny for `*`; only `.opencode/plans/*.md` is writable). Apply with
edits enabled, then run analyze + test. **Do NOT apply any Supabase migration.**

## Goal
On the role-locked login screens, when a signed-in account's role does not match
the entry point (or cannot be resolved), show the Arabic message **immediately**,
guarantee local session teardown, and move the server signOut/device cleanup to
the background (errors swallowed). Bound role fetch (10s) with retry. Keep the
login button loading during resolve. Guard the global revoke **only** on the
background rejection path — normal Step-7 logout behaviour is unchanged.

## Root cause (static trace, no runtime timings captured)
`login_screen.dart:63/74` `await AuthCubit.signOut()` before `showErrorDialog`.
`SupabaseAuthService.signOut` awaits 5 sequential network round-trips
(fcm_token update → `deleteToken` → 2× topic unsubscribe → GoTrue signOut).

---

## 1) `lib/core/auth/auth_cubit.dart`

Add at top of imports:
```dart
import 'dart:async';
```

`_init()` listener — put post-login work off the critical path:
```dart
        emit(AuthAuthenticated(session.user));
        // عمل غير حرج بعد الدخول — لا يُنتظر حتى لا يؤخّر التوجيه/الرفض.
        unawaited(_saveFcmToken(session.user.id));
        unawaited(_subscribeToRoleTopic(session.user));
```

After `resolveCurrentRole()` (currently ends `return _authService.getServerRole(); }`) add:
```dart
  /// يحدّد الدور مع مهلة زمنية وإعادة محاولة — لمسار الدخول. أي انتهاء مهلة
  /// أو خطأ عابر يُعاد معه المحاولة حتى [attempts] مرة، ثم يُرجع null (يُعامل
  /// كدور غير معروف). دور `null` صريح من الخادم لا يُعاد معه المحاولة (حالة
  /// نهائية). لا يُغيّر [resolveCurrentRole] المستخدم في شاشة الإقلاع.
  Future<String?> resolveCurrentRoleWithRetry({
    Duration timeout = const Duration(seconds: 10),
    int attempts = 2,
  }) async {
    if (_authService.currentUser == null) return null;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        return await resolveCurrentRole().timeout(timeout);
      } on TimeoutException {
        // انتهت المهلة — أعد المحاولة.
      } catch (_) {
        // فشل شبكي/خادمي عابر — أعد المحاولة.
      }
    }
    return null;
  }
```

After `signOut()` add:
```dart
  /// يرفض الجلسة التي أُنشئت من نقطة دخول مقيّدة بالدور. يبدأ تنظيف الخادم/
  /// الجهاز في الخلفية (يجلب توكن FCM قبل سحب الجلسة المحلية) ثم يسحب الجلسة
  /// محليًا فورًا حتى يتوقف الوصول بلا انتظار شبكة. لا يبثّ [AuthError] أبدًا —
  /// حتى لا تظهر رسالة خطأ خروج فوق رسالة عدم التطابق.
  void rejectSession() {
    _authService.signOutFromRejection().ignore();
    _authService.clearLocalSession().ignore();
    if (!isClosed) emit(const AuthUnauthenticated());
  }
```
`signOut()` itself is left unchanged.

---

## 2) `lib/core/auth/auth_service.dart`

Abstract `AuthService` — after `Future<void> clearLocalSession();` add:
```dart
  /// مسار رفض الجلسة من نقطة دخول مقيّدة بالدور: ينظّف الجهاز/الخادم ثم يُبطل
  /// الجلسة لدى الخادم فقط إن بقيت هي نفسها (لا يُبطل جلسة جديدة أنشأها
  /// المستخدم بعد الرفض). منفصل عن [signOut] حتى يبقى سلوك الخروج العادي كما هو.
  Future<void> signOutFromRejection();
```

`SupabaseAuthService` — replace the body of `signOut()` (currently lines 212-244)
with the extracted helper + unchanged public `signOut` + new guarded path:
```dart
  @override
  Future<void> signOut() async {
    final userId = _client.auth.currentUser?.id;
    await _cleanupDevice(userId);
    // مسار الخروج العادي: الإبطال العام يبقى دائمًا (بلا حارس) — سلوك غير مُتغيّر.
    await _client.auth.signOut();
  }

  @override
  Future<void> signOutFromRejection() async {
    final userId = _client.auth.currentUser?.id;
    await _cleanupDevice(userId);
    // الحارس هنا فقط: لا نُبطل إن تغيّرت الجلسة (تسجيل دخول جديد بعد الرفض).
    if (userId != null && _client.auth.currentUser?.id == userId) {
      await _client.auth.signOut();
    }
  }

  /// فصل ارتباط الجهاز بالحساب (fcm_token + توكن FCM + الـ topics) بأفضل جهد.
  /// لا يمسّ الجلسة المحلية. فشل أي خطوة يُسجَّل ولا يُوقف الباقي.
  Future<void> _cleanupDevice(String? userId) async {
    if (userId == null) return;
    try {
      await _client.from('profiles').update({'fcm_token': null}).eq('id', userId);
    } catch (e) {
      AuthService.fcmTokenClearFailureCount++;
      debugPrint(
        '[AuthService] FCM_TOKEN_CLEAR_FAILED '
        '(count=${AuthService.fcmTokenClearFailureCount}, userId=$userId): $e '
        '- proceeding with signOut; device may still receive this account notifications.',
      );
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('[AuthService] FCM deleteToken failed: $e');
    }
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic('car_owners');
      await FirebaseMessaging.instance.unsubscribeFromTopic('providers');
    } catch (e) {
      debugPrint('[AuthService] FCM topic unsubscribe failed: $e');
    }
  }
```
`clearLocalSession()` unchanged.

---

## 3) `lib/features/auth/login_screen.dart`

Constructor/fields:
```dart
class LoginScreen extends StatefulWidget {
  final String role;

  /// المهلة القصوى لقراءة الدور من الخادم (كل محاولة). قابلة للحقن للاختبارات.
  final Duration roleFetchTimeout;

  /// عدد محاولات قراءة الدور قبل اعتباره غير معروف.
  final int roleFetchAttempts;

  const LoginScreen({
    super.key,
    required this.role,
    this.roleFetchTimeout = const Duration(seconds: 10),
    this.roleFetchAttempts = 2,
  });
```

Replace the `BlocListener` listener body:
```dart
      listener: (context, state) async {
        if (_resolving) return;

        if (state is! AuthAuthenticated) {
          if (state is AuthError && isTopmostRoute(context, '/login')) {
            showErrorDialog(context, state.message);
          }
          return;
        }

        if (!isTopmostRoute(context, '/login')) return;

        setState(() => _resolving = true);
        try {
          // الدور الفعلي مع مهلة وإعادة محاولة — لا نُبقي الزر قابلاً للضغط
          // ولا نترك المستخدم بلا مؤشر أثناء تحديد الدور.
          final actualRole = AppRole.tryParse(
            await context.read<AuthCubit>().resolveCurrentRoleWithRetry(
                  timeout: widget.roleFetchTimeout,
                  attempts: widget.roleFetchAttempts,
                ),
          );
          if (!context.mounted) return;

          final isArabic = context
                  .read<AppSettingsCubit>()
                  .state
                  .locale
                  .languageCode ==
              'ar';

          // تعذّر تحديد الدور → رسالة فورية ثم رفض الجلسة في الخلفية.
          if (actualRole == null) {
            showErrorDialog(context, roleUnresolvedMessage(isArabic: isArabic));
            context.read<AuthCubit>().rejectSession();
            return;
          }

          final expectedRole = AppRole.tryParse(widget.role);

          // نقطة الدخول مقيّدة بالدور: رسالة فورية ثم رفض الجلسة في الخلفية.
          if (expectedRole != null && actualRole != expectedRole) {
            showErrorDialog(
              context,
              roleMismatchMessage(actualRole: actualRole, isArabic: isArabic),
            );
            context.read<AuthCubit>().rejectSession();
            return;
          }

          context.go(actualRole.homeRoute);
        } finally {
          if (mounted) setState(() => _resolving = false);
        }
      },
```
Pass the busy flag into the form:
```dart
                LoginFormWidget(
                  role: widget.role,
                  isBusy: _resolving,
                  onSubmit: (identifier, password) { ... },
                  ...
                ),
```

---

## 4) `lib/features/auth/widgets/login_form_widget.dart`

Add field + constructor param:
```dart
  final bool isBusy;
  ...
  const LoginFormWidget({
    super.key,
    required this.role,
    this.isBusy = false,
    required this.onSubmit,
    required this.onSignupTap,
    required this.onForgotPasswordTap,
  });
```
Update the busy computation (line 70):
```dart
    final bool isAuthLoading =
        context.watch<AuthCubit>().state is AuthLoading || widget.isBusy;
```
(the button spinner/disabled logic at lines 221-240 already keys off `isAuthLoading`).

---

## 5) `test/fakes/fake_auth_service.dart`

Fields:
```dart
  /// تأخير مُصطنع في `signOut`/`signOutFromRejection` لمحاكاة خروج بطيء.
  Duration? signOutDelay;

  /// تأخيرات `getServerRole` بالترتيب (تُستهلك من الأمام)؛ ما زاد يرجع إلى
  /// [serverRoleDelay] أو بلا تأخير.
  final List<Duration> serverRoleDelays = [];

  int signOutFromRejectionCount = 0;
  Object? signOutFromRejectionError;
```
`getServerRole`:
```dart
  @override
  Future<String?> getServerRole() async {
    serverRoleCount++;
    final delay =
        serverRoleDelays.isNotEmpty ? serverRoleDelays.removeAt(0) : serverRoleDelay;
    if (delay != null) await Future<void>.delayed(delay);
    if (serverRoleError != null) throw serverRoleError!;
    return serverRole;
  }
```
`signOut`:
```dart
  @override
  Future<void> signOut() async {
    signOutCount++;
    if (signOutDelay != null) await Future<void>.delayed(signOutDelay!);
    if (signOutError != null) throw signOutError!;
    user = null;
  }
```
New override:
```dart
  @override
  Future<void> signOutFromRejection() async {
    signOutFromRejectionCount++;
    if (signOutDelay != null) await Future<void>.delayed(signOutDelay!);
    if (signOutFromRejectionError != null) throw signOutFromRejectionError!;
  }
```

---

## 6) `test/login_navigation_gate_test.dart`

Extend `buildApp` with an injectable timeout:
```dart
  (Widget, GoRouter) buildApp(
    FakeAuthService service, {
    String loginRole = 'car_owner',
    Duration roleFetchTimeout = const Duration(seconds: 10),
  }) {
    ...
        GoRoute(
          path: '/login',
          builder: (context, state) =>
              LoginScreen(role: loginRole, roleFetchTimeout: roleFetchTimeout),
        ),
```

Add 4 tests:

**(a) message shows immediately despite a slow background signOut**
```dart
  testWidgets('رسالة عدم التطابق تظهر فورًا دون انتظار تسجيل الخروج البطيء',
      (tester) async {
    final fake = FakeAuthService();
    final (app, router) = buildApp(fake);
    await tester.pumpWidget(app);

    fake.user = providerUser();
    fake.serverRole = 'provider';
    fake.signOutDelay = const Duration(seconds: 5);

    fake.authStateController.add(signedInFor(fake.user!));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(currentPath(router), '/login');
    expect(
      find.text('هذا الحساب مسجّل كمزوّد. يرجى تسجيل الدخول من صفحة تسجيل دخول المزوّد.'),
      findsOneWidget,
    );
    expect(fake.clearLocalSessionCount, 1);
    expect(fake.user, isNull);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });
```

**(b) login button shows a loading indicator while resolving**
```dart
  testWidgets('مؤشر تحميل على زر الدخول أثناء تحديد الدور', (tester) async {
    final fake = FakeAuthService();
    final (app, router) = buildApp(fake);
    await tester.pumpWidget(app);

    fake.user = ownerUser();
    fake.serverRole = 'car_owner';
    fake.serverRoleDelay = const Duration(milliseconds: 300);

    fake.authStateController.add(signedInFor(fake.user!));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(currentPath(router), '/home/owner');

    await tester.pumpWidget(const SizedBox());
  });
```

**(c) timeout retry (unit test)**
```dart
  test('إعادة المحاولة عند انتهاء مهلة قراءة الدور', () async {
    final fake = FakeAuthService();
    fake.user = ownerUser();
    fake.serverRole = 'car_owner';
    fake.serverRoleDelays
      ..add(const Duration(milliseconds: 300))
      ..add(Duration.zero);

    final cubit = AuthCubit(service: fake);
    addTearDown(cubit.close);

    final role = await cubit.resolveCurrentRoleWithRetry(
      timeout: const Duration(milliseconds: 100),
      attempts: 2,
    );

    expect(role, 'car_owner');
    expect(fake.serverRoleCount, 2);
  });
```

**(d) correct sign-in works immediately after a rejection**
```dart
  testWidgets('يمكن تسجيل الدخول الصحيح مباشرة بعد الرفض', (tester) async {
    final fake = FakeAuthService();
    final (app, router) = buildApp(fake);
    await tester.pumpWidget(app);

    fake.user = providerUser();
    fake.serverRole = 'provider';
    fake.authStateController.add(signedInFor(fake.user!));
    await tester.pumpAndSettle();

    expect(find.text('خطأ'), findsOneWidget);
    expect(fake.user, isNull);

    await tester.tap(find.text('حسناً'));
    await tester.pumpAndSettle();

    fake.user = ownerUser();
    fake.serverRole = 'car_owner';
    fake.authStateController.add(signedInFor(fake.user!));
    await tester.pumpAndSettle();

    expect(currentPath(router), '/home/owner');
    await tester.pumpWidget(const SizedBox());
  });
```

Existing cross-role tests (lines 135, 160) stay green: `rejectSession` →
`clearLocalSession` sets `fake.user = null`, and no `AuthError` is emitted, so
`find.text('خطأ')` is still exactly one.

---

## Verification after applying
```
flutter analyze
flutter test
```
Post a changed-files summary. Do NOT run/apply any Supabase migration.

## Notes / rationale
- `Future.ignore()` swallows background errors; the `signOutFromRejection()` call
  runs its synchronous prefix first, dispatching the fcm_token update with a
  still-valid JWT before `clearLocalSession()` clears locally.
- GoTrue `_signOut` removes the local session synchronously before its first
  await, so `clearLocalSession()` nulls `currentUser` immediately; server-side
  session revocation still happens via its internal `scope: local` call.
- Normal Step-7 logout (`signOut()`) keeps the **unguarded** global revoke; only
  the rejection path uses the guarded `signOutFromRejection()`.
