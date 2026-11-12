import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_cubit.dart';
import '../../../core/auth/national_id_utils.dart';
import '../../../core/auth/phone_utils.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/vehicle_selection.dart';
import '../../../core/services/app_messenger.dart';
import '../../../core/settings/app_settings_cubit.dart';
import '../../../core/widgets/loading_form_lock.dart';
import '../../../l10n/app_localizations.dart';
import '../../vehicles/vehicle_picker_screen.dart';
import '../../vehicles/widgets/vehicle_selection_card.dart';

class OwnerSignupFormWidget extends StatefulWidget {
  final Function(
    String fullName,
    String phone,
    String? nationalId,
    VehicleSelection vehicle,
    String password,
  )
  onSubmit;

  const OwnerSignupFormWidget({super.key, required this.onSubmit});

  @override
  State<OwnerSignupFormWidget> createState() => _OwnerSignupFormWidgetState();
}

class _OwnerSignupFormWidgetState extends State<OwnerSignupFormWidget> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  VehicleSelection? _vehicle;
  bool _agreedToTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => context.push('/terms');
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => context.push('/privacy');
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _nationalIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickVehicle() async {
    final selection = await Navigator.of(context).push<VehicleSelection>(
      MaterialPageRoute(builder: (_) => VehiclePickerScreen(initial: _vehicle)),
    );
    if (!mounted || selection == null) return;
    setState(() => _vehicle = selection);
  }

  void _showMessage(String message) {
    AppMessenger.showToast(context, message, background: AppColors.error);
  }

  void _submit(bool isArabic) {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context);
    if (!_agreedToTerms) {
      _showMessage(
        l10n?.signupAgreeTermsRequired ??
            'يجب الموافقة على شروط الاستخدام وسياسة الخصوصية للمتابعة',
      );
      return;
    }
    final vehicle = _vehicle;
    if (vehicle == null) {
      _showMessage(
        l10n?.signupVehicleRequired ?? 'يرجى اختيار سيارتك لإكمال التسجيل',
      );
      return;
    }

    widget.onSubmit(
      _fullNameController.text.trim(),
      PhoneUtils.normalize(_phoneController.text.trim()),
      _nationalIdController.text.trim().isEmpty
          ? null
          : NationalIdUtils.normalize(_nationalIdController.text.trim()),
      vehicle,
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic =
        context.watch<AppSettingsCubit>().state.locale.languageCode == 'ar';
    final l10n = AppLocalizations.of(context);
    final isLoading = context.watch<AuthCubit>().state is AuthLoading;

    return LoadingFormLock(
      loading: isLoading,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. البيانات الشخصية
            _buildFormSectionCard(
              context: context,
              title: l10n?.editPersonalInfo ?? 'البيانات الشخصية',
              icon: Icons.person_outline_rounded,
              isDark: isDark,
              isArabic: isArabic,
              children: [
                // Full Name
                TextFormField(
                  controller: _fullNameController,
                  decoration: _inputDecoration(
                    label: l10n?.signupFullNameLabel ?? 'الاسم رباعي (إجباري)',
                    icon: Icons.person_rounded,
                    isDark: isDark,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n?.signupFullNameRequired ??
                          'يرجى إدخال الاسم رباعي';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Phone Number
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _inputDecoration(
                    label: l10n?.signupPhoneLabel ?? 'رقم الهاتف (إجباري)',
                    hintText: '01xxxxxxxxx',
                    icon: Icons.phone_android_rounded,
                    isDark: isDark,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n?.enterPhonePrompt ?? 'يرجى إدخال رقم الهاتف';
                    }
                    if (!PhoneUtils.isValidEgyptianMobile(value)) {
                      return l10n?.signupInvalidPhone ??
                          'رقم هاتف مصري غير صحيح (11 رقم مثال: 01012345678)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // National ID (Optional at signup)
                TextFormField(
                  controller: _nationalIdController,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 14,
                  decoration: _inputDecoration(
                    label:
                        l10n?.signupNationalIdLabel ?? 'الرقم القومي (اختياري)',
                    helperText:
                        l10n?.signupNationalIdHint ??
                        'اختياري عند التسجيل، مطلوب فقط لإتمام طلب خدمة',
                    icon: Icons.badge_outlined,
                    isDark: isDark,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }
                    if (!NationalIdUtils.isValid(value)) {
                      return l10n?.signupInvalidNationalId ??
                          'الرقم القومي غير صحيح (14 رقم)';
                    }
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. بيانات السيارة
            _buildFormSectionCard(
              context: context,
              title: l10n?.signupVehicleSection ?? 'بيانات السيارة',
              icon: Icons.directions_car_outlined,
              isDark: isDark,
              isArabic: isArabic,
              children: [
                VehicleSelectionCard(selection: _vehicle, onTap: _pickVehicle),
              ],
            ),
            const SizedBox(height: 16),

            // 3. كلمة المرور والأمان
            _buildFormSectionCard(
              context: context,
              title: l10n?.changePassword ?? 'كلمة المرور والأمان',
              icon: Icons.lock_outline_rounded,
              isDark: isDark,
              isArabic: isArabic,
              children: [
                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration(
                    label: l10n?.password ?? 'كلمة المرور',
                    icon: Icons.lock_rounded,
                    isDark: isDark,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return l10n?.passwordTooShort ??
                          'كلمة المرور يجب أن لا تقل عن 6 أحرف';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: _inputDecoration(
                    label: l10n?.confirmPassword ?? 'تأكيد كلمة المرور',
                    icon: Icons.lock_outline_rounded,
                    isDark: isDark,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return l10n?.signupPasswordMismatch ??
                          'كلمة المرور غير متطابقة';
                    }
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4. الشروط والخصوصية
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _agreedToTerms,
                    activeColor: AppColors.orangePrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _agreedToTerms = value ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontFamily: isArabic ? 'Cairo' : 'Poppins',
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                        children: [
                          TextSpan(
                            text: isArabic ? 'أوافق على ' : 'I agree to ',
                          ),
                          TextSpan(
                            text:
                                l10n?.termsOfUse ??
                                (isArabic ? 'شروط الاستخدام' : 'Terms of Use'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.orangePrimary,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: _termsRecognizer,
                          ),
                          TextSpan(text: isArabic ? ' و ' : ' and '),
                          TextSpan(
                            text:
                                l10n?.privacyPolicy ??
                                (isArabic
                                    ? 'سياسة الخصوصية'
                                    : 'Privacy Policy'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.orangePrimary,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: _privacyRecognizer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orangePrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: isLoading ? null : () => _submit(isArabic),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      )
                    : Text(
                        l10n?.signup ?? 'إنشاء حساب جديد',
                        style: TextStyle(
                          fontFamily: isArabic ? 'Cairo' : 'Poppins',
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
    );
  }

  Widget _buildFormSectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool isDark,
    required bool isArabic,
  }) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.orangePrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.orangePrimary, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontFamily: isArabic ? 'Zain' : 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required bool isDark,
    String? hintText,
    String? helperText,
    Widget? suffixIcon,
  }) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      helperText: helperText,
      helperMaxLines: 2,
      prefixIcon: Icon(icon, color: AppColors.orangePrimary),
      suffixIcon: suffixIcon,
      counterText: '',
      filled: true,
      fillColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.orangePrimary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }
}
