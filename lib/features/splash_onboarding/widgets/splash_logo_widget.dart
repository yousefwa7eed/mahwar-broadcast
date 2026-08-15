import 'package:flutter/material.dart';

class SplashLogoWidget extends StatelessWidget {
  const SplashLogoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                'assets/app_icon.png',
                width: 24,
                height: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: 'مِحْوَر',
                    style: TextStyle(color: Color(0xFF1E1E1E)),
                  ),
                  TextSpan(
                    text: ' | Mahwar',
                    style: TextStyle(
                      color: Color(0xFFFF6B00),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
