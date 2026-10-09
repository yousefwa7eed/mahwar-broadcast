import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/auth/home_route.dart';

void main() {
  test('homeRouteForRole يترجم أدوار قاعدة البيانات الفعلية إلى مسارات مسجّلة',
      () {
    expect(homeRouteForRole('car_owner'), '/home/owner');
    expect(homeRouteForRole('provider'), '/home/provider');
  });

  test('homeRouteForRole بلا دور صالح تُرجع null (لا افتراضي car_owner)', () {
    expect(homeRouteForRole('admin'), isNull);
    expect(homeRouteForRole(''), isNull);
    expect(homeRouteForRole(null), isNull);
  });
}
