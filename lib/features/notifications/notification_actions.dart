import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_cubit.dart';
import '../../core/auth/home_route.dart';
import '../../core/models/notification_model.dart';
import '../../core/notifications/notification_cubit.dart';

/// معالج اللمس الموحّد لأي إشعار داخل قوائم التطبيق — يُستخدم من صفحة
/// الإشعارات ومن تبويب الإشعارات في الرئيسية (العميل والمزوّد) بحيث يتصرف
/// الطرفان بشكل متطابق. الترتيب:
///   deep link خارجي → يُفتح في المتصفح.
///   deep_link=home → الرئيسية حسب دور المستخدم.
///   إشعار تقييم أو أي إشعار مرتبط بطلب → شاشة تفاصيل الإشعار بالمعرّف
///     (تعرض المحتوى كاملًا وزر «تفاصيل الطلب» الموجّه حسب دور الجلسة).
///   broadcast → شاشة تفاصيل الإشعار العام (العنوان والنص كاملين + وقت الإرسال).
///
/// أي إشعار ليس له أي من هذه الوجوه (نوع غير معروف بلا order_id) → لا تنقل
/// (كما كان سابقاً) فلا نعيد توجيه المستخدم لشاشة خاطئة.
Future<void> openNotificationFromList(
  BuildContext context,
  NotificationModel notification,
) async {
  if (!notification.isRead) {
    context.read<NotificationCubit>().markAsRead(notification.id);
  }

  final deepLink = notification.deepLink;

  if (deepLink != null &&
      deepLink.isNotEmpty &&
      NotificationModel.isExternalLink(deepLink)) {
    // رابط خارجي → يُفتح في المتصفح خارج التطبيق.
    await NotificationModel.launchExternal(deepLink);
    return;
  }

  if (deepLink == 'home') {
    final cubit = context.read<AuthCubit>();
    final role = cubit.cachedRole ?? await cubit.resolveCurrentRole();
    if (!context.mounted) return;
    // go() لأن الرئيسية شاشة جذرية — نتجنب تكديس نسخة فوق الأخرى. بلا دور
    // صالح لا نتنقل (بدل افتراض car_owner بصمت).
    final homeRoute = homeRouteForRole(role);
    if (homeRoute != null) context.go(homeRoute);
    return;
  }

  // أي إشعار مرتبط بطلب يفتح شاشة تفاصيل الإشعار بالمعرّف (لا بالكائن) — الشاشة
  // تجلبه مقيّدًا بـ user_id الجلسة الحالية، وتعرض زر «تفاصيل الطلب» الذي يوجّه
  // المزوّد لشاشة تفاصيل الطلب الخاصة به والمالك لشاشة التتبع. إشعار التقييم
  // يتبع نفس المسار لأن فيه تفاصيل التقييم.
  if (notification.type == 'rating_received' || notification.orderId != null) {
    context.push('/notification/detail?notificationId=${notification.id}');
    return;
  }

  if (notification.type == 'broadcast') {
    // إشعار عام بدون deep link → شاشة التفاصيل الكاملة.
    context.push('/notification/detail', extra: notification);
  }
}
