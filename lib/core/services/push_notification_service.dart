import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_cubit.dart';
import '../models/notification_model.dart';
import '../notifications/notification_cubit.dart';
import '../router/app_router.dart';
import 'app_messenger.dart';

/// ينسّق كل ما يخص إشعارات الدفع (FCM) على مستوى التطبيق كامل:
///  - طلب إذن الإشعارات + حفظ/تحديث التوكن في profiles.fcm_token
///  - استقبال الرسائل مهما كانت حالة التطبيق (مفتوح/في الخلفية/مغلق)
///  - فتح صفحة تتبع الطلب مباشرة بالضغط على الإشعار
///  - مزامنة قائمة الإشعارات (الجرس) بعد استلام أي إشعار — المصدر واحد
///    (جدول notifications)، فـ push هو مجرد "تنبيه"، والقائمة دائماً صحيحة.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  NotificationCubit? _cubit;
  Timer? _syncDebounce;
  bool _handlersRegistered = false;

  /// يربط الـ cubit ليتسنى تحديث القائمة عند استلام إشعار (يُنادى من main).
  void attach(NotificationCubit cubit) => _cubit = cubit;

  /// يُعرّف معالجات الرسائل مرة واحدة لمدى حياة التطبيق.
  void initialize() {
    if (_handlersRegistered) return;
    _handlersRegistered = true;

    // لا نعرض تنبيهاً نظامياً مزدوجاً — نعرض باندنا الخاص في المقدمة.
    _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
    _messaging.onTokenRefresh.listen(_onTokenRefresh);
  }

  /// طلب إذن إشعارات النظام من المستخدم (أول مرة، Android 13+).
  Future<void> requestPermission() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (_) {
      // لا نوقف أي تدفق بسبب رفض الإذن أو خطأ نظام
    }
  }

  /// إعادة حفظ توكن الجهاز الحالي (خطة بديلة إن غابت عن تدفق تسجيل الدخول).
  Future<void> saveToken() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);
    } catch (_) {
      // فشل الحفظ لا يمنع أي شيء
    }
  }

  /// يعالج رسالة فُتح بها التطبيق وهو مغلق/مقتول (يُنادى بعد إقلاع الـ UI).
  Future<void> handleInitialMessage() async {
    RemoteMessage? message;
    try {
      message = await _messaging.getInitialMessage();
    } catch (_) {
      return; // بيئات بلا plugin (مثل widget tests)
    }
    if (message == null) return;
    _syncAfterPush();
    _openFromMessage(message);
  }

  // ---------------------------------------------------------------------------
  // المعالجات
  // ---------------------------------------------------------------------------
  void _onForegroundMessage(RemoteMessage message) {
    _syncAfterPush();
    AppMessenger.showBanner(
      title: message.notification?.title ?? 'إشعار جديد',
      body: message.notification?.body,
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    _syncAfterPush();
    _openFromMessage(message);
  }

  void _openFromMessage(RemoteMessage message) {
    final orderId = message.data['order_id'] as String?;
    if (orderId != null && orderId.isNotEmpty) {
      appRouter.push('/request/track?orderId=$orderId');
      return;
    }
    final deepLink = message.data['deep_link'] as String?;
    if (deepLink != null && deepLink.isNotEmpty && NotificationModel.isExternalLink(deepLink)) {
      // رابط خارجي → يُفتح في المتصفح خارج التطبيق (لا تنقل داخل التطبيق).
      NotificationModel.launchExternal(deepLink);
      return;
    }
    if (deepLink == 'home') {
      _openHome();
      return;
    }
    // deep link غير محدد → نفتح صفحة الإشعارات فقط.
    appRouter.push('/notifications');
  }

  /// يفتح الرئيسية حسب دور المستخدم (إشعار عام بعمق link = home).
  Future<void> _openHome() async {
    final role = await AuthCubit().resolveCurrentRole();
    appRouter.push(role == 'provider' ? '/home/provider' : '/home/owner');
  }

  /// مزامنة تبعاً لأي إشعار وصل — debounce بسيط لتفادي ازدحام النداءات.
  void _syncAfterPush() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 1200), () {
      _cubit?.loadNotifications();
    });
  }

  Future<void> _onTokenRefresh(String token) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);
    } catch (_) {
      // تجاهل — سيُعاد الحفظ عند تسجيل الدخول التالي
    }
  }
}