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
import '../../../core/services/image_compression_service.dart';
import '../../../l10n/app_localizations.dart';
import 'widgets/location_picker_widget.dart';
import 'widgets/car_selector_widget.dart';
import 'service_request_draft.dart';

class ServiceRequestScreen extends StatefulWidget {
  final String serviceId;

  /// إن وُجد: يُفتح النموذج للتعديل على هذا الطلب المعلّق (يُحمَّل ويُعبّأ
  /// مسبقاً، والزر يُحدّث نفس الصف بدل إدراج صف جديد).
  final String? orderId;

  const ServiceRequestScreen({
    super.key,
    required this.serviceId,
    this.orderId,
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
  bool _sharePhone = false;

  /// حالة الإرسال: حفظ الطلب -> ضغط الصور -> رفع الصور
  bool _isSubmitting = false;
  String _submitStatusText = '';

  final List<XFile> _pickedImages = [];
  final ImagePicker _picker = ImagePicker();

  static const ImageCompressionService _compressionService = ImageCompressionService();
  final OrderSubmitTimer _timer = OrderSubmitTimer();

  List<CarDetail> _userCars = [];
  bool _isLoadingCars = true;

  /// طلب معلّق قائم لنفس المالك — إن وُجد يُعدَّل (تحديث) بدل إنشاء مكرر.
  _PendingOrderDraft? _existingOrder;
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
          SnackBar(content: Text('حدث خطأ: $e')),
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
  }

  /// تسلسل آمن: تحميل السيارات أولاً، ثم البحث عن طلب معلّق، ثم تعبئة
  /// النموذج منه حتى لا تتنافس العمليات غير المتزامنة على الحالة.
  Future<void> _initForm() async {
    await _loadUserCars();
    await _loadExistingPendingOrder();
    _applyExistingPrefill();
    // تعبئة المسودة المحفوظة بعد أساس بيانات الطلب المعلّق حتى تتغلب
    // تعديلات المستخدم الأخيرة (المسودة) على قيم التعبئة من الخادم.
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
      orderId: widget.orderId,
      latitude: _selectedLocation?.latitude,
      longitude: _selectedLocation?.longitude,
      carId: _selectedCar?.id,
      notes: _notesController.text.trim(),
      autoCancel: _autoCancel,
      sharePhone: _sharePhone,
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

  /// يفحص إن كان للمالك طلب معلّق (pending) قائم فيُعبّئ النموذج منه؛ لو ممرّر
  /// widget.orderId يفضّل الطلب المحدد، وإلا أحدث طلب pending للمالك.
  Future<void> _loadExistingPendingOrder() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      var query = _client
          .from('orders')
          .select(
        'id, service_type_id, latitude, longitude, notes, car_make, car_model, car_year, auto_cancel, share_phone, attachments',
      )
          .eq('car_owner_id', userId)
          .eq('status', 'pending');

      if (widget.orderId != null && widget.orderId!.isNotEmpty) {
        query = query.eq('id', widget.orderId!);
      }

      final row = await query.order('created_at', ascending: false).maybeSingle();
      if (row != null) {
        _existingOrder = _PendingOrderDraft.fromJson(Map<String, dynamic>.from(row));
      }
    } catch (e) {
      debugPrint('load existing pending order failed: $e');
    }
    // لا يُقلَب مؤشر _loadingExistingOrder هنا — يقلبه _initForm بعد اكتمال
    // كل التعبئة (بما فيها استعادة المسودة) كي تُبنى الخريطة مرة واحدة فقط.
  }

  /// يجد معرّف طلب pending قائم لحظة الإرسال (جلب طازج) — null إن لا يوجد.
  Future<String?> _findExistingPendingOrderId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final row = await _client
          .from('orders')
          .select('id')
          .eq('car_owner_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .maybeSingle();
      return row?['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// تعبئة النموذج من بيانات الطلب المعلّق: الموقع، الملاحظات، التفضيلات،
  /// ومطابقة السيارة (إن وُجدت في السيارات المسجّلة).
  void _applyExistingPrefill() {
    final draft = _existingOrder;
    if (draft == null || !mounted) return;
    setState(() {
      _selectedLocation = LatLng(draft.latitude, draft.longitude);
      _notesController.text = draft.notes;
      _autoCancel = draft.autoCancel;
      _sharePhone = draft.sharePhone;
      final match = _userCars
          .where((c) =>
      c.make == draft.carMake &&
          c.model == draft.carModel &&
          c.year == draft.carYear)
          .toList();
      if (match.isNotEmpty) _selectedCar = match.first;
    });
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
      final mismatchesOrder =
          draft.orderId != null && widget.orderId != null && draft.orderId != widget.orderId;
      if (!isFresh || draft.userId != userId || draft.serviceId != widget.serviceId || mismatchesOrder) {
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
        _sharePhone = draft.sharePhone;
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

  /// يطابق السيارة المحفوظة (بالمعرّف) مع السيارات المسجّلة الحالية.
  CarDetail? _matchCar(ServiceRequestDraft draft) {
    final carId = draft.carId;
    if (carId == null) return null;
    for (final car in _userCars) {
      if (car.id == carId) return car;
    }
    return null;
  }

  /// بارامترات مشتركة بين RPC التحديث والإدراج — تجنّب تكرار منطق الحقول.
  Map<String, dynamic> _orderPayload(String orderId, String ownerPhone, String serviceTypeId) {
    return {
      'p_order_id': orderId,
      'p_service_type_id': serviceTypeId,
      'p_car_make': _selectedCar!.make,
      'p_car_model': _selectedCar!.model,
      'p_car_year': _selectedCar!.year,
      'p_latitude': _selectedLocation!.latitude,
      'p_longitude': _selectedLocation!.longitude,
      'p_notes': _notesController.text.trim(),
      'p_owner_phone': ownerPhone,
      'p_auto_cancel': _autoCancel,
      'p_share_phone': _sharePhone,
    };
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
            const SnackBar(
              content: Text('حدث خطأ في الاتصال، حاول مرة أخرى.'),
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
            l10n?.nationalIdRequiredToOrderBody ??
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
          const SnackBar(
            content: Text('نوع الخدمة غير معروف، يرجى تحديث التطبيق'),
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

    setState(() {
      _isSubmitting = true;
      _submitStatusText = 'جاري حفظ طلبك...';
    });
    _timer.start('saving order');

    try {
      // 1) حفظ الطلب فوراً في قاعدة البيانات (بدون الصور) — استجابة سريعة
      //    حتى لو تبقى ضغط/رفع الصور جارياً.
      final profile = await _client
          .from('profiles')
          .select('phone_number')
          .eq('id', userId)
          .single();
      final String ownerPhone = profile['phone_number'] as String? ?? '';

      // 1) حفظ الطلب فوراً: إن كان المالك يملك طلباً معلّقاً قائماً نُحدّثه في
      //    مكانه (ويمرّر نفس معرّفه لشاشة المزوّدين)، وإلا نُدرج طلباً جديداً.
      //    لا تنشأ طلبات معلّقة مكررة أبداً — ويمتد ذلك لقاعدة البيانات عبر
      //    فهرس جزئي فريد يرفض الإدراج المكرر (خطأ 23505).
      final existingOrderId = await _findExistingPendingOrderId();

      String realOrderId;
      if (existingOrderId != null) {
        _timer.start('updating pending order');
        await _client.rpc(
          'update_pending_order',
          params: _orderPayload(existingOrderId, ownerPhone, realServiceTypeId),
        );
        _timer.stop();
        realOrderId = existingOrderId;
      } else {
        try {
          final inserted = await _client
              .from('orders')
              .insert({
            'car_owner_id': userId,
            'service_type_id': realServiceTypeId,
            'car_make': _selectedCar!.make,
            'car_model': _selectedCar!.model,
            'car_year': _selectedCar!.year,
            'latitude': _selectedLocation!.latitude,
            'longitude': _selectedLocation!.longitude,
            'notes': _notesController.text.trim(),
            'status': 'pending',
            'owner_phone': ownerPhone,
            'auto_cancel': _autoCancel,
            'share_phone': _sharePhone,
          })
              .select('id')
              .single();
        _timer.stop();

        realOrderId = inserted['id'] as String;
        } on PostgrestException catch (e) {
          // سباق: طلب pending أُنشئ لحظياً بين فحصنا والإدراج، ورفضه الفهرس
          // الفريد. نتخذ الطلب القائم بسلاسة: جلب ثم تحديثه بنفس الحقول.
          if (e.code != '23505') rethrow;
          final racedOrderId = await _findExistingPendingOrderId();
          if (racedOrderId == null) rethrow;
          await _client.rpc(
            'update_pending_order',
            params: _orderPayload(racedOrderId, ownerPhone, realServiceTypeId),
          );
          _timer.stop();
          realOrderId = racedOrderId;
        }
      }

      // 2) ضغط الصور (بالموازاة) ثم رفعها وربطها بالطلب
      if (_pickedImages.isNotEmpty) {
        if (mounted) {
setState(() {
          _submitStatusText = 'جاري تحسين الصور...';
        });
        }
        _timer.start('compressing images');

        final compressed =
            await Future.wait(_pickedImages.map((img) => _compressionService.compress(File(img.path))));
        _timer.stop();

        final List<String> imageUrls = [];
        try {
          for (var i = 0; i < compressed.length; i++) {
            if (mounted) {
              setState(() {
                _submitStatusText = 'جاري رفع الصور (${i + 1}/${compressed.length})';
              });
            }
            _timer.start('uploading image ${i + 1}');

            final fileExt = compressed[i].path.split('.').last;
            final fileName =
                '${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt';
            final filePath = 'orders/$userId/$fileName';

            await _client.storage.from('order-attachments').upload(
              filePath,
              compressed[i],
              fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
            );

            imageUrls.add(
              _client.storage.from('order-attachments').getPublicUrl(filePath),
            );
            _timer.stop();
          }

          // 3) ربط الصور بالطلب عبر RPC آمن (RSL يمنع UPDATE مباشر)
          if (imageUrls.isNotEmpty) {
            if (mounted) {
              setState(() {
                _submitStatusText = 'جاري إنهاء الطلب...';
              });
            }
            _timer.start('saving attachments');
            await _client.rpc('set_order_attachments', params: {
              'p_order_id': realOrderId,
              'p_attachments': imageUrls,
            });
            _timer.stop();
          }
        } catch (uploadError) {
          // لا نفشل الطلب بالكامل: الطلب محفوظ، الصور فقط لم تكتمل.
          debugPrint('[OrderSubmit] رفع صور فشل (الطلب محفوظ بدون صور): $uploadError');
          _timer.stop();
        }
      }

      _timer.report();

      // الطلب حُفظ بنجاح: تُمسح المسودة المحلية نهائياً حتى تُفتح النماذج
      // التالية فارغة (المسح ينتظر أي حفظ جارٍ — لا سباق).
      await _discardDraft();

      if (!mounted) return;

      setState(() => _isSubmitting = false);
      // push() بدلاً من go(): النموذج يبقى في المكدس تحت شاشة المزوّدين،
      // فزرّ الرجوع (السهم/زر النظام) يعيد للمستخدم نموذجاً معبّأً بنفس
      // بيانات الطلب المحفوظ، لا لمُنسّاخ جديد — والتعديل اللاحق يحدّث نفس
      // الطلب المعلّق بدل إنشاء مكرر (مع حماية DB أيضاً).
      context.push(
        '/request/providers?orderId=$realOrderId'
        '&serviceId=$realServiceTypeId'
        '&lat=${_selectedLocation!.latitude}'
        '&lng=${_selectedLocation!.longitude}',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              RpcErrorTranslator.translate(e),
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
                    'يرجى الانتظار، لا تغلق التطبيق',
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
              'خيارات إضافية',
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
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          SwitchListTile(
            value: _sharePhone,
            onChanged: (val) {
              setState(() => _sharePhone = val);
              _scheduleDraftSave();
            },
            activeThumbColor: AppColors.orangePrimary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(
              l10n?.sharePhoneTitle ?? 'مشاركة رقم هاتفي مع المزوّد',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            subtitle: Text(
              l10n?.sharePhoneSubtitle ??
                  'سيتيح للمزوّد رؤية رقمك والاتصال بك مباشرة',
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

/// نسخة مصغّرة من طلب المالك المعلّق — تُستخدم لتعبئة النموذج مسبقاً
/// ولتمرير نفس المعرّف عند التحديث بدل إنشاء طلب معلّق مكرر.
class _PendingOrderDraft {
  const _PendingOrderDraft({
    required this.id,
    required this.serviceTypeId,
    required this.latitude,
    required this.longitude,
    required this.carMake,
    required this.carModel,
    required this.carYear,
    this.notes = '',
    this.autoCancel = true,
    this.sharePhone = false,
    this.attachments = const [],
  });

  final String id;
  final String serviceTypeId;
  final double latitude;
  final double longitude;
  final String carMake;
  final String carModel;
  final int carYear;
  final String notes;
  final bool autoCancel;
  final bool sharePhone;

  /// روابط صور الطلب الحالية — تُبقى كما هي عند التعديل دون إعادة رفعها.
  final List<String> attachments;

  factory _PendingOrderDraft.fromJson(Map<String, dynamic> json) {
    final attachmentsRaw = json['attachments'];
    return _PendingOrderDraft(
      id: json['id'] as String,
      serviceTypeId: json['service_type_id'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      carMake: json['car_make'] as String? ?? '',
      carModel: json['car_model'] as String? ?? '',
      carYear: json['car_year'] as int? ?? 0,
      notes: json['notes'] as String? ?? '',
      autoCancel: json['auto_cancel'] as bool? ?? true,
      sharePhone: json['share_phone'] as bool? ?? false,
      attachments: (attachmentsRaw is List) ? attachmentsRaw.cast<String>() : const [],
    );
  }
}
