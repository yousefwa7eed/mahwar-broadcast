import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'shimmer_box.dart';

/// هيكل بطاقات الإشعارات أثناء التحميل الأول — بنفس مقاسات البطاقة الحقيقية
/// (أيقونة دائرية + سطران + وقت) حتى لا تقفز الواجهة عند وصول البيانات.
class NotificationListSkeleton extends StatelessWidget {
  const NotificationListSkeleton({super.key, this.items = 6});

  final int items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShimmerBox(width: 42, height: 42, circle: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      widthFactor: 0.55,
                      child: const ShimmerBox(height: 14),
                    ),
                    const SizedBox(height: 8),
                    const ShimmerBox(height: 12),
                    const SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: 0.3,
                      child: const ShimmerBox(height: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// هيكل بطاقات الطلبات أثناء التحميل الأول.
class OrderListSkeleton extends StatelessWidget {
  const OrderListSkeleton({super.key, this.items = 4});

  final int items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const ShimmerBox(width: 72, height: 22, borderRadius: 8),
                  const Spacer(),
                  const ShimmerBox(width: 56, height: 14),
                ],
              ),
              const SizedBox(height: 14),
              FractionallySizedBox(
                widthFactor: 0.45,
                child: const ShimmerBox(height: 14),
              ),
              const SizedBox(height: 10),
              const ShimmerBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
