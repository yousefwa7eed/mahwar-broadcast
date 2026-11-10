import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mahwar/features/provider_profile/provider_deep_link.dart';

/// يثبّت سلوك go_router الفعلي مع مخطط التطبيق: الوصلة
/// `mahwar://provider?id=…` تصل للـ redirect العام مع المضيف محفوظًا
/// (المسار يُطبَّع إلى `/`)، فنحوّلها هناك إلى الملف العام بدل شاشة خطأ.
/// لو تغيّر هذا السلوك في ترقية go_router يكسر هذا الاختبار بدل التطبيق.
void main() {
  const providerId = '0f8c6a52-3b7e-4f9a-9d21-1c2b3a4d5e6f';

  GoRouter buildRouter(String location) => GoRouter(
    initialLocation: location,
    redirect: (context, state) {
      if (!isProviderDeepLink(state.uri)) return null;
      return providerProfileTargetFromUri(state.uri) ?? '/select-user-type';
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const Text('splash'),
      ),
      GoRoute(
        path: '/select-user-type',
        builder: (context, state) => const Text('select-type'),
      ),
      GoRoute(
        path: '/provider/profile',
        builder: (context, state) =>
            Text('profile:${state.uri.queryParameters['providerId']}'),
      ),
    ],
  );

  testWidgets('رابط QR يفتح الملف العام للمزوّد', (tester) async {
    final router = buildRouter(buildProviderProfileLink(providerId));
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('profile:$providerId'), findsOneWidget);
  });

  testWidgets('رابط QR بمعرّف غير صالح لا يفتح ملف أي مزوّد', (tester) async {
    final router = buildRouter('mahwar://provider?id=not-a-uuid');
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('select-type'), findsOneWidget);
    expect(find.textContaining('profile:'), findsNothing);
  });
}
