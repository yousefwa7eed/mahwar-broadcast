import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'widgets/splash_animation_widget.dart';
import 'widgets/splash_logo_widget.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFE8E8E6),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SplashAnimationWidget(),
              SizedBox(height: 40),
              SplashLogoWidget(),
            ],
          ),
        ),
      ),
    );
  }
}
