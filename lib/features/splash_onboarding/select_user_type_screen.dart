import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/settings/app_settings_cubit.dart';
import '../../core/settings/app_settings_state.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/select_user_type_footer.dart';
import 'widgets/select_user_type_header.dart';
import 'widgets/user_type_selection_card.dart';

class SelectUserTypeScreen extends StatelessWidget {
  const SelectUserTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<AppSettingsCubit, AppSettingsState>(
      builder: (context, settings) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SelectUserTypeHeader(),
                  ),
                  const Spacer(flex: 2),
                  Text(
                    l10n.selectUserType,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 28),
                  UserTypeSelectionCard(
                    title: l10n.carOwner,
                    description: l10n.carOwnerDesc,
                    imageAsset: 'assets/banners/car_owner.png',
                    fallbackIcon: Icons.directions_car_rounded,
                    gradient: AppColors.orangeGradient,
                    onTap: () => context.go('/login?role=car_owner'),
                  ),
                  const SizedBox(height: 16),
                  UserTypeSelectionCard(
                    title: l10n.serviceProvider,
                    description: l10n.serviceProviderDesc,
                    imageAsset: 'assets/banners/service_provider.png',
                    fallbackIcon: Icons.build_circle_outlined,
                    gradient: AppColors.darkGradient,
                    onTap: () => context.go('/login?role=service_provider'),
                  ),
                  const Spacer(flex: 3),
                  const SelectUserTypeFooter(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
