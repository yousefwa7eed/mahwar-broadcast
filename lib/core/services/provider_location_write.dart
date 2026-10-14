/// نافذة "الحداثة" للموقع المخزّن: ما هو أحدث منه يُعتبر طازجاً.
const Duration defaultLocationFreshnessWindow = Duration(minutes: 30);

/// عتبة الحركة أدناها لاعتبار التحديث ذا قيمة (بالأمتار).
const double defaultMoveThresholdMeters = 30;

/// الموقع بعيداً عن الجسم الذي ستُعرض عليه القائمة القريبة.
/// يستخدمه [decideLocationWrite] فقط لتوثيق رفض تحديث أردأ من مخزون طازج.
const double defaultWorstAcceptableAccuracyMeters = 100;

/// ما إذا كان يجب كتابة إحداثيات المزوّد في قاعدة البيانات من تحديد جديد،
/// وفق القاعدة المتفق عليها:
///
///  - اكتب إذا لم يكن هناك موقع مخزّن أصلاً، أو إذا كان المخزّن قديماً
///    (أقدم من [freshnessWindow]).
///  - اكتب إذا كانت الإحداثيات الجديدة أدق أو بذات الدقة وكانت الحركة
///    أكبر من [moveThresholdMeters].
///  - لا تكتب أبداً فوق تحديد طازج أدق منه تحديدٌ أردأ دقة
///    (مثلاً دقة جديدة 150م فوق مخزّن طازج بدقة 10م) — حتى لو تحرّك الجهاز.
///  - لا تكتب لحركة صغيرة (أقل من العتبة) ما دام المخزّن طازجاً.
enum LocationWriteReason {
  /// لا مخزّن طازج (بلا تاريخ، أو بلا دقة، أو أقدم من النافذة) => نكتب.
  noStoredOrStale,

  /// المخزّن طازج والجديد أدق أو بذات الدقة وحركة كافية => نكتب.
  improvedFreshMove,

  /// المخزّن طازج وأدق من الجديد => لا نكتب فوقه تحديداً أردأ.
  skipWorseAccuracy,

  /// المخزّن طازج والحركة أقل من العتبة => لا حاجة للكتابة.
  skipSmallMove,
}

/// نتيجة قرار الكتابة: هل نكتب، ولماذا.
class LocationWriteDecision {
  const LocationWriteDecision({
    required this.shouldWrite,
    required this.reason,
  });

  /// هل نكتب الإحداثيات الجديدة في قاعدة البيانات؟
  final bool shouldWrite;

  /// سبب القرار (للفحص/الاختبارات والتسجيل).
  final LocationWriteReason reason;

  static const LocationWriteDecision writeNoStoredOrStale =
      LocationWriteDecision(
        shouldWrite: true,
        reason: LocationWriteReason.noStoredOrStale,
      );
  static const LocationWriteDecision writeImprovedFreshMove =
      LocationWriteDecision(
        shouldWrite: true,
        reason: LocationWriteReason.improvedFreshMove,
      );
  static const LocationWriteDecision skipWorseAccuracy =
      LocationWriteDecision(
        shouldWrite: false,
        reason: LocationWriteReason.skipWorseAccuracy,
      );
  static const LocationWriteDecision skipSmallMove =
      LocationWriteDecision(
        shouldWrite: false,
        reason: LocationWriteReason.skipSmallMove,
      );
}

/// يقرر هل نكتب تحديداً جديداً فوق موقع المزوّد المخزّن حالياً.
///
/// [storedUpdatedAt] وقت آخر كتابة مخزّنة (null = غير معروف/قديم)؛
/// [storedAccuracy] دقة آخر كتابة بالأمتار (null = غير معروفة)؛
/// [newAccuracy] دقة التحديد الجديد بالأمتار؛
/// [movedMeters] المسافة بين الإحداثيات المخزّنة والجديدة.
LocationWriteDecision decideLocationWrite({
  required DateTime? storedUpdatedAt,
  required double? storedAccuracy,
  required double newAccuracy,
  required double movedMeters,
  required DateTime now,
  Duration freshnessWindow = defaultLocationFreshnessWindow,
  double moveThresholdMeters = defaultMoveThresholdMeters,
}) {
  final isFresh = storedUpdatedAt != null &&
      now.difference(storedUpdatedAt) <= freshnessWindow;

  if (!isFresh) {
    return LocationWriteDecision.writeNoStoredOrStale;
  }

  // المخزّن طازج.
  final storedMoreAccurate = storedAccuracy != null && storedAccuracy < newAccuracy;
  if (storedMoreAccurate) {
    return LocationWriteDecision.skipWorseAccuracy;
  }

  if (movedMeters <= moveThresholdMeters) {
    return LocationWriteDecision.skipSmallMove;
  }

  final newIsAtLeastAsAccurate =
      storedAccuracy == null || newAccuracy <= storedAccuracy;
  if (!newIsAtLeastAsAccurate) {
    return LocationWriteDecision.skipWorseAccuracy;
  }

  return LocationWriteDecision.writeImprovedFreshMove;
}