import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_cubit.dart';
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
        if (state is AuthAuthenticated) {
          // نوجّه للشاشة الرئيسية بناءً على الدور الفعلي للحساب المسجّل
          // (من جدول profiles) وليس على معرّف الدور الوارد من رابط الصفحة،
          // فلو مالكٍ سجّل الدخول عبر صفحة "دخول مزوّد" يبقى على الرئيسية
          // الصحيحة (ولا العكس).
          final role = await context.read<AuthCubit>().resolveCurrentRole();
          if (!context.mounted) return;
          context.go(role == 'provider' ? '/home/provider' : '/home/owner');
        } else if (state is AuthError) {
          showErrorDialog(context, state.message);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => context.go('/select-user-type'),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              children: [
                LoginHeaderWidget(role: widget.role),
                const SizedBox(height: 28),
                LoginFormWidget(
                  role: widget.role,
                  onSubmit: (identifier, password) {
                    // AuthCubit هو المسؤول عن تحديد هل identifier ده رقم
                    // هاتف أو إيميل، وتحويله للإيميل الحقيقي المرتبط بالحساب
                    // قبل محاولة الدخول.
                    context.read<AuthCubit>().signIn(
                      identifier: identifier,
                      password: password,
                    );
                  },
                  onSignupTap: () => context.push('/signup?role=${widget.role}'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}