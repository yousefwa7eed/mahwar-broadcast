import 'package:flutter/material.dart';

class OnboardingProgressBar extends StatelessWidget {
  final int totalCount;
  final int currentIndex;
  final double animationValue;

  const OnboardingProgressBar({
    super.key,
    required this.totalCount,
    required this.currentIndex,
    required this.animationValue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalCount, (index) {
        double progress = 0.0;
        if (index < currentIndex) {
          progress = 1.0;
        } else if (index == currentIndex) {
          progress = animationValue;
        } else {
          progress = 0.0;
        }

        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
