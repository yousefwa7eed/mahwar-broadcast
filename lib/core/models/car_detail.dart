class CarDetail {
  final String id;
  final String userId;
  final String make;
  final String model;
  final int year;
  final String? plateNumber;
  final String? color;
  final DateTime? createdAt;

  const CarDetail({
    required this.id,
    required this.userId,
    required this.make,
    required this.model,
    required this.year,
    this.plateNumber,
    this.color,
    this.createdAt,
  });

  factory CarDetail.fromJson(Map<String, dynamic> json) {
    return CarDetail(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      make: json['make'] as String,
      model: json['model'] as String,
      year: json['year'] as int,
      plateNumber: json['plate_number'] as String?,
      color: json['color'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'make': make,
      'model': model,
      'year': year,
      'plate_number': plateNumber,
      'color': color,
    };
  }

  String get displayName => '$make $model $year';
}
