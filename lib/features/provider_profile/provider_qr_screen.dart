import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/provider_details.dart';
import '../../l10n/app_localizations.dart';
import 'provider_deep_link.dart';

/// شاشة رمز QR الخاص بالمزوّد: الرمز يفتح ملفه العام عند المسح، ويمكن
/// مشاركة الصورة أو حفظها لطباعتها على واجهة المحل.
///
/// الرمز لا يمنح أي صلاحية (فتح الملف العام فقط)، فلا يحمل رمز دخول ولا
/// بيانات عميل. صورة المشاركة تُبنى من عنصر واجهة حقيقي (RepaintBoundary)
/// بنفس ما يراه المزوّد على الشاشة.
class ProviderQrScreen extends StatefulWidget {
  const ProviderQrScreen({super.key, required this.providerId});

  final String providerId;

  @override
  State<ProviderQrScreen> createState() => _ProviderQrScreenState();
}

class _ProviderQrScreenState extends State<ProviderQrScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  final GlobalKey _shareCardKey = GlobalKey(debugLabel: 'providerQrCard');

  String _workshopName = '';
  bool _isSharing = false;

  late final String _link = buildProviderProfileLink(widget.providerId);

  @override
  void initState() {
    super.initState();
    _loadWorkshopName();
  }

  /// اسم الورشة تجميلي فقط: فشل التحميل لا يمنع عرض الرمز أو مشاركته.
  Future<void> _loadWorkshopName() async {
    try {
      final rows = await _client.rpc(
        'get_provider_details',
        params: {'p_provider_id': widget.providerId},
      ) as List;
      if (rows.isEmpty || !mounted) return;
      final provider = ProviderDetails.fromJson(
        Map<String, dynamic>.from(rows.first as Map),
      );
      final name = provider.workshopName.isNotEmpty
          ? provider.workshopName
          : provider.fullName;
      if (mounted) setState(() => _workshopName = name);
    } catch (_) {
      // اسم تجميلي: نُبقي البطاقة بلا اسم بدل تعطيل الشاشة.
    }
  }

  Future<void> _share() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    final l10n = AppLocalizations.of(context);
    // نلتقط موضع الزر قبل أي انتظار (مطلوب لـ share sheet على iPad).
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      final border =
          _shareCardKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (border == null) throw StateError('qr card not ready');

      final image = await border.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('empty png');

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/mahwar_provider_qr_${widget.providerId}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: _link,
          subject: _workshopName.isEmpty ? null : _workshopName,
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.providerQrShareFailed ?? 'تعذّر مشاركة الصورة',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: primary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n?.providerQrTitle ?? 'رمز QR الخاص بي',
          style: TextStyle(
            fontFamily: 'Zain',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            children: [
              RepaintBoundary(
                key: _shareCardKey,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'محور',
                        style: TextStyle(
                          fontFamily: 'Zain',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.orangePrimary,
                        ),
                      ),
                      if (_workshopName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _workshopName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Zain',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      QrImageView(
                        data: _link,
                        version: QrVersions.auto,
                        size: 232,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l10n?.providerQrScanHint ??
                            'امسح الرمز لعرض ملف الورشة والتقييمات',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n?.providerQrBody ??
                    'اطبع هذا الرمز ليتمكن العملاء من فتح ملفك العام وتقييمك.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  height: 1.6,
                  color: secondary,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isSharing ? null : _share,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.ios_share_rounded),
                  label: Text(
                    l10n?.providerQrShare ?? 'مشاركة / حفظ الصورة',
                    style: const TextStyle(
                      fontFamily: 'Zain',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orangePrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
}
