import 'package:flutter/material.dart';

class LoginFormWidget extends StatefulWidget {
  final String role;
  final Function(String identifier, String password, bool isPhone) onSubmit;
  final VoidCallback onSignupTap;

  const LoginFormWidget({
    super.key,
    required this.role,
    required this.onSubmit,
    required this.onSignupTap,
  });

  @override
  State<LoginFormWidget> createState() => _LoginFormWidgetState();
}

class _LoginFormWidgetState extends State<LoginFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPhoneMode = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onSubmit(
        _identifierController.text.trim(),
        _passwordController.text,
        _isPhoneMode,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isProvider = widget.role == 'provider';
    final Color primaryColor =
        isProvider ? const Color(0xFF1E1E1E) : const Color(0xFFFF6B00);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(
                    child: Text(
                      'رقم الهاتف',
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                    ),
                  ),
                  selected: _isPhoneMode,
                  selectedColor: primaryColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: _isPhoneMode ? primaryColor : Colors.grey.shade700,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _isPhoneMode = true;
                        _identifierController.clear();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Center(
                    child: Text(
                      'البريد الإلكتروني',
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                    ),
                  ),
                  selected: !_isPhoneMode,
                  selectedColor: primaryColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: !_isPhoneMode ? primaryColor : Colors.grey.shade700,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _isPhoneMode = false;
                        _identifierController.clear();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _identifierController,
            keyboardType:
                _isPhoneMode ? TextInputType.phone : TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: _isPhoneMode ? 'رقم الهاتف' : 'البريد الإلكتروني',
              hintText: _isPhoneMode ? '01xxxxxxxxx' : 'example@domain.com',
              prefixIcon: Icon(
                _isPhoneMode ? Icons.phone_android_rounded : Icons.email_rounded,
                color: primaryColor,
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return _isPhoneMode
                    ? 'يرجى إدخال رقم الهاتف'
                    : 'يرجى إدخال البريد الإلكتروني';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              prefixIcon: Icon(Icons.lock_rounded, color: primaryColor),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey.shade600,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال كلمة المرور';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
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
                'تسجيل الدخول',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ليس لديك حساب؟ ',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              GestureDetector(
                onTap: widget.onSignupTap,
                child: Text(
                  'إنشاء حساب جديد',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
