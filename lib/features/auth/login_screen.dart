import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_cubit.dart';
import '../../core/auth/home_route.dart';
import '../../core/auth/role_gate.dart';
import '../../core/settings/app_settings_cubit.dart';
import 'widgets/error_dialog.dart';
import 'widgets/login_form_widget.dart';
import 'widgets/login_header_widget.dart';

class LoginScreen extends StatefulWidget {
  final String role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// يمنع إعادة الدخول للمستمع أثناء معالجة توجيه/خروج (خاصةً خطأ الخروج
  /// الذي ينبعث نتيجة تسجيل خروج عدم التطابق — لا نعرضه فوق رسالة عدم التطابق).
  bool _resolving = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) async {
        if (_resolving) return;

        // لا نتنقل أبدًا إلا على AuthAuthenticated. أي حالة أخرى (تحميل/خطأ/
        // غير مصادق) لا توجّه — كان السبب الأصلي في التوجيه المبكر إلى شاشة
        // المالك قبل اكتمال الجلسة. نعرض أخطاء الدخول فقط ونحن على شاشة الدخول.
        if (state is! AuthAuthenticated) {
          if (state is AuthError && isTopmostRoute(context, '/login')) {
            showErrorDialog(context, state.message);
          }
          return;
        }

        // شاشة OTP أعلى هذه الشاشة أثناء تدفق التسجيل/الاستعادة هي المسؤولة
        // الوحيدة عن التنقل بعد التحقق — لا نتحرك إلا إذا كانت شاشة الدخول هي
        // الشاشة الظاهرة فعلًا.
        if (!isTopmostRoute(context, '/login')) return;

        _resolving = true;
        try {
          // الدور الفعلي من جدول profiles (المصدر الموثوق) ثم user_metadata.
          final actualRole =
              AppRole.tryParse(await context.read<AuthCubit>().resolveCurrentRole());
          if (!context.mounted) return;

          final isArabic = context
                  .read<AppSettingsCubit>()
                  .state
                  .locale
                  .languageCode ==
              'ar';

          // تعذّر تحديد الدور → لا نفترض أي دور ولا نترك المستخدم في شاشة
          // عالقة: نُخرج من الجلسة ونعرض رسالة قابلة لإعادة المحاولة.
          if (actualRole == null) {
            await context.read<AuthCubit>().signOut();
            if (!context.mounted) return;
            showErrorDialog(context, roleUnresolvedMessage(isArabic: isArabic));
            return;
          }

          final expectedRole = AppRole.tryParse(widget.role);

          // نقطة الدخول مقيّدة بالدور: حساب بدور مختلف عن صفحة الدخول التي
          // استُخدمت يُرفض — نخرج من الجلسة ونوضّح الصفحة الصحيحة.
          if (expectedRole != null && actualRole != expectedRole) {
            await context.read<AuthCubit>().signOut();
            if (!context.mounted) return;
            showErrorDialog(
              context,
              roleMismatchMessage(actualRole: actualRole, isArabic: isArabic),
            );
            return;
          }

          context.go(actualRole.homeRoute);
        } finally {
          _resolving = false;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            style: IconButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () => context.go('/select-user-type'),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                LoginHeaderWidget(role: widget.role),
                const SizedBox(height: 28),
                LoginFormWidget(
                  role: widget.role,
                  onSubmit: (identifier, password) {
                    context.read<AuthCubit>().signIn(
                          identifier: identifier,
                          password: password,
                        );
                  },
                  onSignupTap: () => context.push('/signup?role=${widget.role}'),
                  onForgotPasswordTap: () =>
                      context.push('/forgot-password?role=${widget.role}'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
