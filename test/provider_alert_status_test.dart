import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/features/request_tracking/provider_alert_status.dart';

void main() {
  group('parseAlertReason — رموز order_provider_alert_status', () {
    test('كل رمز معروف يُترجم لقيمته', () {
      expect(parseAlertReason('ok'), ProviderAlertReason.ok);
      expect(
        parseAlertReason('provider_active'),
        ProviderAlertReason.providerActive,
      );
      expect(
        parseAlertReason('order_not_pending'),
        ProviderAlertReason.orderNotPending,
      );
      expect(
        parseAlertReason('already_alerted'),
        ProviderAlertReason.alreadyAlerted,
      );
      expect(
        parseAlertReason('monthly_quota_used'),
        ProviderAlertReason.monthlyQuotaUsed,
      );
      expect(
        parseAlertReason('daily_cap_reached'),
        ProviderAlertReason.dailyCapReached,
      );
    });

    test('قيمة غير معروفة أو null → unknown (لا تُعرض البطاقة)', () {
      expect(parseAlertReason('something_new'), ProviderAlertReason.unknown);
      expect(parseAlertReason(null), ProviderAlertReason.unknown);
      expect(parseAlertReason(''), ProviderAlertReason.unknown);
    });
  });

  group('parseProviderAlertStatus — أشكال استجابة RPC', () {
    test('قائمة بصف واحد تُقرأ كاملة', () {
      final status = parseProviderAlertStatus([
        {'is_logged_out': true, 'can_alert': true, 'reason': 'ok'},
      ]);

      expect(status.isLoggedOut, isTrue);
      expect(status.canAlert, isTrue);
      expect(status.reason, ProviderAlertReason.ok);
      expect(status.showCard, isTrue);
    });

    test('map مباشر (RPC مفرد) يُقرأ أيضًا', () {
      final status = parseProviderAlertStatus({
        'is_logged_out': true,
        'can_alert': false,
        'reason': 'monthly_quota_used',
      });

      expect(status.reason, ProviderAlertReason.monthlyQuotaUsed);
      expect(status.showCard, isTrue);
    });

    test('null/فارغ/شكل غير متوقع → hidden', () {
      for (final raw in <dynamic>[null, const [], 'oops', <dynamic>[42]]) {
        final status = parseProviderAlertStatus(raw);
        expect(status.showCard, isFalse);
        expect(status.reason, ProviderAlertReason.unknown);
      }
    });

    test('can_alert غير منطقي لا يُعامل كـ true', () {
      final status = parseProviderAlertStatus([
        {'is_logged_out': true, 'can_alert': 'yes', 'reason': 'ok'},
      ]);
      expect(status.canAlert, isFalse);
    });
  });

  group('showCard — قرار العرض في شاشة التتبع', () {
    test('يظهر فقط للمزوّد المسجّل خروجًا وسبب يخصّ التنبيه', () {
      for (final reason in [
        ProviderAlertReason.ok,
        ProviderAlertReason.monthlyQuotaUsed,
        ProviderAlertReason.dailyCapReached,
      ]) {
        final status = ProviderAlertStatus(
          isLoggedOut: true,
          canAlert: reason == ProviderAlertReason.ok,
          reason: reason,
        );
        expect(status.showCard, isTrue, reason: '$reason');
      }
    });

    test('لا يظهر لمزوّد نشط أو طلب تغيّرت حالته أو تنبيه سابق', () {
      for (final reason in [
        ProviderAlertReason.providerActive,
        ProviderAlertReason.orderNotPending,
        ProviderAlertReason.alreadyAlerted,
        ProviderAlertReason.unknown,
      ]) {
        final status = ProviderAlertStatus(
          isLoggedOut: true,
          canAlert: false,
          reason: reason,
        );
        expect(status.showCard, isFalse, reason: '$reason');
      }
    });

    test('لا يظهر إن لم يكن المزوّد مسجّل خروج أصلًا', () {
      const status = ProviderAlertStatus(
        isLoggedOut: false,
        canAlert: true,
        reason: ProviderAlertReason.ok,
      );
      expect(status.showCard, isFalse);
    });
  });
}
