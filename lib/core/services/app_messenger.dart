import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// باند/تنبيهات عامة على مستوى التطبيق كامل (خارج شجرة الـ widgets)
/// عبر GlobalKey مربوط بـ MaterialApp.scaffoldMessengerKey.
class AppMessenger {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// مفتاح الملاح الجذري — يسمح بإظهار التوست من أماكن بلا [BuildContext]
  /// (مثل منسّق الخروج بعد الانتقال بين الشاشات).
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static OverlayEntry? _toastEntry;

  /// باند عائم غير مزعج — يُستخدم لاستقبال إشعارات الدفع أمام المستخدم
  /// (التطبيق مفتوح). العنوان/النص يأتيان من حمولة الإشعار نفسها.
  static void showBanner({required String title, String? body}) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkBackground,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(
              Icons.notifications_active_rounded,
              color: AppColors.orangePrimary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (body != null && body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// رسالة قصيرة بلا سياق ملاح — تُعرض كارتاً في منتصف الشاشة إن توفّر
  /// Overlay، وإلا تعود لباند سفلي كي لا تُفقد الرسالة (اختبارات/شاشات).
  static void showText(String text) {
    final navigator = navigatorKey.currentState;
    final overlay = navigator?.overlay;
    if (navigator == null || overlay == null) {
      final messenger = messengerKey.currentState;
      if (messenger == null) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(text, style: const TextStyle(fontFamily: 'Cairo')),
        ),
      );
      return;
    }
    _insertToast(
      overlay: overlay,
      text: text,
      isDark: Theme.of(navigator.context).brightness == Brightness.dark,
    );
  }

  /// الرسالة القياسية لكل إجراءات التطبيق: كارت صغير ناعم في منتصف الشاشة
  /// يظهر بلطف ثم يتلاشى تدريجياً بعد ثانية.
  ///
  /// [background] اختياري للتوافق مع نداءات قديمة: تمرير
  /// [AppColors.success]/[AppColors.error] يلوّن أيقونة الكارت فقط ويبقى
  /// سطحه هادئاً.
  static void showToast(
    BuildContext context,
    String text, {
    Color? background,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    _insertToast(
      overlay: overlay,
      text: text,
      isDark: Theme.of(context).brightness == Brightness.dark,
      background: background,
    );
  }

  static void _insertToast({
    required OverlayState overlay,
    required String text,
    required bool? isDark,
    Color? background,
  }) {
    // رسالة جديدة تحلّ محل القديمة فوراً بدل تراكم الكروت.
    _removeToast();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CenterToast(
        text: text,
        background: background,
        dark: isDark ?? false,
        onFinished: () {
          if (identical(_toastEntry, entry)) _toastEntry = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _toastEntry = entry;
    overlay.insert(entry);
  }

  static void _removeToast() {
    final entry = _toastEntry;
    _toastEntry = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}

/// كارت توست هادئ في منتصف الشاشة: ظهور سريع، ثبات ثانية، ثم تلاشٍ تدريجي.
class _CenterToast extends StatefulWidget {
  const _CenterToast({
    required this.text,
    required this.background,
    required this.dark,
    required this.onFinished,
  });

  final String text;
  final Color? background;
  final bool dark;
  final VoidCallback onFinished;

  @override
  State<_CenterToast> createState() => _CenterToastState();
}

class _CenterToastState extends State<_CenterToast>
    with SingleTickerProviderStateMixin {
  // ١٨٠ مللي ظهور + ٩٩٠ مللي ثبات + ٣٣٠ مللي تلاشٍ ≈ ثانية كاملة مقروءة.
  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onFinished();
      });

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 12,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 66),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeInCubic)),
      weight: 22,
    ),
  ]).animate(_controller);

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = widget.background;
    final Color accent;
    final IconData icon;
    if (background == AppColors.success) {
      accent = AppColors.success;
      icon = Icons.check_circle_rounded;
    } else if (background == AppColors.warning) {
      accent = AppColors.warning;
      icon = Icons.warning_amber_rounded;
    } else if (background != null) {
      // أي لون آخر جاء من نداءات قديمة (أحمر خطأ مثلاً) يُعرض كخطأ.
      accent = AppColors.error;
      icon = Icons.error_rounded;
    } else {
      accent = AppColors.orangePrimary;
      icon = Icons.info_rounded;
    }

    final isDark = widget.dark;

    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _opacity,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.30 : 0.08,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.14 : 0.04,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20, color: accent),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13.5,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
