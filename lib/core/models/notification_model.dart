import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ar.dart';
import '../constants/app_colors.dart';
import '../services/server_clock.dart';
import '../utils/supabase_time.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String? orderId;
  final String type;
  final Map<String, dynamic>? metadata;
  final bool isRead;
  final DateTime? createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    this.orderId,
    required this.type,
    this.metadata,
    this.isRead = false,
    this.createdAt,
  });

factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      orderId: json['order_id'] as String?,
      type: json['type'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: parseSupabaseTimestamp(json['created_at']),
    );
  }

  /// رابط صورة اختياري (إشعار عام) يُعرض داخل الإشعار نفسه.
  String? get imageUrl {
    if (metadata == null) return null;
    final url = metadata!['image_url'] as String?;
    return (url == null || url.isEmpty) ? null : url;
  }

  /// deep link اختياري (إشعار عام) يوجّه المستخدم لمكان محدد داخل التطبيق.
  String? get deepLink {
    if (metadata == null) return null;
    final link = metadata!['deep_link'] as String?;
    return (link == null || link.isEmpty) ? null : link;
  }

  /// هل القيمة رابط خارجي (يبدأ بـ http:// أو https://) يُفتح في المتصفح؟
  static bool isExternalLink(String value) =>
      value.startsWith('http://') || value.startsWith('https://');

  /// يفتح رابطًا خارجيًا في متصفح خارج التطبيق (بدون التنقل داخل التطبيق).
  static Future<void> launchExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // تجاهل الفشل (لا نمنع أي شيء آخر)
    }
  }

  // ── Keep in sync with the edge function ───────────────────────────────────
  // The SAME text is built for PUSH delivery (in the recipient's stored
  // language) by supabase/functions/send-push-notification/notification_text.ts.
  // That file carries the FORWARD comment (edge branch → Flutter ARB key); this
  // block is the reverse pointer (ARB key → edge branch).
  //
  // Type → ARB keys (lib/l10n/app_ar.arb + lib/l10n/app_en.arb):
  //   new_order        notificationTitleNewOrder /
  //                    notificationBodyNewOrderWithService | notificationBodyNewOrder
  //   price_offer      notificationTitlePriceOffer /
  //                    notificationBodyPriceOfferWithService | notificationBodyPriceOffer
  //                    | notificationBodyPriceOfferReceived
  //   order_confirmed  notificationTitleOrderConfirmed / notificationBodyOrderConfirmed
  //   order_rejected   notificationTitleOrderRejected /
  //                    notificationBodyOrderRejectedWithProvider | notificationBodyOrderRejected
  //   order_cancelled  notificationTitleOrderCancelled / notificationBodyOrderCancelled
  //   order_completed  notificationTitleOrderCompleted / notificationBodyOrderCompleted
  //   shift_started    notificationTitleShiftStarted / notificationBodyShiftStarted
  //   shift_ended      notificationTitleShiftEnded / notificationBodyShiftEnded
  //   rating_received  notificationTitleRatingReceived /
  //                    notificationBodyRatingWithValue | notificationBodyRating
  //   new_message      notificationTitleNewMessage / notificationBodyNewMessage
  //   broadcast        metadata.title_en|title and metadata.body_en|body,
  //                    fallback notificationTitleBroadcast + empty body
  //   default          notificationTitleDefault / notificationBodyDefault
  //   time ago (client only) notificationTimeNow, notificationTimeMinutes,
  //                    notificationTimeHours, notificationTimeDays
  //   currency         egp
  //   service label    service_types.name_ar|name_en for metadata.service_type_id
  //                    (serviceTypeNameResolver), else metadata.service_name;
  //                    when neither resolves, the suffix is omitted — same as
  //                    resolveServiceName in the edge module.

  /// حقن اختياري: service_type_id → اسم الخدمة بصيغته المحلية من جدول
  /// service_types (name_ar / name_en) — يُضبط عند الإقلاع (main.dart) عبر
  /// ServiceTypeDirectory. إن لم يُحقن أو لم تُحمّل البيانات بعد نرجع إلى
  /// metadata.service_name المحفوظ عند إنشاء الإشعار (عربي فقط).
  static String? Function(String serviceTypeId, bool isArabic)?
      serviceTypeNameResolver;

  /// مطابق تمامًا لـ resolveServiceName في
  /// supabase/functions/send-push-notification/notification_text.ts
  static String? resolveServiceName(
    Map<String, dynamic>? metadata,
    String? serviceNameFromDb,
  ) {
    final fromDb = _nonEmpty(serviceNameFromDb);
    if (fromDb != null) return fromDb;
    if (metadata == null) return null;
    return _nonEmpty(metadata['service_name'] as String?);
  }

  /// نصوص localized تحتفظ بالعربية كلغة افتراضية حين لا يتوفّر [l10n]
  /// (اختبارات معزولة بدون delegates) — فالحقيقة الوحيدة هي ملفات ARB.
  static AppLocalizations _texts(AppLocalizations? l10n) =>
      l10n ?? AppLocalizationsAr();

  static String? _nonEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// اسم الخدمة في لغة العارض: أولاً من service_types عبر service_type_id،
  /// ثم من metadata.service_name، ثم null (يعني: لا تُعرض اللاحقة).
  String? _localizedServiceName(AppLocalizations texts) {
    final typeId = metadata?['service_type_id'] as String?;
    String? fromDb;
    if (typeId != null && typeId.isNotEmpty) {
      fromDb = serviceTypeNameResolver?.call(
        typeId,
        texts.localeName.startsWith('ar'),
      );
    }
    return resolveServiceName(metadata, fromDb);
  }

  String localizedTitle(AppLocalizations? l10n) {
    final texts = _texts(l10n);
    if (type == 'broadcast' && metadata != null) {
      final english = !texts.localeName.startsWith('ar');
      final title = english
          ? _nonEmpty(metadata!['title_en'] as String?) ??
              _nonEmpty(metadata!['title'] as String?)
          : _nonEmpty(metadata!['title'] as String?);
      if (title != null) return title;
      return texts.notificationTitleBroadcast;
    }
    switch (type) {
      case 'new_order':
        return texts.notificationTitleNewOrder;
      case 'price_offer':
        return texts.notificationTitlePriceOffer;
      case 'order_confirmed':
        return texts.notificationTitleOrderConfirmed;
      case 'order_rejected':
        return texts.notificationTitleOrderRejected;
      case 'order_cancelled':
        return texts.notificationTitleOrderCancelled;
      case 'order_completed':
        return texts.notificationTitleOrderCompleted;
      case 'shift_started':
        return texts.notificationTitleShiftStarted;
      case 'shift_ended':
        return texts.notificationTitleShiftEnded;
      case 'rating_received':
        return texts.notificationTitleRatingReceived;
      case 'new_message':
        return texts.notificationTitleNewMessage;
      default:
        return texts.notificationTitleDefault;
    }
  }

  String localizedBody(AppLocalizations? l10n) {
    final texts = _texts(l10n);
    final meta = metadata;

    if (type == 'broadcast') {
      if (meta == null) return '';
      final english = !texts.localeName.startsWith('ar');
      final body = english
          ? _nonEmpty(meta['body_en'] as String?) ??
              _nonEmpty(meta['body'] as String?)
          : _nonEmpty(meta['body'] as String?);
      return body ?? '';
    }

    final providerName =
        meta == null ? null : _nonEmpty(meta['provider_name'] as String?);
    final price = meta?['price'];
    final rating = meta?['rating'];
    final serviceName = _localizedServiceName(texts);
    final currency = texts.egp;

    switch (type) {
      case 'price_offer':
        if (providerName != null && price != null) {
          if (serviceName != null) {
            return texts.notificationBodyPriceOfferWithService(
              providerName,
              '$price',
              currency,
              serviceName,
            );
          }
          return texts.notificationBodyPriceOffer(
            providerName,
            '$price',
            currency,
          );
        }
        return texts.notificationBodyPriceOfferReceived;
      case 'order_confirmed':
        return texts.notificationBodyOrderConfirmed;
      case 'order_rejected':
        if (providerName != null) {
          return texts.notificationBodyOrderRejectedWithProvider(providerName);
        }
        return texts.notificationBodyOrderRejected;
      case 'order_cancelled':
        return texts.notificationBodyOrderCancelled;
      case 'new_order':
        if (serviceName != null) {
          return texts.notificationBodyNewOrderWithService(serviceName);
        }
        return texts.notificationBodyNewOrder;
      case 'order_completed':
        return texts.notificationBodyOrderCompleted;
      case 'rating_received':
        if (rating != null) {
          return texts.notificationBodyRatingWithValue('$rating');
        }
        return texts.notificationBodyRating;
      case 'shift_started':
        return texts.notificationBodyShiftStarted;
      case 'shift_ended':
        return texts.notificationBodyShiftEnded;
      case 'new_message':
        return texts.notificationBodyNewMessage;
      default:
        return texts.notificationBodyDefault;
    }
  }

  IconData get icon {
    switch (type) {
      case 'price_offer':
        return Icons.request_quote_rounded;
      case 'order_confirmed':
        return Icons.check_circle_rounded;
      case 'order_rejected':
        return Icons.cancel_rounded;
      case 'order_cancelled':
        return Icons.stop_circle_rounded;
      case 'new_order':
        return Icons.add_circle_outline_rounded;
      case 'order_completed':
        return Icons.check_circle_rounded;
      case 'rating_received':
        return Icons.star_rounded;
      case 'shift_started':
        return Icons.alarm_on_rounded;
      case 'shift_ended':
        return Icons.alarm_off_rounded;
      case 'new_message':
        return Icons.chat_rounded;
      case 'broadcast':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  /// اللون حسب حالة الإشعار:
  ///  - أخضر: طلب تم (مؤكد / مكتمل)
  ///  - أحمر: طلب مرفوض (سواء من طرف أو آخر) / ملغى
  ///  - برتقالي: في انتظار الرد (طلب جديد / عرض سعر)
  Color get color {
    switch (type) {
      case 'order_confirmed':
      case 'order_completed':
        return AppColors.notifSuccess;
      case 'order_rejected':
      case 'order_cancelled':
        return AppColors.notifDanger;
      case 'price_offer':
      case 'new_order':
        return AppColors.notifPending;
      case 'rating_received':
        return AppColors.notifRating;
      case 'shift_started':
        return AppColors.notifSuccess;
      case 'shift_ended':
        return AppColors.notifDefault;
      case 'broadcast':
        return AppColors.notifBroadcast;
      default:
        return AppColors.notifDefault;
    }
  }

  /// الناتج هو "منذ ..." محسوباً ضد مرجع [asOf] (يُفترض أنه زمن الخادم UTC) لا
  /// ضد ساعة الجهاز — فالجهاز ذو ساعة غير مزامنة لا يغيّر ما يراه المستخدم.
  /// إذا سقط [asOf] نستخدم ServerClock.instance.now كملاذ أخير.
  String timeAgo([DateTime? asOf, AppLocalizations? l10n]) {
    if (createdAt == null) return '';
    final texts = _texts(l10n);
    final now = (asOf ?? ServerClock.instance.now).toUtc();
    final created = createdAt!;
    final diff = now.isBefore(created) ? Duration.zero : now.difference(created);
    if (diff.inMinutes < 1) return texts.notificationTimeNow;
    if (diff.inMinutes < 60) {
      return texts.notificationTimeMinutes(diff.inMinutes);
    }
    if (diff.inHours < 24) return texts.notificationTimeHours(diff.inHours);
    return texts.notificationTimeDays(diff.inDays);
  }
}
