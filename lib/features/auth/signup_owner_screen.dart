import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'widgets/owner_signup_form_widget.dart';

class SignupOwnerScreen extends StatelessWidget {
  const SignupOwnerScreen({super.key});

  void _handleSignup(
    BuildContext context,
    String fullName,
    String phone,
    String? email,
    String? nationalId,
    String make,
    String model,
    String year,
    String password,
  ) {
    // Navigate to OTP Verification Screen
    context.go('/otp-check?role=car_owner&target=$phone');
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
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'حساب مالك سيارة جديد',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E1E1E),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'إنشاء حساب جديد',
                style: TextStyle(
                  fontFamily: 'Zain',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF6B00),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'سجل بياناتك وسيارتك لتتمكن من طلب خدمات الطوارئ',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 28),
              OwnerSignupFormWidget(
                onSubmit: (fullName, phone, email, nationalId, make, model, year, password) {
                  _handleSignup(
                    context,
                    fullName,
                    phone,
                    email,
                    nationalId,
                    make,
                    model,
                    year,
                    password,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
