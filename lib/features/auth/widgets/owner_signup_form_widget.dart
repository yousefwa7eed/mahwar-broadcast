import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'car_selection_dropdowns_widget.dart';
import '../../../core/auth/phone_utils.dart';
import '../../../core/settings/app_settings_cubit.dart';

class OwnerSignupFormWidget extends StatefulWidget {
  final Function(
    String fullName,
    String phone,
    String? email,
    String? nationalId,
    String make,
    String model,
    String year,
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

  String? _carMake;
  String? _carModel;
  String? _carYear;
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

  void _submit(bool isArabic) {
    if (_formKey.currentState!.validate()) {
      if (!_agreedToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'يجب الموافقة على شروط الاستخدام وسياسة الخصوصية للمتابعة'
                  : 'You must agree to the Terms of Use and Privacy Policy to continue',
              style: TextStyle(fontFamily: isArabic ? 'Cairo' : 'Poppins'),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      widget.onSubmit(
        _fullNameController.text.trim(),
        PhoneUtils.normalize(_phoneController.text.trim()),
        _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        _nationalIdController.text.trim().isEmpty
            ? null
            : _nationalIdController.text.trim(),
        _carMake!,
        _carModel!,
        _carYear!,
        _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFF6B00);
    final isArabic = context.watch<AppSettingsCubit>().state.locale.languageCode == 'ar';

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full Name
          TextFormField(
            controller: _fullNameController,
            decoration: InputDecoration(
              labelText: isArabic ? 'الاسم رباعي (إجباري)' : 'Full Name (Required)',
              prefixIcon: const Icon(Icons.person_rounded, color: primaryColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return isArabic ? 'يرجى إدخال الاسم رباعي' : 'Please enter your full name';
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
              labelText: isArabic ? 'رقم الهاتف (إجباري)' : 'Phone Number (Required)',
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
                return isArabic ? 'يرجى إدخال رقم الهاتف' : 'Please enter your phone number';
              }
              if (!PhoneUtils.isValidEgyptianMobile(value)) {
                return isArabic
                    ? 'رقم هاتف مصري غير صحيح (11 رقم مثال: 01012345678)'
                    : 'Invalid Egyptian phone number (e.g. 01012345678)';
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
              labelText: isArabic ? 'البريد الإلكتروني (اختياري)' : 'Email Address (Optional)',
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
              labelText: isArabic ? 'الرقم القومي (اختياري)' : 'National ID (Optional)',
              helperText: isArabic
                  ? 'اختياري عند التسجيل، مطلوب فقط لإتمام طلب خدمة'
                  : 'Optional at registration, required to complete a service request',
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.badge_rounded, color: primaryColor),
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 24),

          // Car Selection Dropdowns
          CarSelectionDropdownsWidget(
            onChanged: (make, model, year) {
              _carMake = make;
              _carModel = model;
              _carYear = year;
            },
          ),
          const SizedBox(height: 24),

          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: isArabic ? 'كلمة المرور' : 'Password',
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
                return isArabic
                    ? 'كلمة المرور يجب أن لا تقل عن 6 أحرف'
                    : 'Password must be at least 6 characters';
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
              labelText: isArabic ? 'تأكيد كلمة المرور' : 'Confirm Password',
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
                return isArabic ? 'كلمة المرور غير متطابقة' : 'Passwords do not match';
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
                    isArabic
                        ? 'أوافق على شروط الاستخدام وسياسة الخصوصية'
                        : 'I agree to the Terms of Use and Privacy Policy',
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
                isArabic ? 'إنشاء حساب جديد' : 'Create Account',
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
