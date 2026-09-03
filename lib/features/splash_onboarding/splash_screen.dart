import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/auth_cubit.dart';
import 'widgets/splash_animation_widget.dart';
import 'widgets/splash_logo_widget.dart';
import 'widgets/splash_version_widget.dart';

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

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      // نحدد الدور من جدول profiles (المصدر الموثوق) مع بديل من user_metadata،
      // بدلاً من الثقة في user_metadata فقط الذي قد يكون فارغاً أو قديماً.
      final cubit = AuthCubit();
      final role = await cubit.resolveCurrentRole();
      await cubit.close();
      if (!mounted) return;
      context.go(role == 'provider' ? '/home/provider' : '/home/owner');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SplashAnimationWidget(),
              ),
            ),
            SplashLogoWidget(),
            SizedBox(height: 8),
            SplashVersionWidget(versionText: 'v1.0.0'),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
