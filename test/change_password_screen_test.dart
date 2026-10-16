import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mahwar/core/auth/change_password_error.dart';
import 'package:mahwar/features/profile/change_password_screen.dart';
import 'package:mahwar/l10n/app_localizations.dart';

import 'fakes/fake_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  (Widget, GoRouter, FakeAuthService) buildApp() {
    final fake = FakeAuthService();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('HOME', key: Key('home_placeholder'))),
          ),
        ),
        GoRoute(
          path: '/change',
          builder: (context, state) => ChangePasswordScreen(service: fake),
        ),
      ],
    );

    final app = MaterialApp.router(
      routerConfig: router,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(useMaterial3: true),
    );
    return (app, router, fake);
  }

  Finder fieldByLabel(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );

  Future<void> openChange(WidgetTester tester, GoRouter router) async {
    router.push('/change');
    await tester.pumpAndSettle();
  }

  testWidgets('نجاح: يمرّر كلمتي المرور ويعود للخلف مع رسالة نجاح',
      (tester) async {
    final (app, router, fake) = buildApp();
    await tester.pumpWidget(app);
    await openChange(tester, router);

    await tester.enterText(fieldByLabel('كلمة المرور الحالية'), 'oldpass123');
    await tester.enterText(fieldByLabel('كلمة المرور الجديدة'), 'newpass123');
    await tester.enterText(
        fieldByLabel('تأكيد كلمة المرور الجديدة'), 'newpass123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'تغيير كلمة المرور'));
    await tester.pumpAndSettle();

    expect(fake.changePasswordCount, 1);
    expect(fake.lastChangeCurrentPassword, 'oldpass123');
    expect(fake.lastChangeNewPassword, 'newpass123');
    expect(find.byKey(const Key('home_placeholder')), findsOneWidget);
    expect(find.text('تم تغيير كلمة المرور بنجاح'), findsOneWidget);
  });

  testWidgets('كلمة المرور الحالية خاطئة: يعرض رسالة دقيقة ويبقى في الشاشة',
      (tester) async {
    final (app, router, fake) = buildApp();
    fake.changePasswordError = const AuthApiException(
      'Invalid login credentials',
      statusCode: '400',
      code: 'invalid_credentials',
    );
    await tester.pumpWidget(app);
    await openChange(tester, router);

    await tester.enterText(fieldByLabel('كلمة المرور الحالية'), 'wrongpass');
    await tester.enterText(fieldByLabel('كلمة المرور الجديدة'), 'newpass123');
    await tester.enterText(
        fieldByLabel('تأكيد كلمة المرور الجديدة'), 'newpass123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'تغيير كلمة المرور'));
    await tester.pumpAndSettle();

    expect(fake.changePasswordCount, 1);
    expect(find.text('كلمة المرور الحالية غير صحيحة'), findsOneWidget);
    expect(find.byKey(const Key('home_placeholder')), findsNothing);
  });

  testWidgets('تجاوز الحد (429): يعرض رسالة المحاولات الكثيرة لا كلمة المرور',
      (tester) async {
    final (app, router, fake) = buildApp();
    fake.changePasswordError = const AuthApiException(
      'Too many requests',
      statusCode: '429',
      code: 'over_request_rate_limit',
    );
    await tester.pumpWidget(app);
    await openChange(tester, router);

    await tester.enterText(fieldByLabel('كلمة المرور الحالية'), 'oldpass123');
    await tester.enterText(fieldByLabel('كلمة المرور الجديدة'), 'newpass123');
    await tester.enterText(
        fieldByLabel('تأكيد كلمة المرور الجديدة'), 'newpass123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'تغيير كلمة المرور'));
    await tester.pumpAndSettle();

    expect(fake.changePasswordCount, 1);
    expect(find.text('محاولات كثيرة، حاول بعد قليل'), findsOneWidget);
    expect(find.text('كلمة المرور الحالية غير صحيحة'), findsNothing);
    expect(find.byKey(const Key('home_placeholder')), findsNothing);
  });

  testWidgets('بلا بريد مرتبط: يعرض رسالة عدم توفر البريد', (tester) async {
    final (app, router, fake) = buildApp();
    fake.changePasswordError = const ChangePasswordNoEmailException();
    await tester.pumpWidget(app);
    await openChange(tester, router);

    await tester.enterText(fieldByLabel('كلمة المرور الحالية'), 'oldpass123');
    await tester.enterText(fieldByLabel('كلمة المرور الجديدة'), 'newpass123');
    await tester.enterText(
        fieldByLabel('تأكيد كلمة المرور الجديدة'), 'newpass123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'تغيير كلمة المرور'));
    await tester.pumpAndSettle();

    expect(
      find.text(
          'لا يمكن تغيير كلمة المرور لعدم وجود بريد إلكتروني مرتبط بالحساب'),
      findsOneWidget,
    );
  });

  testWidgets('الجديدة مطابقة للحالية: يُرفض محليًا بلا نداء الخدمة',
      (tester) async {
    final (app, router, fake) = buildApp();
    await tester.pumpWidget(app);
    await openChange(tester, router);

    await tester.enterText(fieldByLabel('كلمة المرور الحالية'), 'samepass1');
    await tester.enterText(fieldByLabel('كلمة المرور الجديدة'), 'samepass1');
    await tester.enterText(
        fieldByLabel('تأكيد كلمة المرور الجديدة'), 'samepass1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'تغيير كلمة المرور'));
    await tester.pumpAndSettle();

    expect(fake.changePasswordCount, 0);
    expect(
      find.text('كلمة المرور الجديدة يجب أن تختلف عن الحالية'),
      findsOneWidget,
    );
  });

  testWidgets('الجديدة أقل من 6 أحرف: يُرفض', (tester) async {
    final (app, router, fake) = buildApp();
    await tester.pumpWidget(app);
    await openChange(tester, router);

    await tester.enterText(fieldByLabel('كلمة المرور الحالية'), 'oldpass123');
    await tester.enterText(fieldByLabel('كلمة المرور الجديدة'), '12345');
    await tester.enterText(fieldByLabel('تأكيد كلمة المرور الجديدة'), '12345');
    await tester.tap(find.widgetWithText(ElevatedButton, 'تغيير كلمة المرور'));
    await tester.pumpAndSettle();

    expect(fake.changePasswordCount, 0);
    expect(find.text('كلمة المرور يجب أن لا تقل عن 6 أحرف'), findsOneWidget);
  });

  testWidgets('تأكيد مختلف: يُرفض', (tester) async {
    final (app, router, fake) = buildApp();
    await tester.pumpWidget(app);
    await openChange(tester, router);

    await tester.enterText(fieldByLabel('كلمة المرور الحالية'), 'oldpass123');
    await tester.enterText(fieldByLabel('كلمة المرور الجديدة'), 'newpass123');
    await tester.enterText(
        fieldByLabel('تأكيد كلمة المرور الجديدة'), 'different1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'تغيير كلمة المرور'));
    await tester.pumpAndSettle();

    expect(fake.changePasswordCount, 0);
    expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
  });

  testWidgets('الحالية فارغة: يُرفض', (tester) async {
    final (app, router, fake) = buildApp();
    await tester.pumpWidget(app);
    await openChange(tester, router);

    await tester.enterText(fieldByLabel('كلمة المرور الجديدة'), 'newpass123');
    await tester.enterText(
        fieldByLabel('تأكيد كلمة المرور الجديدة'), 'newpass123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'تغيير كلمة المرور'));
    await tester.pumpAndSettle();

    expect(fake.changePasswordCount, 0);
    expect(find.text('يرجى إدخال كلمة المرور الحالية'), findsOneWidget);
  });
}
