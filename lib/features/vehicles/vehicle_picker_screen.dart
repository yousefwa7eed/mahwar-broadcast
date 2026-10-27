import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/vehicle_catalog.dart';
import '../../core/models/vehicle_selection.dart';
import '../../core/services/vehicle_catalog_service.dart';
import '../../core/utils/plate_utils.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/egyptian_plate.dart';
import '../../l10n/app_localizations.dart';

part 'widgets/picker_chrome.dart';
part 'widgets/picker_shared.dart';
part 'widgets/brand_step.dart';
part 'widgets/model_step.dart';
part 'widgets/year_step.dart';
part 'widgets/trim_step.dart';
part 'widgets/color_step.dart';
part 'widgets/plate_step.dart';

/// معالج اختيار سيارة كامل من الكتالوج.
///
/// يُرجع [VehicleSelection] عبر `Navigator.pop`. يُستخدم في التسجيل وفي
/// إضافة/تعديل سيارة من الملف الشخصي.
class VehiclePickerScreen extends StatefulWidget {
  const VehiclePickerScreen({super.key, this.initial});

  final VehicleSelection? initial;

  @override
  State<VehiclePickerScreen> createState() => _VehiclePickerScreenState();
}

class _VehiclePickerScreenState extends State<VehiclePickerScreen> {
  static const int _stepCount = 6;

  final TextEditingController _digitsController = TextEditingController();

  VehicleCatalog? _catalog;
  Object? _loadError;
  bool _isLoading = true;

  int _step = 0;
  VehicleBrand? _brand;
  VehicleModel? _model;
  VehicleGeneration? _generation;
  int? _year;
  VehicleTrim? _trim;
  VehicleColor? _color;
  String? _plateLetter1;
  String? _plateLetter2;
  String? _plateLetter3;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) _step = _stepCount - 1;
    _loadCatalog();
  }

  @override
  void dispose() {
    _digitsController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final catalog = await VehicleCatalogService.instance.load();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _isLoading = false;
        _applyInitialSelection(catalog);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  void _applyInitialSelection(VehicleCatalog catalog) {
    final initial = widget.initial;
    if (initial == null) return;

    _brand = catalog.brand(initial.brand.id) ?? initial.brand;
    _model = catalog.model(initial.model.id) ?? initial.model;
    _generation =
        catalog.generation(initial.generation.id) ?? initial.generation;
    _trim = catalog.trim(initial.trim.id) ?? initial.trim;
    _color = catalog.color(initial.color.id) ?? initial.color;
    _year = initial.modelYear;

    final letters = initial.plateLetters;
    if (letters != null && letters.length == 3) {
      _plateLetter1 = letters[0];
      _plateLetter2 = letters[1];
      _plateLetter3 = letters[2];
    }
    if (initial.plateDigits != null) {
      _digitsController.text = initial.plateDigits!;
    }
  }

  void _goTo(int step) => setState(() => _step = step);

  void _goBack() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    _goTo(_step - 1);
  }

  void _selectBrand(VehicleBrand brand) {
    setState(() {
      if (_brand?.id != brand.id) {
        _model = null;
        _generation = null;
        _year = null;
        _trim = null;
      }
      _brand = brand;
      _step = 1;
    });
  }

  void _selectModel(VehicleModel model) {
    setState(() {
      if (_model?.id != model.id) {
        _generation = null;
        _year = null;
        _trim = null;
      }
      _model = model;
      _step = 2;
    });
  }

  /// سنوات الموديل كلها (اتحاد الأجيال)، الأحدث أولًا.
  List<int> _yearsFor(VehicleModel model) {
    final years = <int>{};
    for (final generation in model.generations) {
      years.addAll(generation.years);
    }
    return years.toList()..sort((a, b) => b.compareTo(a));
  }

  /// الجيل الذي تقع فيه السنة؛ عند التداخل نأخذ الأحدث.
  VehicleGeneration? _generationFor(VehicleModel model, int year) {
    VehicleGeneration? match;
    for (final generation in model.generations) {
      final last = generation.yearTo ?? DateTime.now().year;
      if (year < generation.yearFrom || year > last) continue;
      if (match == null || generation.yearFrom > match.yearFrom) {
        match = generation;
      }
    }
    return match;
  }

  void _selectYear(int year) {
    final generation = _generationFor(_model!, year);
    if (generation == null) return;
    setState(() {
      if (_year != year) _trim = null;
      _year = year;
      _generation = generation;
      _step = 3;
    });
  }

  void _selectTrim(VehicleTrim trim) {
    setState(() {
      _trim = trim;
      _step = 4;
    });
  }

  void _selectColor(VehicleColor color) {
    setState(() {
      _color = color;
      _step = 5;
    });
  }

  void _setPlateLetters(List<String?> letters) {
    setState(() {
      _plateLetter1 = letters[0];
      _plateLetter2 = letters[1];
      _plateLetter3 = letters[2];
    });
  }

  void _clearPlate() {
    setState(() {
      _plateLetter1 = null;
      _plateLetter2 = null;
      _plateLetter3 = null;
      _digitsController.clear();
    });
  }

  void _finish() {
    final l10n = AppLocalizations.of(context);
    final brand = _brand;
    final model = _model;
    final generation = _generation;
    final year = _year;
    final trim = _trim;
    final color = _color;

    if (brand == null ||
        model == null ||
        generation == null ||
        year == null ||
        trim == null ||
        color == null) {
      _showMessage(l10n?.selectCar ?? 'اختر السيارة');
      return;
    }

    final digits = PlateUtils.toWesternDigits(_digitsController.text.trim());
    final hasPlate =
        _plateLetter1 != null ||
        _plateLetter2 != null ||
        _plateLetter3 != null ||
        digits.isNotEmpty;

    if (hasPlate &&
        !PlateUtils.isValidPlate(
          _plateLetter1,
          _plateLetter2,
          _plateLetter3,
          digits,
        )) {
      _showMessage(
        l10n?.vehiclePlateInvalid ?? 'أدخل 3 حروف و3-4 أرقام، أو امسح اللوحة',
      );
      return;
    }

    Navigator.of(context).pop(
      VehicleSelection(
        brand: brand,
        model: model,
        generation: generation,
        trim: trim,
        modelYear: year,
        color: color,
        plateLetters: hasPlate
            ? '$_plateLetter1$_plateLetter2$_plateLetter3'
            : null,
        plateDigits: hasPlate ? digits : null,
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  bool get _canProceed {
    switch (_step) {
      case 0:
        return _brand != null;
      case 1:
        return _model != null;
      case 2:
        return _year != null;
      case 3:
        return _trim != null;
      case 4:
        return _color != null;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
          onPressed: _goBack,
        ),
        title: Text(
          l10n?.selectVehicleTitle ?? 'اختيار السيارة',
          style: TextStyle(
            fontFamily: 'Zain',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.orangePrimary),
            )
          : _loadError != null
          ? _CatalogError(onRetry: _loadCatalog)
          : Column(
              children: [
                _ProgressHeader(step: _step, total: _stepCount),
                _SelectionSummary(
                  brand: _brand,
                  model: _model,
                  year: _year,
                  trim: _trim,
                  color: _color,
                  isArabic: _isArabic,
                  onTapStep: _goTo,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _buildStep(),
                  ),
                ),
                _BottomBar(
                  visible: _step == _stepCount - 1,
                  enabled: _canProceed,
                  onSave: _finish,
                ),
              ],
            ),
    );
  }

  Widget _buildStep() {
    final catalog = _catalog!;
    switch (_step) {
      case 0:
        return _BrandStep(
          key: const ValueKey('brand'),
          brands: catalog.brands,
          selectedId: _brand?.id,
          isArabic: _isArabic,
          onSelected: _selectBrand,
        );
      case 1:
        return _ModelStep(
          key: const ValueKey('model'),
          brand: _brand!,
          selectedId: _model?.id,
          isArabic: _isArabic,
          onSelected: _selectModel,
        );
      case 2:
        return _YearStep(
          key: const ValueKey('year'),
          years: _yearsFor(_model!),
          selectedYear: _year,
          onSelected: _selectYear,
        );
      case 3:
        return _TrimStep(
          key: const ValueKey('trim'),
          generation: _generation!,
          selectedId: _trim?.id,
          isArabic: _isArabic,
          onSelected: _selectTrim,
          onUnknown: () => _selectTrim(_generation!.trims.first),
        );
      case 4:
        return _ColorStep(
          key: const ValueKey('color'),
          colors: catalog.colors,
          selectedId: _color?.id,
          isArabic: _isArabic,
          onSelected: _selectColor,
        );
      default:
        return _PlateStep(
          key: const ValueKey('plate'),
          letters: [_plateLetter1, _plateLetter2, _plateLetter3],
          digitsController: _digitsController,
          onLettersChanged: _setPlateLetters,
          onClear: _clearPlate,
        );
    }
  }
}
