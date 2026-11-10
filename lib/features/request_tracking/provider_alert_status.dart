import 'package:flutter/foundation.dart';

/// أسباب حالة اقتراح تنبيه المزوّد — تطابق قيم `reason` التي تُرجعها
/// `order_provider_alert_status`.
enum ProviderAlertReason {
  ok,
  providerActive,
  orderNotPending,
  alreadyAlerted,
  monthlyQuotaUsed,
  dailyCapReached,
  unknown,
}

class ProviderAlertStatus {
  final bool isLoggedOut;
  final bool canAlert;
  final ProviderAlertReason reason;

  const ProviderAlertStatus({
    required this.isLoggedOut,
    required this.canAlert,
    required this.reason,
  });

  /// البطاقة تظهر فقط للمزوّد المسجّل خروجًا داخل نافذة الساعتين، ومع سبب
  /// يخصّ التنبيه (متاح أو نفدت الحصة) — لا تُعرض بعد ردّ المزوّد أو بعد
  /// إرسال تنبيه لهذا الطلب.
  bool get showCard =>
      isLoggedOut &&
      (reason == ProviderAlertReason.ok ||
          reason == ProviderAlertReason.monthlyQuotaUsed ||
          reason == ProviderAlertReason.dailyCapReached);

  factory ProviderAlertStatus.fromJson(Map<String, dynamic> json) {
    return ProviderAlertStatus(
      isLoggedOut: json['is_logged_out'] == true,
      canAlert: json['can_alert'] == true,
      reason: parseAlertReason(json['reason'] as String?),
    );
  }

  static const ProviderAlertStatus hidden = ProviderAlertStatus(
    isLoggedOut: false,
    canAlert: false,
    reason: ProviderAlertReason.unknown,
  );
}

@visibleForTesting
ProviderAlertReason parseAlertReason(String? raw) {
  switch (raw) {
    case 'ok':
      return ProviderAlertReason.ok;
    case 'provider_active':
      return ProviderAlertReason.providerActive;
    case 'order_not_pending':
      return ProviderAlertReason.orderNotPending;
    case 'already_alerted':
      return ProviderAlertReason.alreadyAlerted;
    case 'monthly_quota_used':
      return ProviderAlertReason.monthlyQuotaUsed;
    case 'daily_cap_reached':
      return ProviderAlertReason.dailyCapReached;
    default:
      return ProviderAlertReason.unknown;
  }
}

/// استجابة RPC جدول بصف واحد. أي شكل غير متوقع يُعامل كـ «لا بطاقة».
ProviderAlertStatus parseProviderAlertStatus(dynamic response) {
  final rows = response is List
      ? response
      : (response == null ? const <dynamic>[] : <dynamic>[response]);
  if (rows.isEmpty) return ProviderAlertStatus.hidden;
  final row = rows.first;
  if (row is! Map) return ProviderAlertStatus.hidden;
  return ProviderAlertStatus.fromJson(Map<String, dynamic>.from(row));
}
