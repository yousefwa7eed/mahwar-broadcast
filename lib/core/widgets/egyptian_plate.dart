import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// لوحة سيارة مصرية (ملاكي): شريط أزرق «EGYPT / مصر»، والأرقام في النصف
/// الأيسر والحروف في النصف الأيمن كما في اللوحة الحقيقية.
///
/// تُستخدم للعرض فقط إن مرّرت [digitsText]، وللإدخال الحيّ إن مرّرت
/// [digitsController] — فيظهر الرقم على اللوحة أثناء الكتابة.
class EgyptianPlate extends StatelessWidget {
  const EgyptianPlate({
    super.key,
    required this.letters,
    this.digitsController,
    this.digitsText,
    this.height = 120,
    this.digitsHint = '0000',
    this.lettersHint = 'الحروف',
  }) : assert(
         digitsController == null || digitsText == null,
         'مرّر حقل الأرقام أو النص الجاهز، لا الاثنين معًا',
       );

  final List<String?> letters;
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
              height: height * 0.30,
              color: _band,
              padding: EdgeInsets.symmetric(horizontal: height * 0.13),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: [
                    Text(
                      'EGYPT',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15 * unit,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6 * unit,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'مصر',
                      style: TextStyle(
                        fontFamily: 'Zain',
                        fontSize: 19 * unit,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                        color: Colors.white,
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
    final textStyle = TextStyle(
      fontFamily: 'Poppins',
      fontSize: 30 * unit,
      fontWeight: FontWeight.w700,
      letterSpacing: 6 * unit,
      color: _ink,
    );

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
              textDirection: TextDirection.ltr,
              style: empty
                  ? textStyle.copyWith(color: Colors.black26)
                  : textStyle,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * unit),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLength: 4,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: textStyle,
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
          isCollapsed: true,
          hintText: digitsHint,
          hintStyle: textStyle.copyWith(color: Colors.black26),
        ),
      ),
    );
  }

  Widget _lettersCell(double unit) {
    final value = letters.whereType<String>().join();
    final empty = value.isEmpty;

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8 * unit),
          child: Text(
            empty ? lettersHint : value,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 34 * unit,
              fontWeight: FontWeight.w700,
              letterSpacing: 12 * unit,
              color: empty ? Colors.black26 : _ink,
            ),
          ),
        ),
      ),
    );
  }
}
