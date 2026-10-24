import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/router/app_router.dart';
import 'core/config/app_config.dart';
import 'core/auth/auth_cubit.dart';
import 'core/auth/profile_cubit.dart';
import 'core/auth/secure_local_storage.dart';
import 'core/models/notification_model.dart';
import 'core/notifications/notification_cubit.dart';
import 'core/services/app_messenger.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/screen_time_service.dart';
import 'core/services/service_type_directory.dart';
import 'core/services/sound_effects_service.dart';
import 'core/settings/app_settings_cubit.dart';
import 'core/settings/app_settings_state.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

/// Once-only migration: Supabase used to persist the session plaintext under
/// this key in SharedPreferences. Now the session lives in secure storage, so
/// this stale key is removed a single time. Safe to run even when the key is
/// already gone; the `supabase.auth.token-code-verifier` key is left untouched.
Future<void> clearLegacySharedPreferencesSessionKey() async {
  const legacySessionKey = 'sb-trgesfzojaoirutkkfcs-auth-token';
  const migrationMarkerKey = 'sb_legacy_session_key_cleared';

  final prefs = await SharedPreferences.getInstance();

  if (prefs.getBool(migrationMarkerKey) ?? false) {
    return;
  }

  await prefs.remove(legacySessionKey);
  await prefs.setBool(migrationMarkerKey, true);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await clearLegacySharedPreferencesSessionKey();
  await Firebase.initializeApp();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      localStorage: SecureLocalStorage(),
    ),
  );

  // اسم الخدمة داخل الإشعارات بلغة العارض (service_types.name_ar/name_en)
  // بدل الاسم العربي المحفوظ لحظة إنشاء الإشعار. يُحمَّل مرة واحدة في الخلفية،
  // وعند فشله نرجع تلقائيًا إلى metadata.service_name.
  NotificationModel.serviceTypeNameResolver = (id, isArabic) =>
      ServiceTypeDirectory.instance.nameFor(id, isArabic);
  ServiceTypeDirectory.instance.ensureLoaded();

  // مصدر واحد للإشعارات: يربطنا الـ PushNotificationService بالـ cubit
  // ليقدر يحدّث القائمة/الجرس بمجرد استلام إشعار دفع.
  final notificationCubit = NotificationCubit();
  PushNotificationService.instance.attach(notificationCubit);
  PushNotificationService.instance.initialize();

  // تتبّع الشاشات لجدول page_views. يُشغَّل هنا (لا من داخل الـ observer نفسه)
  // حتى تبقى الخدمة خاملة في اختبارات الـ widget التي تمرّر appRouter.
  ScreenTimeService.instance.start();

  // مؤثرات الطلب: تُفعّل هنا فقط فتبقى صامتة تماماً في الاختبارات.
  SoundEffectsService.instance.enable();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AppSettingsCubit()),
        // مؤقّت الإبطال الدوري أثرٌ جانبي على مستوى العملية، فيُشغَّل هنا
        // صراحةً بدل أن يبدأ تلقائيًا داخل كل AuthCubit (يبقى الـ cubit خاليًا
        // من المؤقّتات في الاختبارات).
        BlocProvider(
          create: (_) =>
              AuthCubit(revocationPollInterval: const Duration(seconds: 90)),
        ),
        BlocProvider(create: (_) => ProfileCubit()..loadProfile()),
        BlocProvider(create: (_) => notificationCubit),
      ],
      child: const MahwarApp(),
    ),
  );
}

class MahwarApp extends StatefulWidget {
  const MahwarApp({super.key});

  @override
  State<MahwarApp> createState() => _MahwarAppState();
}

class _MahwarAppState extends State<MahwarApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // رسالة ضغط فتح بها التطبيق وهو مغلق → يتوجه مباشرة للطلب/الإشعارات.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final push = PushNotificationService.instance;
      push.handleInitialMessage();
      // مستخدم مسجّل فعلًا → نعيد تسجيل توكن الجهاز (حتى لا يبقى بلا
      // إشعارات بعد دوران/حذف للتوكن) ونتأكد من إذن إشعارات النظام.
      push.ensureTokenSaved();
      push.ensurePermission();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// الرجوع من الخلفية: تعليق النظام للتطبيق يُسقط socket الـ Realtime،
  /// والأحداث التي وقعت أثناء التعليق **لا يُعاد بثّها** — لذا نعيد الجلب من
  /// الخادم بدل الاعتماد على الاشتراك الحي:
  ///  - AuthCubit يتحقق من إشارة إبطال الجلسة فوراً بدل انتظار مؤقّته الدوري.
  ///  - قائمة الإشعارات (الجرس) تُحمَّل من جديد ويُعاد تأكيد الاشتراك.
  ///  - توكن الدفع يُعاد تسجيله إن مضت مهلته (يشفى بعد حذف/دوران).
  /// الشاشات المفتوحة تعيد جلب بياناتها بنفسها عبر مراقب دورة حياتها.
  /// المراقبة هنا لا داخل الـ cubits حتى تبقى قابلة للبناء في اختبارات
  /// الوحدة بلا WidgetsBinding.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    context.read<AuthCubit>().revalidateSessionOnResume();

    final notifications = context.read<NotificationCubit>();
    notifications.loadNotifications();
    notifications.subscribeToNotifications();

    PushNotificationService.instance.ensureTokenSaved();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppSettingsCubit, AppSettingsState>(
      builder: (context, settings) {
        return MaterialApp.router(
          title: 'محور | Mahwar',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings.themeMode,
          routerConfig: appRouter,
          scaffoldMessengerKey: AppMessenger.messengerKey,
          locale: settings.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        );
      },
    );
  }
}
