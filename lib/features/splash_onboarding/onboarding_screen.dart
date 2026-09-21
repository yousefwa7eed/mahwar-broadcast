import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'widgets/onboarding_progress_bar.dart';
import 'widgets/onboarding_story_card.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _currentIndex = 0;

  final List<Map<String, String>> _slides = [
    {
      'image': 'assets/onboarding/on1.png',
      'title': 'أسرع نجدة لطوارئ السيارات',
      'description': 'محور يربطك بأقرب أونياش وفنيي طوارئ الطرق جغرافياً في ثوانٍ معدودة.',
    },
    {
      'image': 'assets/onboarding/on2.png',
      'title': 'تسعير شفاف وبدون تعقيد',
      'description': 'استلم عرض السعر المباشر من مقدم الخدمة واقبل أو ارفض بضغطة زر.',
    },
    {
      'image': 'assets/onboarding/on3.png',
      'title': 'خدمة شاملة لكافة الأعطال',
      'description': 'سواء احتجت ونش، أو تغير إطار، بنزين، بطارية، أو ميكانيكي طوارئ.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _animController.addListener(() {
      setState(() {});
    });

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _animController.forward();
  }

  void _nextStory() {
    if (_currentIndex < _slides.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _animController.reset();
      _animController.forward();
    } else {
      _finishOnboarding();
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _animController.reset();
      _animController.forward();
    }
  }

  void _finishOnboarding() {
    _animController.stop();
    context.go('/select-user-type');
  }

  void _onTapDown(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;

    if (dx < screenWidth / 3) {
      _previousStory();
    } else {
      _nextStory();
    }
  }

  void _onLongPressStart() {
    _animController.stop();
  }

  void _onLongPressEnd() {
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSlide = _slides[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        onLongPressStart: (_) => _onLongPressStart(),
        onLongPressEnd: (_) => _onLongPressEnd(),
        child: Stack(
          children: [
            // Current Story Content
            OnboardingStoryCard(
              imagePath: currentSlide['image']!,
              title: currentSlide['title']!,
              description: currentSlide['description']!,
            ),

            // Top Header: Progress Bar & Skip Button
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  OnboardingProgressBar(
                    totalCount: _slides.length,
                    currentIndex: _currentIndex,
                    animationValue: _animController.value,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox.shrink(),
                      GestureDetector(
                        onTap: _finishOnboarding,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            'تخطي',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
