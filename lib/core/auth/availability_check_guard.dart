import 'phone_utils.dart';

/// درع جلسة أمام RPC فحص التفرّد (`is_phone_available` / `email_for_phone`).
///
/// بدل إرسال استعلام لكل ضغطة إعادة محاولة على نفس الرقم:
/// - لا يمر أي رقم غير مكتمل الصيغة إلى الخادم إطلاقًا.
/// - الطلب الجاري على رقم يُعاد استخدامه بدل تكراره (تضغط مرتين = طلب واحد).
/// - نتيجة الفحص الناجحة تُخزَّن مؤقتًا؛ الخطأ لا يُخزَّن فيُعادحاول لاحقًا.
/// القيود الخادمية (قيد التفرّد + `PHONE_CHANGE_REQUIRES_OTP`) تبقى خط الدفاع
/// الأخير؛ مدة الكاش قصيرة عمدًا حتى لا تتعارض مع تغيّر ملكية الرقم.
class AvailabilityCheckGuard {
  AvailabilityCheckGuard({this.ttl = const Duration(seconds: 60)});

  static final AvailabilityCheckGuard instance = AvailabilityCheckGuard();

  final Duration ttl;

  final Map<String, Future<Object?>> _inFlight = {};
  final Map<String, _CacheEntry> _cache = {};

  /// هل هذا الرقم متاح؟ [fetch] هو مكالمة RPC الفعلية.
  Future<bool> isPhoneAvailable(
    String phone,
    Future<bool> Function(String normalizedPhone) fetch,
  ) async {
    final normalized = _requireValid(phone);
    final result = await _cached('available:$normalized', () => fetch(normalized));
    return result as bool;
  }

  /// البريد المرتبط بالرقم (أو null إن غير مسجل). [fetch] هو مكالمة RPC الفعلية.
  Future<String?> emailForPhone(
    String phone,
    Future<String?> Function(String normalizedPhone) fetch,
  ) async {
    final normalized = _requireValid(phone);
    final result = await _cached('email:$normalized', () => fetch(normalized));
    return result as String?;
  }

  /// يسقط الكاش والطلبات الجارية (لتسجيل الخروج أو في الاختبارات).
  void clear() {
    _inFlight.clear();
    _cache.clear();
  }

  String _requireValid(String phone) {
    final normalized = PhoneUtils.normalize(phone);
    if (!PhoneUtils.isValidEgyptianMobile(normalized)) {
      throw const FormatException('رقم غير مكتمل: لا يُرسل فحصه إلى الخادم');
    }
    return normalized;
  }

  Future<Object?> _cached(String key, Future<Object?> Function() fetch) {
    final now = DateTime.now();
    final cached = _cache[key];
    if (cached != null && cached.expiresAt.isAfter(now)) {
      return Future.value(cached.value);
    }
    final pending = _inFlight[key];
    if (pending != null) return pending;

    final future = Future.microtask(fetch).then((value) {
      _inFlight.remove(key);
      _cache[key] = _CacheEntry(value, now.add(ttl));
      return value;
    }).catchError((Object error, StackTrace stack) {
      _inFlight.remove(key);
      Error.throwWithStackTrace(error, stack);
    });
    _inFlight[key] = future;
    return future;
  }
}

class _CacheEntry {
  const _CacheEntry(this.value, this.expiresAt);

  final Object? value;
  final DateTime expiresAt;
}
