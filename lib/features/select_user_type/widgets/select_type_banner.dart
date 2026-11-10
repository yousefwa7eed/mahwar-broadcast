import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

/// بانر اختيار النوع — مبني بالكود بالكامل (لا صور)، نسخة مبسّطة من تصميم
/// الأصل: تدرّج برتقالي بريمي، شعار دائري، سطر تعريفي صغير، وعنوان كبير مع
/// كبسولة سوداء. شارة "نسخة تجريبية" تشغل موقع الصورة القديمة أعلى البانر.
class SelectTypeBanner extends StatelessWidget {
  final bool isArabic;
  final double themeT;

  const SelectTypeBanner({
    super.key,
    required this.isArabic,
    required this.themeT,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = themeT.clamp(0.0, 1.0);
    Color mix(Color light, Color dark) => Color.lerp(light, dark, t)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // مقاست متناسبة مع عرض البانر بدل قيم ثابتة — تتلاءم مع كل الشاشات.
        final logoSize = (w * 0.16).clamp(40.0, 56.0);
        final smallFont = (w * 0.036).clamp(11.0, 14.0);
        final headlineFont = (w * 0.115).clamp(28.0, 46.0);
        final pillFont = (w * 0.095).clamp(22.0, 38.0);
        // ارتفاع متناسب: يبقى قريباً من نسبة البانر الأصلي (700×300 ≈ 2.33)
        // على التابلت، ولا ينضغط كثيراً على شاشات الهاتف الضيقة.
        final bannerHeight = (w * 0.42).clamp(200.0, 300.0);

        return AspectRatio(
          aspectRatio: w / bannerHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: BoxDecoration(
                // فاتح: تدرّج برتقالي بريمي. داكن: أسود قاتح متدرّج بلمعة
                // علوية "منيرة" — يتدرّج بينهما بسلاسة مع themeT.
                gradient: LinearGradient(
                  colors: [
                    mix(const Color(0xFFFFA95C), const Color(0xFF3D3D3D)),
                    mix(const Color(0xFFFF8A33), const Color(0xFF232323)),
                    mix(const Color(0xFFF76F00), const Color(0xFF0F0F0F)),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: Stack(
                alignment: AlignmentDirectional.topEnd,
                children: [
                  // حلقة زخرفية باهتة (بديل بسيط لشعار الطبلون في الصورة)
                  PositionedDirectional(
                    start: -logoSize * 0.5,
                    bottom: -logoSize * 0.2,
                    child: Container(
                      width: logoSize * 2.2,
                      height: logoSize * 2.2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: mix(
                            Colors.white.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.08),
                          ),
                          width: logoSize * 0.28,
                        ),
                      ),
                    ),
                  ),

                  // شارة "نسخة تجريبية" — بديل تنبيه بسيط في موقع الصورة
                  PositionedDirectional(
                    start: 10,
                    top: 10,
                    end: 10,
                    child: Align(
                      alignment: AlignmentDirectional.topStart,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: mix(
                            Colors.black.withValues(alpha: 0.35),
                            Colors.white.withValues(alpha: 0.14),
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.science_outlined,
                              color: Colors.white,
                              size: 13,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                l10n?.betaVersionNotice ??
                                    'نسخة تجريبية — كل جديد يوصل قريب',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: smallFont * 0.92,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // لمعة ناعمة أعلى البانر (بريم خفيف)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              mix(
                                Colors.white.withValues(alpha: 0.10),
                                Colors.white.withValues(alpha: 0.20),
                              ),
                              Colors.transparent,
                              mix(
                                Colors.black.withValues(alpha: 0.08),
                                Colors.black.withValues(alpha: 0.35),
                              ),
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // المحتوى: سطر تعريفي + عنوان كبير + كبسولة سوداء
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 44, 20, 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // سطر الهوية: محور — نجدة فورية 24/7
                        // FittedBox يمنع تجاوز العرض على الشاشات الضيقة أو عند
                        // تبديل اللغة إلى الإنجليزية (نص أطول).
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerEnd,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isArabic ? 'محور' : 'Mahwar',
                                style: TextStyle(
                                  fontFamily: isArabic ? 'Zain' : 'Poppins',
                                  fontSize: smallFont * 1.15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '  •  ${l10n?.topRoadsideAssistance ?? 'شبكة طوارئ السيارات الأولى'}',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: smallFont * 0.95,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: smallFont * 0.9),

                        // العنوان الرئيسي (ينكمش بدل أن يفيض على الشاشات القصيرة)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            l10n?.bannerHeadline ?? 'سلكناها للطريق!',
                            textDirection: isArabic
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            style: TextStyle(
                              fontFamily: isArabic ? 'Zain' : 'Poppins',
                              fontSize: headlineFont,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.0,
                              shadows: [
                                Shadow(
                                  color: mix(
                                    Colors.black.withValues(alpha: 0.15),
                                    Colors.black.withValues(alpha: 0.40),
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: smallFont * 0.6),

                        // الكبسولة: سوداء في الوضع الفاتح، وتصبح برتقالية متدرجة
                        // في الوضع الداكن (تبادل مع البانر) مع نص أبيض متباين.
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: smallFont * 1.6,
                            vertical: smallFont * 0.55,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                mix(
                                  const Color(0xFF141414),
                                  const Color(0xFFFF8A33),
                                ),
                                mix(
                                  const Color(0xFF141414),
                                  const Color(0xFFF76F00),
                                ),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              smallFont * 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: mix(
                                  Colors.black.withValues(alpha: 0.25),
                                  const Color(
                                    0xFFFF6B00,
                                  ).withValues(alpha: 0.40),
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              l10n?.fastSafeRoadside24_7 ??
                                  'خدمة سريعة وآمنة على كافة الطرق 24/7',
                              textDirection: isArabic
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: isArabic ? 'Zain' : 'Poppins',
                                fontSize: pillFont,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.15,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.20),
                                    blurRadius: 6,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
