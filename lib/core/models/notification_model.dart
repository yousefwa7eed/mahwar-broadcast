import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

  String get title {
    if (type == 'broadcast' && metadata != null) {
      final t = metadata!['title'] as String?;
      if (t != null && t.isNotEmpty) return t;
    }
    switch (type) {
      case 'new_order':
        return 'طلب جديد';
      case 'price_offer':
        return 'عرض سعر جديد';
      case 'order_confirmed':
        return 'تم تأكيد الطلب';
      case 'order_rejected':
        return 'تم رفض الطلب';
      case 'order_cancelled':
        return 'تم إلغاء الطلب';
      case 'order_completed':
        return 'تم إتمام الطلب';
      case 'shift_started':
        return 'بدء ساعات الدوام';
      case 'shift_ended':
        return 'انتهاء ساعات الدوام';
      case 'rating_received':
        return 'تقييم جديد';
      case 'new_message':
        return 'رسالة جديدة';
      default:
        return 'إشعار جديد';
    }
  }

  String get body {
    if (metadata == null) return '';
    if (type == 'broadcast') {
      final b = metadata!['body'] as String?;
      return (b == null || b.isEmpty) ? '' : b;
    }
    final providerName = metadata!['provider_name'] as String?;
    final price = metadata!['price'];
    final serviceName = metadata!['service_name'] as String?;

    switch (type) {
      case 'price_offer':
        if (providerName != null && price != null) {
          return '$providerName قدم عرض سعر $price ج.م${serviceName != null ? ' لطلب $serviceName' : ''}';
        }
        return 'تم استلام عرض سعر جديد';
      case 'order_confirmed':
        return 'تم تأكيد طلبك بنجاح';
      case 'order_rejected':
        return providerName != null ? 'تم رفض الطلب من $providerName' : 'تم رفض الطلب';
      case 'order_cancelled':
        return 'تم إلغاء هذا الطلب';
      case 'new_order':
        return serviceName != null ? 'لديك طلب جديد: $serviceName' : 'لديك طلب جديد';
      case 'order_completed':
        return 'تم إتمام خدمة الطلب بنجاح';
      case 'rating_received':
        final rating = metadata?['rating'];
        return rating != null ? 'حصلت على تقييم $rating من 5' : 'حصلت على تقييم جديد';
      case 'shift_started':
        return 'بدأت ساعات عملك — أنت الآن متاح أمام العملاء';
      case 'shift_ended':
        return 'انتهت ساعات عملك — أصبحت الآن غير متاح';
      default:
        return '';
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
  String timeAgo([DateTime? asOf]) {
    if (createdAt == null) return '';
    final now = (asOf ?? ServerClock.instance.now).toUtc();
    final created = createdAt!;
    final diff = now.isBefore(created) ? Duration.zero : now.difference(created);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return 'منذ ${diff.inDays} يوم';
  }
}
