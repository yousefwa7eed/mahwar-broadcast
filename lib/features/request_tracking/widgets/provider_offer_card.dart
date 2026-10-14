import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/avatar_config.dart';
import '../../../core/utils/distance_format.dart';
import '../../../core/widgets/attachments_gallery.dart';
import '../../../l10n/app_localizations.dart';

class ProviderOfferCard extends StatelessWidget {
  final String providerName;
  final String workshopName;
  final double? distanceMeters;
  final double price;
  final String currency;
  final int estimatedMinutes;
  final String? providerNotes;
  final List<String> attachments;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;
  final String? avatarId;
  final String? avatarUrl;

  const ProviderOfferCard({
    super.key,
    required this.providerName,
    required this.workshopName,
    this.distanceMeters,
    required this.price,
    this.currency = 'EGP',
    required this.estimatedMinutes,
    this.providerNotes,
    this.attachments = const [],
    this.onAccept,
    this.onReject,
    this.onCall,
    this.onMessage,
    this.avatarId,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.orangePrimary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Provider Info
          Row(
            children: [
              AvatarWidget(
                avatarId: avatarId,
                role: 'provider',
                size: 48,
                photoUrl: avatarUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      providerName,
                      style: TextStyle(
                        fontFamily: 'Zain',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      workshopName,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Distance & Time
          Row(
            children: [
              if (distanceMeters != null) ...[
                _buildInfoChip(
                  icon: Icons.location_on_outlined,
                  label: formatApproxDistance(
                    distanceMeters,
                    meterUnit: l10n?.m ?? 'م',
                    kmUnit: l10n?.km ?? 'كم',
                  ),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
              ],
              _buildInfoChip(
                icon: Icons.access_time_rounded,
                label: '$estimatedMinutes ${l10n?.min ?? 'دقيقة'}',
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (providerNotes != null && providerNotes!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_rounded, size: 18, color: AppColors.orangePrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      providerNotes!,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (attachments.isNotEmpty) ...[
            AttachmentsGallery(urls: attachments, height: 100),
            const SizedBox(height: 16),
          ],

          // Price
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.orangePrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  l10n?.priceOfferLabel ?? 'عرض السعر',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${price.toStringAsFixed(0)} $currency',
                  style: const TextStyle(
                    fontFamily: 'Zain',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.orangePrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    l10n?.acceptPrice ?? 'قبول السعر',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    l10n?.reject ?? 'رفض',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Contact Buttons (shown after acceptance)
          if (onCall != null || onMessage != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onCall != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCall,
                      icon: const Icon(Icons.phone_rounded, size: 18),
                      label: Text(l10n?.call ?? 'اتصال'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.success),
                        foregroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (onCall != null && onMessage != null) const SizedBox(width: 12),
                if (onMessage != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onMessage,
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: Text(l10n?.message ?? 'رسالة'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.orangePrimary),
                        foregroundColor: AppColors.orangePrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.orangePrimary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
