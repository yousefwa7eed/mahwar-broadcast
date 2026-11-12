import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/national_id_utils.dart';
import '../../../core/auth/phone_utils.dart';
import '../../../core/auth/profile_cubit.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/app_messenger.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/otp_screen.dart' show changePhoneRoute;

/// حقول تعديل البيانات الشخصية. تُستخدم داخل شاشة مستقلة وفي صفحة الملف
/// الشخصي، لذا لا تحتوي على Scaffold ولا تخرج من الصفحة بنفسها.
class PersonalInfoForm extends StatefulWidget {
  const PersonalInfoForm({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  State<PersonalInfoForm> createState() => _PersonalInfoFormState();
}

class _PersonalInfoFormState extends State<PersonalInfoForm> {
  final SupabaseClient _client = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  late final ProfileCubit _profileCubit =
      context.read<ProfileCubit>();
  StreamSubscription<ProfileState>? _profileSub;

  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _nationalIdController;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _nationalIdController = TextEditingController();
    _nationalIdController.addListener(_onNationalIdChanged);

    // الملف الشخصي محمّل مسبقًا في الغالب، فلا نعيد استعلامه عند فتح الصفحة.
    final state = _profileCubit.state;
    if (state is ProfileLoaded) {
      _applyProfile(state.profile);
    } else {
      if (state is ProfileError) _isLoading = false;
      _profileSub = _profileCubit.stream.listen((state) {
        if (!mounted) return;
        if (state is ProfileLoaded) {
          setState(() => _applyProfile(state.profile));
          _profileSub?.cancel();
          _profileSub = null;
        } else if (state is ProfileError) {
          setState(() => _isLoading = false);
        }
      });
    }
  }

  void _applyProfile(ProfileData profile) {
    _fullNameController.text = profile.fullName;
    _phoneController.text = profile.phoneNumber ?? '';
    _nationalIdController.text = profile.nationalId ?? '';
    _isLoading = false;
  }

  void _onNationalIdChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _fullNameController.dispose();
    _phoneController.dispose();
    _nationalIdController.removeListener(_onNationalIdChanged);
    _nationalIdController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isSaving = true);

    try {
      final newName = _fullNameController.text.trim();

      // لا نكتب phone_number من العميل: تغيير الرقم يمرّ عبر تدفق OTP فقط
      // (زر "تغيير الرقم")، ويُزامَن خادميًا بعد تأكيد auth.users.phone.
      // ولا نمسّ الإيميل إطلاقًا: لا يوجد تحقق بريدي موثوق، فالهاتف وحده هو
      // هوية الحساب القابلة للتعديل من المستخدم.
      await _client.from('profiles').update({
        'full_name': newName,
        'national_id': _nationalIdController.text.trim().isEmpty
            ? null
            : NationalIdUtils.normalize(_nationalIdController.text.trim()),
      }).eq('id', userId);

      await _client.auth.updateUser(
        UserAttributes(data: {'full_name': newName}),
      );

      if (mounted) {
        final cubit = context.read<ProfileCubit>();
        final current = cubit.state is ProfileLoaded
            ? (cubit.state as ProfileLoaded).profile
            : const ProfileData();
        cubit.updateProfile(ProfileData(
              fullName: newName,
              phoneNumber: _phoneController.text.trim().isEmpty
                  ? null
                  : _phoneController.text.trim(),
              email: current.email,
              nationalId: _nationalIdController.text.trim().isEmpty
                  ? null
                  : NationalIdUtils.normalize(_nationalIdController.text.trim()),
              role: current.role,
              avatarId: current.avatarId,
              avatarUrl: current.avatarUrl,
            ));

        AppMessenger.showToast(
          context,
          AppLocalizations.of(context)?.savedSuccessfully ?? 'تم الحفظ بنجاح',
          background: AppColors.success,
        );
        setState(() => _isSaving = false);
        widget.onSaved?.call();
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        final message = e.code == '23505'
            ? (l10n?.phoneAlreadyRegistered ??
                'رقم الهاتف مسجل بالفعل لدى مستخدم آخر')
            : (l10n?.saveFailedRetry ?? 'تعذر حفظ البيانات، حاول مرة أخرى');
        AppMessenger.showToast(
          context,
          message,
          background: AppColors.error,
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showToast(
          context,
          AppLocalizations.of(context)?.saveFailedRetry ??
              'تعذر حفظ البيانات، حاول مرة أخرى',
          background: AppColors.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// يفتح تدفق تغيير الرقم (إدخال الرقم الجديد → OTP). بعد العودة بنجاح يكون
  /// الخادم قد حدّث profiles.phone_number عبر مُشغِّل المزامنة، فنعيد تحميل
  /// الملف لعرض الرقم الجديد.
  Future<void> _onChangePhone() async {
    await context.push(changePhoneRoute);
    if (!mounted) return;
    await _profileCubit.refreshProfile();
    if (!mounted) return;
    final state = _profileCubit.state;
    if (state is ProfileLoaded) {
      _phoneController.text = state.profile.phoneNumber ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (_isLoading) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.orangePrimary),
        ),
      );
    }

    final nationalIdText = _nationalIdController.text.trim();
    String? nationalIdHelper;
    Color? nationalIdHelperColor;
    if (nationalIdText.isEmpty) {
      nationalIdHelper = l10n?.nationalIdOptionalHint ??
          (isArabic ? 'اختياري عند التسجيل، مطلوب للطلب' : 'Optional on registration, required for orders');
    } else if (NationalIdUtils.isValid(nationalIdText)) {
      nationalIdHelper =
          l10n?.nationalIdValid ?? (isArabic ? 'الرقم القومي صحيح' : 'National ID is valid');
      nationalIdHelperColor = AppColors.success;
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildField(
            controller: _fullNameController,
            label: l10n?.fullName ?? 'الاسم الكامل',
            icon: Icons.person_outline_rounded,
            isDark: isDark,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return l10n?.nameRequired ?? 'الاسم مطلوب';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _phoneController,
            label: l10n?.phoneNumber ?? 'رقم الهاتف',
            icon: Icons.phone_android_rounded,
            isDark: isDark,
            enabled: false,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return l10n?.phoneRequired ?? 'رقم الهاتف مطلوب';
              }
              final sanitized = PhoneUtils.normalize(v.trim());
              if (!PhoneUtils.isValidEgyptianMobile(sanitized)) {
                return l10n?.enterValidEgyptianPhoneNumber ??
                    'أدخل رقم هاتف مصري صحيح (01xxxxxxxxx)';
              }
              return null;
            },
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: _isSaving ? null : _onChangePhone,
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppColors.orangePrimary,
              ),
              label: Text(
                l10n?.changeNumberTitle ?? 'تغيير رقم الهاتف',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: AppColors.orangePrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _nationalIdController,
            label:
                '${l10n?.nationalId ?? 'الرقم القومي'} (${l10n?.nationalIdOptionalHint ?? 'اختياري'})',
            icon: Icons.badge_outlined,
            isDark: isDark,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 14,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            helperText: nationalIdHelper,
            helperStyle: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: nationalIdHelperColor ??
                  (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null; // optional
              if (!NationalIdUtils.isValid(v)) {
                return l10n?.nationalIdInvalid ??
                    (isArabic ? 'الرقم القومي غير صحيح' : 'Invalid national ID');
              }
              return null;
            },
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orangePrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      l10n?.savedSuccessfully ?? 'حفظ التعديلات',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool enabled = true,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    AutovalidateMode? autovalidateMode,
    String? helperText,
    TextStyle? helperStyle,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      autovalidateMode: autovalidateMode,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 15,
        color: enabled
            ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
        helperText: helperText,
        helperStyle: helperStyle,
        prefixIcon: Icon(icon, color: AppColors.orangePrimary),
        counterText: '',
        filled: true,
        fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.orangePrimary, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      validator: validator,
    );
  }
}
