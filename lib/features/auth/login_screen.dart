import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'widgets/login_form_widget.dart';
import 'widgets/login_header_widget.dart';

class LoginScreen extends StatefulWidget {
  final String role;
  const LoginScreen({super.key, this.role = 'car_owner'});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  void _handleLogin(String identifier, String password, bool isPhone) {
    context.go('/otp-check?role=${widget.role}&target=$identifier');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF1E1E1E)),
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
                onSubmit: _handleLogin,
                onSignupTap: () => context.push('/signup?role=${widget.role}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
