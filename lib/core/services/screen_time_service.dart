import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// تتبّع رحلة المستخدم داخل التطبيق: أي شاشة دخلها، وقضى فيها كم، وبعدها راح
/// فين. يُدار عبر [ScreenTimeService] بصف واحد لكل «زيارة شاشة» يُرفع دفعةً
/// واحدة لجدول `page_views` في Supabase (RLS يسمح بإدراج صفوف للمستخدم الحالي
/// فقط). تُحسب الشاشات الحقيقية فقط — أي مسارات go_router المسماة.
///
///  · [didPush]/[didReplace] → نغلق الشاشة المفتوحة حاليًا (تصير زيارة) ونفتح
///    الجديدة. المربّعات (dialogs) بلا اسم لا تقطع العدّ — زمنها يُحسب للشاشة
///    تحتها (هذا هو السلوك المطلوب).
///  · [didPop] → إن انغلق مسار مسجَّل (بنفس الاسم أعلى المكدّس) نغلق، وإلا
///    نُعيد ضبط بداية العدّ للشاشة الأدنى (العودة من «dialog»).
///  · الإرسال: دفعة كل 45 ثانية وأيضًا عند توقيف التطبيق (الخلفية/الإغلاق).
class ScreenTimeService extends NavigatorObserver with WidgetsBindingObserver {
  ScreenTimeService._();

  static final ScreenTimeService instance = ScreenTimeService._();

  bool _started = false;
  bool _busy = false;
  final List<Map<String, dynamic>> _buffer = <Map<String, dynamic>>[];
  final List<({String screen, DateTime enteredAt})> _stack =
      <({String screen, DateTime enteredAt})>[];

  static const int _maxDurationSec = 600; // سقف مطابق لـ CHECK في قاعدة البيانات

  /// يبدأ التتبّع: يسجّل مراقب دورة الحياة ويؤقّت الدفعات. يُستدعى مرة واحدة
  /// من `main()` بعد تهيئة الـ binding.
  ///
  /// قبل [start] الخدمة خاملة تمامًا — لا مؤقّتات ولا وصول إلى Supabase. هذا
  /// مقصود: الـ [instance] singleton على مستوى العملية ومربوط كـ observer في
  /// `appRouter`، فلو سجّل نفسه عند أول [didPush] لورّث كل اختبار widget يمرّر
  /// الموجّه مؤقّتًا حيًّا لا يُلغى أبدًا.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    Timer.periodic(const Duration(seconds: 45), (_) => flush());
  }

  String _nameOf(Route<dynamic>? route) {
    final String? name = route?.settings.name;
    if (name == null || name.isEmpty) return '';
    return name;
  }

  void _closeTop() {
    if (_stack.isEmpty) return;
    final ({String screen, DateTime enteredAt}) top = _stack.removeLast();
    final int sec =
        DateTime.now().difference(top.enteredAt).inSeconds.clamp(0, _maxDurationSec);
    _buffer.add({
      'screen': top.screen,
      'entered_at': top.enteredAt.toUtc().toIso8601String(),
      'duration_sec': sec,
    });
    if (_buffer.length > 120) _buffer.removeRange(0, _buffer.length - 120);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_started) return;
    final String name = _nameOf(route);
    if (name.isEmpty) return;
    _closeTop();
    _stack.add((screen: name, enteredAt: DateTime.now()));
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_started) return;
    final String popped = _nameOf(route);
    if (popped.isNotEmpty &&
        _stack.isNotEmpty &&
        _stack.last.screen == popped) {
      _closeTop();
    }
    // إعادة فتح الشاشة الظاهرة الآن (بدون بدء زمن جديد إن كانت هي نفسها
    // الجلسة) — فقط للشاشات المسجَّلة.
    if (_stack.isNotEmpty) {
      _stack.last = (
        screen: _stack.last.screen,
        enteredAt: DateTime.now(),
      );
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (!_started) return;
    final String name = _nameOf(newRoute);
    if (name.isEmpty) return;
    _closeTop();
    _stack.add((screen: name, enteredAt: DateTime.now()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      flush();
    }
  }

  /// يرفع الدفعة الحالية لجدول `page_views`. صامت (no-throw): أي فشل شبكة أو
  /// RLS يُهمل بلا إزعاج — الدفعة القادمة تحمل الجديد فقط.
  Future<void> flush() async {
    if (!_started || _busy || _buffer.isEmpty) return;
    final client = Supabase.instance.client;
    final String? uid = client.auth.currentUser?.id;
    if (uid == null) return;

    _busy = true;
    final List<Map<String, dynamic>> batch = _buffer.map((e) {
      return <String, dynamic>{...e, 'user_id': uid};
    }).toList();
    _buffer.clear();
    try {
      await client.from('page_views').insert(batch);
    } catch (_) {
      // تجاهل — الشاشة المسجِّل لا يُفترض أن تكسر تجربة المستخدم.
    } finally {
      _busy = false;
    }
  }
}
