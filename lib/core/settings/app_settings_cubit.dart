import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_settings_state.dart';

class AppSettingsCubit extends Cubit<AppSettingsState> {
  static const _localeKey = 'app_locale';
  static const _themeKey = 'app_theme_mode';

  AppSettingsCubit()
      : super(
          const AppSettingsState(
            locale: Locale('ar'),
            themeMode: ThemeMode.light,
          ),
        ) {
    _loadPersistedSettings();
  }

  Future<void> _loadPersistedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final storedLocale = prefs.getString(_localeKey);
    final themeName = prefs.getString(_themeKey) ?? 'light';

    var localeCode = storedLocale ?? 'ar';

    if (storedLocale == null) {
      // أول إقلاع على هذا الجهاز: نتبنّى اللغة المخزّنة في الملف الشخصي (إن
      // وُجدت) حتى تتفق لغة الواجهة مع لغة إشعارات الدفع.
      final profileLanguage = await _fetchProfileLanguage();
      if (profileLanguage != null) {
        localeCode = profileLanguage;
        await prefs.setString(_localeKey, profileLanguage);
      }
    } else {
      // لغة الجهاز معروفة → نتأكد أن الملف الشخصي يطابقها مرة واحدة عند الإقلاع.
      final profileLanguage = await _fetchProfileLanguage();
      if (profileLanguage != null && profileLanguage != storedLocale) {
        await _pushLanguage(storedLocale);
      }
    }

    emit(
      AppSettingsState(
        locale: Locale(localeCode),
        themeMode: themeName == 'dark' ? ThemeMode.dark : ThemeMode.light,
      ),
    );
  }

  Future<void> toggleLocale() async {
    final nextLocale = state.locale.languageCode == 'ar'
        ? const Locale('en')
        : const Locale('ar');

    emit(state.copyWith(locale: nextLocale));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, nextLocale.languageCode);

    await _pushLanguage(nextLocale.languageCode);
  }

  /// يخزّن اللغة في profiles.language — المصدر الذي يقرأه بناء نص إشعارات الدفع
  /// لتحديد لغة المستقبِل. صامت تمامًا: محاولة ثم إعادة محاولة واحدة، ثم نستسلم
  /// بلا رمي استثناء (أوفلاين / بلا جلسة → لا يتعطّل تبديل اللغة محليًا).
  Future<void> _pushLanguage(String languageCode) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser?.id;
        if (userId == null) return;
        await client
            .from('profiles')
            .update({'language': languageCode}).eq('id', userId);
        return;
      } catch (_) {
        // إعادة محاولة واحدة فقط.
      }
    }
  }

  /// يقرأ profiles.language الحالية للجلسة، أو null إن تعذّر (بلا جلسة/أوفلاين).
  Future<String?> _fetchProfileLanguage() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;
      final row = await client
          .from('profiles')
          .select('language')
          .eq('id', userId)
          .maybeSingle();
      final value = row?['language'] as String?;
      return (value == 'ar' || value == 'en') ? value : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> toggleTheme() async {
    final nextTheme = state.themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;

    emit(state.copyWith(themeMode: nextTheme));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeKey,
      nextTheme == ThemeMode.dark ? 'dark' : 'light',
    );
  }
}
