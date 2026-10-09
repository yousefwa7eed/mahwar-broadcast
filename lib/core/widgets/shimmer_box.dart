import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// هيكل «شيمر» (skeleton shimmer) يُعرض في مكان المحتوى القادم أثناء التحميل.
/// ألوانه مستخرجة من توكينات الثيم عبر [Theme.of], فينسجم تلقائياً مع
/// الوضع الفاتح والداكن دون ألوان مسطّحة.
class ShimmerBox extends StatefulWidget {
  /// العرض؛ بلا قيمة يُملأ المساحة المتاحة (أفقياً).
  final double? width;

  /// الارتفاع؛ بلا قيمة يُملأ المساحة المتاحة (عمودياً).
  final double? height;

  final double borderRadius;

  /// عند true يُرسم دائرة (مثلاً مكان صورة الملف الشخصي).
  final bool circle;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 10,
    this.circle = false,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.darkCard : AppColors.lightBorder;
    final highlightColor =
        isDark ? AppColors.darkBorder : AppColors.lightSurface;

    final radius =
        widget.circle ? double.infinity : widget.borderRadius;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [baseColor, highlightColor, baseColor],
                  stops: const [0.35, 0.5, 0.65],
                  transform:
                      _SlideGradientTransform(_controller.value),
                ).createShader(bounds);
              },
              child: child,
            );
          },
          child: ColoredBox(color: baseColor),
        ),
      ),
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlideGradientTransform(this.slidePercent);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final width = bounds.width.toDouble();
    final shift = (slidePercent * 2 - 1) * width;
    return Matrix4.translationValues(shift, 0, 0);
  }
}