import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class ServiceCategory {
  final String id;
  final String nameAr;
  final String nameEn;
  final IconData icon;
  final Color color;

  const ServiceCategory({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.icon,
    required this.color,
  });
}

const List<ServiceCategory> kServiceCategories = [
  ServiceCategory(
    id: 'crane',
    nameAr: 'ونش S.O.S',
    nameEn: 'Crane S.O.S',
    icon: Icons.fire_truck_outlined,
    color: Color(0xFFFF6B00),
  ),
  ServiceCategory(
    id: 'tires',
    nameAr: 'خدمات الإطارات',
    nameEn: 'Tire Services',
    icon: Icons.tire_repair_rounded,
    color: Color(0xFF28A745),
  ),
  ServiceCategory(
    id: 'fuel',
    nameAr: 'تزويد بنزين',
    nameEn: 'Fuel Delivery',
    icon: Icons.local_gas_station_outlined,
    color: Color(0xFF007BFF),
  ),
  ServiceCategory(
    id: 'battery',
    nameAr: 'بطاريات / كهرباء',
    nameEn: 'Battery / Electric',
    icon: Icons.battery_charging_full_rounded,
    color: Color(0xFF6F42C1),
  ),
  ServiceCategory(
    id: 'mechanic',
    nameAr: 'ميكانيكي طوارئ',
    nameEn: 'Emergency Mechanic',
    icon: Icons.build_rounded,
    color: Color(0xFFDC3545),
  ),
];

class ServicesGrid extends StatelessWidget {
  final Function(ServiceCategory) onServiceTap;

  const ServicesGrid({super.key, required this.onServiceTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.emergencyServices ?? 'خدمات الطوارئ',
            style: TextStyle(
              fontFamily: 'Zain',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: kServiceCategories.length,
            itemBuilder: (context, index) {
              final service = kServiceCategories[index];
              return _ServiceCard(
                service: service,
                isDark: isDark,
                onTap: () => onServiceTap(service),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceCategory service;
  final bool isDark;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.service,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: service.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(service.icon, color: service.color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              Localizations.localeOf(context).languageCode == 'ar' ? service.nameAr : service.nameEn,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
