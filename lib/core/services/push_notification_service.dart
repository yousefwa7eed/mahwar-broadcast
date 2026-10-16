import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_service.dart';
import '../auth/home_route.dart';
import '../auth/role_gate.dart';
import '../models/notification_model.dart';
import '../notifications/notification_cubit.dart';
import '../../l10n/app_localizations.dart';
import '../router/app_router.dart';
import 'app_messenger.dart';
import 'device_identity.dart';

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
  bool _startupSaveAttempted = false;

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
      final deviceId = await DeviceIdentity.instance.get();
      if (Supabase.instance.client.auth.currentUser?.id != userId) return;
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token, 'device_id': deviceId})
          .eq('id', userId);
    } catch (_) {
      // فشل الحفظ لا يمنع أي شيء
    }
  }

  /// إعادة حفظ fcm_token + device_id عند إقلاع التطبيق إذا كان المستخدم
  /// مسجّلًا فعلًا — مرة واحدة لكل إقلاع (لتفادي تكرار النداء). ضمانة إعادة
  /// ربط الجهاز بعد أي مسح خارجي للتوكن (مثل تنظيف Stage 4) دون انتظار تسجيل
  /// دخول أو تحديث توكن من FCM. نفس حارس الهوية داخل [saveToken]: نلتقط
  /// userId ثم نتأكد أنه ما زال المستخدم الحالي قبل الكتابة.
  Future<void> ensureTokenSavedOnStart() async {
    if (_startupSaveAttempted) return;
    _startupSaveAttempted = true;
    await saveToken();
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
    final ctx = AppMessenger.messengerKey.currentContext;
    final l10n = ctx == null ? null : AppLocalizations.of(ctx);
    AppMessenger.showBanner(
      title: message.notification?.title ??
          l10n?.notificationTitleDefault ??
          'إشعار جديد',
      body: message.notification?.body,
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    _syncAfterPush();
    _openFromMessage(message);
  }

  /// الوجهة الصحيحة لمسة إشعار مرتبط بطلب — جدول موحّد واحد (نفس قواعد الخادم
  /// في send-push-notification) يغطي كل أنواع الإشعارات حسب دور المستقبِل:
  ///   provider + new_order        → شاشة القبول/عرض السعر.
  ///   provider + order_confirmed  → الرئيسية (بطاقة الطلب فيها زر «إتمام الطلب»).
  ///   provider + rating_received  → صفحة الإشعارات (لا إجراء على الطلب).
  ///   provider + rejected/cancelled → شاشة التتبع (كتلة الحالة العامة).
  ///   car_owner + أي طلب          → شاشة التتبع (يقبل/يرفض السعر من نفس الشاشة).
  /// التركيبات غير المطابقة (دور/نوع غير متوقع) → شاشة التتبع بأمان.
  static String orderRouteFor({
    required String orderId,
    required String type,
    required String role,
  }) {
    if (role == 'provider') {
      switch (type) {
        case 'new_order':
          return '/request/quote?orderId=$orderId';
        case 'order_confirmed':
          return AppRole.provider.homeRoute;
        case 'rating_received':
          return '/notifications';
        case 'order_rejected':
        case 'order_cancelled':
          return '/request/track?orderId=$orderId';
      }
    }
    // car_owner (أو نوع/دور غير معروف) مع order_id ↔ شاشة التتبع بأمان.
    return '/request/track?orderId=$orderId';
  }

  /// وجهة إشعار مرتبط بطلب مع مراعاة **حالة الطلب الحالية**: أي إشعار لطلب
  /// انتهى (مكتمل/مرفوض/ملغى) يُفتح على شاشة التتبع حيث «ملخّص المعاملة»، بدل
  /// الوصول لشاشة إجراء لم يعد لها معنى (مثل «عرض السعر» بعد انتهاء المعاملة).
  /// عند تعذّر قراءة الحالة (شبكة) نتراجع للجدول الثابت [orderRouteFor].
  static Future<String> resolveOrderRoute({
    required String orderId,
    required String type,
    required String role,
  }) async {
    final route = orderRouteFor(orderId: orderId, type: type, role: role);
    final finished = await orderIsFinalized(orderId);
    if (finished == true) {
      // الطلب انتهى — تُعرض حالة النهاية وملخّص المعاملة في شاشة التتبع لكلا
      // الطرفين، بدل شاشة إجراء (عرض سعر/بطاقة نشطة) تجاوزها الزمن.
      return '/request/track?orderId=$orderId';
    }
    return route;
  }

  /// هل الطلب وصل لحالة نهائية؟ null عند تعذّر القراءة (نتراجع بأمان للجدول).
  static Future<bool?> orderIsFinalized(String orderId) async {
    try {
      final row = await Supabase.instance.client
          .from('orders')
          .select('status')
          .eq('id', orderId)
          .maybeSingle();
      final status = row?['status'] as String?;
      if (status == null) return null;
      return status == 'completed' ||
          status == 'rejected_by_provider' ||
          status == 'rejected_by_owner' ||
          status == 'cancelled';
    } catch (_) {
      return null;
    }
  }

  void _openFromMessage(RemoteMessage message) {
    final data = message.data;
    final screen = data['screen'] as String?;
    final orderId = data['order_id'] as String?;
    final type = data['type'] as String?;
    final deepLink = data['deep_link'] as String?;

    // 1) رسالة تحمل order_id → ننفّذ وجهة الخادم الصريحة (quote/track/
    //    provider_home/notifications)، وإن كانت قديمة أو القيمة غير معروفة
    //    فنقرر بأمان حسب الدور والنوع (نفس الجدول).
    if (orderId != null && orderId.isNotEmpty) {
      // إشعار تقييم: يُفتح على شاشة تفاصيل الإشعار (محتوى التقييم + رابط
      // تفاصيل المعاملة) بدل الاكتفاء بصفحة الإشعارات.
      if (type == 'rating_received') {
        _openNotificationDetail(data['notification_id'] as String?);
        return;
      }
      switch (screen) {
        case 'quote':
        case 'provider_home':
          // شاشة إجرائية — قد يكون الطلب انتهى؛ نتحقق ونحوّل لشاشة التتبع
          // (ملخّص المعاملة) عند اللزوم.
          _openActionableOrder(orderId, type, screen!);
          return;
        case 'track':
          appRouter.push('/request/track?orderId=$orderId');
          return;
        case 'notifications':
          appRouter.push('/notifications');
          return;
      }
      // 2) رسالة قديمة/غير مكتملة الحقل screen (null أو غير معروف) =>
      //    نقرر حسب دور المستقبِل ونوع الإشعار بدل افتراض شاشة العميل.
      _openOrderByRole(orderId, type);
      return;
    }

    // إشعار حدود ساعات العمل (مزوّد): يفتح الرئيسية مباشرة عبر go() — يحلّ محل
    // الشاشات المكدّسة ولا يفتح نسخة ثانية من لوحة المزوّد.
    if (type == 'shift_started' || type == 'shift_ended') {
      _openHome();
      return;
    }

    // 3) إشعار عام (broadcast) — لا order_id، ولا screen دالّ على وجهة طلب.
    //    نعطي الأولوية للـ deep link (خارجي → متصفح، home → رئيسية حسب الدور)،
    //    وفي غيابه نفتح شاشة التفاصيل الكاملة (العنوان والنص ووقت الإرسال)
    //    بدلاً من الاكتفاء بصفحة الإشعارات.
    if (type == 'broadcast') {
      if (deepLink != null && deepLink.isNotEmpty && NotificationModel.isExternalLink(deepLink)) {
        NotificationModel.launchExternal(deepLink);
        return;
      }
      if (deepLink == 'home') {
        _openHome();
        return;
      }
      _openNotificationDetail(data['notification_id'] as String?);
      return;
    }

    if (screen == 'notifications') {
      appRouter.push('/notifications');
      return;
    }
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

  /// مسار آمن لرسالة قديمة تحمل order_id بدون screen معرّف (أو بقيمة غير
  /// معروفة): نستنتج الوجهة من الدور والنوع بنفس قاعدة مسارات القائمة، مع مراعاة
  /// حالة الطلب (الطلب المنتهي → ملخّص المعاملة في شاشة التتبع).
  Future<void> _openOrderByRole(String orderId, String? type) async {
    final role = await resolveCurrentUserRole(SupabaseAuthService());
    final route = await PushNotificationService.resolveOrderRoute(
      orderId: orderId,
      type: type ?? '',
      role: role ?? '',
    );
    appRouter.push(route);
  }

  /// شاشة إجرائية (عرض سعر / رئيسية المزوّد) لإشعار طلب — لكن إن كان الطلب قد
  /// انتهى بالفعل نحوّل لشاشة التتبع (ملخّص المعاملة) بدل فتح شاشة تجاوزها الزمن.
  Future<void> _openActionableOrder(
    String orderId,
    String? type,
    String screen,
  ) async {
    final finished = await PushNotificationService.orderIsFinalized(orderId);
    if (finished == true) {
      appRouter.push('/request/track?orderId=$orderId');
      return;
    }
    appRouter.push(
      screen == 'quote'
          ? '/request/quote?orderId=$orderId'
          : '/home/provider',
    );
  }

  /// يفتح شاشة تفاصيل الإشعار (عام أو تقييم) قادمة من الـ push: نجلب صفّ الإشعار
  /// من جدول notifications عبر notification_id (المصدر الوحيد للبيانات — كما في
  /// send-push-notification) ثم نعرض شاشة التفاصيل الكاملة. إن تعذّر الجلب
  /// (معرف ناقص/محذوف/خطأ) نلجأ إلى صفحة الإشعارات بأمان.
  Future<void> _openNotificationDetail(String? notificationId) async {
    if (notificationId == null || notificationId.isEmpty) {
      appRouter.push('/notifications');
      return;
    }
    try {
      final response = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('id', notificationId)
          .maybeSingle();
      if (response == null) {
        appRouter.push('/notifications');
        return;
      }
      appRouter.push(
        '/notification/detail',
        extra: NotificationModel.fromJson(response),
      );
    } catch (_) {
      appRouter.push('/notifications');
    }
  }

  /// يفتح الرئيسية حسب دور المستخدم (إشعار عام بعمق link = home).
  Future<void> _openHome() async {
    final role = await resolveCurrentUserRole(SupabaseAuthService());
    // go() لأن الرئيسية شاشة جذرية — نتجنب تكديس نسخة فوق الشاشات الحالية.
    // بلا دور صالح لا نتنقل (بدل افتراض car_owner بصمت).
    final homeRoute = homeRouteForRole(role);
    if (homeRoute != null) appRouter.go(homeRoute);
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
      final deviceId = await DeviceIdentity.instance.get();
      if (Supabase.instance.client.auth.currentUser?.id != userId) return;
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token, 'device_id': deviceId})
          .eq('id', userId);
    } catch (_) {
      // تجاهل — سيُعاد الحفظ عند تسجيل الدخول التالي
    }
  }
}