import 'package:flutter/material.dart';
import 'car_selection_dropdowns_widget.dart';

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

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (!_agreedToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'يجب الموافقة على شروط الاستخدام وسياسة الخصوصية للمتابعة',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      widget.onSubmit(
        _fullNameController.text.trim(),
        _phoneController.text.trim(),
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

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full Name
          TextFormField(
            controller: _fullNameController,
            decoration: InputDecoration(
              labelText: 'الاسم رباعي (إجباري)',
              prefixIcon: const Icon(Icons.person_rounded, color: primaryColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال الاسم رباعي';
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
            decoration: InputDecoration(
              labelText: 'رقم الهاتف (إجباري)',
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
                return 'يرجى إدخال رقم الهاتف';
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
              labelText: 'البريد الإلكتروني (اختياري)',
              hintText: 'example@domain.com',
              prefixIcon: const Icon(Icons.email_rounded, color: primaryColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 16),

          // National ID (Optional at signup with explanatory note)
          TextFormField(
            controller: _nationalIdController,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'الرقم القومي (اختياري)',
              helperText: 'اختياري عند التسجيل، مطلوب فقط لإتمام طلب خدمة',
              helperMaxLines: 2,
              prefixIcon:
                  const Icon(Icons.badge_rounded, color: primaryColor),
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
              labelText: 'كلمة المرور',
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
                return 'كلمة المرور يجب أن لا تقل عن 6 أحرف';
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
              labelText: 'تأكيد كلمة المرور',
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
                return 'كلمة المرور غير متطابقة';
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
              const Expanded(
                child: Text(
                  'أوافق على شروط الاستخدام وسياسة الخصوصية',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
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
              onPressed: _submit,
              child: const Text(
                'إنشاء حساب جديد',
                style: TextStyle(
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
}
