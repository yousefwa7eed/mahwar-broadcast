import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/auth/home_route.dart';
import 'package:mahwar/core/auth/role_gate.dart';

void main() {
  test(
    'homeRouteForRole يترجم أدوار قاعدة البيانات الفعلية إلى مسارات مسجّلة',
    () {
      expect(homeRouteForRole('car_owner'), '/home/owner');
      expect(homeRouteForRole('provider'), '/home/provider');
    },
  );

  test('homeRouteForRole بلا دور صالح تُرجع null (لا افتراضي car_owner)', () {
    expect(homeRouteForRole('admin'), isNull);
    expect(homeRouteForRole(''), isNull);
    expect(homeRouteForRole(null), isNull);
  });

  group('roleHomeRedirectFor', () {
    test('يترك كل دور على رئيسيته', () {
      expect(
        roleHomeRedirectFor(path: '/home/owner', role: 'car_owner'),
        isNull,
      );
      expect(
        roleHomeRedirectFor(path: '/home/provider', role: 'provider'),
        isNull,
      );
    });

    test('يعيد التوجيه من رئيسية الدور الآخر', () {
      expect(
        roleHomeRedirectFor(path: '/home/owner', role: 'provider'),
        '/home/provider',
      );
      expect(
        roleHomeRedirectFor(path: '/home/provider', role: 'car_owner'),
        '/home/owner',
      );
    });

    test('لا يوجّه خارج مسارات الرئيسية', () {
      expect(roleHomeRedirectFor(path: '/orders', role: 'provider'), isNull);
    });

    test('الدور غير المعروف لا يُخمَّن', () {
      expect(roleHomeRedirectFor(path: '/home/owner', role: 'admin'), isNull);
      expect(roleHomeRedirectFor(path: '/home/provider', role: null), isNull);
    });
  });

  group('trackingBackRouteFor', () {
    test('دور الخادم هو المصدر الأول', () {
      expect(
        trackingBackRouteFor(
          serverRole: 'provider',
          userId: 'u1',
          ownerId: 'u1',
          providerId: 'u2',
        ),
        '/home/provider',
      );
    });

    test('عند غياب الدور يعتمد عضوية الطلب', () {
      expect(
        trackingBackRouteFor(
          serverRole: null,
          userId: 'owner-1',
          ownerId: 'owner-1',
          providerId: 'provider-1',
        ),
        '/home/owner',
      );
      expect(
        trackingBackRouteFor(
          serverRole: null,
          userId: 'provider-1',
          ownerId: 'owner-1',
          providerId: 'provider-1',
        ),
        '/home/provider',
      );
    });

    test('بلا دور ولا عضوية معروفة لا يتنقّل', () {
      expect(
        trackingBackRouteFor(
          serverRole: null,
          userId: 'stranger',
          ownerId: 'owner-1',
          providerId: 'provider-1',
        ),
        isNull,
      );
      expect(
        trackingBackRouteFor(
          serverRole: null,
          userId: null,
          ownerId: null,
          providerId: null,
        ),
        isNull,
      );
    });
  });

  group('safeInternalRoute — مسار الرجوع من رابط خارجي', () {
    test('يقبل المسارات الداخلية مع الاستعلام', () {
      expect(
        safeInternalRoute('/provider/profile?providerId=p-1'),
        '/provider/profile?providerId=p-1',
      );
      expect(safeInternalRoute('/orders/owner'), '/orders/owner');
    });

    test('يرفض القيم الفارغة والمسارات النسبية', () {
      expect(safeInternalRoute(null), isNull);
      expect(safeInternalRoute(''), isNull);
      expect(safeInternalRoute('   '), isNull);
      expect(safeInternalRoute('provider/profile'), isNull);
    });

    test('يرفض أي مخطط أو سلطة (منع القفز خارج التطبيق)', () {
      expect(safeInternalRoute('https://evil.example'), isNull);
      expect(safeInternalRoute('javascript:alert(1)'), isNull);
      expect(safeInternalRoute('//evil.example/path'), isNull);
      expect(safeInternalRoute('/\\evil.example'), isNull);
    });
  });

  test('loginRouteWithNext يحافظ على الدور ويرمّز مسار الرجوع', () {
    final route = loginRouteWithNext(
      role: AppRole.carOwner,
      next: '/provider/profile?providerId=p-1',
    );

    expect(route, startsWith('/login?role=car_owner&next='));
    final next = Uri.parse(route).queryParameters['next'];
    expect(next, '/provider/profile?providerId=p-1');
  });
}
