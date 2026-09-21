import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/auth/home_route.dart';

void main() {
  test('homeRouteForRole يترجم أدوار قاعدة البيانات الفعلية إلى مسارات مسجّلة',
      () {
    expect(homeRouteForRole('car_owner'), '/home/owner');
    expect(homeRouteForRole('provider'), '/home/provider');
  });

  test('homeRouteForRole لأي دور آخر يعود بأمان إلى منزل مالك السيارة', () {
    expect(homeRouteForRole('admin'), '/home/owner');
    expect(homeRouteForRole(''), '/home/owner');
  });
}