import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_cubit.dart';
import '../../../core/auth/national_id_utils.dart';
import '../../../core/auth/phone_utils.dart';
import '../../../core/settings/app_settings_cubit.dart';
import '../../../l10n/app_localizations.dart';
import 'specialization_chips_widget.dart';

final Geocoding _geocoding = Geocoding();

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
        showMessage(l10n?.providerEnableLocationService ??
            'يرجى تفعيل خدمة الموقع (GPS) من إعدادات جهازك');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLocating = false);
          showMessage(l10n?.providerLocationDenied ?? 'تم رفض إذن الوصول للموقع');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLocating = false);
        showMessage(
          l10n?.providerLocationDeniedForever ??
              'إذن الموقع مرفوض بشكل دائم، يرجى تفعيله من إعدادات التطبيق',
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
        final placemarks = await _geocoding.placemarkFromCoordinates(
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
          l10n?.providerLocationFilled ??
              'تم تحديد موقعك وكتابة العنوان، يمكنك تعديله يدويًا',
          background: const Color(0xFFFF6B00),
        );
      }
    } catch (e) {
      setState(() => _isLocating = false);
      showMessage(l10n?.providerLocationDetectFailed ??
          'تعذّر تحديد الموقع الحالي');
    }
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context);

    if (_selectedSpecializations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.providerSelectSpecPrompt ??
              'يرجى اختيار تخصص واحد على الأقل'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.providerAgreeTermsPrompt ??
              'يجب الموافقة على الشروط والأحكام وميثاق الخدمة'),
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
      nationalId: NationalIdUtils.normalize(_nationalIdController.text.trim()),
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
                return l10n?.providerFullNameRequired ?? 'يرجى إدخال الاسم رباعي';
              }
              if (value.trim().split(' ').length < 3) {
                return l10n?.providerNameAtLeast3 ??
                    'يرجى كتابة الاسم الثلاثي على الأقل';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Phone Number Input
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n?.phoneNumber ?? (isArabic ? 'رقم الهاتف' : 'Phone Number'),
              hintText: '01xxxxxxxxx',
              prefixIcon: const Icon(Icons.phone_android_rounded),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n?.providerEnterPhone ?? 'يرجى إدخال رقم الهاتف';
              }
              final clean = value.trim();
              if (!RegExp(r'^01[0125][0-9]{8}$').hasMatch(clean)) {
                return l10n?.providerInvalidPhone ??
                    'رقم هاتف مصري غير صحيح (11 رقم)';
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
                  return l10n?.invalidEmailFormat ?? 'صيغة البريد الإلكتروني غير صحيحة';
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
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 14,
            decoration: InputDecoration(
              labelText: '${l10n?.nationalId ?? (isArabic ? 'الرقم القومي' : 'National ID')} *',
              hintText: l10n?.providerNationalIdHint ?? '14 رقم قومي مدون في البطاقة',
              prefixIcon: const Icon(Icons.badge_outlined),
              counterText: '',
              helperText: l10n?.providerNationalIdHelper ??
                  'إجباري لمزودي الخدمة لتوثيق الحساب والأمان',
              helperStyle: const TextStyle(color: Color(0xFFFF6B00), fontSize: 11),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n?.providerNationalIdRequired ??
                    'الرقم القومي إجباري لمزودي الخدمة';
              }
              if (!NationalIdUtils.isValid(value)) {
                return l10n?.nationalIdInvalid ??
                    (isArabic ? 'الرقم القومي غير صحيح' : 'Invalid national ID');
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
            l10n?.providerWorkshopSectionTitle ?? 'بيانات الورشة والخدمة',
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
                return l10n?.providerWorkshopRequired ?? 'يرجى إدخال اسم الورشة أو التوكيل';
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
              hintText: l10n?.providerAddressHint ??
                  'حدد موقعك تلقائيًا أو اكتب العنوان يدويًا',
              suffixIcon: _isLocating
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B00)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.my_location_rounded, color: Color(0xFFFF6B00)),
                      tooltip: l10n?.providerLocateTooltip ?? 'تحديد موقعي وكتابة العنوان تلقائيًا',
                      onPressed: _pickCurrentLocation,
                    ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n?.providerAddressRequired ?? 'يرجى إدخال عنوان الورشة/المقر';
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
                  l10n?.providerAutoFillHint ??
                      'اضغط على أيقونة الموقع لملء العنوان تلقائيًا، ويمكنك تعديله بعد ذلك',
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
                        l10n?.providerScopeRoadside ?? 'طوارئ الطريق',
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
                        l10n?.providerScopeOnSite ?? 'في الورشة',
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
                        l10n?.supportScopeBoth ?? 'كلاهما',
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
                labelText: l10n?.providerVehicleMakeLabel ?? 'ماركة السيارة',
                hintText: l10n?.providerVehicleMakeHint ?? 'مثال: تويوتا',
                prefixIcon: const Icon(Icons.directions_car),
              ),
              validator: (value) {
                if (_hasServiceVehicle && (value == null || value.trim().isEmpty)) {
                  return l10n?.providerVehicleMakeRequired ?? 'يرجى إدخال ماركة السيارة';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vehicleModelController,
              decoration: InputDecoration(
                labelText: l10n?.providerVehicleModelLabel ?? 'موديل السيارة',
                hintText: l10n?.providerVehicleModelHint ?? 'مثال: كورولا',
                prefixIcon: const Icon(Icons.directions_car),
              ),
              validator: (value) {
                if (_hasServiceVehicle && (value == null || value.trim().isEmpty)) {
                  return l10n?.providerVehicleModelRequired ?? 'يرجى إدخال موديل السيارة';
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: l10n?.providerVehicleYearLabel ?? 'السنة',
                      hintText: '2024',
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                    validator: (value) {
                      if (_hasServiceVehicle && (value == null || value.trim().isEmpty)) {
                        return l10n?.providerVehicleYearRequired ?? 'مطلوب';
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
                      labelText: l10n?.providerVehicleColorLabel ?? 'اللون',
                      hintText: l10n?.providerVehicleColorHint ?? 'أبيض',
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
                labelText: l10n?.providerVehiclePlateLabel ?? 'رقم اللوحة',
                hintText: l10n?.providerVehiclePlateHint ?? 'أ ب ج 1234',
                prefixIcon: const Icon(Icons.pin),
              ),
              validator: (value) {
                if (_hasServiceVehicle && (value == null || value.trim().isEmpty)) {
                  return l10n?.providerVehiclePlateRequired ?? 'يرجى إدخال رقم اللوحة';
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
                hintText: l10n?.providerVehicleSpecsHint ?? 'مثال: ونش هيدروليك',
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
                return l10n?.providerEnterPassword ?? 'يرجى إدخال كلمة المرور';
              }
              if (value.length < 6) {
                return l10n?.providerPasswordTooShort ??
                    'كلمة المرور يجب أن لا تقل عن 6 خانات';
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
                return l10n?.passwordsDoNotMatch ?? 'كلمتا المرور غير متطابقتين';
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
                l10n?.alreadyHaveAccount ?? 'لديك حساب بالفعل؟',
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
