import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/plate_utils.dart';

/// لوحة سيارة مصرية (ملاكي): شريط أزرق «EGYPT / مصر»، والأرقام في النصف
/// الأيسر والحروف في النصف الأيمن كما في اللوحة الحقيقية.
///
/// تُستخدم للعرض فقط إن مرّرت [digitsText]، وللإدخال الحيّ إن مرّرت
/// [digitsController] — فيظهر الرقم على اللوحة أثناء الكتابة.
///
/// الحروف تُرسم منفصلة (كل حرف Text مستقل) حتى لا تتصل ببعضها كما في اللوحة
/// الحقيقية، والأرقام تُعرض عربية-هندية بينما تُخزَّن لاتينية.
class EgyptianPlate extends StatelessWidget {
  const EgyptianPlate({
    super.key,
    required this.letters,
    this.digitsController,
    this.digitsText,
    this.height = 120,
    this.digitsHint = '٠٠٠٠',
    this.lettersHint = 'الحروف',
  }) : assert(
         digitsController == null || digitsText == null,
         'مرّر حقل الأرقام أو النص الجاهز، لا الاثنين معًا',
       );

  final List<String> letters;
  final TextEditingController? digitsController;
  final String? digitsText;
  final double height;
  final String digitsHint;
  final String lettersHint;

  static const Color _band = Color(0xFF0B4C9C);
  static const Color _ink = Color(0xFF121212);

  @override
  Widget build(BuildContext context) {
    // كل المقاسات مشتقة من الارتفاع لتبقى اللوحة متناسقة في أي حجم.
    final unit = height / 120;

    // اللوحة تحاكي مقاسات لوحة حقيقية؛ تكبير الخط للنظام يكسرها.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _ink, width: 2),
        ),
        child: Column(
          children: [
            Container(
              height: height * 0.26,
              color: _band,
              child: Directionality(
                textDirection: TextDirection.ltr,
                // كل اسم في نصف الشريط المقابل لخانته أدناه، فيتمركز فوقها.
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          'EGYPT',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15 * unit,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6 * unit,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 2),
                    Expanded(
                      child: Center(
                        child: Text(
                          'مصر',
                          style: TextStyle(
                            fontFamily: 'Zain',
                            fontSize: 19 * unit,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: [
                    Expanded(child: _digitsCell(unit)),
                    Container(width: 2, color: _ink),
                    Expanded(child: _lettersCell(unit)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _digitsCell(double unit) {
    final controller = digitsController;
    if (controller == null) {
      final text = digitsText ?? '';
      final empty = text.isEmpty;
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8 * unit),
            child: Text(
              empty ? digitsHint : text,
              style: _digitsStyle(
                30 * unit,
                unit,
              ).copyWith(color: empty ? Colors.black26 : _ink),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * unit),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              // نضبط المقاس حسب عدد الأرقام حتى تتسع اللوحة لسبعة أرقام.
              final count = math.max(4, value.text.length);
              final available = constraints.maxWidth - 8 * unit;
              final fontSize = math.min(30 * unit, available / (count * 0.62));
              final style = _digitsStyle(fontSize, unit);
              return TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: PlateUtils.maxDigits,
                inputFormatters: const [_ArabicIndicDigitsFormatter()],
                style: style,
                decoration: InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: digitsHint,
                  hintStyle: style.copyWith(color: Colors.black26),
                ),
              );
            },
          );
        },
      ),
    );
  }

  TextStyle _digitsStyle(double fontSize, double unit) => TextStyle(
    fontFamily: 'Cairo',
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    letterSpacing: 2 * unit,
    color: _ink,
  );

  Widget _lettersCell(double unit) {
    final chars = letters.where((letter) => letter.trim().isNotEmpty).toList();
    final empty = chars.isEmpty;
    final style = TextStyle(
      fontFamily: 'Cairo',
      fontSize: 30 * unit,
      fontWeight: FontWeight.w700,
      color: _ink,
    );

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10 * unit),
          child: empty
              ? Text(
                  lettersHint,
                  textDirection: TextDirection.rtl,
                  style: style.copyWith(
                    fontSize: 32 * unit,
                    color: Colors.black26,
                  ),
                )
              // كل حرف في Text مستقل كي لا يتصل بما بعده — كما تُطبع اللوحة.
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.rtl,
                  children: [
                    for (var i = 0; i < chars.length; i++) ...[
                      if (i > 0) SizedBox(width: 12 * unit),
                      Text(chars[i], style: style),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// يحوّل ما يكتبه المستخدم إلى أرقام عربية-هندية ويمنع أي محرف آخر.
class _ArabicIndicDigitsFormatter extends TextInputFormatter {
  const _ArabicIndicDigitsFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = PlateUtils.normalizeDigitsInput(newValue.text);
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
