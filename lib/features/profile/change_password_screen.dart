import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/change_password_form.dart';

/// شاشة تغيير كلمة المرور للمستخدم المسجّل (صاحب حساب/مقدّم خدمة). تتحقق من
/// كلمة المرور الحالية عبر عميل معزول ثم تضبط الجديدة على الجلسة الحالية، ولا
/// تُخرج المستخدم من حسابه.
class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key, this.service});

  /// حقن الخدمة للاختبارات؛ الافتراضي هو العميل الحقيقي.
  final AuthService? service;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = AppColors.orangePrimary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.changePassword,
          style: TextStyle(
            fontFamily: isArabic ? 'Cairo' : 'Poppins',
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.password_rounded,
                    color: primaryColor, size: 32),
              ),
              const SizedBox(height: 20),
              ChangePasswordForm(
                service: service,
                onSuccess: () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
