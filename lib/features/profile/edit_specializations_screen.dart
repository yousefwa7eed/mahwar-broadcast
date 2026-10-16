import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';

class EditSpecializationsScreen extends StatefulWidget {
  const EditSpecializationsScreen({super.key});

  @override
  State<EditSpecializationsScreen> createState() => _EditSpecializationsScreenState();
}

class _EditSpecializationsScreenState extends State<EditSpecializationsScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;

  /// التخصصات المتاحة في النظام (من service_types)
  List<Map<String, dynamic>> _allSpecializations = [];

  /// التخصصات المختارة حالياً
  List<String> _selected = [];

  @override
  void initState() {
    super.initState();
    _loadSpecializations();
  }

  Future<void> _loadSpecializations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final typesResponse = await _client
          .from('service_types')
          .select('id, name_ar, name_en')
          .order('name_ar');
      final selectedResponse = await _client
          .from('provider_specializations')
          .select('service_type_id')
          .eq('provider_id', userId);

      if (mounted) {
        setState(() {
          _allSpecializations = List<Map<String, dynamic>>.from(typesResponse);
          _selected = selectedResponse
              .map((r) => r['service_type_id'] as String)
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSpecializations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.providerSelectSpecPrompt ??
                'يرجى اختيار تخصص واحد على الأقل',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // تحميل التخصصات الحالية للمقارنة
    List<String> current = [];
    try {
      final response = await _client
          .from('provider_specializations')
          .select('service_type_id')
          .eq('provider_id', userId);
      current = response.map((r) => r['service_type_id'] as String).toList();
    } catch (_) {}

    final toAdd = _selected.where((s) => !current.contains(s)).toList();
    final toRemove = current.where((s) => !_selected.contains(s)).toList();

    setState(() => _isSaving = true);

    try {
      if (toAdd.isNotEmpty) {
        await _client.from('provider_specializations').insert(
          toAdd.map((s) => {'provider_id': userId, 'service_type_id': s}).toList(),
        );
      }
      if (toRemove.isNotEmpty) {
        await _client
            .from('provider_specializations')
            .delete()
            .eq('provider_id', userId)
            .inFilter('service_type_id', toRemove);
      }

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
              AppLocalizations.of(context)?.errorSaving('$e') ?? 'حدث خطأ أثناء الحفظ: $e',
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

  String _specializationLabel(Map<String, dynamic> spec, bool isArabic) {
    final ar = spec['name_ar'] as String?;
    final en = spec['name_en'] as String?;
    if (isArabic && ar != null && ar.isNotEmpty) return ar;
    if (en != null && en.isNotEmpty) return en;
    return spec['id'] as String;
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
          l10n?.mySpecializations ?? 'تخصصاتي',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.specialization ?? (isArabic ? 'التخصصات المتاحة' : 'Specializations'),
                    style: TextStyle(
                      fontFamily: isArabic ? 'Cairo' : 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.selectSpecialtiesDesc ??
                        'اختر التخصصات التي تقدمها ورشتك، وستظهر لمالكي السيارات عند البحث عن الخدمات',
                    style: TextStyle(
                      fontFamily: isArabic ? 'Cairo' : 'Poppins',
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_allSpecializations.isEmpty)
                    Text(
                      l10n?.noSpecialtiesAvailable ?? 'لا توجد تخصصات متاحة حالياً',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allSpecializations.map((spec) {
                        final id = spec['id'] as String;
                        final label = _specializationLabel(spec, isArabic);
                        final isSelected = _selected.contains(id);
                        return FilterChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selected = [..._selected, id];
                              } else {
                                _selected = _selected.where((s) => s != id).toList();
                              }
                            });
                          },
                          selectedColor: AppColors.orangePrimary,
                          checkmarkColor: Colors.white,
                          backgroundColor: isDark
                              ? AppColors.darkCard
                              : Colors.grey.withValues(alpha: 0.1),
                          labelStyle: TextStyle(
                            fontFamily: isArabic ? 'Cairo' : 'Poppins',
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : null,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.orangePrimary
                                  : (isDark ? AppColors.darkBorder : Colors.grey.withValues(alpha: 0.3)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSpecializations,
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
    );
  }
}
