import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/rpc_error_translator.dart';
import '../../../l10n/app_localizations.dart';

/// نافذة تقييم المزوّد — تُعرض تلقائياً للعميل لحظة اكتمال الطلب.
/// تلتزم بنفس واجهة [rate_provider] المستخدمة في شاشة التتبع
/// (request_tracking_screen) حتى لا يُقيَّم الطلب مرتين.
class ProviderRatingDialog extends StatefulWidget {
  final String orderId;
  final String providerName;

  const ProviderRatingDialog({
    super.key,
    required this.orderId,
    this.providerName = '',
  });

  @override
  State<ProviderRatingDialog> createState() => _ProviderRatingDialogState();
}

class _ProviderRatingDialogState extends State<ProviderRatingDialog> {
  final _commentController = TextEditingController();

  int _rating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final l10n = AppLocalizations.of(context);

    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.selectRatingPrompt ?? 'يرجى اختيار تقييم من 1 إلى 5'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await Supabase.instance.client.rpc('rate_provider', params: {
        'p_order_id': widget.orderId,
        'p_rating': _rating,
        'p_comment': _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      });

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n?.ratingSubmittedThanks ?? 'شكراً لك! تم إرسال تقييمك'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(RpcErrorTranslator.translate(e, l10n)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                l10n?.ratingExperienceTitle ?? 'قيّم تجربتك مع المزوّد',
                style: TextStyle(
                  fontFamily: 'Zain',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                widget.providerName.isEmpty
                    ? (l10n?.ratingQualityPrompt ?? 'كيف كانت جودة الخدمة؟')
                    : (l10n?.ratingProviderPrompt(widget.providerName) ??
                        'كيف كانت خدمة «${widget.providerName}»؟'),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => GestureDetector(
                  onTap: () => setState(() => _rating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      i < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: Colors.amber,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n?.addCommentOptionalHint ?? 'أضف تعليقاً (اختياري)...',
                hintStyle: TextStyle(
                  fontFamily: 'Cairo',
                  color: textSecondary,
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
              style: TextStyle(
                fontFamily: 'Cairo',
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orangePrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        l10n?.submitRating ?? 'إرسال التقييم',
                        style: const TextStyle(
                          fontFamily: 'Zain',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                child: Text(
                  l10n?.rateLater ?? 'التقييم لاحقاً',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}