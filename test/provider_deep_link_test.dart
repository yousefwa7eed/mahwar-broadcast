import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/auth/home_route.dart';
import 'package:mahwar/core/auth/role_gate.dart';
import 'package:mahwar/features/provider_profile/provider_deep_link.dart';

void main() {
  const providerId = '0f8c6a52-3b7e-4f9a-9d21-1c2b3a4d5e6f';

  group('buildProviderProfileLink', () {
    test('ينتج مخطط mahwar والمضيف provider والمعرّف في الاستعلام', () {
      final link = buildProviderProfileLink(providerId);

      expect(link, 'mahwar://provider?id=$providerId');
      final uri = Uri.parse(link);
      expect(uri.scheme, 'mahwar');
      expect(uri.host, 'provider');
      expect(uri.queryParameters['id'], providerId);
    });
  });

  group('providerProfileTargetFromUri', () {
    test('يحوّل رابط QR إلى الملف العام الداخلي', () {
      final target = providerProfileTargetFromUri(
        Uri.parse(buildProviderProfileLink(providerId)),
      );

      expect(target, '/provider/profile?providerId=$providerId');
    });

    test('يرفض مخططًا أو مضيفًا مختلفًا', () {
      expect(
        providerProfileTargetFromUri(
          Uri.parse('https://provider?id=$providerId'),
        ),
        isNull,
      );
      expect(
        providerProfileTargetFromUri(Uri.parse('mahwar://orders?id=$providerId')),
        isNull,
      );
    });

    test('يرفض معرّفًا غائبًا أو غير صالح (لا ملف لمزوّد مجهول)', () {
      expect(providerProfileTargetFromUri(Uri.parse('mahwar://provider')), isNull);
      expect(
        providerProfileTargetFromUri(Uri.parse('mahwar://provider?id=')),
        isNull,
      );
      expect(
        providerProfileTargetFromUri(Uri.parse('mahwar://provider?id=abc')),
        isNull,
      );
      expect(
        providerProfileTargetFromUri(
          Uri.parse('mahwar://provider?id=$providerId%20DROP'),
        ),
        isNull,
      );
    });
  });

  test('isProviderDeepLink يميّز روابط المزوّد قبل التحقق من المعرّف', () {
    expect(isProviderDeepLink(Uri.parse('mahwar://provider')), isTrue);
    expect(isProviderDeepLink(Uri.parse('mahwar://provider?id=bad')), isTrue);
    expect(isProviderDeepLink(Uri.parse('mahwar://other?id=$providerId')), isFalse);
    expect(
      isProviderDeepLink(Uri.parse('/provider/profile?providerId=$providerId')),
      isFalse,
    );
  });

  test('رابط الدخول البديل يعيد إلى الملف العام بعد تسجيل الدخول', () {
    final target = providerProfileTargetFromUri(
      Uri.parse(buildProviderProfileLink(providerId)),
    );

    final login = loginRouteWithNext(role: AppRole.carOwner, next: target!);
    final uri = Uri.parse(login);

    expect(uri.path, '/login');
    expect(uri.queryParameters['role'], 'car_owner');
    expect(uri.queryParameters['next'], target);
  });
}
