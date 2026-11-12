import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/rpc_error_translator.dart';
import '../../../core/models/vehicle.dart';
import '../../../core/models/vehicle_catalog.dart';
import '../../../core/models/vehicle_selection.dart';
import '../../../core/services/app_messenger.dart';
import '../../../core/services/vehicle_catalog_service.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../l10n/app_localizations.dart';
import '../../vehicles/vehicle_picker_screen.dart';

/// قائمة سيارات المستخدم مع الإضافة والتعديل والحذف. تُستخدم داخل شاشة
/// مستقلة وفي صفحة الملف الشخصي.
class CarsSection extends StatefulWidget {
  const CarsSection({super.key, this.showInlineAddButton = true});

  /// شاشة «إدارة السيارات» تعرض زر الإضافة العائم، فتمرّر false.
  final bool showInlineAddButton;

  @override
  State<CarsSection> createState() => CarsSectionState();
}

/// عامة لتتمكن شاشة «إدارة السيارات» من ربط زر الإضافة العائم بها.
class CarsSectionState extends State<CarsSection> {
  final SupabaseClient _client = Supabase.instance.client;

  List<Vehicle> _vehicles = [];
  VehicleCatalog? _catalog;
  Object? _loadError;
  bool _isLoading = true;
  bool _isMutating = false;

  @override
  void initState() {
    super.initState();
    _loadCars();
  }

  Future<void> _loadCars() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _vehicles = [];
      });
      return;
    }

    // نسبينر فقط عند أول تحميل أو بعد خطأ؛ تحديث ما بعد الإضافة/الحذف
    // يُبقي الكروت معروضة بدل استبدالها بدائرة انتظار.
    if (_vehicles.isEmpty || _loadError != null) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final response = await _client
          .from('vehicles')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      if (!mounted) return;
      final vehicles = response.map(Vehicle.fromJson).toList();
      setState(() {
        _vehicles = vehicles;
        _isLoading = false;
        _loadError = null;
      });

      // الكتالوج لا يُحمّل إلا لو فيه عربيات فعلًا، ويُحمّل مرة واحدة فقط.
      if (vehicles.isEmpty || _catalog != null) return;
      try {
        final catalog = await VehicleCatalogService.instance.load();
        if (mounted) setState(() => _catalog = catalog);
      } catch (_) {
        // نعرض اللوحة و«—» بدل أسماء الكتالوج بدل تعطيل القسم بالكامل.
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  VehicleSummary? _summaryOf(Vehicle vehicle) =>
      _catalog == null ? null : vehicle.resolve(_catalog!);

  /// يفتح معالج إضافة سيارة (يُستخدم من زر الإضافة العائم).
  Future<void> openAddPicker() => _openPicker();

  Future<void> _openPicker({VehicleSummary? existing}) async {
    if (_isMutating) return;
    final l10n = AppLocalizations.of(context);

    VehicleSelection? initial;
    if (existing != null) {
      final brand = existing.brand;
      final model = existing.model;
      final generation = existing.generation;
      final trim = existing.trim;
      final color = existing.color;
      if (brand == null ||
          model == null ||
          generation == null ||
          trim == null ||
          color == null) {
        _showMessage(
          l10n?.vehicleCatalogLoadFailed ??
              'تعذّر تحميل كتالوج السيارات، تحقق من الاتصال وحاول مرة أخرى',
          isError: true,
        );
        return;
      }
      initial = VehicleSelection(
        brand: brand,
        model: model,
        generation: generation,
        trim: trim,
        modelYear: existing.vehicle.modelYear,
        color: color,
        plateLetters: existing.vehicle.plateLetters,
        plateDigits: existing.vehicle.plateDigits,
      );
    }

    final selection = await Navigator.of(context).push<VehicleSelection>(
      MaterialPageRoute(
        builder: (_) => VehiclePickerScreen(initial: initial),
      ),
    );
    if (!mounted || selection == null) return;

    if (existing == null) {
      await _insert(selection);
    } else {
      await _update(existing.vehicle.id, selection);
    }
  }

  Future<void> _insert(VehicleSelection selection) async {
    final l10n = AppLocalizations.of(context);
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isMutating = true);
    try {
      await _client.from('vehicles').insert({
        'user_id': userId,
        ...selection.toInsertJson(),
      });
      if (!mounted) return;
      _showMessage(l10n?.vehicleSaved ?? 'تم حفظ السيارة');
      await _loadCars();
    } catch (error) {
      if (!mounted) return;
      _showMessage(RpcErrorTranslator.translate(error, l10n), isError: true);
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _update(String vehicleId, VehicleSelection selection) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isMutating = true);
    try {
      await _client
          .from('vehicles')
          .update(selection.toInsertJson())
          .eq('id', vehicleId);
      if (!mounted) return;
      _showMessage(l10n?.vehicleSaved ?? 'تم حفظ السيارة');
      await _loadCars();
    } catch (error) {
      if (!mounted) return;
      _showMessage(RpcErrorTranslator.translate(error, l10n), isError: true);
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _setDefault(String vehicleId) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isMutating = true);
    try {
      await _client
          .from('vehicles')
          .update({'is_default': true})
          .eq('id', vehicleId);
      if (!mounted) return;
      _showMessage(l10n?.vehicleDefaultSet ?? 'تم تعيين السيارة كافتراضية');
      await _loadCars();
    } catch (error) {
      if (!mounted) return;
      _showMessage(RpcErrorTranslator.translate(error, l10n), isError: true);
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _delete(Vehicle vehicle) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n?.deleteCarTitle ?? 'حذف السيارة',
          style: const TextStyle(fontFamily: 'Zain', color: AppColors.error),
        ),
        content: Text(
          l10n?.deleteCarConfirm ?? 'هل أنت متأكد من حذف هذه السيارة؟',
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n?.cancel ?? 'إلغاء',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n?.delete ?? 'حذف',
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isMutating = true);
    try {
      await _client.from('vehicles').delete().eq('id', vehicle.id);
      if (!mounted) return;
      _showMessage(l10n?.vehicleDeleted ?? 'تم حذف السيارة');
      await _loadCars();
    } catch (error) {
      if (!mounted) return;
      _showMessage(RpcErrorTranslator.translate(error, l10n), isError: true);
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    AppMessenger.showToast(
      context,
      message,
      background: isError ? AppColors.error : AppColors.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    if (_isLoading) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.orangePrimary),
        ),
      );
    }

    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              l10n?.vehicleCatalogLoadFailed ??
                  'تعذّر تحميل كتالوج السيارات، تحقق من الاتصال وحاول مرة أخرى',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loadCars,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orangePrimary,
              ),
              child: Text(
                l10n?.retry ?? 'إعادة المحاولة',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_vehicles.isEmpty) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.directions_car_outlined,
                  size: 44,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n?.noCarsRegistered ?? 'لا توجد سيارات مسجلة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                if (!widget.showInlineAddButton) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n?.tapToAddCar ?? 'اضغط + لإضافة سيارة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.showInlineAddButton) ...[
            const SizedBox(height: 12),
            _buildAddButton(isDark, l10n),
          ],
        ],
      );
    }

    return Column(
      children: [
        for (int i = 0; i < _vehicles.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _buildCarCard(_vehicles[i], isDark, l10n),
        ],
        if (widget.showInlineAddButton) ...[
          const SizedBox(height: 12),
          _buildAddButton(isDark, l10n),
        ],
      ],
    );
  }

  Widget _buildAddButton(bool isDark, AppLocalizations? l10n) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _isMutating ? null : () => _openPicker(),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          l10n?.addCar ?? 'إضافة سيارة',
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.orangePrimary,
          side: BorderSide(
            color: AppColors.orangePrimary.withValues(alpha: 0.5),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildCarCard(
    Vehicle vehicle,
    bool isDark,
    AppLocalizations? l10n,
  ) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final summary = _summaryOf(vehicle);
    final title = summary?.title(isArabic) ?? '—';
    final details = <String>[
      if (summary?.trim != null) summary!.trim!.name(isArabic),
      if (summary?.color != null) summary!.color!.name(isArabic),
      if (vehicle.plateNumber != null) vehicle.plateNumber!,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: vehicle.isDefault
              ? AppColors.orangePrimary.withValues(alpha: 0.5)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: vehicle.isDefault ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (summary?.brand != null)
                BrandLogo(brand: summary!.brand!, size: 52)
              else
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.orangePrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.directions_car_rounded,
                    color: AppColors.orangePrimary,
                    size: 28,
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontFamily: isArabic ? 'Zain' : 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                        if (vehicle.isDefault) ...[
                          const SizedBox(width: 8),
                          _DefaultBadge(l10n: l10n),
                        ],
                      ],
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        details.join(' · '),
                        style: TextStyle(
                          fontFamily: isArabic ? 'Cairo' : 'Poppins',
                          fontSize: 12.5,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!vehicle.isDefault)
                TextButton.icon(
                  onPressed:
                      _isMutating ? null : () => _setDefault(vehicle.id),
                  icon: const Icon(Icons.check_circle_outline_rounded,
                      size: 18),
                  label: Text(
                    l10n?.setAsDefault ?? 'تعيين كافتراضية',
                    style: TextStyle(
                      fontFamily: isArabic ? 'Cairo' : 'Poppins',
                      fontSize: 12.5,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.orangePrimary,
                  ),
                ),
              IconButton(
                onPressed: _isMutating || summary == null
                    ? null
                    : () => _openPicker(existing: summary),
                tooltip: l10n?.editVehicle ?? 'تعديل السيارة',
                icon: Icon(
                  Icons.edit_outlined,
                  size: 21,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              IconButton(
                onPressed: _isMutating ? null : () => _delete(vehicle),
                tooltip: l10n?.delete ?? 'حذف',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: 21,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge({required this.l10n});

  final AppLocalizations? l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.orangePrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        l10n?.defaultVehicle ?? 'السيارة الافتراضية',
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: AppColors.orangePrimary,
        ),
      ),
    );
  }
}
