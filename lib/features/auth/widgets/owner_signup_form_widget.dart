import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import '../../../core/auth/national_id_utils.dart';
import '../../../core/auth/phone_utils.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/vehicle_selection.dart';
import '../../../core/settings/app_settings_cubit.dart';
import '../../../l10n/app_localizations.dart';
import '../../vehicles/vehicle_picker_screen.dart';
import '../../vehicles/widgets/vehicle_selection_card.dart';

class OwnerSignupFormWidget extends StatefulWidget {
  final Function(
    String fullName,
    String phone,
    String? email,
    String? nationalId,
    VehicleSelection vehicle,
    String password,
  ) onSubmit;

  const OwnerSignupFormWidget({super.key, required this.onSubmit});

  @override
  State<OwnerSignupFormWidget> createState() => _OwnerSignupFormWidgetState();
}

class _OwnerSignupFormWidgetState extends State<OwnerSignupFormWidget> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  VehicleSelection? _vehicle;
  bool _agreedToTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nationalIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickVehicle() async {
    final selection = await Navigator.of(context).push<VehicleSelection>(
      MaterialPageRoute(builder: (_) => const VehiclePickerScreen()),
    );
    if (!mounted || selection == null) return;
    setState(() => _vehicle = selection);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error,
      ),
    );
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
      _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      _nationalIdController.text.trim().isEmpty
          ? null
          : NationalIdUtils.normalize(_nationalIdController.text.trim()),
      vehicle,
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF6B00);
    final isArabic = context.watch<AppSettingsCubit>().state.locale.languageCode == 'ar';
    final l10n = AppLocalizations.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full Name
          TextFormField(
            controller: _fullNameController,
            decoration: InputDecoration(
              labelText: l10n?.signupFullNameLabel ?? 'الاسم رباعي (إجباري)',
              prefixIcon: const Icon(Icons.person_rounded, color: primaryColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n?.signupFullNameRequired ?? 'يرجى إدخال الاسم رباعي';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Phone Number
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n?.signupPhoneLabel ?? 'رقم الهاتف (إجباري)',
              hintText: '01xxxxxxxxx',
              prefixIcon:
                  const Icon(Icons.phone_android_rounded, color: primaryColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
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
          const SizedBox(height: 16),

          // Email (Optional)
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: l10n?.signupEmailLabel ?? 'البريد الإلكتروني (اختياري)',
              hintText: 'example@domain.com',
              prefixIcon: const Icon(Icons.email_rounded, color: primaryColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 16),

          // National ID (Optional at signup)
          TextFormField(
            controller: _nationalIdController,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 14,
            decoration: InputDecoration(
              labelText: l10n?.signupNationalIdLabel ?? 'الرقم القومي (اختياري)',
              helperText: l10n?.signupNationalIdHint ??
                  'اختياري عند التسجيل، مطلوب فقط لإتمام طلب خدمة',
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.badge_rounded, color: primaryColor),
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return null; // optional at signup
              }
              if (!NationalIdUtils.isValid(value)) {
                return l10n?.signupInvalidNationalId ?? 'الرقم القومي غير صحيح (14 رقم)';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Vehicle from the catalog
          Text(
            l10n?.signupVehicleSection ?? 'سيارتك',
            style: TextStyle(
              fontFamily: isArabic ? 'Zain' : 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          VehicleSelectionCard(
            selection: _vehicle,
            onTap: _pickVehicle,
          ),
          const SizedBox(height: 24),

          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: l10n?.password ?? 'كلمة المرور',
              prefixIcon: const Icon(Icons.lock_rounded, color: primaryColor),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            validator: (value) {
              if (value == null || value.length < 6) {
                return l10n?.passwordTooShort ??
                    'كلمة المرور يجب أن لا تقل عن 6 أحرف';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm Password
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: l10n?.confirmPassword ?? 'تأكيد كلمة المرور',
              prefixIcon:
                  const Icon(Icons.lock_outline_rounded, color: primaryColor),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            validator: (value) {
              if (value != _passwordController.text) {
                return l10n?.signupPasswordMismatch ?? 'كلمة المرور غير متطابقة';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Terms Checkbox
          Row(
            children: [
              Checkbox(
                value: _agreedToTerms,
                activeColor: primaryColor,
                onChanged: (value) {
                  setState(() {
                    _agreedToTerms = value ?? false;
                  });
                },
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                  child: Text(
                    l10n?.signupAgreeTerms ??
                        'أوافق على شروط الاستخدام وسياسة الخصوصية',
                    style: TextStyle(
                      fontFamily: isArabic ? 'Cairo' : 'Poppins',
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _submit(isArabic),
              child: Text(
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
    );
  }
}
