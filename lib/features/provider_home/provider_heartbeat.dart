import 'dart:async';

/// جدولة نبضة موقع المزوّد — منطق نقي قابل للاختبار بلا جهاز أو شبكة.
///
/// السلوك المطلوب:
///  * نبضة فورية عند أول تفعيل (فتح الشاشة والمزوّد متاح، أو انتقاله لمتاح،
///    أو عودة التطبيق للمقدمة).
///  * ثم نبضة دورية كل [interval].
///  * لا نبضات إطلاقاً بينما المزوّد غير متاح (offline) أو التطبيق في الخلفية.
///  * في الخلفية يتوقّف المؤقّت كلياً، وعند العودة للمقدمة يُستأنف فوراً.
///  * إلغاء كامل في [dispose].
///
/// [sendBeat] هو التنفيذ الفعلي (يقابل RPC provider_heartbeat) ويُحقَن
/// ليُختبر الجدولة وحدها. أي خطأ منه يُبتلع هنا، فلا تُسقِط النبضة الواجهة
/// ولا تُعطّل الجدولة، ولا تُنتظر نتيجتها (لا حجب للواجهة).
class ProviderHeartbeat {
  ProviderHeartbeat({
    required this.sendBeat,
    this.interval = const Duration(seconds: 60),
  });

  /// التنفيذ الفعلي لنبضة واحدة؛ نتيجته غير مُنتظرة وأخطاؤه تُبتلع.
  final Future<void> Function() sendBeat;

  /// الفاصل الزمني بين النبضات الدورية.
  final Duration interval;

  Timer? _timer;
  bool _online = false;
  bool _foreground = true;
  bool _disposed = false;
  bool _inFlight = false;

  /// هل يجوز إرسال نبضة الآن؟ (متاح + في المقدمة + لم يُغلق).
  bool get isEligible => _online && _foreground && !_disposed;

  /// يُحدّث حالة توفّر المزوّد. الانتقال إلى «متاح» (وهو في المقدمة) يرسل
  /// نبضة فورية، والانتقال إلى «غير متاح» يوقف الجدولة.
  void setOnline(bool value) {
    if (_disposed || _online == value) return;
    final becameOnline = value;
    _online = value;
    _reconcile(immediate: becameOnline);
  }

  /// يُحدّث حالة مقدّمة/خلفية التطبيق. العودة للمقدمة (والمزوّد متاح) ترسل
  /// نبضة فورية، والذهاب للخلفية يوقف الجدولة.
  void setForeground(bool value) {
    if (_disposed || _foreground == value) return;
    final resumed = value;
    _foreground = value;
    _reconcile(immediate: resumed);
  }

  void _reconcile({required bool immediate}) {
    if (!isEligible) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(interval, (_) => _fire());
    if (immediate) _fire();
  }

  /// نبضة واحدة غير محجوبة: تُتجاهل إن وُجدت نبضة جارية، وفشلها لا يخرج.
  void _fire() {
    if (!isEligible || _inFlight) return;
    _inFlight = true;

    Future<void> beat;
    try {
      beat = sendBeat();
    } catch (_) {
      _inFlight = false;
      return;
    }

    unawaited(
      beat
          .catchError((Object _) {})
          .whenComplete(() => _inFlight = false),
    );
  }

  /// إيقاف نهائي (يُستدعى من dispose الشاشة).
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
