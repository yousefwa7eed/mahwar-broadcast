import 'package:flutter/foundation.dart';

import 'vehicle_catalog.dart';

/// اختيار سيارة كامل من المعالج (كتالوج + سنة + لون + لوحة اختيارية).
///
/// يُستخدم في التسجيل (لتوليد metadata) وفي إضافة/تعديل سيارة في الملف الشخصي.
@immutable
class VehicleSelection {
  const VehicleSelection({
    required this.brand,
    required this.model,
    required this.generation,
    required this.trim,
    required this.modelYear,
    required this.color,
    this.plateLetters,
    this.plateDigits,
  });

  final VehicleBrand brand;
  final VehicleModel model;
  final VehicleGeneration generation;
  final VehicleTrim trim;
  final int modelYear;
  final VehicleColor color;
  final String? plateLetters;
  final String? plateDigits;

  String get plateNumber =>
      plateLetters != null && plateDigits != null
          ? '$plateLetters $plateDigits'
          : '';

  /// المفاتيح التي يقرؤها `handle_new_user` في قاعدة البيانات.
  Map<String, dynamic> toSignupMetadata() => {
        'vehicle_trim_id': trim.id,
        'vehicle_model_year': modelYear,
        'vehicle_color_id': color.id,
        'vehicle_plate_letters': plateLetters,
        'vehicle_plate_digits': plateDigits,
      };

  /// صف جاهز لجدول `vehicles` (بدون user_id — يُضاف في الشاشة).
  Map<String, dynamic> toInsertJson() => {
        'trim_id': trim.id,
        'model_year': modelYear,
        'color_id': color.id,
        'plate_letters': plateLetters,
        'plate_digits': plateDigits,
      };

  VehicleSelection copyWith({
    VehicleBrand? brand,
    VehicleModel? model,
    VehicleGeneration? generation,
    VehicleTrim? trim,
    int? modelYear,
    VehicleColor? color,
    String? plateLetters,
    String? plateDigits,
    bool clearPlate = false,
  }) {
    return VehicleSelection(
      brand: brand ?? this.brand,
      model: model ?? this.model,
      generation: generation ?? this.generation,
      trim: trim ?? this.trim,
      modelYear: modelYear ?? this.modelYear,
      color: color ?? this.color,
      plateLetters: clearPlate ? null : (plateLetters ?? this.plateLetters),
      plateDigits: clearPlate ? null : (plateDigits ?? this.plateDigits),
    );
  }
}
