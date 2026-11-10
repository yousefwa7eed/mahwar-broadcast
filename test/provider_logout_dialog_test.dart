import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/auth/provider_logout_dialog.dart';
import 'package:mahwar/core/auth/provider_logout_service.dart';

class _FakeProviderLogoutService extends ProviderLogoutService {
  _FakeProviderLogoutService({required this.lastSession});

  final bool lastSession;
  bool throwOnPreview = false;
  int markLoggedOutCalls = 0;

  @override
  Future<bool> isLastSession() async {
    if (throwOnPreview) throw Exception('network down');
    return lastSession;
  }

  @override
  Future<void> markLoggedOut() async {
    markLoggedOutCalls++;
  }
}

Widget _harness(Future<void> Function(BuildContext) onPressed) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => onPressed(context),
          child: const Text('logout'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('آخر جلسة: تحذير الساعتين ثم تسجيل الخروج عند التأكيد', (
    tester,
  ) async {
    final fake = _FakeProviderLogoutService(lastSession: true);
    bool? result;

    await tester.pumpWidget(
      _harness((context) async {
        result = await confirmProviderLastSessionLogout(
          context,
          service: fake,
        );
      }),
    );

    await tester.tap(find.text('logout'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('نشاطك هيتوقف بعد ساعتين، سجّل دخول تاني عشان يرجع نشاطك'),
      findsOneWidget,
    );

    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();

    expect(fake.markLoggedOutCalls, 1);
    expect(result, isTrue);
  });

  testWidgets('آخر جلسة + تراجع: لا خروج ولا تسجيل', (tester) async {
    final fake = _FakeProviderLogoutService(lastSession: true);
    bool? result;

    await tester.pumpWidget(
      _harness((context) async {
        result = await confirmProviderLastSessionLogout(
          context,
          service: fake,
        );
      }),
    );

    await tester.tap(find.text('logout'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('تراجع'));
    await tester.pumpAndSettle();

    expect(fake.markLoggedOutCalls, 0);
    expect(result, isFalse);
  });

  testWidgets('ليست آخر جلسة: خروج مباشر بلا حوار ولا تسجيل', (tester) async {
    final fake = _FakeProviderLogoutService(lastSession: false);
    bool? result;

    await tester.pumpWidget(
      _harness((context) async {
        result = await confirmProviderLastSessionLogout(
          context,
          service: fake,
        );
      }),
    );

    await tester.tap(find.text('logout'));
    await tester.pumpAndSettle();

    expect(find.text('تأكيد'), findsNothing);
    expect(fake.markLoggedOutCalls, 0);
    expect(result, isTrue);
  });

  testWidgets('فشل الفحص الشبكي لا يمنع الخروج ولا يُظهر تحذيرًا', (tester) async {
    final fake = _FakeProviderLogoutService(lastSession: true)
      ..throwOnPreview = true;
    bool? result;

    await tester.pumpWidget(
      _harness((context) async {
        result = await confirmProviderLastSessionLogout(
          context,
          service: fake,
        );
      }),
    );

    await tester.tap(find.text('logout'));
    await tester.pumpAndSettle();

    expect(find.text('تأكيد'), findsNothing);
    expect(fake.markLoggedOutCalls, 0);
    expect(result, isTrue);
  });
}
