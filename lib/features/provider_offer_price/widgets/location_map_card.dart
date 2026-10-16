import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// نافذة خريطة مصغّرة تُظهر موقع العميل في صفحة تقديم عرض السعر.
/// بالضغط عليها تُفتح شاشة الخريطة الكاملة التي تعرض موقع المزوّد والعميل معاً.
class LocationMapCard extends StatelessWidget {
  final LatLng customerLocation;
  final String orderId;

  const LocationMapCard({
    super.key,
    required this.customerLocation,
    required this.orderId,
  });

  void _openFullMap(BuildContext context) {
    context.push('/request/map?orderId=$orderId');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: () => _openFullMap(context),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: customerLocation,
                  initialZoom: 14,
                  interactionOptions:
                      const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.mahwar.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: customerLocation,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.error,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fullscreen_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      l10n?.tapToViewFullMap ?? 'اضغط لعرض الخريطة الكاملة',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}