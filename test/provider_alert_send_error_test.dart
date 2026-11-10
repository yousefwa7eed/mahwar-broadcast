import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:mahwar/features/request_tracking/provider_alert_service.dart';

void main() {
  group('parseAlertSendError — رموز Edge Function', () {
    test('رموز معروفة تُترجم', () {
      expect(
        parseAlertSendError({'error': 'provider_active'}),
        ProviderAlertSendError.providerActive,
      );
      expect(
        parseAlertSendError({'error': 'order_not_pending'}),
        ProviderAlertSendError.orderNotPending,
      );
      expect(
        parseAlertSendError({'error': 'not_owner'}),
        ProviderAlertSendError.notOwner,
      );
      expect(
        parseAlertSendError({'error': 'already_sent'}),
        ProviderAlertSendError.alreadySent,
      );
      expect(
        parseAlertSendError({'error': 'monthly_quota_used'}),
        ProviderAlertSendError.monthlyQuotaUsed,
      );
      expect(
        parseAlertSendError({'error': 'daily_cap_reached'}),
        ProviderAlertSendError.dailyCapReached,
      );
      expect(
        parseAlertSendError({'error': 'unauthenticated'}),
        ProviderAlertSendError.unauthenticated,
      );
    });

    test('جسم JSON نصي (FunctionException.details) يُفكّ', () {
      expect(
        parseAlertSendError(jsonEncode({'error': 'already_sent'})),
        ProviderAlertSendError.alreadySent,
      );
    });

    test('أي شكل غير معروف → failed (رسالة عامة)', () {
      expect(parseAlertSendError(null), ProviderAlertSendError.failed);
      expect(
        parseAlertSendError({'error': 'something_new'}),
        ProviderAlertSendError.failed,
      );
      expect(parseAlertSendError('boom'), ProviderAlertSendError.failed);
      expect(parseAlertSendError(const []), ProviderAlertSendError.failed);
    });
  });
}
