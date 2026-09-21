class ServiceType {
  final String id;
  final String nameAr;
  final String nameEn;
  final String? iconName;
  final String? descriptionAr;
  final String? descriptionEn;

  const ServiceType({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.iconName,
    this.descriptionAr,
    this.descriptionEn,
  });

  factory ServiceType.fromJson(Map<String, dynamic> json) {
    return ServiceType(
      id: json['id'] as String,
      nameAr: json['name_ar'] as String,
      nameEn: json['name_en'] as String,
      iconName: json['icon_name'] as String?,
      descriptionAr: json['description_ar'] as String?,
      descriptionEn: json['description_en'] as String?,
    );
  }

  String name(bool isArabic) => isArabic ? nameAr : nameEn;
  String? description(bool isArabic) => isArabic ? descriptionAr : descriptionEn;
}
