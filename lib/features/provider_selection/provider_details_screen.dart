import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/avatar_config.dart';
import '../../core/errors/rpc_error_translator.dart';
import '../../core/models/provider_details.dart';
import '../../core/services/image_compression_service.dart';
import '../../core/services/sound_effects_service.dart';
import '../../features/service_request/service_request_draft.dart';
import '../../l10n/app_localizations.dart';
import 'order_rpc_params.dart';

class ProviderDetailsScreen extends StatefulWidget {
  final String providerId;

  const ProviderDetailsScreen({
    super.key,
    required this.providerId,
  });

  @override
  State<ProviderDetailsScreen> createState() => _ProviderDetailsScreenState();
}

class _ProviderDetailsScreenState extends State<ProviderDetailsScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  final ServiceRequestDraftStore _draftStore = ServiceRequestDraftStore();
  static const ImageCompressionService _compressionService = ImageCompressionService();

  ProviderDetails? _provider;
  Map<String, String> _serviceNames = {};
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await _client.rpc('get_provider_details', params: {
        'p_provider_id': widget.providerId,
      });

      final rows = response as List;
      if (rows.isEmpty) {
        if (mounted) {
          setState(() => _error =
              AppLocalizations.of(context)?.providerDataUnavailable ??
                  'بيانات المزوّد غير متاحة');
        }
        return;
      }

      final provider = ProviderDetails.fromJson(
        Map<String, dynamic>.from(rows.first as Map),
      );

      final services = await _client.from('service_types').select('id, name_ar');
      final serviceNames = {
        for (final row in services) row['id'] as String: row['name_ar'] as String? ?? row['id'] as String,
      };

      if (mounted) {
        setState(() {
          _provider = provider;
          _serviceNames = serviceNames;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _error = l10n?.providerLoadFailed(e.toString()) ??
              'تعذّر تحميل بيانات المزوّد: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendRequest() async {
    if (_isSending) return;
    final l10n = AppLocalizations.of(context);

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      _showError(l10n?.mustLoginToSend ?? 'يجب تسجيل الدخول لإرسال الطلب');
      return;
    }

    // النموذج لم يعد في المكدس، فمصدر البيانات هو المسودة المحفوظة.
    final draft = await _draftStore.load();
    final missingDraft = draft == null ||
        draft.userId != userId ||
        draft.serviceTypeId == null ||
        draft.latitude == null ||
        draft.longitude == null ||
        draft.carMake == null;
    if (missingDraft) {
      _showError(l10n?.requestDataNotFound ??
          'تعذّر العثور على بيانات الطلب، يرجى إعادة إدخاله من جديد');
      return;
    }

    setState(() => _isSending = true);

    // مسارات الصور المرفوعة — تُحذف عند فشل الطلب كي لا تبقى ملفات يتيمة.
    final uploadedPaths = <String>[];
    try {
      // ضغط ورفع الصور لحظة الإرسال فقط (لا نرفع شيئاً إن لم يُرسَل الطلب).
      final imageUrls = <String>[];
      final validPaths =
          draft.imagePaths.where((path) => File(path).existsSync()).toList();
      for (var i = 0; i < validPaths.length; i++) {
        final compressed = await _compressionService.compress(File(validPaths[i]));
        final fileExt = compressed.path.split('.').last;
        final filePath =
            'orders/$userId/${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt';
        await _client.storage.from('order-attachments').upload(
              filePath,
              compressed,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
            );
        uploadedPaths.add(filePath);
        imageUrls.add(
          _client.storage.from('order-attachments').getPublicUrl(filePath),
        );
      }

      // إنشاء الطلب ذرّياً مع المزوّد المختار (SECURITY DEFINER): صف واحد
      // يكتمل بـ provider_id وrespond_deadline وإشعار المزوّد. تُرسل معاملات
      // p_owner_phone/p_share_phone الإلزامية كـ null/false — القاعدة تُصفّر
      // الهاتف عبر trg_orders_force_null_phone.
      final newOrderId = await _client.rpc(
        'create_order_for_provider',
        params: buildCreateOrderForProviderParams(
          providerId: widget.providerId,
          serviceTypeId: draft.serviceTypeId,
          carMake: draft.carMake,
          carModel: draft.carModel,
          carYear: draft.carYear,
          latitude: draft.latitude,
          longitude: draft.longitude,
          notes: draft.notes,
          autoCancel: draft.autoCancel,
          attachments: imageUrls.isEmpty ? null : imageUrls,
        ),
      ) as String;

      await _draftStore.clear();

      unawaited(SoundEffectsService.instance.play(SoundEffect.requestSent));
      if (!mounted) return;
      setState(() => _isSending = false);
      // الانتقال إلى شاشة التتبّع عبر push — يحفظ المكدّس (قائمة المزوّدين
      // والنموذج) فيبقى زر الرجوع يعمل.
      context.push('/request/track?orderId=$newOrderId');
    } catch (e) {
      // تراجع عن الصور: لا نترك ملفات يتيمة عند فشل إنشاء الطلب.
      for (final path in uploadedPaths) {
        try {
          await _client.storage.from('order-attachments').remove([path]);
        } catch (cleanupError) {
          debugPrint('attachment cleanup failed: $cleanupError');
        }
      }
      if (mounted) {
        setState(() => _isSending = false);
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(RpcErrorTranslator.translate(e, l10n)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _callProvider() async {
    final phone = _provider?.phoneNumber;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              AppLocalizations.of(context)?.phoneUnavailable ??
                  'رقم الهاتف غير متاح'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              AppLocalizations.of(context)?.cannotCallNumber ??
                  'لا يمكن الاتصال بهذا الرقم'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

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
          l10n?.providerDetailsTitle ?? 'بيانات المزوّد',
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
    final p = _provider!;
    final l10n = AppLocalizations.of(context);

    final serviceLabels = p.services.map((s) => _serviceNames[s] ?? s).toList();

return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  AvatarWidget(
                    avatarId: p.avatarId,
                    role: 'provider',
                    size: 80,
                    photoUrl: p.avatarUrl,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    p.workshopName.isNotEmpty ? p.workshopName : p.fullName,
                    style: TextStyle(
                      fontFamily: 'Zain',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                if (p.fullName.isNotEmpty && p.workshopName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    p.fullName,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      p.ratingLabel(l10n),
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (serviceLabels.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: serviceLabels
                        .map((s) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.orangePrimary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                s,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.orangePrimary,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildInfoRow(
            isDark,
            icon: Icons.phone_rounded,
            label: p.phoneNumber.isNotEmpty ? p.phoneNumber : '—',
            onCopyTap: p.phoneNumber.isNotEmpty ? _callProvider : null,
          ),
          const SizedBox(height: 10),
          if (p.address.isNotEmpty)
            _buildInfoRow(isDark, icon: Icons.place_outlined, label: p.address),
          const SizedBox(height: 10),
          _buildInfoRow(
              isDark,
              icon: Icons.support_agent_rounded,
              label: p.supportScopeLabel(l10n)),
          const SizedBox(height: 10),
          _buildInfoRow(
            isDark,
            icon: Icons.car_repair,
            label: p.hasVehicle
                ? (p.vehicleType ?? (l10n?.hasServiceVehicle ?? 'لديه سيارة خدمة'))
                : (l10n?.noServiceVehicle ?? 'بدون سيارة خدمة'),
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            isDark,
            icon: Icons.circle,
            iconColor: p.isOnline ? AppColors.success : AppColors.error,
            label: p.isOnline
                ? (l10n?.availableNow ?? 'متاح الآن')
                : (l10n?.availabilityOfflineTitle ?? 'غير متاح حالياً'),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendRequest,
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                l10n?.sendRequestToProvider ?? 'إرسال الطلب لهذا المزوّد',
                style: TextStyle(
                  fontFamily: 'Zain',
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orangePrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _callProvider,
              icon: const Icon(Icons.phone_rounded, size: 18),
              label: Text(
                l10n?.call ?? 'اتصال مباشر',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.success),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    bool isDark, {
    required IconData icon,
    required String label,
    Color? iconColor,
    VoidCallback? onCopyTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor ?? AppColors.orangePrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ),
          if (onCopyTap != null)
            GestureDetector(
              onTap: onCopyTap,
              child: const Icon(Icons.call_rounded, size: 18, color: AppColors.success),
            ),
        ],
      ),
    );
  }
}
