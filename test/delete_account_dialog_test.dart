import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mahwar/core/auth/change_password_error.dart';
import 'package:mahwar/core/widgets/delete_account_dialog.dart';
import 'package:mahwar/l10n/app_localizations.dart';

import 'fakes/fake_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// حساب هاتفي كما تُنشئه GoTrue فعلًا: `phone` بلا بادئة `+`.
  FakeAuthService fakeWithPhone({String? phone = '201012345678'}) {
    return FakeAuthService()
      ..user = User(
        id: 'fake-user-id',
        appMetadata: const {},
        userMetadata: const {'role': 'car_owner'},
        aud: 'authenticated',
        createdAt: 'now',
        phone: phone,
      );
  }

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

  /// بعد إرسال الرمز يبدأ عدّاد إعادة الإرسال (Timer.periodic)، فلا يجوز
  /// استخدام pumpAndSettle بعده — نُقدّم الإطارات يدويًا.
  Future<void> sendCode(WidgetTester tester) async {
    await tester.tap(find.text('Send verification code'));
    await tester.pump();
    await tester.pump();
  }

  Future<void> submitOtp(WidgetTester tester, String otp) async {
    await tester.enterText(find.byType(TextField), otp);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pump();
    // حركة إغلاق الحوار تحتاج وقتًا؛ نُقدّمه يدويًا لأن عدّاد إعادة الإرسال
    // يمنع pumpAndSettle.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('النجاح: إرسال رمز ثم تأكيده يغلق الحوار ويعيد true',
      (tester) async {
    final fake = fakeWithPhone();
    final captured = <bool?>[];

    await openDialog(tester, fake, captured);
    expect(find.byType(TextField), findsNothing);

    await sendCode(tester);
    expect(fake.deleteAccountOtpCount, 1);
    expect(fake.deleteAccountCount, 0);
    expect(find.byType(TextField), findsOneWidget);

    await submitOtp(tester, '123456');

    expect(fake.deleteAccountCount, 1);
    expect(fake.lastDeleteOtp, '123456');
    expect(find.byType(AlertDialog), findsNothing);
    expect(captured, [true]);
  });

  testWidgets('رمز غير صحيح: 403 INVALID_OTP يعرض رسالة الرمز ويُبقي الحوار',
      (tester) async {
    final fake = fakeWithPhone()
      ..deleteAccountError = const FunctionException(
        status: 403,
        details: {'code': 'INVALID_OTP'},
      );
    final captured = <bool?>[];

    await openDialog(tester, fake, captured);
    await sendCode(tester);
    await submitOtp(tester, '000000');

    expect(
      find.text('The verification code is incorrect or expired. Request a new one.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(captured, isEmpty);
  });

  testWidgets('خطأ خادمي آخر يعرض الرسالة العامة لا رسالة الرمز', (tester) async {
    final fake = fakeWithPhone()
      ..deleteAccountError = const FunctionException(status: 500);
    final captured = <bool?>[];

    await openDialog(tester, fake, captured);
    await sendCode(tester);
    await submitOtp(tester, '123456');

    expect(
      find.text('The verification code is incorrect or expired. Request a new one.'),
      findsNothing,
    );
    expect(
      find.text('Could not delete your account. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('فشل إرسال الرمز يبقى على الخطوة الأولى ويعرض السبب',
      (tester) async {
    final fake = fakeWithPhone(phone: null)
      ..deleteAccountOtpError = const DeleteAccountException('PHONE_REQUIRED');
    final captured = <bool?>[];

    await openDialog(tester, fake, captured);
    await sendCode(tester);

    expect(fake.deleteAccountOtpCount, 1);
    expect(fake.deleteAccountCount, 0);
    expect(find.byType(TextField), findsNothing);
    expect(
      find.text(
        'No phone number is linked to this account. Contact support to delete it.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('رمز ناقص لا يُرسل للخادم ويظهر تنبيه', (tester) async {
    final fake = fakeWithPhone();
    final captured = <bool?>[];

    await openDialog(tester, fake, captured);
    await sendCode(tester);
    await submitOtp(tester, '123');

    expect(fake.deleteAccountCount, 0);
    expect(find.text('Enter the 6-digit verification code'), findsOneWidget);
  });
}
