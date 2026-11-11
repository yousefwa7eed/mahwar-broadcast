import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'shimmer_box.dart';

/// أقل مدة يظل فيها الهيكل ظاهراً حتى لو كانت البيانات جاهزة فوراً (لقطة
/// الجلب المسبق أو ذاكرة الشاشة) — فلا يظهر وميض هيكل لحظي لا يُرى.
const Duration kSkeletonMinVisible = Duration(milliseconds: 700);

/// يحكم ظهور هيكل الصفحة في أول تحميل وفي السحب للتحديث: يبدأ ظاهراً، ويبقى
/// حتى تكتمل المهمة **و** تمضي [kSkeletonMinVisible] كاملة، ثم يختفي.
/// استخدامه مقصور على التحميل اليدوي (الفتح/السحب)؛ تحديثات Realtime والعودة
/// من الخلفية لا تمرّ عليه فلا تُغطّي المحتوى المعروض.
mixin SkeletonGate<T extends StatefulWidget> on State<T> {
  bool skeletonVisible = true;

  /// ترتيب آخر تشغيل — لو بدأ تحميل جديد قبل انتهاء السابق يبقى الهيكل
  /// ظاهراً حتى ينتهي الأحدث.
  int _gateSeq = 0;

  Future<void> runWithSkeleton(Future<void> Function() task) async {
    final seq = ++_gateSeq;
    final startedAt = DateTime.now();
    if (mounted && !skeletonVisible) {
      setState(() => skeletonVisible = true);
    }
    try {
      await task();
    } finally {
      final remaining =
          kSkeletonMinVisible - DateTime.now().difference(startedAt);
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
      if (mounted && seq == _gateSeq) {
        setState(() => skeletonVisible = false);
      }
    }
  }
}

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

/// هيكل الرئيسية أثناء أول تحميل بلا لقطة جلب مسبق — بنفس ترتيب البلوكات
/// ومقاساتها (رأس، بنر S.O.S، بطاقة الخريطة، عنوان الشبكة و٣ بطاقات) حتى لا
/// تقفز الواجهة عند وصول البيانات.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const ShimmerBox(width: 40, height: 40, circle: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(
                        widthFactor: 0.55,
                        child: const ShimmerBox(height: 20),
                      ),
                      const SizedBox(height: 8),
                      FractionallySizedBox(
                        widthFactor: 0.4,
                        child: const ShimmerBox(height: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const ShimmerBox(width: 28, height: 28, borderRadius: 8),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: ShimmerBox(height: 112, borderRadius: 20),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: ShimmerBox(height: 72, borderRadius: 18),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.35,
                  child: ShimmerBox(height: 20),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: ShimmerBox(height: 112, borderRadius: 16)),
                    SizedBox(width: 12),
                    Expanded(child: ShimmerBox(height: 112, borderRadius: 16)),
                    SizedBox(width: 12),
                    Expanded(child: ShimmerBox(height: 112, borderRadius: 16)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// هيكل لوحة المزوّد أثناء أول تحميل: الرأس، مفتاح التوفّر، عنوان «طلباتك
/// الحالية» وبطاقتان — بنفس ترتيب البلوكات ومقاساتها.
class ProviderDashboardSkeleton extends StatelessWidget {
  const ProviderDashboardSkeleton({super.key, this.orders = 2});

  final int orders;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              const ShimmerBox(width: 44, height: 44, circle: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      widthFactor: 0.5,
                      child: const ShimmerBox(height: 24),
                    ),
                    const SizedBox(height: 6),
                    FractionallySizedBox(
                      widthFactor: 0.35,
                      child: const ShimmerBox(height: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const ShimmerBox(width: 24, height: 24, borderRadius: 8),
            ],
          ),
          const SizedBox(height: 20),
          const ShimmerBox(height: 72, borderRadius: 16),
          const SizedBox(height: 24),
          FractionallySizedBox(
            widthFactor: 0.45,
            child: const ShimmerBox(height: 20),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < orders; i++) ...[
            const ShimmerBox(height: 170, borderRadius: 16),
            if (i < orders - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// هيكل شاشة سجل الطلبات كاملة: شرائح الفلترة وسطر التاريخ ثم بطاقات القائمة.
/// وجود الفلاتر في الهيكل يمنع ظهورها فجأة فوق القائمة عند وصول البيانات.
class OrdersHistorySkeleton extends StatelessWidget {
  const OrdersHistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(child: ShimmerBox(height: 40, borderRadius: 10)),
                SizedBox(width: 8),
                Expanded(child: ShimmerBox(height: 40, borderRadius: 10)),
                SizedBox(width: 8),
                Expanded(child: ShimmerBox(height: 40, borderRadius: 10)),
                SizedBox(width: 8),
                Expanded(child: ShimmerBox(height: 40, borderRadius: 10)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: ShimmerBox(height: 40, borderRadius: 12),
          ),
          const Expanded(child: OrderListSkeleton()),
        ],
      ),
    );
  }
}

/// هيكل بطاقات الطلبات أثناء التحميل الأول.
class OrderListSkeleton extends StatelessWidget {
  const OrderListSkeleton({
    super.key,
    this.items = 4,
    this.showSectionHeader = false,
  });

  final int items;

  /// عنوان القسم وزر «عرض الكل» فوق القائمة (كما في تبويب الطلبات بالرئيسية)،
  /// فنترك محلّهما في الهيكل بدل أن يظهرا فجأة بعد التحميل.
  final bool showSectionHeader;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final list = ListView.builder(
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
    );

    if (!showSectionHeader) {
      return ExcludeSemantics(child: list);
    }

    return ExcludeSemantics(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                ShimmerBox(width: 130, height: 20),
                Spacer(),
                ShimmerBox(width: 56, height: 14),
              ],
            ),
          ),
          Expanded(child: list),
        ],
      ),
    );
  }
}
