import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/attachments_gallery.dart';

class NearbyRequestCard extends StatelessWidget {
  final String carMake;
  final String carModel;
  final int carYear;
  final String issueType;
  final double distance;
  final String address;
  final List<String> attachments;
  final DateTime? deadline;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const NearbyRequestCard({
    super.key,
    required this.carMake,
    required this.carModel,
    required this.carYear,
    required this.issueType,
    required this.distance,
    required this.address,
    this.attachments = const [],
    this.deadline,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          // Header with distance
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
                      '${distance.toStringAsFixed(1)} كم',
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

          // Car Info
          Row(
            children: [
              const Icon(Icons.directions_car_rounded, size: 20, color: AppColors.orangePrimary),
              const SizedBox(width: 8),
              Text(
                '$carMake $carModel $carYear',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Address
          Row(
            children: [
              Icon(Icons.place_outlined, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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

/// عداد تنازلي لمدة الاستجابة (3 دقائق) — ينبض كل ثانية حتى انتهاء المهلة.
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
    _remaining = widget.deadline.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final next = widget.deadline.difference(DateTime.now());
    if (next.inSeconds <= 0) {
      _timer?.cancel();
      if (mounted) setState(() => _remaining = Duration.zero);
    } else if (mounted) {
      setState(() => _remaining = next);
    }
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
    // دقائق:ثواني — على النحو المطلوب "متبقي 03:00 دقيقة للرد"
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final expired = _remaining.inSeconds <= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (expired ? AppColors.error : AppColors.warning)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            expired ? Icons.timer_off_outlined : Icons.timer_outlined,
            size: 16,
            color: expired ? AppColors.error : AppColors.orangePrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              expired
                  ? 'انتهت المهلة — سيُلغى الطلب تلقائياً'
                  : 'متبقي ${_fmt(_remaining)} دقيقة للرد',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: expired ? AppColors.error : AppColors.orangePrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
