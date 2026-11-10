import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'provider_alert_params.dart';
import 'provider_alert_status.dart';

/// أخطاء الإرسال التي تعيدها `send-provider-alert-sms` كرموز JSON.
enum ProviderAlertSendError {
  providerActive,
  orderNotPending,
  notOwner,
  alreadySent,
  monthlyQuotaUsed,
  dailyCapReached,
  unauthenticated,
  failed,
}

class ProviderAlertSmsException implements Exception {
  final ProviderAlertSendError error;
  const ProviderAlertSmsException(this.error);

  @override
  String toString() => 'ProviderAlertSmsException($error)';
}

/// قراءة/إرسال حالة تنبيه المزوّد الغائب.
///
/// التحقق النهائي (الملكية، النافذة، الحصة، السقف اليومي) يتم داخل Edge
/// Function — العميل لا يرسل إلا `order_id`.
class ProviderAlertService {
  final SupabaseClient? _clientOverride;

  ProviderAlertService({SupabaseClient? client}) : _clientOverride = client;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  Future<ProviderAlertStatus> status(String orderId) async {
    final response = await _client.rpc(
      'order_provider_alert_status',
      params: buildOrderProviderAlertStatusParams(orderId: orderId),
    );
    return parseProviderAlertStatus(response);
  }

  Future<void> send(String orderId) async {
    try {
      await _client.functions.invoke(
        'send-provider-alert-sms',
        body: {'order_id': orderId},
      );
    } on FunctionException catch (e) {
      throw ProviderAlertSmsException(parseAlertSendError(e.details));
    } catch (_) {
      throw const ProviderAlertSmsException(ProviderAlertSendError.failed);
    }
  }
}

@visibleForTesting
ProviderAlertSendError parseAlertSendError(Object? details) {
  String? code;
  if (details is Map) {
    final raw = details['error'];
    if (raw is String) code = raw;
  } else if (details is String) {
    try {
      final decoded = jsonDecode(details);
      if (decoded is Map && decoded['error'] is String) {
        code = decoded['error'] as String;
      }
    } catch (_) {
      code = details;
    }
  }

  switch (code) {
    case 'provider_active':
      return ProviderAlertSendError.providerActive;
    case 'order_not_pending':
      return ProviderAlertSendError.orderNotPending;
    case 'not_owner':
      return ProviderAlertSendError.notOwner;
    case 'already_sent':
      return ProviderAlertSendError.alreadySent;
    case 'monthly_quota_used':
      return ProviderAlertSendError.monthlyQuotaUsed;
    case 'daily_cap_reached':
      return ProviderAlertSendError.dailyCapReached;
    case 'unauthenticated':
      return ProviderAlertSendError.unauthenticated;
    default:
      return ProviderAlertSendError.failed;
  }
}
