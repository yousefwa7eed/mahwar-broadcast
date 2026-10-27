import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/app_colors.dart';

/// شعار ماركة السيارة من معرّفها فقط (`assets/brands/<id>.svg`) — للاستخدام
/// داخل بطاقات الطلبات حيث لا يُحمَّل كتالوج كامل. يسقط لأيقونة سيارة عند
/// غياب المعرّف أو الملف.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.brandId,
    this.size = 20,
    this.color,
  });

  final String? brandId;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final id = brandId;
    final fallback = Icon(
      Icons.directions_car_rounded,
      size: size,
      color: color ?? AppColors.orangePrimary,
    );
    if (id == null || id.isEmpty) return fallback;
    return SvgPicture.asset(
      'assets/brands/$id.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => fallback,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
