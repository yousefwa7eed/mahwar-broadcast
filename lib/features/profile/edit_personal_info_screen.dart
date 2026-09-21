import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import '../../../core/auth/phone_utils.dart';
import '../../../core/auth/profile_cubit.dart';
import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class EditPersonalInfoScreen extends StatefulWidget {
  const EditPersonalInfoScreen({super.key});

  @override
  State<EditPersonalInfoScreen> createState() => _EditPersonalInfoScreenState();
}

class _EditPersonalInfoScreenState extends State<EditPersonalInfoScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _nationalIdController;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _nationalIdController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nationalIdController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _client
          .from('profiles')
          .select('full_name, phone_number, email, national_id')
          .eq('id', userId)
          .maybeSingle();

      if (response != null && mounted) {
        _fullNameController.text = response['full_name'] ?? '';
        _phoneController.text = response['phone_number'] ?? '';
        _emailController.text = response['email'] ?? '';
        _nationalIdController.text = response['national_id'] ?? '';
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isSaving = true);

    try {
      final phone = PhoneUtils.normalize(_phoneController.text.trim());
      final newName = _fullNameController.text.trim();
      final newEmail = _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim();

      final oldEmail = _client.auth.currentUser?.email;

      await _client.from('profiles').update({
        'full_name': newName,
        'phone_number': phone,
        'email': newEmail,
        'national_id': _nationalIdController.text.trim().isEmpty
            ? null
            : _nationalIdController.text.trim(),
      }).eq('id', userId);

      if (newEmail != null && newEmail.isNotEmpty && newEmail != oldEmail) {
        await _client.auth.updateUser(
          UserAttributes(email: newEmail),
        );
        await _client.rpc('update_auth_email', params: {
          'p_user_id': userId,
          'p_new_email': newEmail,
        });
      }

      await _client.auth.updateUser(
        UserAttributes(data: {'full_name': newName}),
      );

      if (mounted) {
        context.read<ProfileCubit>().updateProfile(ProfileData(
              fullName: newName,
              phoneNumber: phone,
              email: newEmail,
              nationalId: _nationalIdController.text.trim().isEmpty
                  ? null
                  : _nationalIdController.text.trim(),
              role: context.read<ProfileCubit>().state is ProfileLoaded
                  ? (context.read<ProfileCubit>().state as ProfileLoaded).profile.role
                  : null,
            ));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.savedSuccessfully ?? 'تم الحفظ بنجاح',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        String message = 'حدث خطأ: ${e.message}';
        if (e.code == '23505') {
          final isArabic = Localizations.localeOf(context).languageCode == 'ar';
          message = isArabic
              ? 'رقم الهاتف مسجل بالفعل لدى مستخدم آخر'
              : 'This phone number is already registered';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n?.editPersonalInfo ?? 'تعديل البيانات الشخصية',
          style: TextStyle(
            fontFamily: 'Zain',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orangePrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
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
                          return isArabic ? 'الاسم مطلوب' : 'Name is required';
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
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return isArabic ? 'رقم الهاتف مطلوب' : 'Phone number is required';
                        }
                        final sanitized = PhoneUtils.normalize(v.trim());
                        if (!PhoneUtils.isValidEgyptianMobile(sanitized)) {
                          return isArabic
                              ? 'أدخل رقم هاتف مصري صحيح (01xxxxxxxxx)'
                              : 'Enter a valid Egyptian phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildField(
                      controller: _emailController,
                      label: l10n?.email ?? 'البريد الإلكتروني (اختياري)',
                      icon: Icons.email_outlined,
                      isDark: isDark,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    _buildField(
                      controller: _nationalIdController,
                      label: '${l10n?.nationalId ?? 'الرقم القومي'} (${l10n?.nationalIdOptionalHint ?? 'اختياري'})',
                      icon: Icons.badge_outlined,
                      isDark: isDark,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 14,
                    ),
                    const SizedBox(height: 32),

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
              ),
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
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
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
