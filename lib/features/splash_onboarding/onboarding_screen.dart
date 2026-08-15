import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Onboarding Screen'),
            ElevatedButton(
              onPressed: () => context.go('/select-user-type'),
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}
