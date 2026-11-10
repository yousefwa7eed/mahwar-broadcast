import 'package:flutter/widgets.dart';

/// يجمّد نموذجًا كاملًا أثناء عملية شبكية (دخول/تسجيل/OTP/طلب خدمة):
/// يمنع كل اللمسات عبر [AbsorbPointer]، ويُخفت المحتوى قليلًا ليدرك المستخدم
/// أن النموذج غير قابل للتفاعل، ويسحب التركيز من أي حقل حتى لا تظل لوحة
/// المفاتيح مفتوحة فوق مؤشر التحميل.
///
/// التعتيم مقصود أن يكون خفيفًا (0.55) لا إخفاءً كاملًا: النموذج يظل مقروءًا
/// والمستخدم يرى ما أدخله أثناء الانتظار.
class LoadingFormLock extends StatefulWidget {
  const LoadingFormLock({
    super.key,
    required this.loading,
    required this.child,
    this.dimOpacity = 0.55,
  });

  final bool loading;
  final Widget child;
  final double dimOpacity;

  @override
  State<LoadingFormLock> createState() => _LoadingFormLockState();
}

class _LoadingFormLockState extends State<LoadingFormLock> {
  @override
  void didUpdateWidget(LoadingFormLock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading && !oldWidget.loading) {
      // بعد الإطار الحالي: لا نعدّل التركيز أثناء مرحلة build/didUpdate.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusManager.instance.primaryFocus?.unfocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: widget.loading,
      child: AnimatedOpacity(
        opacity: widget.loading ? widget.dimOpacity : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
