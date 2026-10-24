import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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
///  - طلب إذن الإشعارات + تسجيل توكن الجهاز في `device_tokens`
///  - استقبال الرسائل مهما كانت حالة التطبيق (مفتوح/في الخلفية/مغلق)
///  - فتح صفحة تتبع الطلب مباشرة بالضغط على الإشعار
///  - مزامنة قائمة الإشعارات (الجرس) بعد استلام أي إشعار — المصدر واحد
///    (جدول notifications)، فـ push هو مجرد "تنبيه"، والقائمة دائماً صحيحة.
///
/// التسجيل صفّ لكل (حساب، جهاز) عبر RPC `register_device_token`، والصفّ يبقى
/// بعد الخروج — فالحساب يستمر في استقبال إشعاراته على جهازه (مثلاً هاتف ورشة
/// واحد عليه حساب مزوّد وحساب مالك). الخادم يرسل لكل توكنات المستقبِل.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  NotificationCubit? _cubit;
  Timer? _syncDebounce;
  bool _handlersRegistered = false;
  DateTime? _lastTokenSave;
  bool _permissionWarningShown = false;

  /// مهلة إعادة التسجيل التلقائي: كافية لتغطية العودة من الخلفية بلا نداء
  /// متكرر، وقصيرة بما يكفي لشفاء توكن حُذف من الخادم (موت التوكن).
  static const Duration _tokenSaveInterval = Duration(minutes: 5);

  /// منصة الجهاز كما يقبلها قيد `device_tokens.platform`.
  static final String _platform = switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => 'web',
  };

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

  /// يفحص إذن إشعارات النظام ويطلبه إن لم يُقرَّر بعد، وينبّه المستخدم مرة
  /// واحدة لكل جلسة عند تعطّله. بلا إذن لا يظهر أي دفع على الجهاز وإن كان
  /// التوكن سليماً والخادم أجاب `sent` — فشل صامت بالكامل من جهة المستخدم.
  Future<void> ensurePermission() async {
    try {
      var settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      debugPrint(
        '[Push] notification permission: ${settings.authorizationStatus.name}',
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          !_permissionWarningShown) {
        _permissionWarningShown = true;
        _warnPermissionDenied();
      }
    } catch (e) {
      // بيئات بلا plugin (اختبارات) أو رفض نظام — لا نوقف أي تدفق.
      debugPrint('[Push] permission check failed: $e');
    }
  }

  /// تنبيه الإذن المعطّل. السياق يُقرأ لحظياً من مفتاح الرسول العام لا من
  /// سياق مُمرَّر، لأن الاستدعاء يأتي بعد فجوات async.
  void _warnPermissionDenied() {
    const fallback =
        'إشعارات النظام معطّلة — فعّلها من إعدادات التطبيق حتى تصلك تنبيهات الطلبات';
    final ctx = AppMessenger.messengerKey.currentContext;
    AppMessenger.showText(
      ctx == null
          ? fallback
          : AppLocalizations.of(ctx)?.notificationsPermissionDenied ?? fallback,
    );
  }

  /// يسجّل توكن الجهاز الحالي للحساب الحالي — يُستدعى عند الدخول دائماً
  /// (بلا مهلة) لأن تبديل الحساب على نفس الجهاز يجب أن يُسجَّل فوراً.
  Future<void> saveToken() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint(
          '[Push] getToken returned null — no FCM registration on this device',
        );
        return;
      }
      await _register(token, userId);
    } catch (e) {
      // بيئات بلا firebase/Supabase (اختبارات) أو فشل شبكة: لا نوقف أي تدفق،
      // لكن لا نصمت — الصمت هنا هو ما أخفى غياب توكن المزوّد سابقاً.
      debugPrint('[Push] token save FAILED: $e');
    }
  }

  /// إعادة تسجيل التوكن بمهلة [_tokenSaveInterval] — للإقلاع والعودة من
  /// الخلفية، فيشفى التوكن بعد أي حذف خارجي دون نداء عند كل تبديل تطبيق.
  Future<void> ensureTokenSaved() async {
    final last = _lastTokenSave;
    if (last != null && DateTime.now().difference(last) < _tokenSaveInterval) {
      return;
    }
    await saveToken();
  }

  /// يكتب (الحساب، الجهاز، التوكن) عبر RPC الخادم. الصف يخص هذا الحساب وحده؛
  /// لا نلمس صفوف حسابات أخرى تشترك في نفس الجهاز (منع اختطاف الإشعارات).
  /// التوكنات الميتة ينظّفها الخادم عند UNREGISTERED لا العميل.
  Future<void> _register(String token, String userId) async {
    final client = Supabase.instance.client;
    final deviceId = await DeviceIdentity.instance.get();
    // حارس الهوية: لا نربط توكن الجهاز بحساب لم يعد هو الحالي (تبديل حساب
    // أثناء النداء) — وإلّا استقبل الحساب الخاطئ إشعارات هذا الجهاز.
    if (client.auth.currentUser?.id != userId) return;
    await client.rpc(
      'register_device_token',
      params: {
        'p_token': token,
        'p_device_id': deviceId,
        'p_platform': _platform,
      },
    );
    _lastTokenSave = DateTime.now();
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
      title:
          message.notification?.title ??
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
      if (deepLink != null &&
          deepLink.isNotEmpty &&
          NotificationModel.isExternalLink(deepLink)) {
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
    if (deepLink != null &&
        deepLink.isNotEmpty &&
        NotificationModel.isExternalLink(deepLink)) {
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
      screen == 'quote' ? '/request/quote?orderId=$orderId' : '/home/provider',
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
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      await _register(token, userId);
    } catch (e) {
      // يُعاد التسجيل عند الإقلاع/العودة من الخلفية التالية.
      debugPrint('[Push] token refresh registration FAILED: $e');
    }
  }
}
