import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class SelectUserTypeFooter extends StatelessWidget {
  const SelectUserTypeFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _FooterLink(
          label: l10n.termsAndConditions,
          onTap: () => _showPolicySheet(
            context,
            title: l10n.termsAndConditions,
          ),
        ),
        Text(
          ' • ',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
        _FooterLink(
          label: l10n.privacyPolicy,
          onTap: () => _showPolicySheet(
            context,
            title: l10n.privacyPolicy,
          ),
        ),
      ],
    );
  }

  void _showPolicySheet(BuildContext context, {required String title}) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.policyPlaceholder,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FooterLink({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.orangePrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.orangePrimary,
          ),
        ),
      ),
    );
  }
}
