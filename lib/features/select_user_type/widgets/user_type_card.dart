import 'dart:math' as math;

import 'package:flutter/material.dart';

/// كرت اختيار النوع: تدرّج بريمي خفيف + حواف لامعة متدرجة (gradient border)
/// + لمعة ناعمة أعلى الكرت، بلا زوايا حادة إطلاقاً.
class UserTypeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData iconData;
  final LinearGradient gradient;
  final Color shadowColor;
  final double themeT;

  /// تُمرَّر من الشاشة بدل قراءة اللغة الحالية مباشرة: أثناء تبديل اللغة يبقى
  /// الكرت القديم (خارج الشاشة الآن) بنصّه وخطّه الأصليين حتى يختفي.
  final bool isArabic;

  /// 0 = دائرة السهم يميناً (إنجليزي)، 1 = يساراً (عربي). تتحرك تدريجياً
  /// مع تبديل اللغة فتنزلق الدائرة وتدور الأيقونة بدل القفز.
  final double arrowProgress;
  final VoidCallback onTap;

  const UserTypeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.iconData,
    required this.gradient,
    required this.shadowColor,
    required this.themeT,
    required this.isArabic,
    required this.arrowProgress,
    required this.onTap,
  });

  @override
  State<UserTypeCard> createState() => _UserTypeCardState();
}

class _UserTypeCardState extends State<UserTypeCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isArabic = widget.isArabic;
    final t = widget.themeT.clamp(0.0, 1.0);
    final p = widget.arrowProgress.clamp(0.0, 1.0);
    final arrowAlignment = Alignment.lerp(
      Alignment.centerRight,
      Alignment.centerLeft,
      p,
    )!;

    final borderTop = Color.lerp(
      Colors.white.withValues(alpha: 0.75),
      Colors.white.withValues(alpha: 0.16),
      t,
    )!;
    final borderMid = Color.lerp(
      widget.shadowColor.withValues(alpha: 0.30),
      widget.shadowColor.withValues(alpha: 0.45),
      t,
    )!;
    final borderBottom = Color.lerp(
      Colors.white.withValues(alpha: 0.55),
      Colors.white.withValues(alpha: 0.08),
      t,
    )!;
    final shadow = Color.lerp(
      widget.shadowColor.withValues(alpha: _isPressed ? 0.14 : 0.22),
      Colors.black.withValues(alpha: _isPressed ? 0.30 : 0.45),
      t,
    )!;
    final sheen = Color.lerp(
      Colors.white.withValues(alpha: 0.14),
      Colors.white.withValues(alpha: 0.08),
      t,
    )!;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          // الحافة اللامعة المتدرجة: خلفية متدرجة رفيعة تُرسم عبر الحشو
          padding: const EdgeInsets.all(1.6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              colors: [borderTop, borderMid, borderBottom],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: shadow,
                blurRadius: _isPressed ? 12 : 22,
                offset: Offset(0, _isPressed ? 4 : 8),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Stack(
              children: [
                // لمعة ناعمة أعلى الكرت (بريم خفيف جداً)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 110,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(25),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [sheen, Colors.white.withValues(alpha: 0.0)],
                        ),
                      ),
                    ),
                  ),
                ),

                // محتوى الكرت: النص في الصف، ودائرة السهم طبقة مستقلة تتحرك
                // بين الحافتين مع [arrowProgress] ثم تدور معها لتشير للاتجاه.
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(22, 22, 46, 22),
                  child: Row(
                    children: [
                      // حاوية الأيقونة
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.30),
                          ),
                        ),
                        child: Icon(
                          widget.iconData,
                          size: 34,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 18),

                      // العنوان والوصف (تعرض يميناً في العربية تلقائياً
                      // لأن الاتجاه محكوم بالإعدادات العامة)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontFamily: isArabic ? 'Zain' : 'Poppins',
                                fontSize: isArabic ? 28 : 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                fontFamily: isArabic ? 'Cairo' : 'Poppins',
                                fontSize: isArabic ? 13 : 12,
                                color: Colors.white.withValues(alpha: 0.9),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // سهم الانتقال — Positioned.fill يمنحه ارتفاع الكرت كاملاً
                // فيتوسّط عمودياً بدل أن يلتصق بالحافة العلوية.
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Align(
                      alignment: arrowAlignment,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        // ltr ثابت: أيقونة السهم تنعكس تلقائياً في RTL، فنلغي
                        // ذلك هنا لأن الدوران ([p]) هو من يحدد الاتجاه وحدها.
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Transform.rotate(
                            angle: math.pi * p,
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
