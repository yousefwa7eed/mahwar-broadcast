import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../constants/app_colors.dart';
import '../services/app_messenger.dart';
import '../utils/map_launcher.dart';

/// اقتراح للمزوّد بعد موافقة العميل على السعر: التوجّه إليه عبر تطبيق
/// خرائط جوجل. لا نملك ملاحة داخلية، فزر واحد يفتح الاتجاهات مباشرة.
class NavigateToCustomerCard extends StatelessWidget {
  const NavigateToCustomerCard({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  Future<void> _openDirections(BuildContext context) async {
    final opened = await MapLauncher.openDirections(
      latitude: latitude,
      longitude: longitude,
    );
    if (!opened && context.mounted) {
      AppMessenger.showToast(
        context,
        AppLocalizations.of(context)?.noMapAppsAvailable ??
            'لا توجد تطبيقات خرائط متاحة على جهازك',
        background: AppColors.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.navigation_rounded,
                size: 18,
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n?.navigateToCustomerTitle ??
                      'العميل وافق على السعر — توجّه إليه الآن',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () => _openDirections(context),
              icon: const Icon(Icons.directions_rounded, size: 18),
              label: Text(
                l10n?.navigateToCustomerAction ?? 'التوجّه إلى العميل',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
