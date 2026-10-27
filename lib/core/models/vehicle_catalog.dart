import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';

/// كتالوج السيارات المرجعي: ماركة → موديل → جيل → فئة.
///
/// تُبنى النسخة من استجابة قاعدة البيانات أو من ملف الكاش المحلي، ثم تُحفظ في
/// الذاكرة طوال عمر التطبيق. كل المعرّفات نصية (slug) ومطابقة لما في القاعدة.

@immutable
class VehicleBrand {
  const VehicleBrand({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.countryCode,
    this.logoAsset,
    this.brandColor,
    this.isPopular = false,
    this.sortOrder = 0,
    this.models = const [],
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String? countryCode;
  final String? logoAsset;
  final String? brandColor;
  final bool isPopular;
  final int sortOrder;
  final List<VehicleModel> models;

  String name(bool isArabic) => isArabic ? nameAr : nameEn;

  factory VehicleBrand.fromJson(Map<String, dynamic> json) {
    return VehicleBrand(
      id: json['id'] as String,
      nameAr: json['name_ar'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      countryCode: json['country_code'] as String?,
      logoAsset: json['logo_asset'] as String?,
      brandColor: json['brand_color'] as String?,
      isPopular: json['is_popular'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      models: (json['models'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => VehicleModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }
}

@immutable
class VehicleModel {
  const VehicleModel({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.bodyType,
    this.sortOrder = 0,
    this.generations = const [],
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String bodyType;
  final int sortOrder;
  final List<VehicleGeneration> generations;

  String name(bool isArabic) => isArabic ? nameAr : nameEn;

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String,
      nameAr: json['name_ar'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      bodyType: json['body_type'] as String? ?? 'sedan',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      generations: (json['generations'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => VehicleGeneration.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }
}

@immutable
class VehicleGeneration {
  const VehicleGeneration({
    required this.id,
    required this.yearFrom,
    required this.yearTo,
    required this.nameAr,
    required this.nameEn,
    this.sortOrder = 0,
    this.trims = const [],
  });

  final String id;
  final int yearFrom;
  final int? yearTo;
  final String nameAr;
  final String nameEn;
  final int sortOrder;
  final List<VehicleTrim> trims;

  String name(bool isArabic) => isArabic ? nameAr : nameEn;

  /// السنوات القابلة للاختيار داخل هذا الجيل، الأحدث أولاً.
  List<int> get years {
    final last = yearTo ?? DateTime.now().year;
    return [for (var year = last; year >= yearFrom; year--) year];
  }

  factory VehicleGeneration.fromJson(Map<String, dynamic> json) {
    return VehicleGeneration(
      id: json['id'] as String,
      yearFrom: (json['year_from'] as num).toInt(),
      yearTo: (json['year_to'] as num?)?.toInt(),
      nameAr: json['name_ar'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      trims: (json['trims'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => VehicleTrim.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }
}

@immutable
class VehicleTrim {
  const VehicleTrim({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.engineCc,
    this.fuel,
    this.transmission,
    this.horsepower,
    this.seats,
    this.sortOrder = 0,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final int? engineCc;
  final String? fuel;
  final String? transmission;
  final int? horsepower;
  final int? seats;
  final int sortOrder;

  String name(bool isArabic) => isArabic ? nameAr : nameEn;

  factory VehicleTrim.fromJson(Map<String, dynamic> json) {
    return VehicleTrim(
      id: json['id'] as String,
      nameAr: json['name_ar'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      engineCc: (json['engine_cc'] as num?)?.toInt(),
      fuel: json['fuel'] as String?,
      transmission: json['transmission'] as String?,
      horsepower: (json['horsepower'] as num?)?.toInt(),
      seats: (json['seats'] as num?)?.toInt(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class VehicleColor {
  const VehicleColor({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.hex,
    this.sortOrder = 0,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String hex;
  final int sortOrder;

  String name(bool isArabic) => isArabic ? nameAr : nameEn;

  factory VehicleColor.fromJson(Map<String, dynamic> json) {
    return VehicleColor(
      id: json['id'] as String,
      nameAr: json['name_ar'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      hex: json['hex'] as String? ?? '#FFFFFF',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

/// تسميات عربية/إنجليزية لأنواع الهيكل وناقل الحركة والوقود.
String vehicleBodyTypeLabel(String? bodyType, AppLocalizations? l10n) {
  switch (bodyType) {
    case 'hatchback':
      return l10n?.vehicleBodyHatchback ?? 'هاتشباك';
    case 'suv':
      return l10n?.vehicleBodySuv ?? 'SUV';
    case 'crossover':
      return l10n?.vehicleBodyCrossover ?? 'كروس أوفر';
    case 'pickup':
      return l10n?.vehicleBodyPickup ?? 'بيك أب';
    case 'van':
      return l10n?.vehicleBodyVan ?? 'فان';
    case 'mpv':
      return l10n?.vehicleBodyMpv ?? 'MPV';
    case 'coupe':
      return l10n?.vehicleBodyCoupe ?? 'كوبيه';
    case 'wagon':
      return l10n?.vehicleBodyWagon ?? 'ستيشن';
    case 'sedan':
    default:
      return l10n?.vehicleBodySedan ?? 'سيدان';
  }
}

String vehicleFuelLabel(String? fuel, AppLocalizations? l10n) {
  switch (fuel) {
    case 'diesel':
      return l10n?.vehicleFuelDiesel ?? 'ديزل';
    case 'hybrid':
      return l10n?.vehicleFuelHybrid ?? 'هايبرد';
    case 'electric':
      return l10n?.vehicleFuelElectric ?? 'كهربائي';
    case 'cng':
      return l10n?.vehicleFuelCng ?? 'غاز طبيعي';
    case 'petrol':
    default:
      return l10n?.vehicleFuelPetrol ?? 'بنزين';
  }
}

String vehicleTransmissionLabel(String? transmission, AppLocalizations? l10n) {
  switch (transmission) {
    case 'manual':
      return l10n?.vehicleTransmissionManual ?? 'عادي';
    case 'cvt':
      return l10n?.vehicleTransmissionCvt ?? 'CVT';
    case 'dct':
      return l10n?.vehicleTransmissionDct ?? 'DCT';
    case 'automatic':
    default:
      return l10n?.vehicleTransmissionAutomatic ?? 'أوتوماتيك';
  }
}

/// الكتالوج كاملًا مع فهارس بحث سريعة بالمعرّف.
@immutable
class VehicleCatalog {
  VehicleCatalog({
    required this.fetchedAt,
    required this.brands,
    required this.colors,
  })  : _brandsById = {for (final brand in brands) brand.id: brand},
        _modelsById = {
          for (final brand in brands)
            for (final model in brand.models) model.id: model,
        },
        _generationsById = {
          for (final brand in brands)
            for (final model in brand.models)
              for (final generation in model.generations)
                generation.id: generation,
        },
        _trimsById = {
          for (final brand in brands)
            for (final model in brand.models)
              for (final generation in model.generations)
                for (final trim in generation.trims)
                  trim.id: trim,
        },
        _colorsById = {for (final color in colors) color.id: color},
        _generationIdByTrimId = {
          for (final brand in brands)
            for (final model in brand.models)
              for (final generation in model.generations)
                for (final trim in generation.trims) trim.id: generation.id,
        },
        _modelIdByGenerationId = {
          for (final brand in brands)
            for (final model in brand.models)
              for (final generation in model.generations)
                generation.id: model.id,
        },
        _brandIdByModelId = {
          for (final brand in brands)
            for (final model in brand.models) model.id: brand.id,
        };

  static const int schemaVersion = 1;

  final DateTime fetchedAt;
  final List<VehicleBrand> brands;
  final List<VehicleColor> colors;

  final Map<String, VehicleBrand> _brandsById;
  final Map<String, VehicleModel> _modelsById;
  final Map<String, VehicleGeneration> _generationsById;
  final Map<String, VehicleTrim> _trimsById;
  final Map<String, VehicleColor> _colorsById;
  final Map<String, String> _generationIdByTrimId;
  final Map<String, String> _modelIdByGenerationId;
  final Map<String, String> _brandIdByModelId;

  VehicleBrand? brand(String? id) => id == null ? null : _brandsById[id];
  VehicleModel? model(String? id) => id == null ? null : _modelsById[id];
  VehicleGeneration? generation(String? id) =>
      id == null ? null : _generationsById[id];
  VehicleTrim? trim(String? id) => id == null ? null : _trimsById[id];
  VehicleColor? color(String? id) => id == null ? null : _colorsById[id];

  VehicleGeneration? generationOfTrim(String? trimId) {
    if (trimId == null) return null;
    return _generationsById[_generationIdByTrimId[trimId]];
  }

  VehicleModel? modelOfTrim(String? trimId) {
    final generation = generationOfTrim(trimId);
    if (generation == null) return null;
    return _modelsById[_modelIdByGenerationId[generation.id]];
  }

  VehicleBrand? brandOfTrim(String? trimId) {
    final model = modelOfTrim(trimId);
    if (model == null) return null;
    return _brandsById[_brandIdByModelId[model.id]];
  }

  factory VehicleCatalog.fromJson(Map<String, dynamic> json) {
    final fetchedAtRaw = json['fetched_at'] as String?;
    return VehicleCatalog(
      fetchedAt: fetchedAtRaw != null
          ? DateTime.tryParse(fetchedAtRaw) ?? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0),
      brands: (json['brands'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => VehicleBrand.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      colors: (json['colors'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => VehicleColor.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }
}
