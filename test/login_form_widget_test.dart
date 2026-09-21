import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mahwar/core/auth/auth_cubit.dart';
import 'package:mahwar/core/settings/app_settings_cubit.dart';
import 'package:mahwar/features/auth/widgets/login_form_widget.dart';
import 'package:mahwar/l10n/app_localizations.dart';

import 'fakes/fake_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildApp({
    required void Function() onForgotPasswordTap,
  }) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AppSettingsCubit>(create: (_) => AppSettingsCubit()),
        BlocProvider<AuthCubit>(create: (_) => AuthCubit(service: FakeAuthService())),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: LoginFormWidget(
            role: 'car_owner',
            onSubmit: (_, _) {},
            onSignupTap: () {},
            onForgotPasswordTap: onForgotPasswordTap,
          ),
        ),
      ),
    );
  }

  testWidgets('رابط "نسيت كلمة المرور؟" يظهر ويطلق الـ callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildApp(onForgotPasswordTap: () => tapped = true));

    expect(find.text('نسيت كلمة المرور؟'), findsOneWidget);

    await tester.tap(find.text('نسيت كلمة المرور؟'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}