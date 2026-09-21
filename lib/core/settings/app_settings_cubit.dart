import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final localeCode = prefs.getString(_localeKey) ?? 'ar';
    final themeName = prefs.getString(_themeKey) ?? 'light';

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
