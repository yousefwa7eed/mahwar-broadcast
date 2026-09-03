import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_cubit.dart';
import '../../../core/auth/phone_utils.dart';
import '../../../core/settings/app_settings_cubit.dart';
import '../../../l10n/app_localizations.dart';
import 'specialization_chips_widget.dart';

class ProviderSignupFormWidget extends StatefulWidget {
  const ProviderSignupFormWidget({super.key});

  @override
  State<ProviderSignupFormWidget> createState() => _ProviderSignupFormWidgetState();
}

class _ProviderSignupFormWidgetState extends State<ProviderSignupFormWidget> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _workshopController = TextEditingController();
  final _addressController = TextEditingController();
  final _vehicleSpecsController = TextEditingController();
  final _vehicleMakeController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  List<String> _selectedSpecializations = ['crane'];
  String _supportScope = 'both'; // 'emergency', 'on_site', 'both'
  bool _hasServiceVehicle = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;
  bool _isLocating = false;
  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nationalIdController.dispose();
    _workshopController.dispose();
    _addressController.dispose();
    _vehicleSpecsController.dispose();
    _vehicleMakeController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehiclePlateController.dispose();
    _vehicleColorController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// يطلب صلاحية الموقع من نظام التشغيل، ويجلب الإحداثيات الحالية للجهاز،
  /// ثم يحوّل الإحداثيات إلى عنوان نصي مكتوب تلقائيًا في حقل العنوان.
  /// يظل الحقل قابلاً للتعديل اليدوي (يمكن للمزوّد تصحيح العنوان بعد الملء التلقائي).
  Future<void> _pickCurrentLocation() async {
    setState(() => _isLocating = true);

    final l10n = AppLocalizations.of(context);
    final isArabic = l10n?.localeName.startsWith('ar') ?? true;

    void showMessage(String message, {Color background = Colors.red}) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: background),
      );
    }

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLocating = false);
        showMessage(isArabic ? 'يرجى تفعيل خدمة الموقع (GPS) من إعدادات جهازك' : 'Please enable location services (GPS)');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLocating = false);
          showMessage(isArabic ? 'تم رفض إذن الوصول للموقع' : 'Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLocating = false);
        showMessage(
          isArabic
              ? 'إذن الموقع مرفوض بشكل دائم، يرجى تفعيله من إعدادات التطبيق'
              : 'Location permission permanently denied, please enable it in app settings',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      // Reverse geocoding: تحويل الإحداثيات إلى عنوان نصي تلقائيًا
      String addressText = '';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final street = p.street?.trim() ?? '';
          final district = p.subLocality?.trim() ?? p.locality?.trim() ?? '';
          final city = p.locality?.trim() ?? '';
          final parts = <String>[
            if (street.isNotEmpty) street,
            if (district.isNotEmpty) district,
            if (city.isNotEmpty && city != district) city,
          ];
          addressText = parts.join('، ');
        }
      } catch (_) {
        // في حال فشل تحويل الإحداثيات، نكتب الإحداثيات نفسها كعنوان مؤقت
        addressText = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      }

      setState(() => _isLocating = false);

      if (mounted) {
        _addressController.text = addressText.isEmpty
            ? '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}'
            : addressText;
        showMessage(
          isArabic ? 'تم تحديد موقعك وكتابة العنوان، يمكنك تعديله يدويًا' : 'Location pinned and address filled, you can edit it',
          background: const Color(0xFFFF6B00),
        );
      }
    } catch (e) {
      setState(() => _isLocating = false);
      showMessage(isArabic ? 'تعذّر تحديد الموقع الحالي' : 'Could not determine current location');
    }
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSpecializations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار تخصص واحد على الأقل'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب الموافقة على الشروط والأحكام وميثاق الخدمة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final normalizedPhone = PhoneUtils.normalize(_phoneController.text.trim());
    final email = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : '$normalizedPhone@mahwar.app';

    context.read<AuthCubit>().signUp(
      email: email,
      password: _passwordController.text,
      fullName: _nameController.text.trim(),
      phoneNumber: normalizedPhone,
      role: 'provider',
      nationalId: _nationalIdController.text.trim(),
      workshopName: _workshopController.text.trim(),
      address: _addressController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      supportScope: _supportScope,
      hasVehicle: _hasServiceVehicle,
      vehicleSpecs: _hasServiceVehicle ? _vehicleSpecsController.text.trim() : null,
      vehicleMake: _hasServiceVehicle ? _vehicleMakeController.text.trim() : null,
      vehicleModel: _hasServiceVehicle ? _vehicleModelController.text.trim() : null,
      vehicleYear: _hasServiceVehicle ? int.tryParse(_vehicleYearController.text.trim()) : null,
      vehiclePlate: _hasServiceVehicle ? _vehiclePlateController.text.trim() : null,
      vehicleColor: _hasServiceVehicle ? _vehicleColorController.text.trim() : null,
      specializations: List<String>.from(_selectedSpecializations),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = context.watch<AppSettingsCubit>().state.locale.languageCode == 'ar';

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full Name Input
          TextFormField(
            controller: _nameController,
            keyboardType: TextInputType.name,
            decoration: InputDecoration(
              labelText: l10n?.fullName ?? (isArabic ? 'الاسم رباعي (المسئول)' : 'Full Name'),
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return isArabic ? 'يرجى إدخال الاسم رباعي' : 'Please enter full name';
              }
              if (value.trim().split(' ').length < 3) {
                return isArabic ? 'يرجى كتابة الاسم الثلاثي على الأقل' : 'Please enter at least 3 names';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Phone Number Input
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l10n?.phoneNumber ?? (isArabic ? 'رقم الهاتف' : 'Phone Number'),
              hintText: '01xxxxxxxxx',
              prefixIcon: const Icon(Icons.phone_android_rounded),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return isArabic ? 'يرجى إدخال رقم الهاتف' : 'Please enter phone number';
              }
              final clean = value.trim();
              if (!RegExp(r'^01[0125][0-9]{8}$').hasMatch(clean)) {
                return isArabic
                    ? 'رقم هاتف مصري غير صحيح (11 رقم)'
                    : 'Invalid Egyptian phone number (11 digits)';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Email Input (Optional)
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: l10n?.email ?? (isArabic ? 'البريد الإلكتروني (اختياري)' : 'Email (Optional)'),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                  return isArabic ? 'صيغة البريد الإلكتروني غير صحيحة' : 'Invalid email format';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // National ID Input (Mandatory for Provider)
          TextFormField(
            controller: _nationalIdController,
            keyboardType: TextInputType.number,
            maxLength: 14,
            decoration: InputDecoration(
              labelText: '${l10n?.nationalId ?? (isArabic ? 'الرقم القومي' : 'National ID')} *',
              hintText: '14 رقم قومي مدون في البطاقة',
              prefixIcon: const Icon(Icons.badge_outlined),
              counterText: '',
              helperText: isArabic
                  ? 'إجباري لمزودي الخدمة لتوثيق الحساب والأمان'
                  : 'Mandatory for service providers for security verification',
              helperStyle: const TextStyle(color: Color(0xFFFF6B00), fontSize: 11),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return isArabic ? 'الرقم القومي إجباري لمزودي الخدمة' : 'National ID is mandatory';
              }
              if (value.trim().length != 14 || !RegExp(r'^[0-9]+$').hasMatch(value.trim())) {
                return isArabic ? 'الرقم القومي يجب أن يتكون من 14 رقم' : 'National ID must be 14 digits';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Divider
          const Divider(),
          const SizedBox(height: 12),

          // Section Title: Business Details
          Text(
            isArabic ? 'بيانات الورشة والخدمة' : 'Workshop & Service Details',
            style: TextStyle(
              fontFamily: isArabic ? 'Zain' : 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),

          // Workshop / Agency Name Input
          TextFormField(
            controller: _workshopController,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: l10n?.workshopName ?? (isArabic ? 'اسم التوكيل / الورشة / الشهرة' : 'Workshop Name'),
              prefixIcon: const Icon(Icons.storefront_rounded),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return isArabic ? 'يرجى إدخال اسم الورشة أو التوكيل' : 'Please enter workshop name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Address Input + Map Location Button
          TextFormField(
            controller: _addressController,
            keyboardType: TextInputType.streetAddress,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l10n?.address ?? (isArabic ? 'العنوان التفصيلي' : 'Address'),
              prefixIcon: const Icon(Icons.location_on_outlined),
              hintText: isArabic ? 'حدد موقعك تلقائيًا أو اكتب العنوان يدويًا' : 'Use auto-location or type your address',
              suffixIcon: _isLocating
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B00)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.my_location_rounded, color: Color(0xFFFF6B00)),
                      tooltip: isArabic ? 'تحديد موقعي وكتابة العنوان تلقائيًا' : 'Use my current location',
                      onPressed: _pickCurrentLocation,
                    ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return isArabic ? 'يرجى إدخال عنوان الورشة/المقر' : 'Please enter detailed address';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Color(0xFFFF6B00)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isArabic
                      ? 'اضغط على أيقونة الموقع لملء العنوان تلقائيًا، ويمكنك تعديله بعد ذلك'
                      : 'Tap the location icon to auto-fill the address, then edit if needed',
                  style: TextStyle(
                    fontFamily: isArabic ? 'Cairo' : 'Poppins',
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Specialization Title & Chips
          Text(
            '${l10n?.specialization ?? (isArabic ? 'التخصصات المتاحة' : 'Specializations')} *',
            style: TextStyle(
              fontFamily: isArabic ? 'Cairo' : 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SpecializationChipsWidget(
            selectedSpecializations: _selectedSpecializations,
            isArabic: isArabic,
            onChanged: (updated) {
              setState(() {
                _selectedSpecializations = updated;
              });
            },
          ),
          const SizedBox(height: 20),

          // Support Scope
          Text(
            l10n?.supportScope ?? (isArabic ? 'نطاق تقديم الخدمة' : 'Support Scope'),
            style: TextStyle(
              fontFamily: isArabic ? 'Cairo' : 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Center(
                      child: Text(
                        isArabic ? 'طوارئ الطريق' : 'Roadside',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    selected: _supportScope == 'emergency',
                    selectedColor: const Color(0xFFFF6B00),
                    labelStyle: TextStyle(
                      fontFamily: isArabic ? 'Cairo' : 'Poppins',
                      color: _supportScope == 'emergency' ? Colors.white : null,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _supportScope = 'emergency');
                    },
                  ),
                ),
                Expanded(
                  child: ChoiceChip(
                    label: Center(
                      child: Text(
                        isArabic ? 'في الورشة' : 'On-site',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    selected: _supportScope == 'on_site',
                    selectedColor: const Color(0xFFFF6B00),
                    labelStyle: TextStyle(
                      fontFamily: isArabic ? 'Cairo' : 'Poppins',
                      color: _supportScope == 'on_site' ? Colors.white : null,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _supportScope = 'on_site');
                    },
                  ),
                ),
                Expanded(
                  child: ChoiceChip(
                    label: Center(
                      child: Text(
                        isArabic ? 'كلاهما' : 'Both',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    selected: _supportScope == 'both',
                    selectedColor: const Color(0xFFFF6B00),
                    labelStyle: TextStyle(
                      fontFamily: isArabic ? 'Cairo' : 'Poppins',
                      color: _supportScope == 'both' ? Colors.white : null,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _supportScope = 'both');
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Has Service Vehicle Switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.fire_truck_outlined, color: Color(0xFFFF6B00)),
                    const SizedBox(width: 12),
                    Text(
                      l10n?.hasVehicle ?? (isArabic ? 'هل لديك سيارة خدمة مجهزة؟' : 'Has Service Vehicle?'),
                      style: TextStyle(
                        fontFamily: isArabic ? 'Cairo' : 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _hasServiceVehicle,
                  activeTrackColor: const Color(0xFFFF6B00),
                  onChanged: (val) {
                    setState(() {
                      _hasServiceVehicle = val;
                    });
                  },
                ),
              ],
            ),
          ),

          if (_hasServiceVehicle) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _vehicleMakeController,
              decoration: InputDecoration(
                labelText: isArabic ? 'ماركة السيارة' : 'Vehicle Make',
                hintText: isArabic ? 'مثال: تويوتا' : 'e.g. Toyota',
                prefixIcon: const Icon(Icons.directions_car),
              ),
              validator: (value) {
                if (_hasServiceVehicle && (value == null || value.trim().isEmpty)) {
                  return isArabic ? 'يرجى إدخال ماركة السيارة' : 'Please enter vehicle make';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vehicleModelController,
              decoration: InputDecoration(
                labelText: isArabic ? 'موديل السيارة' : 'Vehicle Model',
                hintText: isArabic ? 'مثال: كورولا' : 'e.g. Corolla',
                prefixIcon: const Icon(Icons.directions_car),
              ),
              validator: (value) {
                if (_hasServiceVehicle && (value == null || value.trim().isEmpty)) {
                  return isArabic ? 'يرجى إدخال موديل السيارة' : 'Please enter vehicle model';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _vehicleYearController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'السنة' : 'Year',
                      hintText: '2024',
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                    validator: (value) {
                      if (_hasServiceVehicle && (value == null || value.trim().isEmpty)) {
                        return isArabic ? 'مطلوب' : 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _vehicleColorController,
                    decoration: InputDecoration(
                      labelText: isArabic ? 'اللون' : 'Color',
                      hintText: isArabic ? 'أبيض' : 'White',
                      prefixIcon: const Icon(Icons.color_lens),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vehiclePlateController,
              decoration: InputDecoration(
                labelText: isArabic ? 'رقم اللوحة' : 'Plate Number',
                hintText: 'أ ب ج 1234',
                prefixIcon: const Icon(Icons.pin),
              ),
              validator: (value) {
                if (_hasServiceVehicle && (value == null || value.trim().isEmpty)) {
                  return isArabic ? 'يرجى إدخال رقم اللوحة' : 'Please enter plate number';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vehicleSpecsController,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: l10n?.vehicleSpecs ?? (isArabic ? 'مواصفات إضافية' : 'Additional Specs'),
                hintText: isArabic ? 'مثال: ونش هيدروليك' : 'e.g. Hydraulic crane',
                prefixIcon: const Icon(Icons.minor_crash_outlined),
              ),
            ),
          ],

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // Password Input
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: l10n?.password ?? (isArabic ? 'كلمة المرور' : 'Password'),
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return isArabic ? 'يرجى إدخال كلمة المرور' : 'Please enter password';
              }
              if (value.length < 6) {
                return isArabic ? 'كلمة المرور يجب أن لا تقل عن 6 خانات' : 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm Password Input
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: l10n?.confirmPassword ?? (isArabic ? 'تأكيد كلمة المرور' : 'Confirm Password'),
              prefixIcon: const Icon(Icons.lock_reset_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                },
              ),
            ),
            validator: (value) {
              if (value != _passwordController.text) {
                return isArabic ? 'كلمتا المرور غير متطابقتين' : 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Terms & Conditions Checkbox
          Row(
            children: [
              Checkbox(
                value: _agreedToTerms,
                activeColor: const Color(0xFFFF6B00),
                onChanged: (value) {
                  setState(() => _agreedToTerms = value ?? false);
                },
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                  child: Text(
                    l10n?.agreeToTerms ??
                        (isArabic
                            ? 'أوافق على الشروط والأحكام وميثاق مزودي الخدمة'
                            : 'I agree to Terms & Conditions and Service Provider Charter'),
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
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      l10n?.signup ?? (isArabic ? 'إنشاء حساب مقدم الخدمة' : 'Register Provider Account'),
                      style: TextStyle(
                        fontFamily: isArabic ? 'Zain' : 'Poppins',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Already Have Account Redirect Link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isArabic ? 'لديك حساب بالفعل؟' : 'Already have an account?',
                style: TextStyle(
                  fontFamily: isArabic ? 'Cairo' : 'Poppins',
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/login?role=provider'),
                child: Text(
                  l10n?.login ?? (isArabic ? 'تسجيل الدخول' : 'Login'),
                  style: TextStyle(
                    fontFamily: isArabic ? 'Cairo' : 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF6B00),
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
