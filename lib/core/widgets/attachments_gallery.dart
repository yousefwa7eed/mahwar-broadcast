import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'image_viewer.dart';

/// صف أفقي من صور مصغّرة قابلة للضغط لفتح [ImageViewerScreen].
/// يُستخدم لعرض مرفقات العميل أو المزوّد داخل بطاقات الطلبات.
class AttachmentsGallery extends StatelessWidget {
  final List<String> urls;
  final double height;

  const AttachmentsGallery({super.key, required this.urls, this.height = 100});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final urls = this.urls.where((u) => u.trim().isNotEmpty).toList();
    if (urls.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: urls.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => showAttachmentsViewer(context, urls, index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                urls[index],
                width: height,
                height: height,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    width: height,
                    height: height,
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.orangePrimary,
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stack) => Container(
                  width: height,
                  height: height,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.broken_image_outlined, color: AppColors.darkTextSecondary),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}