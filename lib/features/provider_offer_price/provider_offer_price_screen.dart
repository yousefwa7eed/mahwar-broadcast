import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/errors/rpc_error_translator.dart';
import '../../core/models/order.dart';
import '../../core/widgets/attachments_gallery.dart';
import '../../l10n/app_localizations.dart';

class ProviderOfferPriceScreen extends StatefulWidget {
  final String orderId;

  const ProviderOfferPriceScreen({super.key, required this.orderId});

  @override
  State<ProviderOfferPriceScreen> createState() => _ProviderOfferPriceScreenState();
}

class _ProviderOfferPriceScreenState extends State<ProviderOfferPriceScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  final _priceController = TextEditingController();
  final _timeController = TextEditingController();
  final _notesController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _providerImages = [];

  Order? _order;
  String _serviceName = '';
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

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
        final photos = await Permission.photos.request();
        if (!photos.isGranted && !photos.isLimited) {
          if (photos.isPermanentlyDenied) openAppSettings();
          return;
        }
      }

      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (image != null && mounted) {
        setState(() => _providerImages.add(image));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء اختيار الصورة: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() => _providerImages.removeAt(index));
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

  Future<void> _loadOrder() async {
    try {
      final response = await _client
          .from('orders')
          .select()
          .eq('id', widget.orderId)
          .single();

      final order = Order.fromJson(response);

      try {
        final st = await _client
            .from('service_types')
            .select('name_ar')
            .eq('id', order.serviceTypeId)
            .maybeSingle();
        _serviceName = st?['name_ar'] as String? ?? order.serviceTypeId;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _order = order;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'تعذّر تحميل بيانات الطلب: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// الطلب لم يعد في حالة "بانتظار عرض سعر" (أُلغي بانتهاء المهلة، أُكّد، أو اكتمل).
  /// يعرض رسالة ودية ويعيد المزوّد إلى لوحة التحكم بدلاً من خطأ خام بالإنكليزية.
  bool _handleOrderNotPending(Object error) {
    final message = error.toString();
    if (!message.contains('ORDER_NOT_PENDING') &&
        !message.contains('NOT_ASSIGNED')) {
      return false;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عذراً، هذا الطلب لم يعد متاحاً (ربما انتهت مدته)'),
          backgroundColor: AppColors.warning,
        ),
      );
      context.go('/home/provider');
    }
    return true;
  }

  Future<void> _submitOffer() async {
    if (_priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال السعر المقترح'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال سعر صحيح'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final eta = int.tryParse(_timeController.text.trim());

    setState(() => _isSubmitting = true);

    try {
      // رفع صور المزوّد إلى التخزين إن وُجدت قبل إرسال العرض
      final List<String> providerImageUrls = [];
      for (var i = 0; i < _providerImages.length; i++) {
        final image = _providerImages[i];
        final fileExt = image.path.split('.').last;
        final fileName = 'provider_${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt';
        final filePath = 'orders/${_order!.carOwnerId}/$fileName';

        await _client.storage.from('order-attachments').upload(
          filePath,
          File(image.path),
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
        providerImageUrls.add(
          _client.storage.from('order-attachments').getPublicUrl(filePath),
        );
      }

      await _client.rpc('provider_set_price', params: {
        'p_order_id': widget.orderId,
        'p_price': price,
        'p_notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'p_eta_minutes': eta,
        'p_attachments': providerImageUrls.isEmpty ? null : providerImageUrls,
      });

      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال عرض السعر بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/home/provider');
      }
    } catch (e) {
      if (mounted) {
        if (_handleOrderNotPending(e)) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(RpcErrorTranslator.translate(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectOrder() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'رفض الطلب',
          style: TextStyle(fontFamily: 'Zain'),
        ),
        content: const Text(
          'هل أنت متأكد من رفض هذا الطلب؟',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'رفض',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      await _client.rpc('provider_reject_order', params: {
        'p_order_id': widget.orderId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفض الطلب'),
            backgroundColor: AppColors.error,
          ),
        );
        context.go('/home/provider');
      }
    } catch (e) {
      if (mounted) {
        if (_handleOrderNotPending(e)) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(RpcErrorTranslator.translate(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          'تقديم عرض سعر',
          style: TextStyle(
            fontFamily: 'Zain',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orangePrimary))
          : _error != null
          ? _buildError(context, isDark)
          : _buildContent(context, isDark),
    );
  }

  Widget _buildError(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    final order = _order!;
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Info Card - بيانات حقيقية من قاعدة البيانات
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
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
                Row(
                  children: [
                    if (_serviceName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _serviceName,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      order.statusLabel,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.directions_car_rounded, size: 20, color: AppColors.orangePrimary),
                    const SizedBox(width: 8),
                    Text(
                      order.carDisplayName,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                if (order.notes != null && order.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    order.notes!,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
                if (order.attachments != null && order.attachments!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'صور من العميل',
                    style: TextStyle(
                      fontFamily: 'Zain',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.orangePrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AttachmentsGallery(urls: order.attachments!),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${l10n?.faultLocation ?? 'موقع العطل'}: ${order.latitude.toStringAsFixed(5)}, ${order.longitude.toStringAsFixed(5)}',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Price Input
          Text(
            'السعر المقترح (ج.م)',
            style: TextStyle(
              fontFamily: 'Zain',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'مثال: 350',
              hintStyle: TextStyle(
                fontFamily: 'Cairo',
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              prefixIcon: const Icon(Icons.attach_money_rounded, color: AppColors.orangePrimary),
              suffixText: 'ج.م',
              suffixStyle: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.orangePrimary,
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Time Input
          Text(
            'الوقت المتوقع للوصول (دقيقة)',
            style: TextStyle(
              fontFamily: 'Zain',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _timeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'مثال: 15',
              hintStyle: TextStyle(
                fontFamily: 'Cairo',
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              prefixIcon: const Icon(Icons.access_time_rounded, color: AppColors.orangePrimary),
              suffixText: 'دقيقة',
              suffixStyle: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.orangePrimary,
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Notes (optional)
          Text(
            'ملاحظات للمالك (اختياري)',
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
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'اكتب أي تفاصيل إضافية عن الخدمة...',
              hintStyle: TextStyle(
                fontFamily: 'Cairo',
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_a_photo_rounded, color: AppColors.orangePrimary),
                onPressed: _showImagePickerOptions,
                tooltip: (AppLocalizations.of(context)?.attachImages ?? 'إرفاق صور'),
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
          if (_providerImages.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'صور مرفقة منك (${_providerImages.length})',
              style: TextStyle(
                fontFamily: 'Zain',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _providerImages.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_providerImages[index].path),
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
                            child: const Icon(Icons.close, size: 16, color: Colors.white),
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
              onPressed: _isSubmitting ? null : _submitOffer,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'تقديم العرض',
                      style: TextStyle(
                        fontFamily: 'Zain',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Reject Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _isSubmitting ? null : _rejectOrder,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'رفض الطلب',
                style: TextStyle(
                  fontFamily: 'Zain',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}