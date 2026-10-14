import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

final Geocoding _geocoding = Geocoding();

/// نتيجة تحديد موقع مُحسّن (refinePosition): إحداثيات + دقة + علم تقريبي.
class RefinedFix {
  const RefinedFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.isApproximate,
  });

  /// خط العرض.
  final double latitude;

  /// خط الطول.
  final double longitude;

  /// دقة التحديد بالأمتار (position.accuracy).
  final double accuracyMeters;

  /// true إذا كانت الدقة أكبر من الهدف المطلوب (افتراضياً 50 م).
  /// في هذه الحالة الموقع «تقريبي» ويُنصح المستخدم بتحسينه.
  final bool isApproximate;
}

/// يجيب الموقع الحالي للجهاز ويحوّله إلى عنوان نصي (عكس الجيوكودينغ)،
/// ويزوّد النتيجة مؤقتاً حتى لا تتكرر استدعاءات GPS مع كل شاشة.
class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  Position? _lastPosition;
  String? _lastAddress;

  /// مهلة تحديد موقع مباشر قبل اعتباره فشلاً (ثوانٍ).
  static const Duration _fixTimeout = Duration(seconds: 10);

  /// تحديد "مُسبَق" في الخلفية: عند استدعاء [prewarmRefinedPosition] يُبدأ تحديد
  /// دقيقاً (refinePosition) وتُخزّن المستقبلية. لاحقاً يمكن لـ
  /// [takePrewarmedRefinedPosition] استلامها فوراً إن اكتملت، أو null إن لم
  /// تكن مُبدأة — فيبدأ المُستدعي تحديداً جديداً.
  Future<RefinedFix?>? _refineWarmUp;

  /// يبدأ تحديداً دقيقاً في الخلفية (يُستدعى عند فتح شاشة الطلب) حتى يكون
  /// التحديد جاهزاً بسرعة عند الضغط على «موقعي». لا يفعل شيئاً إن كان جارياً.
  void prewarmRefinedPosition() {
    _refineWarmUp ??= refinePosition();
  }

  /// يُسلّم نتيجة التحديد المُسبَق (إن وُجد) ويصفّرها؛ يعيد null إن لم يكن هناك
  /// تحديد مُسبَق جارٍ. يتيح للمُنتقي طلب تحديد جديد إن كان القديم غير متاح.
  Future<RefinedFix?> takePrewarmedRefinedPosition() {
    final pending = _refineWarmUp;
    _refineWarmUp = null;
    return pending ?? Future<RefinedFix?>.value();
  }

  /// تحديد أدق: يستمع لتيّار المواقع ويعيد أول تحديد بدقة ≤ [targetAccuracyMeters]
  /// فوراً، وإلا يحتفظ بأفضل تحديد حتى انتهاء [maxDuration] ثم يعيده.
  ///
  /// يعيد null فقط لو: الخدمة مغلقة، الصلاحية مرفوضة، أو خطأ في التيّار.
  ///
  /// معلمات التبعية (للاختبارات الوحدوية):
  /// - [positionStreamFactory] دالة تعيد التيّار (افتراضي: high accuracy stream).
  /// - [isServiceEnabled] دالة تتحقق من تفعيل GPS (افتراضي: Geolocator.isLocationServiceEnabled).
  /// - [checkPermission] دالة تفحص الصلاحية (افتراضي: Geolocator.checkPermission).
  /// - [requestPermission] دالة تطلب الصلاحية (افتراضي: Geolocator.requestPermission).
  Future<RefinedFix?> refinePosition({
    double targetAccuracyMeters = 50,
    Duration maxDuration = const Duration(seconds: 30),
    Stream<Position> Function()? positionStreamFactory,
    Future<bool> Function()? isServiceEnabled,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
  }) async {
    final serviceCheck = isServiceEnabled ?? Geolocator.isLocationServiceEnabled;
    final check = checkPermission ?? Geolocator.checkPermission;
    final request = requestPermission ?? Geolocator.requestPermission;

    if (!await serviceCheck()) return null;
    var permission = await check();
    if (permission == LocationPermission.denied) {
      permission = await request();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final factory = positionStreamFactory ??
        () => Geolocator.getPositionStream(
              locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
            );

    RefinedFix? best;
    final completer = Completer<RefinedFix?>();
    StreamSubscription<Position>? sub;
    Timer? timeoutTimer;

    void finish() {
      if (completer.isCompleted) return;
      timeoutTimer?.cancel();
      sub?.cancel();
      completer.complete(best);
    }

    try {
      sub = factory().listen(
        (position) {
          final fix = RefinedFix(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracyMeters: position.accuracy,
            isApproximate: position.accuracy > targetAccuracyMeters,
          );
          if (best == null || fix.accuracyMeters < best!.accuracyMeters) {
            best = fix;
          }
          if (fix.accuracyMeters <= targetAccuracyMeters) {
            finish();
          }
        },
        onError: (_) {
          finish();
        },
        cancelOnError: true,
      );
      timeoutTimer = Timer(maxDuration, finish);
    } catch (_) {
      return best;
    }

    return completer.future;
  }

  /// يعيد ضبط القيم المخزّنة مؤقتاً (يُستخدم لو تغيّر الموقع بشكل جوهري).
  void resetCache() {
    _lastPosition = null;
    _lastAddress = null;
  }

  /// يجيب الموقع الحالي بعد التأكد من تفعيل الخدمة وطلب الصلاحية.
  /// يعيد null فقط لو الخدمة مغلقة أو الصلاحية مرفوضة أو فشل التحديد كله.
  ///
  /// بقيمة forceRefresh = true: نطلب تحديداً مباشراً جديداً بالدقة العالية
  /// أولاً (الملاذ الأول)، ثم بالدقة المتوسطة، ولا نُسقط إلى آخر موقع معروف
  /// من الجهاز إلا كملاذ أخير. بقيمة false: نُفضل مخزون الذاكرة ثم آخر موقع
  /// معروف (سريع) ثم GPS مباشر.
  ///
  /// [maxLastKnownAge] (اختياري): عند ضبطه يقتصر قبول آخر موقع معروف على ما
  /// كان زمنه ضمن هذه المدة (خلاف ذلك يُعامَل كعديم). الافتراضي null يُبقي
  /// السلوك الحالي كما هو لجميع المتصلين.
  ///
  /// تُعرض دقة الإحداثيات (position.accuracy بالأمتار) على المتصل ليقرر
  /// عليها — لا تُتجاهل.
  Future<Position?> getCurrentPosition({
    bool forceRefresh = false,
    Duration? maxLastKnownAge,
  }) async {
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

    if (forceRefresh) {
      // تحديد مباشر جديد يجب ألا يُستبدل بموقع قديم أثناء وجوده.
      Position? fresh = await _tryDirectFix(LocationAccuracy.high);
      fresh ??= await _tryDirectFix(LocationAccuracy.medium);
      if (fresh != null) {
        _lastPosition = fresh;
        return fresh;
      }
      // ملاذ أخير فقط: آخر موقع يعرفه الجهاز، بنقاوته الأصلية (accuracy)،
      // وضمن العمر الأقصى إن طُلبت قيود الحداثة (maxLastKnownAge).
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && isFreshEnough(lastKnown.timestamp, maxLastKnownAge)) {
          _lastPosition = lastKnown;
          return lastKnown;
        }
        return null;
      } catch (_) {
        return null;
      }
    }

    // المسار السريع (بدون قوة): آخر موقع معروف ثم GPS مباشر.
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && isFreshEnough(lastKnown.timestamp, maxLastKnownAge)) {
        _lastPosition = lastKnown;
        return lastKnown;
      }
    } catch (_) {
      // نكمل لمحاولة GPS المباشر
    }

    return _tryDirectFix(LocationAccuracy.high);
  }

  /// محاولة تحديد مباشر واحد بدقة معيّنة وبمهلة زمنية محدودة.
  /// يعيد null عند أي فشل أو تجاوز المهلة (لا يعلق لأجل غير مسمى).
  Future<Position?> _tryDirectFix(LocationAccuracy accuracy) async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy, timeLimit: _fixTimeout),
      );
    } catch (_) {
      return null;
    }
  }

  /// دالة حداثة نقيّة: هل زمان [timestamp] ضمن [maxAge] بالنسبة إلى [now]؟
  /// عند غياب [maxAge] تُقبل أي قيمة (السلوك الحالي)، وعند غياب الطابع الزمني
  /// تُرفض. مفصولة عن الاستدعاء لتُختبَر وحدةً مستقلة.
  static bool isFreshEnough(
    DateTime? timestamp,
    Duration? maxAge, {
    DateTime? now,
  }) {
    if (maxAge == null) return true;
    if (timestamp == null) return false;
    final reference = now ?? DateTime.now();
    return reference.difference(timestamp).abs() <= maxAge;
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
      final placemarks = await _geocoding.placemarkFromCoordinates(
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

  /// يحوّل إحداثيات معيّنة إلى عنوان نصي مقروء (مثل: المعادي، القاهرة، مصر).
  /// يعيد الإحداثيات نفسها كنص احتياطي إن فشل التحويل أو لم يكن هناك عنوان.
  Future<String> getAddressForLocation(double latitude, double longitude) async {
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(latitude, longitude);
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
        if (parts.isNotEmpty) return parts.join('، ');
      }
    } catch (_) {
      // نكمل للإحداثيات كاحتياط
    }
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }
}