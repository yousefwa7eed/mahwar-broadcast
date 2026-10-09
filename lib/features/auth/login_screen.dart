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

  /// المهلة القصوى لقراءة الدور من الخادم (كل محاولة). قابلة للحقن للاختبارات.
  final Duration roleFetchTimeout;

  /// عدد محاولات قراءة الدور قبل اعتباره غير معروف.
  final int roleFetchAttempts;

  const LoginScreen({
    super.key,
    required this.role,
    this.roleFetchTimeout = const Duration(seconds: 10),
    this.roleFetchAttempts = 2,
  });

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

        setState(() => _resolving = true);
        try {
          // الدور الفعلي مع مهلة وإعادة محاولة — لا نُبقي الزر قابلاً للضغط
          // ولا نترك المستخدم بلا مؤشر أثناء تحديد الدور.
          final actualRole = AppRole.tryParse(
            await context.read<AuthCubit>().resolveCurrentRoleWithRetry(
                  timeout: widget.roleFetchTimeout,
                  attempts: widget.roleFetchAttempts,
                ),
          );
          if (!context.mounted) return;

          final isArabic = context
                  .read<AppSettingsCubit>()
                  .state
                  .locale
                  .languageCode ==
              'ar';

          // تعذّر تحديد الدور → رسالة فورية ثم رفض الجلسة في الخلفية (بلا
          // انتظار أي طلب شبكي حتى لا تتأخر الرسالة).
          if (actualRole == null) {
            showErrorDialog(context, roleUnresolvedMessage(isArabic: isArabic));
            context.read<AuthCubit>().rejectSession();
            return;
          }

          final expectedRole = AppRole.tryParse(widget.role);

          // نقطة الدخول مقيّدة بالدور: حساب بدور مختلف عن صفحة الدخول التي
          // استُخدمت يُرفض — نعرض الرسالة فورًا ثم نرفض الجلسة في الخلفية.
          if (expectedRole != null && actualRole != expectedRole) {
            showErrorDialog(
              context,
              roleMismatchMessage(actualRole: actualRole, isArabic: isArabic),
            );
            context.read<AuthCubit>().rejectSession();
            return;
          }

          context.go(actualRole.homeRoute);
        } finally {
          if (mounted) setState(() => _resolving = false);
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
                  isBusy: _resolving,
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
