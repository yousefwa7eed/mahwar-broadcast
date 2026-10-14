import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/avatar_config.dart';
import '../../../core/services/server_clock.dart';
import '../../../core/utils/distance_format.dart';
import '../../../core/widgets/attachments_gallery.dart';
import '../../../l10n/app_localizations.dart';

/// بطاقة الطلب الواصل للمزوّد في لوحة التحكم.
/// تعرض اسم العميل، السيارة، الموقع بالعربية (وليس الإحداثيات فقط)،
/// المرفقات إن وُجدت، المسافة التقريبية، وتنبيه الإلغاء التلقائي
/// (5 دقائق — قرار العميل) بعدّاد مباشر.
class NearbyRequestCard extends StatelessWidget {
  final String customerName;
  final String carMake;
  final String carModel;
  final int carYear;
  final String issueType;
  final double? distanceMeters;
  final String address;
  final List<String> attachments;
  final DateTime? deadline;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onLocationTap;
  final String? customerAvatarId;
  final String? customerAvatarUrl;

  const NearbyRequestCard({
    super.key,
    this.customerName = 'العميل',
    required this.carMake,
    required this.carModel,
    required this.carYear,
    required this.issueType,
    required this.distanceMeters,
    required this.address,
    this.attachments = const [],
    this.deadline,
    this.onAccept,
    this.onReject,
    this.onLocationTap,
    this.customerAvatarId,
    this.customerAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: distance + service type
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.orangePrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.orangePrimary),
                    const SizedBox(width: 4),
                    Text(
                      formatApproxDistance(
                        distanceMeters,
                        meterUnit: l10n?.m ?? 'م',
                        kmUnit: l10n?.km ?? 'كم',
                      ),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.orangePrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  issueType,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Customer name
          Row(
            children: [
              AvatarWidget(
                avatarId: customerAvatarId,
                role: 'car_owner',
                size: 36,
                photoUrl: customerAvatarUrl,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  customerName,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Car info
          Row(
            children: [
              const Icon(Icons.directions_car_rounded, size: 18, color: AppColors.orangePrimary),
              const SizedBox(width: 8),
              Text(
                '$carMake $carModel $carYear',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Location (Arabic address) — tap to open full map
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onLocationTap,
            child: Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address.isEmpty ? 'الموقع غير متاح' : address,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onLocationTap != null)
                  Icon(
                    Icons.open_in_full_rounded,
                    size: 14,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
              ],
            ),
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            AttachmentsGallery(urls: attachments, height: 70),
          ],
          if (deadline != null) ...[
            const SizedBox(height: 10),
            _RequestDeadline(deadline: deadline!),
          ],
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text(
                    'قبول الطلب',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text(
                    'رفض',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// تنبيه مهلة الإلغاء التلقائي (5 دقائق — قرار العميل) بعدّاد تنازلي مباشر.
/// عند انتهاء العدّاد تختفي رسالة المهلة فوراً (لا تبقى ثابتة)
/// بينما تبقى البطاقة ظاهرة — الإزالة الحقيقية تأتي من الخادم
/// (cron expires) عبر التحديث الفوري Realtime.
class _RequestDeadline extends StatefulWidget {
  final DateTime deadline;

  const _RequestDeadline({required this.deadline});

  @override
  State<_RequestDeadline> createState() => _RequestDeadlineState();
}

class _RequestDeadlineState extends State<_RequestDeadline> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    // ثبّت "الآن" على ساعة الخادم ثم احسب المتبقي — لا على ساعة الجهاز.
    _remaining = _computeRemaining();
    if (_remaining.inSeconds > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
    }
    ServerClock.instance.refresh().then((_) {
      if (mounted) _updateRemaining();
    });
  }

  Duration _computeRemaining() {
    final next = widget.deadline.difference(ServerClock.instance.now);
    return next.inSeconds <= 0 ? Duration.zero : next;
  }

  void _updateRemaining() {
    final next = _computeRemaining();
    if (next.inSeconds <= 0) {
      _timer?.cancel();
    }
    if (mounted) setState(() => _remaining = next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (d.inHours > 0) {
      return '${d.inHours}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final expired = _remaining.inSeconds <= 0;

    // عند انتهاء المهلة تختفي الرسالة فوراً؛ هذه الحالة هي مجرد احتياط أمان.
    if (expired) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'سيُلغى الطلب تلقائياً خلال 5 دقائق — متبقي ${_fmt(_remaining)}',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}