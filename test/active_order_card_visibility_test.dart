import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/models/order.dart';

Order _order({
  String? providerId,
  required OrderStatus status,
}) {
  return Order(
    id: 'order-1',
    carOwnerId: 'owner-1',
    providerId: providerId,
    serviceTypeId: 'crane',
    status: status,
    ownerPhone: '01000000000',
    latitude: 30.0,
    longitude: 31.0,
    carMake: 'Toyota',
    carModel: 'Corolla',
    carYear: 2020,
  );
}

void main() {
  group('Order.isSentToProvider', () {
    test('false when provider_id is null (draft before choosing a provider)', () {
      expect(
        _order(providerId: null, status: OrderStatus.pending).isSentToProvider,
        isFalse,
      );
    });

    test('false when provider_id is empty', () {
      expect(
        _order(providerId: '', status: OrderStatus.pending).isSentToProvider,
        isFalse,
      );
    });

    test('true when provider_id is set', () {
      expect(
        _order(providerId: 'prov-1', status: OrderStatus.pending).isSentToProvider,
        isTrue,
      );
    });
  });

  group('Order.showsActiveOrderCard (home tracking card)', () {
    test('pending + provider_id NULL => no card', () {
      expect(
        _order(providerId: null, status: OrderStatus.pending).showsActiveOrderCard,
        isFalse,
      );
    });

    test('pending + provider assigned => card', () {
      expect(
        _order(providerId: 'prov-1', status: OrderStatus.pending).showsActiveOrderCard,
        isTrue,
      );
    });

    test('priced + provider assigned => card', () {
      expect(
        _order(providerId: 'prov-1', status: OrderStatus.priced).showsActiveOrderCard,
        isTrue,
      );
    });

    test('confirmed + provider assigned => card', () {
      expect(
        _order(providerId: 'prov-1', status: OrderStatus.confirmed).showsActiveOrderCard,
        isTrue,
      );
    });

    test('priced but not yet assigned => no card', () {
      expect(
        _order(providerId: null, status: OrderStatus.priced).showsActiveOrderCard,
        isFalse,
      );
    });

    test('completed => no card', () {
      expect(
        _order(providerId: 'prov-1', status: OrderStatus.completed).showsActiveOrderCard,
        isFalse,
      );
    });

    test('cancelled => no card', () {
      expect(
        _order(providerId: 'prov-1', status: OrderStatus.cancelled).showsActiveOrderCard,
        isFalse,
      );
    });

    test('rejected_by_provider => no card', () {
      expect(
        _order(providerId: 'prov-1', status: OrderStatus.rejectedByProvider)
            .showsActiveOrderCard,
        isFalse,
      );
    });

    test('rejected_by_owner => no card', () {
      expect(
        _order(providerId: 'prov-1', status: OrderStatus.rejectedByOwner)
            .showsActiveOrderCard,
        isFalse,
      );
    });
  });
}