import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/provider_model.dart';
import '../../core/services/location_service.dart';
import '../../core/services/provider_location_write.dart';
import '../../core/utils/distance.dart';
import '../../l10n/app_localizations.dart';

class EditWorkshopScreen extends StatefulWidget {
  const EditWorkshopScreen({super.key});

  @override
  State<EditWorkshopScreen> createState() => _EditWorkshopScreenState();
}

class _EditWorkshopScreenState extends State<EditWorkshopScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _workshopController;
  late TextEditingController _addressController;
  late TextEditingController _vehicleSpecsController;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLocating = false;

  SupportScope _supportScope = SupportScope.both;
  bool _hasServiceVehicle = false;
  double _latitude = 0;
  double _longitude = 0;

  // بيانات حداثة الموقع المخزّن — تُحمّل من قاعدة البيانات للحكم هل
  // تحديثات هذا التحديد تستحق الكتابة فوق المخزّن.
  DateTime? _locationUpdatedAt;
  double? _locationAccuracy;

  @override
  void initState() {
    super.initState();
    _workshopController = TextEditingController();
    _addressController = TextEditingController();
    _vehicleSpecsController = TextEditingController();
    _loadWorkshop();
  }

  @override
  void dispose() {
    _workshopController.dispose();
    _addressController.dispose();
    _vehicleSpecsController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkshop() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _client
          .from('providers')
          .select(
            'workshop_name, address, latitude, longitude, location_updated_at, location_accuracy, support_scope, has_vehicle, vehicle_specs',
          )
          .eq('id', userId)
          .maybeSingle();

      if (response != null && mounted) {
        _workshopController.text = response['workshop_name'] ?? '';
        _addressController.text = response['address'] ?? '';
        _vehicleSpecsController.text = response['vehicle_specs'] ?? '';
        _latitude = (response['latitude'] as num?)?.toDouble() ?? 0;
        _longitude = (response['longitude'] as num?)?.toDouble() ?? 0;
        _locationUpdatedAt = DateTime.tryParse(
          response['location_updated_at'] as String? ?? '',
        )?.toUtc();
        _locationAccuracy = (response['location_accuracy'] as num?)?.toDouble();
        _hasServiceVehicle = response['has_vehicle'] ?? false;

        final scope = response['support_scope'] as String?;
        if (scope == 'emergency') {
          _supportScope = SupportScope.emergency;
        } else if (scope == 'on_site') {
          _supportScope = SupportScope.onSite;
        } else {
          _supportScope = SupportScope.both;
        }

        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickCurrentLocation() async {
    setState(() => _isLocating = true);

    final position = await LocationService.instance.getCurrentPosition(forceRefresh: true);
    if (position != null) {
      final now = DateTime.now().toUtc();
      final movedMeters = distanceMeters(
        _latitude,
        _longitude,
        position.latitude,
        position.longitude,
      );
      // نفس قاعدة قرار الكتابة المطبّقة على شاشة المزوّد الرئيسية: لا نقبل
      // تحديداً أردأ فوق مخزّن طازج أدق، ولا حركة صغيرة على مخزّن طازج.
      final decision = decideLocationWrite(
        storedUpdatedAt: _locationUpdatedAt,
        storedAccuracy: _locationAccuracy,
        newAccuracy: position.accuracy,
        movedMeters: movedMeters,
        now: now,
      );
      if (decision.shouldWrite) {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationUpdatedAt = now;
        _locationAccuracy = position.accuracy;
      }
    }

    // العنوان يُشتق من آخر تحديد فعلي (نفس التحديد إن لم يُرفض) دون تكرار
    // محاولة GPS ثانية.
    final address = await LocationService.instance.getCurrentAddress(forceRefresh: false);

    if (mounted) {
      setState(() {
        if (address != null && address.isNotEmpty) {
          _addressController.text = address;
        }
        _isLocating = false;
      });
    }
  }

  Future<void> _saveWorkshop() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    setState(() => _isSaving = true);

    final scopeValue = switch (_supportScope) {
      SupportScope.emergency => 'emergency',
      SupportScope.onSite => 'on_site',
      SupportScope.both => 'both',
    };

    final vehicleSpecs = _hasServiceVehicle
        ? _vehicleSpecsController.text.trim()
        : null;

    try {
      await _client.from('providers').update({
        'workshop_name': _workshopController.text.trim(),
        'address': _addressController.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'location_updated_at': _locationUpdatedAt?.toIso8601String(),
        'location_accuracy': _locationAccuracy,
        'support_scope': scopeValue,
        'has_vehicle': _hasServiceVehicle,
        'vehicle_specs': vehicleSpecs,
      }).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.savedSuccessfully ?? 'تم الحفظ بنجاح',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic ? 'حدث خطأ أثناء الحفظ: $e' : 'Error saving: $e',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
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
          l10n?.workshopInfo ?? 'بيانات الورشة',
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
                      controller: _workshopController,
                      label: l10n?.workshopName ?? 'اسم الورشة / التوكيل',
                      icon: Icons.storefront_rounded,
                      isDark: isDark,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return isArabic ? 'اسم الورشة مطلوب' : 'Workshop name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildField(
                      controller: _addressController,
                      label: l10n?.address ?? 'العنوان التفصيلي',
                      icon: Icons.location_on_outlined,
                      isDark: isDark,
                      maxLines: 2,
                      keyboardType: TextInputType.streetAddress,
                      hintText: isArabic ? 'حدد موقعك تلقائيًا أو اكتب العنوان يدويًا' : 'Use auto-location or type your address',
                      suffixIcon: _isLocating
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.orangePrimary,
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.my_location_rounded, color: AppColors.orangePrimary),
                              tooltip: isArabic ? 'تحديد موقعي وكتابة العنوان تلقائيًا' : 'Use my current location',
                              onPressed: _pickCurrentLocation,
                            ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return isArabic ? 'يرجى إدخال عنوان الورشة' : 'Please enter workshop address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // نطاق تقديم الخدمة
                    Text(
                      l10n?.supportScope ?? (isArabic ? 'نطاق تقديم الخدمة' : 'Support Scope'),
                      style: TextStyle(
                        fontFamily: isArabic ? 'Cairo' : 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          _buildScopeChip(
                            label: isArabic ? 'طوارئ الطريق' : 'Roadside',
                            selected: _supportScope == SupportScope.emergency,
                            onSelected: () => setState(() => _supportScope = SupportScope.emergency),
                            isDark: isDark,
                          ),
                          _buildScopeChip(
                            label: isArabic ? 'في الورشة' : 'On-site',
                            selected: _supportScope == SupportScope.onSite,
                            onSelected: () => setState(() => _supportScope = SupportScope.onSite),
                            isDark: isDark,
                          ),
                          _buildScopeChip(
                            label: isArabic ? 'كلاهما' : 'Both',
                            selected: _supportScope == SupportScope.both,
                            onSelected: () => setState(() => _supportScope = SupportScope.both),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // هل لديك سيارة خدمة؟
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.fire_truck_outlined, color: AppColors.orangePrimary),
                              const SizedBox(width: 12),
                              Text(
                                l10n?.hasVehicle ?? (isArabic ? 'هل لديك سيارة خدمة مجهزة؟' : 'Has Service Vehicle?'),
                                style: TextStyle(
                                  fontFamily: isArabic ? 'Cairo' : 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _hasServiceVehicle,
                            activeTrackColor: AppColors.orangePrimary,
                            onChanged: (val) => setState(() => _hasServiceVehicle = val),
                          ),
                        ],
                      ),
                    ),

                    if (_hasServiceVehicle) ...[
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _vehicleSpecsController,
                        label: l10n?.vehicleSpecs ?? (isArabic ? 'مواصفات السيارة' : 'Vehicle Specs'),
                        icon: Icons.minor_crash_outlined,
                        isDark: isDark,
                        hintText: isArabic ? 'مثال: ونش هيدروليك، سيارة مجهزة' : 'e.g. Hydraulic crane',
                      ),
                    ],

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveWorkshop,
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

  Widget _buildScopeChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    required bool isDark,
  }) {
    return Expanded(
      child: ChoiceChip(
        label: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Cairo',
              color: selected ? Colors.white : null,
            ),
          ),
        ),
        selected: selected,
        selectedColor: AppColors.orangePrimary,
        backgroundColor: Colors.transparent,
        onSelected: (_) => onSelected(),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hintText,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 15,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
        hintText: hintText,
        hintStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
        prefixIcon: Icon(icon, color: AppColors.orangePrimary),
        suffixIcon: suffixIcon,
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
      ),
      validator: validator,
    );
  }
}
