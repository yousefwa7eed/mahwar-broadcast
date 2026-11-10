import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mahwar/core/constants/app_colors.dart';
import 'package:mahwar/core/settings/app_settings_cubit.dart';
import 'package:mahwar/core/settings/app_settings_state.dart';
import 'package:mahwar/core/theme/app_theme.dart';
import 'package:mahwar/features/select_user_type/select_user_type_screen.dart';
import 'package:mahwar/features/select_user_type/widgets/select_type_header.dart';
import 'package:mahwar/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp(AppSettingsCubit cubit) {
    return BlocProvider<AppSettingsCubit>.value(
      value: cubit,
      child: BlocBuilder<AppSettingsCubit, AppSettingsState>(
        builder: (context, settings) {
          return MaterialApp(
            locale: settings.locale,
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            themeAnimationDuration: const Duration(milliseconds: 350),
            home: const SelectUserTypeScreen(),
          );
        },
      ),
    );
  }

  testWidgets('شاشة اختيار نوع المستخدم تتبع الوضع الداكن', (tester) async {
    SharedPreferences.setMockInitialValues({'app_theme_mode': 'dark'});
    final cubit = AppSettingsCubit();
    addTearDown(cubit.close);

    await tester.pumpWidget(buildApp(cubit));
    await tester.pumpAndSettle();

    expect(cubit.state.themeMode, ThemeMode.dark);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, AppColors.darkBackground);

    // زر الثيم يعرض الحالة الفعلية (شمس = داكن) بدل القمر الثابت.
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
  });

  testWidgets('تبديل اللغة يعيد الواجهة باللغة الجديدة', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cubit = AppSettingsCubit();
    addTearDown(cubit.close);

    await tester.pumpWidget(buildApp(cubit));
    await tester.pumpAndSettle();

    // زر اللغة أصبح أيقونة فقط (ترجمة) بلا نص.
    expect(find.byIcon(Icons.translate_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.translate_rounded));
    await tester.pumpAndSettle();

    expect(cubit.state.locale.languageCode, 'en');
    expect(
      find.descendant(
        of: find.byType(SelectTypeHeader),
        matching: find.text('Mahwar'),
      ),
      findsOneWidget,
    );
    // الشجرة العربية خرجت بالكامل بعد الجهة الجديدة.
    expect(find.text('مالك السيارة'), findsNothing);
    expect(find.text('Car Owner'), findsOneWidget);
  });
}
