import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/car_detail.dart';
import '../../../core/services/image_compression_service.dart';
import '../../../l10n/app_localizations.dart';
import 'widgets/location_picker_widget.dart';
import 'widgets/car_selector_widget.dart';

class ServiceRequestScreen extends StatefulWidget {
  final String serviceId;

  const ServiceRequestScreen({super.key, required this.serviceId});

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

  /// حالة الإرسال: حفظ الطلب -> ضغط الصور -> رفع الصور
  bool _isSubmitting = false;
  String _submitStatusText = '';

  final List<XFile> _pickedImages = [];
  final ImagePicker _picker = ImagePicker();

  static const ImageCompressionService _compressionService = ImageCompressionService();
  final OrderSubmitTimer _timer = OrderSubmitTimer();

  List<CarDetail> _userCars = [];
  bool _isLoadingCars = true;

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
    _loadUserCars();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
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
      })
          .select('id')
          .single();
      _timer.stop();

      final String realOrderId = inserted['id'] as String;

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

      if (!mounted) return;

      setState(() => _isSubmitting = false);
      // go() بدلاً من push(): بعد حفظ الطلب بنجاح نستبدل شاشة الطلب الحالية،
      // فلو رجّع المستخدم للخلف من شاشة المزوّدين يصل للرئيسية — لا لمُنسّاخ
      // من النموذج المعبّأ ما يسمح بإعادة الإرسال وإنشاء طلب مكرر.
      context.go(
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
            content: Text('حدث خطأ أثناء إرسال الطلب: $e'),
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
            LocationPickerWidget(
              autoLocate: true,
              onLocationChanged: (latLng) {
                setState(() => _selectedLocation = latLng);
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