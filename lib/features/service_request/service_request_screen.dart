import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/auth/national_id_utils.dart';
import '../../../core/errors/rpc_error_translator.dart';
import '../../../core/models/car_detail.dart';
import '../../../core/services/location_service.dart';
import '../../../l10n/app_localizations.dart';
import 'widgets/location_picker_widget.dart';
import 'widgets/car_selector_widget.dart';
import 'service_request_draft.dart';

class ServiceRequestScreen extends StatefulWidget {
  final String serviceId;

  const ServiceRequestScreen({
    super.key,
    required this.serviceId,
  });

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  /// خريطة تحويل من معرّف الخدمة المستخدم في واجهة اختيار الخدمة
  /// إلى المعرّف الحقيقي المسجّل في جدول service_types بقاعدة البيانات.
  /// السببان مختلفان في التسمية (tires ≠ tire ، mechanic ≠ mechanical)
  /// وده اللي كان بيسبب خطأ foreign key عند الإرسال.
  static const Map<String, String> _serviceTypeIdMap = {
    'crane': 'crane',
    'tires': 'tire',
    'fuel': 'fuel',
    'battery': 'battery',
    'mechanic': 'mechanical',
  };

  /// يحلّ المعرّض المعروض (تسمية UI) إلى المعرّف الحقيقي المسجّل في جدول
  /// service_types. يعيد null إن كان المعرّف غير معروف حتى لا يُرسَل id مجهول
  /// يكسر قيد FK (السلوك القديم كان يمرّره كما هو صامتاً).
  String? _resolveServiceTypeId() {
    final real = _serviceTypeIdMap[widget.serviceId];
    if (real == null) {
      debugPrint('service_request: unknown service type "${widget.serviceId}"');
    }
    return real;
  }

  LatLng? _selectedLocation;
  CarDetail? _selectedCar;
  final _notesController = TextEditingController();

  /// خيارات العميل عند إنشاء الطلب:
  /// 1) إلغاء الطلب تلقائياً بعد 5 دقائق — مفعّل افتراضياً (يستطيع العميل تعطيله).
  /// 2) مشاركة رقم الهاتف مع المزوّد — معطّل افتراضياً (اختيار العميل).
  bool _autoCancel = true;

  /// حالة الإرسال: حفظ الطلب -> ضغط الصور -> رفع الصور
  bool _isSubmitting = false;
  String _submitStatusText = '';

  final List<XFile> _pickedImages = [];
  final ImagePicker _picker = ImagePicker();

  List<CarDetail> _userCars = [];
  bool _isLoadingCars = true;

  /// يبقى true حتى تكتمل تعبئة النموذج الأولية (السيارات + المسودة) فتُبنى
  /// الخريطة مرة واحدة بموقعها النهائي.
  bool _loadingExistingOrder = true;

  /// مسودة النموذج المحفوظة محلياً: تُستعاد عند إعادة فتح النموذج بعد انتهاء
  /// العملية، وتُمسح عند نجاح الإرسال أو عند الخروج اليدوي من الشاشة.
  static const Duration _draftSaveDebounce = Duration(milliseconds: 700);
  final ServiceRequestDraftStore _draftStore = ServiceRequestDraftStore();
  Timer? _draftSaveTimer;
  bool _restoringDraft = false;

  /// كل كتابات المسودة تُجرى بالترتيب عبر سلسلة واحدة — يمنع سباقاً بين حفظ
  /// معلّق والمسح عند الإرسال/الخروج (المسح ينتظر أي حفظ جارٍ ليسبقه).
  Future<void> _draftWrites = Future<void>.value();

  Future<void> _pickImage(ImageSource source) async {
    final l10n = AppLocalizations.of(context);
    try {
      if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        if (status.isPermanentlyDenied) {
          openAppSettings();
          return;
        }
        if (!status.isGranted) return;
      } else {
        if (Platform.isAndroid) {
          // محاولة طلب أذونات الصور لأندرويد 13+ أو التخزين للأقدم
          final photos = await Permission.photos.request();
          if (!photos.isGranted && !photos.isLimited) {
            final storage = await Permission.storage.request();
            if (!storage.isGranted && !storage.isLimited) {
              if (storage.isPermanentlyDenied) openAppSettings();
              return;
            }
          }
        } else {
          final photos = await Permission.photos.request();
          if (!photos.isGranted && !photos.isLimited) {
            if (photos.isPermanentlyDenied) openAppSettings();
            return;
          }
        }
      }

      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() {
          _pickedImages.add(image);
        });
        _scheduleDraftSave();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.errorWithDetail('$e') ?? 'حدث خطأ: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _pickedImages.removeAt(index);
    });
    _scheduleDraftSave();
  }

  void _showImagePickerOptions() {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n?.attachImages ?? 'إرفاق صور',
                style: TextStyle(
                  fontFamily: 'Zain',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPickerOption(
                    icon: Icons.camera_alt_rounded,
                    label: l10n?.camera ?? 'الكاميرا',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                    isDark: isDark,
                  ),
                  _buildPickerOption(
                    icon: Icons.photo_library_rounded,
                    label: l10n?.gallery ?? 'المعرض',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.orangePrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.orangePrimary, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _notesController.addListener(_onNotesChanged);
    _initForm();
    // بدء تحديد دقيق في الخلفية (pre-warm) ليكون جاهزاً عند ضغط «موقعي»
    LocationService.instance.prewarmRefinedPosition();
  }

  /// تسلسل آمن: تحميل السيارات أولاً، ثم تعبئة المسودة المحفوظة محلياً
  /// (آخر تعديلات المستخدم تتغلب على القيم الافتراضية).
  Future<void> _initForm() async {
    await _loadUserCars();
    await _applySavedDraft();
    // إنهاء «الحاوية المستقرة» بعد اكتمال كل التعبئة — تُبنى الخريطة مرة
    // واحدة بموقعها النهائي دون أن «تقفز».
    if (mounted) setState(() => _loadingExistingOrder = false);
  }

  void _onNotesChanged() {
    if (_restoringDraft) return;
    _scheduleDraftSave();
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    _notesController.removeListener(_onNotesChanged);
    // الخروج اليدوي من النموذج ينهي المسودة؛ أما موت العملية/النشاط فتبقى
    // المسودة على القرص لتُستعاد في الجلسة التالية.
    unawaited(_discardDraft());
    _notesController.dispose();
    super.dispose();
  }

  /// يجدّول حفظاً مؤجلاً بعد هدوء قصير من آخر تغيير — يمنع ضغط عمليات الكتابة
  /// على القرص مع كل حرف/نقرة.
  void _scheduleDraftSave() {
    if (_restoringDraft) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(_draftSaveDebounce, _saveDraft);
  }

  Future<void> _saveDraft() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final draft = ServiceRequestDraft(
      userId: userId,
      serviceId: widget.serviceId,
      serviceTypeId: _resolveServiceTypeId(),
      latitude: _selectedLocation?.latitude,
      longitude: _selectedLocation?.longitude,
      carId: _selectedCar?.id,
      carMake: _selectedCar?.make,
      carModel: _selectedCar?.model,
      carYear: _selectedCar?.year,
      notes: _notesController.text.trim(),
      autoCancel: _autoCancel,
      imagePaths: _pickedImages.map((img) => img.path).toList(),
      savedAt: DateTime.now(),
    );
    try {
      await _enqueueDraftWrite(() =>
          draft.hasContent ? _draftStore.save(draft) : _draftStore.clear());
    } catch (e) {
      debugPrint('save service request draft failed: $e');
    }
  }

  /// يمسح المسودة بعد استكمال أي حفظ جارٍ (يُستدعى عند الإرسال والخروج).
  Future<void> _discardDraft() async {
    _draftSaveTimer?.cancel();
    try {
      await _enqueueDraftWrite(_draftStore.clear);
    } catch (_) {
      // المسح فشل — تجاهل: لن تُستعاد مسودة حديثة إلا بعد فتح النموذج مجدداً.
    }
  }

  Future<void> _enqueueDraftWrite(Future<void> Function() write) {
    final operation = _draftWrites.then((_) => write());
    _draftWrites = operation.catchError((Object _) {});
    return operation;
  }

  /// يجلب السيارات الحقيقية المسجّلة لصاحب الحساب الحالي من جدول car_details
  Future<void> _loadUserCars() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoadingCars = false);
      return;
    }

    try {
      final response = await _client
          .from('car_details')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final cars = response
          .map<CarDetail>((json) => CarDetail(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        make: json['make'] as String? ?? '',
        model: json['model'] as String? ?? '',
        year: json['year'] as int? ?? 0,
        plateNumber: json['plate_number'] as String? ?? '',
        color: json['color'] as String? ?? '',
      ))
          .toList();

      if (mounted) {
        setState(() {
          _userCars = cars;
          _isLoadingCars = false;
          // لو فيه سيارة واحدة بس، اختارها تلقائيًا لتسهيل التجربة
          if (cars.length == 1) _selectedCar = cars.first;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCars = false);
      }
    }
  }

  /// يستعيد مسودة محفوظة محلياً وتطبقها على النموذج (إن كانت حديثة وتخصّ هذا
  /// المستخدم والمعرّف نفسه). مسودة قديمة أو لأخرى/لحساب آخر تُمسح ولا تُطبق.
  Future<void> _applySavedDraft() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final draft = await _draftStore.load();
      if (draft == null) return;

      final isFresh =
          DateTime.now().difference(draft.savedAt) < ServiceRequestDraft.stalenessWindow;
      if (!isFresh || draft.userId != userId || draft.serviceId != widget.serviceId) {
        await _discardDraft();
        return;
      }

      // الصور: نحتفظ فقط بالمسارات التي ما زالت تشير لملف قائم وقت الاستعادة.
      final validImagePaths =
          draft.imagePaths.where((path) => File(path).existsSync()).toList();

      _restoringDraft = true;
      setState(() {
        if (draft.latitude != null && draft.longitude != null) {
          _selectedLocation = LatLng(draft.latitude!, draft.longitude!);
        }
        _notesController.text = draft.notes;
        _autoCancel = draft.autoCancel;
        final car = _matchCar(draft);
        if (car != null) _selectedCar = car;
      });
      if (validImagePaths.isNotEmpty) {
        setState(() {
          _pickedImages
            ..clear()
            ..addAll(validImagePaths.map(XFile.new));
        });
      }
      _restoringDraft = false;
    } catch (e) {
      debugPrint('apply saved service request draft failed: $e');
    }
  }

  /// يطابق السيارة المحفوظة مع السيارات المسجّلة الحالية: بالمعرّف أولاً،
  /// ثم بالطراز/السنة (في حال حُذفت السيارة وأُعيدت إضافتها بمعرّف جديد).
  CarDetail? _matchCar(ServiceRequestDraft draft) {
    final carId = draft.carId;
    if (carId != null) {
      for (final car in _userCars) {
        if (car.id == carId) return car;
      }
    }
    if (draft.carMake != null) {
      for (final car in _userCars) {
        if (car.make == draft.carMake &&
            car.model == draft.carModel &&
            car.year == draft.carYear) {
          return car;
        }
      }
    }
    return null;
  }

  /// بوابة إرسال الطلب: يتأكد (بجلب طازج) أن العميل يملك رقماً قومياً صالحاً.
  /// عند النقص/الخطأ يعرض حواراً يوجّه للبيانات الشخصية عبر push() ليظل
  /// النموذج (والمسودة) حياً في المكدس، ثم يعيد الفحص بعد العودة.
  /// يعيد true للمتابعة، false عند الإلغاء أو تعذّر الفحص/الشبكة.
  Future<bool> _confirmNationalIdGate(String userId) async {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n?.localeName.startsWith('ar') ?? true;

    while (true) {
      String? nationalId;
      try {
        final row = await _client
            .from('profiles')
            .select('national_id')
            .eq('id', userId)
            .single();
        nationalId = row['national_id'] as String?;
      } catch (e) {
        debugPrint('national id gate fetch failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n?.connectionError ?? 'حدث خطأ في الاتصال، حاول مرة أخرى.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return false;
      }

      if (NationalIdUtils.isValid(nationalId)) return true;
      if (!mounted) return false;

      final go = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            l10n?.nationalIdRequiredToOrderTitle ??
                (isArabic ? 'الرقم القومي مطلوب' : 'National ID required'),
          ),
          content: Text(
            l10n?.needNationalIdFirst ??
                (isArabic
                    ? 'لإرسال طلب خدمة يجب إضافة رقمك القومي الصحيح أولاً في بياناتك الشخصية.'
                    : 'To submit a service request, add your valid national ID in your personal info first.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n?.cancel ?? (isArabic ? 'إلغاء' : 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n?.goToPersonalInfo ??
                  (isArabic ? 'الذهاب للبيانات الشخصية' : 'Go to personal info')),
            ),
          ],
        ),
      );

      if (go != true || !mounted) return false;

      // push() لا go(): النموذج الحالي ومسودته يبقيان في المكدس حتى تُحدَّث
      // البيانات ثم نعود، فيُعاد الفحص من جلب طازج.
      await context.push('/profile/edit');
    }
  }

  Future<void> _submitRequest() async {
    final l10n = AppLocalizations.of(context);

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.selectLocationOnMap ?? 'يرجى تحديد موقع السيارة على الخريطة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedCar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.noCarAdded ?? 'يرجى اختيار السيارة أولاً'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final realServiceTypeId = _resolveServiceTypeId();
    if (realServiceTypeId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.unknownServiceType ?? 'نوع الخدمة غير معروف، يرجى تحديث التطبيق'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // بوابة الرقم القومي: لا يُرسَل طلب خدمة إلا بوجود رقم قومي صالح لدى
    // العميل (فحص طازج). يُوجَّه المستخدم لبياناته الشخصية عند نقصه أو
    // عدم صحته — والرجوع يعيد الفحص حتى يلتزم الشرط أو يُلغى الإرسال.
    if (!await _confirmNationalIdGate(userId)) return;

    // لا يُنشأ أي صف في قاعدة البيانات هنا: يُحفظ النموذج كمسودة محلية فقط ثم
    // ننتقل لاختيار المزوّد. الطلب الحقيقي يُنشأ ذرّياً في شاشة تفاصيل المزوّد
    // لحظة التأكيد (RPC create_order_for_provider) — فإن أُغلق التطبيق الآن لا
    // يوجد أي طلب معلّق يتيم في قاعدة البيانات.
    setState(() {
      _isSubmitting = true;
      _submitStatusText = l10n?.preparingYourRequest ?? 'جاري تجهيز طلبك...';
    });

    try {
      // حفظ نهائي (يمرّ عبر سلسلة الكتابات فينتظر أي حفظ مؤجل جارٍ) لضمان
      // توفّر المسودة في شاشة المزوّد حتى لو انتقل المستخدم بسرعة.
      await _saveDraft();

      if (!mounted) return;

      setState(() => _isSubmitting = false);
      // push() بدلاً من go(): النموذج (ومسودته) يبقى في المكدس تحت شاشة
      // المزوّدين، فزرّ الرجوع يعيد لنموذج معبّأ بدل نموذج فارغ.
      context.push(
        '/request/providers?serviceId=$realServiceTypeId'
        '&lat=${_selectedLocation!.latitude}'
        '&lng=${_selectedLocation!.longitude}',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              RpcErrorTranslator.translate(e, AppLocalizations.of(context)),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          _buildMainContent(context, isDark, l10n),
          if (_isSubmitting) _buildSubmittingOverlay(context, isDark),
        ],
      ),
    );
  }

  String _resolveServiceTitle(AppLocalizations? l10n) {
    switch (widget.serviceId) {
      case 'crane':
        return l10n?.crane ?? 'ونش S.O.S';
      case 'tires':
        return l10n?.tire ?? 'خدمات الإطارات';
      case 'fuel':
        return l10n?.fuel ?? 'تزويد بنزين';
      case 'battery':
        return l10n?.battery ?? 'بطاريات / كهرباء';
      case 'mechanic':
        return l10n?.mechanical ?? 'ميكانيكي طوارئ';
      default:
        return l10n?.requestService ?? 'خدمة طوارئ';
    }
  }

  /// مؤشر تقدم واضح أثناء حفظ الطلب / ضغط الصور / الرفع.
  Widget _buildSubmittingOverlay(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: Colors.black54,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.orangePrimary),
                  const SizedBox(height: 20),
                  Text(
                    _submitStatusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n?.pleaseWaitDontClose ?? 'يرجى الانتظار، لا تغلق التطبيق',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
  );
}

  Widget _buildOrderOptions(BuildContext context, bool isDark, AppLocalizations? l10n) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              l10n?.additionalOptions ?? 'خيارات إضافية',
              style: TextStyle(
                fontFamily: 'Zain',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ),
          SwitchListTile(
            value: _autoCancel,
            onChanged: (val) {
              setState(() => _autoCancel = val);
              _scheduleDraftSave();
            },
            activeThumbColor: AppColors.orangePrimary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(
              l10n?.autoCancelTitle ?? 'إلغاء الطلب تلقائياً بعد 5 دقائق',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            subtitle: Text(
              l10n?.autoCancelSubtitle ??
                  'إذا لم يكتمل طلبك خلال 5 دقائق سيُلغى تلقائياً',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, bool isDark, AppLocalizations? l10n) {
    return Column(
      children: [
        AppBar(
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
            _resolveServiceTitle(l10n),
            style: TextStyle(
              fontFamily: 'Zain',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          centerTitle: true,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Location Picker
            Text(
              l10n?.faultLocation ?? 'موقع العطل',
              style: TextStyle(
                fontFamily: 'Zain',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _loadingExistingOrder
                // عند فحص وجود طلب معلّق نُبقِي على حاوية مستقلة حتى لا
                // «تقفز» الخريطة عند استبدال autoLocate — منع وميض غريب.
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.orangePrimary,
                        ),
                      ),
                    ),
                  )
                : LocationPickerWidget(
                    // الموقع المختار/المستعاد يُمرَّر كموقع أولي — يشمل طلباً
                    // معلّقاً أو مسودة مستعادة. لا يُفعَّل التحديد التلقائي إن
                    // كان الموقع محدداً مسبقاً حتى لا تُستبدل قيمتها بموقع الجهاز.
                    initialLocation: _selectedLocation,
                    autoLocate: _selectedLocation == null,
                    onLocationChanged: (latLng) {
                      setState(() => _selectedLocation = latLng);
                      _scheduleDraftSave();
                    },
                  ),
            const SizedBox(height: 24),

            // Car Selector - سيارات حقيقية من Supabase
            _isLoadingCars
                ? const Center(child: CircularProgressIndicator(color: AppColors.orangePrimary))
                : CarSelectorWidget(
              cars: _userCars,
              selectedCar: _selectedCar,
              onCarSelected: (car) {
                setState(() => _selectedCar = car);
                _scheduleDraftSave();
              },
            ),
            const SizedBox(height: 24),

            // Notes Field
            Text(
              l10n?.faultDescription ?? 'وصف العطل / ملاحظات',
              style: TextStyle(
                fontFamily: 'Zain',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: l10n?.faultHint ?? 'اكتب وصفاً مختصراً للعطل...',
                hintStyle: TextStyle(
                  fontFamily: 'Cairo',
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_a_photo_rounded, color: AppColors.orangePrimary),
                  onPressed: _showImagePickerOptions,
                  tooltip: l10n?.attachImages ?? 'إرفاق صور',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
              style: TextStyle(
                fontFamily: 'Cairo',
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Image Preview List
            if (_pickedImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pickedImages.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_pickedImages[index].path),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Additional options (customer's own choices)
            _buildOrderOptions(context, isDark, l10n),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orangePrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                  l10n?.sendRequest ?? 'إرسال الطلب',
                  style: TextStyle(
                    fontFamily: 'Zain',
                    fontSize: 20,
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
    ],
  );
}
}




