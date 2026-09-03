import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// يجيب الموقع الحالي للجهاز ويحوّله إلى عنوان نصي (عكس الجيوكودينغ)،
/// ويزوّد النتيجة مؤقتاً حتى لا تتكرر استدعاءات GPS مع كل شاشة.
class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  Position? _lastPosition;
  String? _lastAddress;

  /// يجيب الموقع الحالي بعد التأكد من تفعيل الخدمة وطلب الصلاحية.
  /// يبدأ بآخر موقع معروف (سريع) ثم يحاول GPS مباشر، ومع أي فشل حقيقي
  /// يعيد null فقط لو الخدمة مغلقة أو الصلاحية مرفوضة.
  Future<Position?> getCurrentPosition({bool forceRefresh = false}) async {
    if (!forceRefresh && _lastPosition != null) return _lastPosition;

    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) return null;

    if (!forceRefresh && _lastPosition != null) return _lastPosition;

    // 1) آخر موقع معروف من الجهاز (بدون تشغيل GPS)
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _lastPosition = lastKnown;
        return lastKnown;
      }
    } catch (_) {
      // نكمل لمحاولة GPS المباشر
    }

    // 2) تحديد مباشر بالدقة العالية
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _lastPosition = position;
      return position;
    } catch (_) {
      // 3) إعادة محاولة بدقة متوسطة (مقاومة لفشل الإصلاح السريع)
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
        );
        _lastPosition = position;
        return position;
      } catch (_) {
        return null;
      }
    }
  }

  /// يجيب عنوان نصي مقروء للموقع الحالي (مثل: المعادي، القاهرة، مصر).
  /// يعيد null فقط لو الموقع غير متاح أو رفض المستخدم الصلاحية.
  Future<String?> getCurrentAddress({bool forceRefresh = false}) async {
    if (!forceRefresh && _lastAddress != null && _lastAddress!.isNotEmpty) {
      return _lastAddress;
    }

    final position = await getCurrentPosition(forceRefresh: forceRefresh);
    if (position == null) return null;

    String address = '';
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final street = (p.street ?? '').trim();
        final district = (p.subLocality ?? '').trim();
        final city = (p.locality ?? '').trim();
        final country = (p.country ?? '').trim();

        final parts = <String>[
          if (street.isNotEmpty) street,
          if (district.isNotEmpty) district,
          if (city.isNotEmpty && city != district) city,
          if (country.isNotEmpty && country != city) country,
        ];
        address = parts.join('، ');
      }
    } catch (_) {
      // في حال فشل التحويل، نكتب الإحداثيات نفسها كعنوان مؤقت
      address = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    }

    // حتى لو لم ينتج الجيوكودينغ نصاً، نعرض الإحداثيات بدلاً من تركها فارغة
    if (address.isEmpty) {
      address = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    }

    _lastAddress = address;
    return address;
  }

  /// يعيد ضبط القيم المخزّنة مؤقتاً (يُستخدم لو تغيّر الموقع بشكل جوهري).
  void resetCache() {
    _lastPosition = null;
    _lastAddress = null;
  }
}