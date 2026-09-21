import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/supabase_time.dart';

/// مرجع "الآن" موحّد من ساعة الخادم (RPC server_now) لِكل حسابات الزمن
/// النسبية ("منذ ...", عدّادات المهلة) بدل `DateTime.now()` الذي قد يكون
/// غير مزامن على الأجهزة القديمة.
///
/// كيف يعمل:
///  - [refresh] يجلب `server_now()` (UTC) من قاعدة البيانات ويخزّنه مع لحظة
///    الجلب على ساعة الجهاز، ويُعيد استعماله حتى ينتهي [cacheTtl].
///  - [now] يُعيد زمن الخادم بعد الجلب الأخير مضافاً إليه الفارق الزمني الذي
///    مَرّ منذ الجلب (فارق ساعة الجهاز دقيق بالثواني حتى لو كانت قراءتها
///    المطلقة خاطئة). أي: المطلق مُرسى على ساعة الخادم، وساعة الجهاز لا
///    تحسب شيئاً مقابل حدث من الخادم بل تقيس انقضاء دقيق فقط.
///  - قبل أول جلب ناجح (أو دون اتصال) يُرجع `DateTime.now().toUtc()` كملاذ
///    أخير ضعيف، ثم يصحّح نفسه بعد أول [refresh].
class ServerClock {
  ServerClock._();
  static final ServerClock instance = ServerClock._();

  /// فترة صلاحية آخر "آن" مُجلب من الخادم قبل إعادة الجلب.
  static const Duration cacheTtl = Duration(seconds: 45);

  DateTime? _lastServerNow; // UTC
  DateTime? _lastDeviceTs; // توقيت الجهاز لحظة الجلب

  /// الآن وفق ساعة الخادم (UTC).
  DateTime get now {
    final server = _lastServerNow;
    final device = _lastDeviceTs;
    if (server == null || device == null) return DateTime.now().toUtc();
    final elapsed = DateTime.now().difference(device);
    return server.add(elapsed).toUtc();
  }

  bool get _isFresh {
    final device = _lastDeviceTs;
    if (device == null) return false;
    return DateTime.now().difference(device) < cacheTtl;
  }

  /// يجلب زمن الخادم (UTC) عبر RPC `server_now` ويُعيده. إن كانت القيمة
  /// المخزونة حديثة يكتفي بها دون طلب شبكة. الفشل لا يرمي خطأ — نُرجع آخر
  /// قيمة معروفة أو ساعة الجهاز.
  Future<DateTime> refresh() async {
    if (_isFresh) return now;
    try {
      final client = Supabase.instance.client;
      final response = await client.rpc('server_now');
      if (response is String) {
        final parsed = parseSupabaseTimestamp(response);
        if (parsed != null) {
          _lastServerNow = parsed;
          _lastDeviceTs = DateTime.now();
        }
      }
    } catch (_) {
      // لا نُسقط أي تدفّق بسبب تعذّر الجلب — نُبقي آخر قيمة معروفة.
    }
    return now;
  }
}