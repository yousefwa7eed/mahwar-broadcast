import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mahwar/core/widgets/delete_account_dialog.dart';
import 'package:mahwar/l10n/app_localizations.dart';

import 'fakes/fake_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// يعرض [showDeleteAccountDialog] فوق خدمة وهمية ويسجّل الناتج في [captured]
  /// بعد إغلاق الحوار.
  Future<void> openDialog(
    WidgetTester tester,
    FakeAuthService fake,
    List<bool?> captured,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  captured.add(
                    await showDeleteAccountDialog(
                      context,
                      authService: fake,
                    ),
                  );
                },
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
  }

  Future<void> submitPassword(WidgetTester tester, String password) async {
    await tester.enterText(find.byType(TextField), password);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'رمي FunctionException(403, INVALID_PASSWORD) يُظهر currentPasswordIncorrect',
      (tester) async {
    final fake = FakeAuthService()
      ..deleteAccountError = const FunctionException(
        status: 403,
        details: {'code': 'INVALID_PASSWORD'},
      );
    final captured = <bool?>[];

    await openDialog(tester, fake, captured);
    await submitPassword(tester, 'wrong-pass');

    expect(find.text('Current password is incorrect'), findsOneWidget);
    expect(fake.deleteAccountCount, 1);
    expect(fake.lastDeletePassword, 'wrong-pass');
    expect(captured, isEmpty); // الحوار ما زال مفتوحًا (لم يُغلق).
  });

  testWidgets('خطأ خادمي آخر يُظهر الرسالة العامة لا رسالة كلمة المرور',
      (tester) async {
    final fake = FakeAuthService()
      ..deleteAccountError = const FunctionException(status: 500);
    final captured = <bool?>[];

    await openDialog(tester, fake, captured);
    await submitPassword(tester, 'any-pass');

    expect(find.text('Current password is incorrect'), findsNothing);
    expect(
      find.text('Could not change your password. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('نجاح الحذف يُغلق الحوار ويعيد true', (tester) async {
    final fake = FakeAuthService();
    final captured = <bool?>[];

    await openDialog(tester, fake, captured);
    await submitPassword(tester, 'right-pass');

    expect(find.byType(AlertDialog), findsNothing);
    expect(captured, [true]);
    expect(fake.deleteAccountCount, 1);
  });
}
