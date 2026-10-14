/// منطق قرار تواجد المزوّد (availability) — دالة نقية بلا أي اعتماد على
/// Supabase، قابلة للاختبار مباشرة.
///
/// المصدران:
///   - الجدول (provider_schedules) عبر `in_hours`.
///   - القرار اليدوي المخزّن على الصف `availability_override`:
///       'auto' = الجدول يحكم | 'on' = مفعّل يدوياً | 'off' = مخفي يدوياً.
///
/// القاعدة: القرار اليدوي يعلو على الجدول حتى يعيده cron إلى 'auto' عند أقرب
/// حدّ للجدول. بلا جدول = تحكّم يدوي كامل.
enum AvailabilityAction { none, goOnline, goOffline }

AvailabilityAction resolveAvailability({
  required bool hasSchedule,
  required bool inHours,
  required String availabilityOverride,
  required bool isOnline,
}) {
  // بلا جدول: المزوّد يتحكّم يدوياً بالكامل — لا نلمس حالته.
  if (!hasSchedule) return AvailabilityAction.none;

  // قرار يدوي صريح: الداتابيز/cron هي المرجع، ولا نوحّد مع الجدول.
  if (availabilityOverride != 'auto') return AvailabilityAction.none;

  if (inHours && !isOnline) return AvailabilityAction.goOnline;
  if (!inHours && isOnline) return AvailabilityAction.goOffline;
  return AvailabilityAction.none;
}
