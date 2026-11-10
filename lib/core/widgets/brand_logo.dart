import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/vehicle_catalog.dart';

/// شعار ماركة السيارة داخل مربع أبيض مطفي محايد — اللون للشعار وحده. يسقط
/// إلى حرف الماركة عند غياب الملف أو فشل تحميله، فلا تظهر مساحة فارغة أبدًا.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    required this.brand,
    this.size = 48,
    this.padding = 8,
  });

  final VehicleBrand brand;
  final double size;
  final double padding;

  /// أبيض مطفي (لا أبيض صريح) حتى لا يتوه الشعار الملون في خلفية البطاقة.
  static const Color _tile = Color(0xFFF7F7F5);

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(brand.brandColor) ?? const Color(0xFFFF6B00);

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: brand.logoAsset == null
          ? _Monogram(brand: brand, color: color)
          : SvgPicture.asset(
              'assets/${brand.logoAsset}',
              fit: BoxFit.contain,
              placeholderBuilder: (_) => _Monogram(brand: brand, color: color),
              errorBuilder: (_, _, _) => _Monogram(brand: brand, color: color),
            ),
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null || !hex.startsWith('#') || hex.length != 7) return null;
    final value = int.tryParse(hex.substring(1), radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.brand, required this.color});

  final VehicleBrand brand;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final letter = brand.nameEn.isEmpty
        ? '?'
        : brand.nameEn.substring(0, 1).toUpperCase();
    return FittedBox(
      child: Text(
        letter,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
