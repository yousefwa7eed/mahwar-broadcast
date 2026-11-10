import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// فحص توفّر الشبكة عند فشل أي تحميل، حتى تظهر رسالة «لا يوجد اتصال»
/// بدل رسالة خطأ عامة أو نص استثناء خام.
///
/// الفحص ليس استباقيًا: لا نستدعيه إلا بعد فشل طلب فعلي، فيبقى بلا أي كلفة
/// في المسار الطبيعي. النتيجة تُخزَّن لثوانٍ قليلة حتى لا تتكرر عمليات
/// DNS عند فشل عدة استعلامات في الشاشة نفسها.
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  static const Duration probeTimeout = Duration(seconds: 3);
  static const Duration cacheTtl = Duration(seconds: 5);

  /// مضيف المشروع — فحص DNS له يكفي لتمييز «لا شبكة» عن «خطأ من الخادم».
  static const String probeHost = 'trgesfzojaoirutkkfcs.supabase.co';

  /// يُستبدل في الاختبارات بفحص وهمي (نجاح/فشل) بدل الشبكة الحقيقية.
  @visibleForTesting
  Future<bool> Function()? probeOverride;

  bool? _lastResult;
  DateTime? _checkedAt;

  /// هل يوجد اتصال شبكة فعلي؟ أي خطأ أو مهلة في الفحص = لا اتصال.
  Future<bool> isOnline() async {
    final now = DateTime.now();
    final last = _lastResult;
    final checkedAt = _checkedAt;
    if (last != null &&
        checkedAt != null &&
        now.difference(checkedAt) < cacheTtl) {
      return last;
    }

    bool online;
    try {
      final probe = probeOverride ?? _defaultProbe;
      online = await probe().timeout(probeTimeout);
    } catch (_) {
      online = false;
    }
    _lastResult = online;
    _checkedAt = DateTime.now();
    return online;
  }

  static Future<bool> _defaultProbe() async {
    final result = await InternetAddress.lookup(probeHost);
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  }

  @visibleForTesting
  void resetForTesting() {
    probeOverride = null;
    _lastResult = null;
    _checkedAt = null;
  }
}

/// سبب فشل تحميل — يحدد هل نعرض «لا يوجد اتصال» أم خطأ تحميل عامًا.
enum LoadFailure { offline, failed }

/// تصنيف فشل تحميل حصل للتو: نتحقق من الشبكة فقط عند الفشل.
Future<LoadFailure> classifyLoadFailure() async {
  final online = await ConnectivityService.instance.isOnline();
  return online ? LoadFailure.failed : LoadFailure.offline;
}
