import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// صف روابط قانونية مختصرة (الدعم • الشروط • الخصوصية) بخط صغير مسطّر —
/// يُثبَّت أسفل شاشات الدخول والتسجيل واختيار نوع المستخدم.
///
/// [onSupportTap] اختياري: تمريره يضيف رابط «الدعم»، وتركه يعرض الرابطين
/// القانونيين فقط (كما في شاشة اختيار النوع).
class LegalFooter extends StatelessWidget {
  final Color textColor;
  final bool isArabic;
  final VoidCallback? onSupportTap;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  const LegalFooter({
    super.key,
    required this.textColor,
    required this.isArabic,
    this.onSupportTap,
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fontFamily = isArabic ? 'Cairo' : 'Poppins';

    Widget link(String label, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            color: textColor,
            decoration: TextDecoration.underline,
          ),
        ),
      );
    }

    final links = <Widget>[
      if (onSupportTap != null)
        link(
          l10n?.supportLink ?? (isArabic ? 'الدعم' : 'Support'),
          onSupportTap!,
        ),
      link(
        l10n?.termsAndConditions ??
            (isArabic ? 'شروط الاستخدام' : 'Terms & Conditions'),
        onTermsTap,
      ),
      link(
        l10n?.privacyPolicy ??
            (isArabic ? 'سياسة الخصوصية' : 'Privacy Policy'),
        onPrivacyTap,
      ),
    ];

    final children = <Widget>[];
    for (var i = 0; i < links.length; i++) {
      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '•',
              style: TextStyle(color: textColor.withValues(alpha: 0.5)),
            ),
          ),
        );
      }
      children.add(links[i]);
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}
