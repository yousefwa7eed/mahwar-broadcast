import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_cubit.dart';
import '../../core/auth/home_route.dart';
import '../../core/models/notification_model.dart';
import '../../core/notifications/notification_cubit.dart';
import '../../core/services/push_notification_service.dart';

/// معالج اللمس الموحّد لأي إشعار داخل قوائم التطبيق — يُستخدم من صفحة
/// الإشعارات ومن تبويب الإشعارات في الرئيسية (العميل والمزوّد) بحيث يتصرف
/// الطرفان بشكل متطابق. الترتيب مطابق لجدول مسارات الـ push:
///   deep link خارجي → يُفتح في المتصفح.
///   deep_link=home → الرئيسية حسب دور المستخدم.
///   order_id → مسار الطلب حسب الدور والنوع (quote/track/provider_home/…).
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

  if (deepLink != null && deepLink.isNotEmpty && NotificationModel.isExternalLink(deepLink)) {
    // رابط خارجي → يُفتح في المتصفح خارج التطبيق.
    await NotificationModel.launchExternal(deepLink);
    return;
  }

  if (deepLink == 'home') {
    final role = await context.read<AuthCubit>().resolveCurrentRole();
    if (!context.mounted) return;
    // go() لأن الرئيسية شاشة جذرية — نتجنب تكديس نسخة فوق الأخرى. بلا دور
    // صالح لا نتنقل (بدل افتراض car_owner بصمت).
    final homeRoute = homeRouteForRole(role);
    if (homeRoute != null) context.go(homeRoute);
    return;
  }

  if (notification.orderId != null) {
    final role = await context.read<AuthCubit>().resolveCurrentRole();
    if (!context.mounted) return;
    // نفس جدول مسارات الدفع الموحّد (حسب الدور ونوع الإشعار). الدور غير
    // المعروف يُمرَّر فارغًا فيقع الجدول على شاشة التتبع الآمنة.
    context.push(
      PushNotificationService.orderRouteFor(
        orderId: notification.orderId!,
        type: notification.type,
        role: role ?? '',
      ),
    );
    return;
  }

  if (notification.type == 'broadcast') {
    // إشعار عام بدون deep link → شاشة التفاصيل الكاملة.
    context.push('/notification/detail', extra: notification);
  }
}