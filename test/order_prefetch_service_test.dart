// اختبارات ذاكرة الجلب المسبق للطلبات:
//  - القراءة مقيّدة بمعرّف المستخدم (لا تسريب طلبات حساب لحساب آخر).
//  - عمر الذاكرة (freshness) يحدد هل تُعرض وحدها أم يُعاد الجلب.
//  - مسح كامل عند الخروج.

import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/core/models/order.dart';
import 'package:mahwar/core/services/order_prefetch_service.dart';

Order orderWithId(String id) {
  return Order.fromJson({
    'id': id,
    'car_owner_id': '00000000-0000-0000-0000-000000000002',
    'service_type_id': 'crane',
    'status': 'pending',
    'owner_phone': '01000000000',
    'latitude': 30.0,
    'longitude': 31.0,
    'car_make': 'Toyota',
    'car_model': 'Corolla',
    'car_year': 2020,
  });
}

void main() {
  final service = OrderPrefetchService.instance;

  setUp(service.stopForTesting);

  test('قراءة بمعرّف مستخدم آخر ترجع null — لا تسريب بين الحسابات', () {
    service.setOwnerOrders('user-a', [orderWithId('o1')]);

    expect(service.ownerOrdersFor('user-a'), isNotNull);
    expect(service.ownerOrdersFor('user-a')!.single.id, 'o1');
    expect(service.ownerOrdersFor('user-b'), isNull);
    expect(service.ownerOrdersFor(null), isNull);
  });

  test('ذاكرة المزوّد وذاكرة المالك منفصلتان حتى لنفس المستخدم', () {
    service.setOwnerOrders('user-a', [orderWithId('owner-order')]);
    service.setProviderOrders('user-a', [orderWithId('provider-order')]);

    expect(service.ownerOrdersFor('user-a')!.single.id, 'owner-order');
    expect(service.providerOrdersFor('user-a')!.single.id, 'provider-order');
  });

  test('الذاكرة «حديثة» داخل المدة فقط', () {
    final now = DateTime(2026, 11, 10, 12, 0);

    expect(service.isFreshWithin(null, now: now), isFalse);
    expect(
      service.isFreshWithin(
        now.subtract(const Duration(seconds: 59)),
        now: now,
      ),
      isTrue,
    );
    expect(
      service.isFreshWithin(
        now.subtract(OrderPrefetchService.cacheTtl),
        now: now,
      ),
      isFalse,
    );
  });

  test('ownerCacheIsFresh يتبع وقت آخر جلب', () {
    service.setOwnerOrders('user-a', [orderWithId('o1')]);

    expect(service.ownerCacheIsFresh(), isTrue);
    expect(
      service.ownerCacheIsFresh(
        now: DateTime.now().add(
          OrderPrefetchService.cacheTtl + const Duration(seconds: 1),
        ),
      ),
      isFalse,
    );
  });

  test('clear يفرّغ ذاكرة الدورين (يُستدعى عند الخروج)', () {
    service.setOwnerOrders('user-a', [orderWithId('o1')]);
    service.setProviderOrders('user-a', [orderWithId('o2')]);

    service.clear();

    expect(service.ownerOrdersFor('user-a'), isNull);
    expect(service.providerOrdersFor('user-a'), isNull);
    expect(service.ownerCacheIsFresh(), isFalse);
    expect(service.providerCacheIsFresh(), isFalse);
  });
}
