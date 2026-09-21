/// يحفظ مؤقت إعادة الإرسال لكل رقم هاتف (في الذاكرة داخل الجلسة) بحيث يُحترم
/// مهلة الـ 60 ثانية حتى لو غادر المستخدم الشاشة ورجع إليها. المعرّف هو الرقم
/// المحلي الموحَّد (01xxxxxxxxx).
class OtpCooldownStore {
  OtpCooldownStore._();

  static const Duration defaultCooldown = Duration(seconds: 60);

  /// ساعة قابلة للحقن تسمح للاختبارات بمحاكاة مرور الزمن بشكل حتمي.
  static DateTime Function() now = DateTime.now;

  static final Map<String, DateTime> _deadlines = {};

  /// المدة المتبقية قبل السماح بإعادة الإرسال (صفر إذا لم يعد العدّاد يعمل).
  static Duration remainingFor(String phone) {
    final deadline = _deadlines[phone];
    if (deadline == null) return Duration.zero;
    final remaining = deadline.difference(now());
    if (remaining <= Duration.zero) {
      _deadlines.remove(phone);
      return Duration.zero;
    }
    return remaining;
  }

  static void start(String phone, {Duration duration = defaultCooldown}) {
    _deadlines[phone] = now().add(duration);
  }

  static void clear(String phone) {
    _deadlines.remove(phone);
  }
}