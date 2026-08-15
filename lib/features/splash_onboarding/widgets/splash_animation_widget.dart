import 'package:flutter/material.dart';

class SplashAnimationWidget extends StatelessWidget {
  const SplashAnimationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/splash.gif',
      width: 250,
      height: 250,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B00).withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.car_repair_rounded,
            size: 90,
            color: Color(0xFFFF6B00),
          ),
        );
      },
    );
  }
}
