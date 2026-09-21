// عمليات زمنية موحّدة لكل التواقيت القادمة من Supabase.
//
// قاعدة واحدة: أي طابع زمني يولّده الخادم (created_at / updated_at /
// respond_deadline / server_now) يُحفظ داخل التطبيق كـ UTC مطلق — وهو المرجع
// الوحيد لِحِساب "منذ ..." والمهلات. التوقيت المحلي للمستخدم يُستخدم
// للعرض فقط (toLocal() لحظة الرسم)، لا لِحساب الفروق الزمنية.

/// يحوّل أي صيغة تايم ستامب تصدرها Supabase (PostgREST أو Realtime أو edge
/// functions أو RPC) إلى [DateTime] آمن بتوقيت UTC:
/// - إن كان الخيط يحمل منطقة زمنية (Z أو +00:00) فيُحفظ كتوقيت مطلق كما هو.
/// - وإن كان بدون منطقة زمنية (غالبًا مع Realtime) فيُعتبر توقيت UTC وليس
///   التوقيت المحلي، حتى لا تنحرف قيمة "منذ ..." بفارق منطقة زمنية الجهاز.
DateTime? parseSupabaseTimestamp(Object? value) {
  if (value is! String || value.isEmpty) return null;
  var text = value.contains(' ') ? value.replaceFirst(' ', 'T') : value;
  final dt = DateTime.tryParse(text);
  if (dt == null) return null;
  if (dt.isUtc) return dt;
  return DateTime.utc(
    dt.year, dt.month, dt.day, dt.hour,
    dt.minute, dt.second, dt.millisecond, dt.microsecond,
  );
}