import 'package:flutter/material.dart';

class LoginHeaderWidget extends StatelessWidget {
  final String role;
  const LoginHeaderWidget({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final bool isProvider = role == 'provider';

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/banner.png',
            height: 140,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 140,
                color: isProvider ? const Color(0xFF1E1E1E) : const Color(0xFFFF6B00),
                child: const Center(
                  child: Icon(Icons.directions_car_rounded, size: 60, color: Colors.white),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isProvider
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFFFF6B00).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isProvider ? Icons.build_rounded : Icons.directions_car_rounded,
                    size: 16,
                    color: isProvider ? Colors.white : const Color(0xFFFF6B00),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isProvider ? 'مقدم الخدمة' : 'مالك السيارة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isProvider ? Colors.white : const Color(0xFFFF6B00),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'سجل دخول',
          style: TextStyle(
            fontFamily: 'Zain',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: isProvider ? const Color(0xFF1E1E1E) : const Color(0xFFFF6B00),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'مرحباً بعودتك، يرجى إدخال بيانات حسابك للمتابعة',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
