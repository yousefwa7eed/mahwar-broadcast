import 'package:flutter_test/flutter_test.dart';
import 'package:mahwar/features/provider_home/availability_resolution.dart';

void main() {
  group('resolveAvailability', () {
    test('no schedule -> manual control, never touches state', () {
      for (final override in ['auto', 'on', 'off']) {
        for (final online in [true, false]) {
          for (final inHours in [true, false]) {
            expect(
              resolveAvailability(
                hasSchedule: false,
                inHours: inHours,
                availabilityOverride: override,
                isOnline: online,
              ),
              AvailabilityAction.none,
            );
          }
        }
      }
    });

    test('manual on overrides the schedule', () {
      expect(
        resolveAvailability(
          hasSchedule: true,
          inHours: false,
          availabilityOverride: 'on',
          isOnline: true,
        ),
        AvailabilityAction.none,
      );
    });

    test('manual off overrides the schedule', () {
      expect(
        resolveAvailability(
          hasSchedule: true,
          inHours: true,
          availabilityOverride: 'off',
          isOnline: false,
        ),
        AvailabilityAction.none,
      );
    });

    test('auto + inside hours + offline -> go online', () {
      expect(
        resolveAvailability(
          hasSchedule: true,
          inHours: true,
          availabilityOverride: 'auto',
          isOnline: false,
        ),
        AvailabilityAction.goOnline,
      );
    });

    test('auto + outside hours + online -> go offline', () {
      expect(
        resolveAvailability(
          hasSchedule: true,
          inHours: false,
          availabilityOverride: 'auto',
          isOnline: true,
        ),
        AvailabilityAction.goOffline,
      );
    });

    test('auto + already matching schedule -> none', () {
      expect(
        resolveAvailability(
          hasSchedule: true,
          inHours: true,
          availabilityOverride: 'auto',
          isOnline: true,
        ),
        AvailabilityAction.none,
      );
      expect(
        resolveAvailability(
          hasSchedule: true,
          inHours: false,
          availabilityOverride: 'auto',
          isOnline: false,
        ),
        AvailabilityAction.none,
      );
    });
  });
}
