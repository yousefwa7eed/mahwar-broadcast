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
import 'core/notifications/notification_cubit.dart';
import 'core/services/app_messenger.dart';
import 'core/services/push_notification_service.dart';
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

  // مصدر واحد للإشعارات: يربطنا الـ PushNotificationService بالـ cubit
  // ليقدر يحدّث القائمة/الجرس بمجرد استلام إشعار دفع.
  final notificationCubit = NotificationCubit();
  PushNotificationService.instance.attach(notificationCubit);
  PushNotificationService.instance.initialize();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AppSettingsCubit()),
        BlocProvider(create: (_) => AuthCubit()),
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

class _MahwarAppState extends State<MahwarApp> {
  @override
  void initState() {
    super.initState();
    // رسالة ضغط فتح بها التطبيق وهو مغلق → يتوجه مباشرة للطلب/الإشعارات.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.instance.handleInitialMessage();
      // مستخدم مسجّل فعلًا → نعيد حفظ التوكن/الجهاز مرة واحدة لكل إقلاع
      // (حتى لا يبقى جهاز بلا إشعارات بعد مسح خارجي للتوكن).
      PushNotificationService.instance.ensureTokenSavedOnStart();
    });
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