import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// نافذة تأكيد عامة قبل أي إجراء مصيري (إتمام طلب، رفض عرض/طلب، إلغاء...).
/// تُرجع `true` عند موافقة المستخدم. النمط مطابق لـ dialogs التأكيد المستخدمة
/// في شاشة التتبع حتى لا تتباين النوافذ في أرجاء التطبيق.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'تأكيد',
  String cancelLabel = 'تراجع',
  Color confirmColor = AppColors.error,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final cancelColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Zain',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              cancelLabel,
              style: TextStyle(fontFamily: 'Cairo', color: cancelColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                color: confirmColor,
              ),
            ),
          ),
        ],
      );
    },
  );
  return result ?? false;
}