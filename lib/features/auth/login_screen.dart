import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_cubit.dart';
import '../../core/auth/home_route.dart';
import 'widgets/login_form_widget.dart';
import 'widgets/login_header_widget.dart';
import 'widgets/error_dialog.dart';

class LoginScreen extends StatefulWidget {
  final String role;
  const LoginScreen({super.key, this.role = 'car_owner'});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) async {
        // شاشة OTP أعلى هذه الشاشة أثناء تدفق التسجيل/الاستعادة هي المسؤولة
        // الوحيدة عن التنقل بعد التحقق — لا نتحرك ونُبث رحلة مزدوجة. لا
        // نتنقل إلا إذا كانت شاشة الدخول هي الشاشة الظاهرة فعلًا.
        if (!isTopmostRoute(context, '/login')) return;
        // الدور يُقرأ من جدول profiles (المصدر الموثوق) أولًا ثم من
        // user_metadata كاحتياط — وليس من نقطة الدخول التي مرّ منها
        // المستخدم (مثلاً: مالك سيارة سجّل دخوله من شاشة المزوّد).
        // هذا يطابق سلوك splash والتنقل من الإشعارات، فيُوجَّه المستخدم
        // دائمًا إلى شاشته الرئيسية حسب دوره الفعلي حتى لو استخدم شاشة
        // دخول غير مناسبة.
        final role = await context.read<AuthCubit>().resolveCurrentRole();
        if (!context.mounted) return;
        context.go(homeRouteForRole(role));
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
