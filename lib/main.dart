import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/router/app_router.dart';
import 'core/auth/auth_cubit.dart';
import 'core/auth/profile_cubit.dart';
import 'core/notifications/notification_cubit.dart';
import 'core/services/app_messenger.dart';
import 'core/services/push_notification_service.dart';
import 'core/settings/app_settings_cubit.dart';
import 'core/settings/app_settings_state.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await Supabase.initialize(
    url: 'https://trgesfzojaoirutkkfcs.supabase.co',
    publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRyZ2VzZnpvamFvaXJ1dGtrZmNzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwNTIwMTMsImV4cCI6MjEwMTYyODAxM30.FtFVE8KilYJqU9hATPT1ylrVTjkmVx6UbQMIb_QvcXI',
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