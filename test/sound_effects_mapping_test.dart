import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/core/models/order.dart';
import 'package:mahwar/core/services/sound_effects_service.dart';

void main() {
  group('SoundEffect.forOrderStatus', () {
    test('owner hears an offer, not an offer-sent cue, on priced', () {
      expect(
        SoundEffect.forOrderStatus(OrderStatus.priced),
        SoundEffect.newOffer,
      );
      expect(
        SoundEffect.forOrderStatus(OrderStatus.priced, forProvider: true),
        SoundEffect.offerSent,
      );
    });

    test('provider hears a new-order cue on pending', () {
      expect(
        SoundEffect.forOrderStatus(OrderStatus.pending, forProvider: true),
        SoundEffect.newOrder,
      );
      expect(SoundEffect.forOrderStatus(OrderStatus.pending), isNull);
    });

    test('approval, rejection, completion and cancellation have cues', () {
      expect(SoundEffect.forOrderStatus(OrderStatus.confirmed),
          SoundEffect.confirmed);
      expect(SoundEffect.forOrderStatus(OrderStatus.rejectedByOwner),
          SoundEffect.rejected);
      expect(SoundEffect.forOrderStatus(OrderStatus.rejectedByProvider),
          SoundEffect.rejected);
      expect(SoundEffect.forOrderStatus(OrderStatus.completed),
          SoundEffect.completed);
      expect(SoundEffect.forOrderStatus(OrderStatus.cancelled),
          SoundEffect.cancelled);
    });
  });

  group('Order.tryParseStatus', () {
    test('parses every supported status', () {
      expect(Order.tryParseStatus('pending'), OrderStatus.pending);
      expect(Order.tryParseStatus('priced'), OrderStatus.priced);
      expect(Order.tryParseStatus('confirmed'), OrderStatus.confirmed);
      expect(Order.tryParseStatus('rejected_by_provider'),
          OrderStatus.rejectedByProvider);
      expect(Order.tryParseStatus('rejected_by_owner'),
          OrderStatus.rejectedByOwner);
      expect(Order.tryParseStatus('cancelled'), OrderStatus.cancelled);
      expect(Order.tryParseStatus('completed'), OrderStatus.completed);
    });

    test('returns null for an unknown future status', () {
      expect(Order.tryParseStatus('on_the_way'), isNull);
    });
  });
}
