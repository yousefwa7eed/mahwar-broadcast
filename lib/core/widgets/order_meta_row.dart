import 'package:flutter/material.dart';

/// صف البيانات الوصفية الموحّد للبطاقات (شارة الحالة + عنصر وسطي + ذيل
/// كالتاريخ/السعر/سهم). يحافظ على شكل الصف الحالي حرفياً عندما تتّسع الشاشة:
/// الشارة في البداية، الذيل في النهاية، والوسط يمتد بينهما.
///
/// منع الفيض: عرض الشارة والذيل محدود كلٌ بـ 45% من عرض الصف، فيتقلّصان
/// (بنصوص maxLines + ellipsis من المستدعي) بدل أن يتجاوزا الحدود، ولا يتراكب
/// السعر مع الشارة أبداً. الوسط Expanded يبتلع المساحة المتبقية، وSpacer
/// يقوم بنفس الدور عند غياب الوسط.
///
/// الاتجاه: Row + Spacer + AlignmentDirectional كلها محترمة لاتجاه اللغة،
/// فيعمل الصف تلقائياً RTL (عربي) وLTR (إنجليزي) بلا أي إحداثيات صلبة.
class OrderMetaRow extends StatelessWidget {
  /// الشارة في بداية الصف (عادة كبسولة حالة ملوّنة).
  final Widget badge;

  /// عنصر وسطي مرن (مثل الشارة الحيّة) — يُحاذى لبداية المساحة المتبقية.
  final Widget? middle;

  /// ذيل الصف (تاريخ/سعر/أيقونة/شارة أخرى) — لا يتراكب مع الشارة أبداً.
  final Widget? trailing;

  /// المسافة الثابتة بين الشارة والوسط (كما كانت في البطاقات الأصلية).
  final double gap;

  const OrderMetaRow({
    super.key,
    required this.badge,
    this.middle,
    this.trailing,
    this.gap = 0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cap = BoxConstraints(maxWidth: constraints.maxWidth * 0.45);
        return Row(
          children: [
            ConstrainedBox(constraints: cap, child: badge),
            if (middle != null) ...[
              SizedBox(width: gap),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: middle,
                ),
              ),
            ] else
              const Spacer(),
            if (trailing != null) ConstrainedBox(constraints: cap, child: trailing!),
          ],
        );
      },
    );
  }
}