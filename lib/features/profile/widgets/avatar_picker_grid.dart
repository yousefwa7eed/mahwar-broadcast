import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/profile_cubit.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/avatar_config.dart';
import '../../../core/services/app_messenger.dart';
import '../../../l10n/app_localizations.dart';

/// شبكة الأفاتارات المتاحة للدور الحالي؛ الحفظ فوري عند الاختيار.
/// تأخذ الصورة الحالية من [ProfileCubit] بدل استعلام إضافي.
class AvatarPickerGrid extends StatefulWidget {
  const AvatarPickerGrid({
    super.key,
    required this.role,
    this.initialAvatarId,
    this.onSaved,
  });

  final String role;
  final String? initialAvatarId;
  final VoidCallback? onSaved;

  @override
  State<AvatarPickerGrid> createState() => _AvatarPickerGridState();
}

class _AvatarPickerGridState extends State<AvatarPickerGrid> {
  late String? _selectedAvatarId = widget.initialAvatarId;
  bool _isSaving = false;

  @override
  void didUpdateWidget(covariant AvatarPickerGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // الملف الشخصي قد يصل بعد بناء الشبكة؛ نلتقط الاختيار أول مرة فقط.
    if (_selectedAvatarId == null &&
        widget.initialAvatarId != oldWidget.initialAvatarId) {
      _selectedAvatarId = widget.initialAvatarId;
    }
  }

  Future<void> _saveAvatar(String avatarId) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _selectedAvatarId = avatarId;
      _isSaving = true;
    });

    try {
      await client
          .from('profiles')
          .update({'avatar_id': avatarId}).eq('id', userId);

      if (mounted) {
        final cubit = context.read<ProfileCubit>();
        final state = cubit.state;
        if (state is ProfileLoaded) {
          cubit.updateProfile(state.profile.copyWith(avatarId: avatarId));
        }
        AppMessenger.showToast(
          context,
          AppLocalizations.of(context)?.savedSuccessfully ?? 'تم الحفظ بنجاح',
          background: AppColors.success,
        );
        widget.onSaved?.call();
        // مزامنة خلفية بأحدث نسخة من الخادم دون حجب الواجهة.
        unawaited(cubit.refreshProfile());
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showToast(
          context,
          AppLocalizations.of(context)?.errorWithDetail('$e') ?? 'حدث خطأ: $e',
          background: AppColors.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildAvatar(AvatarOption avatar, bool isSelected) {
    return GestureDetector(
      onTap: _isSaving
          ? null
          : () {
              if (isSelected) return;
              _saveAvatar(avatar.id);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: avatar.gradient,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: AppColors.orangePrimary, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: avatar.gradient.colors.first
                  .withValues(alpha: isSelected ? 0.3 : 0.14),
              blurRadius: isSelected ? 8 : 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            avatar.emoji,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatars = AvatarConfig.getAvatarsForRole(widget.role);

    return Material(
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final avatar in avatars)
              _buildAvatar(avatar, _selectedAvatarId == avatar.id),
          ],
        ),
      ),
    );
  }
}
