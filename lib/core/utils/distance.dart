// حساب المسافات الجغرافية الموحّد للعميل.
//
// قاعدة واحدة: كل مسافة تُعرض للمستخدم تُحسب هنا بنفس الصيغة (Haversine)
// وبنفس نصف قطر الأرض الذي يستخدمه الخادم في دالة earthdistance في PostgreSQL،
// حتى لا يظهر للمستخدم رقم مختلف عمّا رتّب به الخادم قائمة المزوّدين.

import 'dart:math' as math;

/// نصف قطر الأرض المستخدم في الحساب بالأمتار.
///
/// 6,378,168 م = متوسط نصف القطر المستخدم في دالة `earthdistance` في PostgreSQL.
/// مطابقته تُبقي مسافة العميل متوافقة مع ما تحسبه دالّة `get_nearest_providers`
/// على الخادم (فرق لا يتعدّى ~0.1% وهو مهمَل تحت تقريب الـ 10 أمتار).
const double earthRadiusMeters = 6378168.0;

/// مسافة الدائرة العظمى بين نقطتين بالأمتار (صيغة Haversine).
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  final dLat = _radians(lat2 - lat1);
  final dLng = _radians(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_radians(lat1)) *
          math.cos(_radians(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMeters * c;
}

/// مسافة بين نقطتين إن كانت الإحداثيات متاحة فعلاً، وإلا null.
///
/// الإحداثيات (0, 0) تعني «غير محدّدة» في هذا التطبيق، فلا تُحسب لها مسافة
/// وتُعرض شرطة محايدة بدلاً من رقم مضلّل.
double? optionalDistanceMeters(
  double? lat1,
  double? lng1,
  double? lat2,
  double? lng2,
) {
  if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) return null;
  if (lat1 == 0 && lng1 == 0) return null;
  if (lat2 == 0 && lng2 == 0) return null;
  return distanceMeters(lat1, lng1, lat2, lng2);
}

double _radians(double degrees) => degrees * math.pi / 180.0;
