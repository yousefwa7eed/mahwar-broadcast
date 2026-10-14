// تنسيق موحّد واحد لكل المسافات المعروضة في التطبيق.
//
// قاعدة العرض الواحدة (تطبيق واحد لا تنسيقان متناقضان):
// - null → شرطة محايدة "—" (لا نُخفي المسافة، ولا نعرض "0" كأنها مسافة حقيقية).
// - تُقرَّب الأمتار إلى أقرب 10 أمتار أولاً (دقة GPS لا تستحق أكثر من ذلك).
// - إن كانت النتيجة المقرّبة < 1000 م → تُعرض بالأمتار مع الوحدة (م / m).
// - وإلا → تُعرض بالكيلومترات بمنزلة عشرية واحدة مع الوحدة (كم / km).
// - البادئة دائماً "≈ " لأن القيمة تقريبية.

/// يُنسّق مسافة بالأمتار وفق القاعدة الموحّدة أعلاه.
///
/// [meters] المسافة بالأمتار (قد تكون null).
/// [meterUnit] وحدة الأمتار المعرّبة من ARB (م / m).
/// [kmUnit] وحدة الكيلومترات المعرّبة من ARB (كم / km).
/// [dash] الرمز المعروض عند غياب القيمة.
String formatApproxDistance(
  double? meters, {
  required String meterUnit,
  required String kmUnit,
  String dash = '—',
}) {
  if (meters == null || meters.isNaN || meters.isInfinite) return dash;
  final roundedMeters = (meters / 10).round() * 10;
  if (roundedMeters < 1000) {
    return '≈ $roundedMeters $meterUnit';
  }
  final km = roundedMeters / 1000;
  return '≈ ${km.toStringAsFixed(1)} $kmUnit';
}
