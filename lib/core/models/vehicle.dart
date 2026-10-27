import 'package:flutter/foundation.dart';

import 'vehicle_catalog.dart';

/// مركبة مسجّلة لصاحب حساب — صف من جدول `vehicles`.
@immutable
class Vehicle {
  const Vehicle({
    required this.id,
    required this.userId,
    required this.trimId,
    required this.modelYear,
    this.colorId,
    this.plateLetters,
    this.plateDigits,
    this.isDefault = false,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String trimId;
  final int modelYear;
  final String? colorId;
  final String? plateLetters;
  final String? plateDigits;
  final bool isDefault;
  final DateTime? createdAt;

  String? get plateNumber {
    if (plateLetters == null || plateDigits == null) return null;
    return '$plateLetters $plateDigits';
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      trimId: json['trim_id'] as String,
      modelYear: (json['model_year'] as num).toInt(),
      colorId: json['color_id'] as String?,
      plateLetters: json['plate_letters'] as String?,
      plateDigits: json['plate_digits'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'user_id': userId,
        'trim_id': trimId,
        'model_year': modelYear,
        'color_id': colorId,
        'plate_letters': plateLetters,
        'plate_digits': plateDigits,
        'is_default': isDefault,
      };

  VehicleSummary resolve(VehicleCatalog catalog) {
    return VehicleSummary(
      vehicle: this,
      brand: catalog.brandOfTrim(trimId),
      model: catalog.modelOfTrim(trimId),
      generation: catalog.generationOfTrim(trimId),
      trim: catalog.trim(trimId),
      color: catalog.color(colorId),
    );
  }
}

/// مركبة + أسماء الكتالوج المحلولة، للعرض دون استعلامات إضافية.
@immutable
class VehicleSummary {
  const VehicleSummary({
    required this.vehicle,
    this.brand,
    this.model,
    this.generation,
    this.trim,
    this.color,
  });

  final Vehicle vehicle;
  final VehicleBrand? brand;
  final VehicleModel? model;
  final VehicleGeneration? generation;
  final VehicleTrim? trim;
  final VehicleColor? color;

  String title(bool isArabic) {
    final make = brand?.name(isArabic) ?? '';
    final name = model?.name(isArabic) ?? '';
    final base = '$make $name'.trim();
    return base.isEmpty ? '—' : '$base ${vehicle.modelYear}';
  }

  String? subtitle(bool isArabic) {
    final parts = <String>[
      if (trim != null) trim!.name(isArabic),
      if (color != null) color!.name(isArabic),
      if (vehicle.plateNumber != null) vehicle.plateNumber!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
