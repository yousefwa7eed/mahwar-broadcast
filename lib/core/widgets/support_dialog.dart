import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../auth/profile_cubit.dart';
import '../constants/app_colors.dart';
import '../errors/rpc_error_translator.dart';
import 'support_ticket_params.dart';

/// تعرض نافذة الدعم الفني والشكاوى والاقتراحات ذات تصميم محاكاة ظرف الرسالة.
/// الإرسال يتم داخل التطبيق عبر `submit_support_ticket` (صندوق تذاكر)، والمستخدم
/// المسجّل يتابع ردود الإدارة من «تذاكراتي». تفرّق تلقائياً بين الحساب الموثق
/// (المسجّل) وتمنحه شارة أولوية قصوى، وبين الزائر الذي يرسل بدون مرفقات.
Future<void> showSupportDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const SupportDialog(),
  );
}

class SupportDialog extends StatefulWidget {
  const SupportDialog({super.key});

  @override
  State<SupportDialog> createState() => _SupportDialogState();
}

enum SupportMessageType {
  complaint('complaint'),
  suggestion('suggestion'),
  inquiry('inquiry');

  const SupportMessageType(this.dbValue);

  final String dbValue;
}

/// خطأ محلي أثناء رفع المرفق (قبل الوصول للـ RPC) برسالة جاهزة للعرض.
class _SupportUploadException implements Exception {
  const _SupportUploadException(this.message);

  final String message;
}

class _SupportDialogState extends State<SupportDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _subjectController;
  late TextEditingController _detailsController;

  SupportMessageType _type = SupportMessageType.complaint;
  String? _selectedCategory;
  XFile? _attachedImage;
  bool _isSending = false;
  bool _isLoggedInUser = false;
  bool _contactLocked = false;

  bool _showTickets = false;
  bool _ticketsLoading = false;
  bool _ticketsLoaded = false;
  String? _ticketsError;
  List<Map<String, dynamic>> _tickets = const [];
  String? _sentTicketId;
  String? _errorText;

  final ImagePicker _picker = ImagePicker();

  static const Map<String, String> _attachmentMimeByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'heif': 'image/heif',
  };

  static const Map<SupportMessageType, List<String>> _categoryOptionsAr = {
    SupportMessageType.complaint: [
      'مظهر أو تصميم التطبيق',
      'طلب أو حجز خدمة',
      'الحساب وتسجيل الدخول',
      'أخرى',
    ],
    SupportMessageType.suggestion: [
      'إضافة ميزة جديدة',
      'تحسين صفحة معينة',
      'طرق الدفع والأسعار',
      'فكرة أخرى',
    ],
    SupportMessageType.inquiry: [
      'كيف يعمل التطبيق؟',
      'سياسة الخصوصية والبيانات',
      'التواصل مع المزوّدين',
      'استفسار عام',
    ],
  };

  static const Map<SupportMessageType, List<String>> _categoryOptionsEn = {
    SupportMessageType.complaint: [
      'UI / App Appearance',
      'Order / Service Booking',
      'Account / Login Issue',
      'Other',
    ],
    SupportMessageType.suggestion: [
      'New Feature Idea',
      'Page UX Improvement',
      'Pricing / Payments',
      'Other Idea',
    ],
    SupportMessageType.inquiry: [
      'How App Works',
      'Privacy Policy & Data',
      'Provider Contact',
      'General Inquiry',
    ],
  };

  @override
  void initState() {
    super.initState();
    String initialName = '';
    String initialPhone = '';

    _isLoggedInUser = Supabase.instance.client.auth.currentUser != null;
    final profileState = context.read<ProfileCubit>().state;
    if (profileState is ProfileLoaded) {
      initialName = profileState.profile.fullName;
      initialPhone = profileState.profile.phoneNumber ?? '';
    }
    _contactLocked = _isLoggedInUser && initialName.isNotEmpty;

    _nameController = TextEditingController(text: initialName);
    _phoneController = TextEditingController(text: initialPhone);
    _subjectController = TextEditingController();
    _detailsController = TextEditingController();

    _selectedCategory = _categoryOptionsAr[SupportMessageType.complaint]!.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _subjectController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  void _onTypeChanged(SupportMessageType type, bool isArabic) {
    setState(() {
      _type = type;
      final options = isArabic ? _categoryOptionsAr[type] : _categoryOptionsEn[type];
      _selectedCategory = options?.first;
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() => _attachedImage = image);
      }
    } catch (e) {
      // Ignore picker errors or permissions denied
    }
  }

  String _typeLabel(bool isArabic) {
    switch (_type) {
      case SupportMessageType.complaint:
        return isArabic ? 'شكوى' : 'Complaint';
      case SupportMessageType.suggestion:
        return isArabic ? 'اقتراح' : 'Suggestion';
      case SupportMessageType.inquiry:
        return isArabic ? 'دعم واستفسار' : 'Inquiry / Support';
    }
  }

  String _extensionOf(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  Future<String> _uploadAttachment(
    SupabaseClient client,
    String uid,
    AppLocalizations? l10n,
  ) async {
    final file = File(_attachedImage!.path);
    final length = await file.length();
    if (length > supportAttachmentMaxBytes) {
      throw _SupportUploadException(
        l10n?.supportAttachmentTooLarge ?? 'حجم الصورة أكبر من 10 ميجابايت.',
      );
    }

    final ext = _extensionOf(_attachedImage!.path);
    final mime = _attachmentMimeByExtension[ext];
    if (mime == null) {
      throw _SupportUploadException(
        l10n?.supportAttachmentUnsupported ??
            'صيغة الصورة غير مدعومة. استخدم JPG أو PNG أو WebP.',
      );
    }

    final path = 'support/$uid/support_${DateTime.now().millisecondsSinceEpoch}.$ext';
    try {
      await client.storage.from('support-attachments').upload(
        path,
        file,
        fileOptions: FileOptions(
          contentType: mime,
          cacheControl: '3600',
          upsert: false,
        ),
      );
    } catch (_) {
      throw _SupportUploadException(
        l10n?.supportAttachmentUploadFailed ??
            'تعذّر رفع الصورة المرفقة. جرّب صورة أخرى أو أرسل بدون مرفق.',
      );
    }
    return path;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    final l10n = AppLocalizations.of(context);

    setState(() {
      _isSending = true;
      _errorText = null;
    });

    try {
      String? attachmentPath;
      // المرفق للمسجل فقط (مسار support/<uid>/...)؛ الزائر يرسل بدون مرفق.
      if (_attachedImage != null && uid != null) {
        attachmentPath = await _uploadAttachment(client, uid, l10n);
      }

      final id = await client.rpc(
        'submit_support_ticket',
        params: buildSubmitSupportTicketParams(
          kind: _type.dbValue,
          category: _selectedCategory,
          subject: _subjectController.text.trim(),
          body: _detailsController.text.trim(),
          contactName: _contactLocked ? null : _nameController.text.trim(),
          contactPhone: _contactLocked ? null : _phoneController.text.trim(),
          attachmentPath: attachmentPath,
        ),
      );

      if (!mounted) return;
      setState(() {
        _sentTicketId = id?.toString();
        _subjectController.clear();
        _detailsController.clear();
        _attachedImage = null;
        _isSending = false;
        _ticketsLoaded = false;
      });
    } on _SupportUploadException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorText = e.message;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorText = RpcErrorTranslator.translate(e, l10n);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorText = l10n?.rpcErrorGeneric ?? 'حدث خطأ في الاتصال، حاول مرة أخرى.';
      });
    }
  }

  void _openTickets() {
    setState(() => _showTickets = true);
    if (!_ticketsLoaded) _loadTickets();
  }

  Future<void> _loadTickets() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _ticketsLoading = true;
      _ticketsError = null;
    });

    try {
      final rows = await Supabase.instance.client.rpc(
        'get_my_support_tickets',
        params: buildMySupportTicketsParams(),
      );
      if (!mounted) return;
      setState(() {
        _tickets = (rows as List<dynamic>)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
        _ticketsLoading = false;
        _ticketsLoaded = true;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _ticketsLoading = false;
        _ticketsError = RpcErrorTranslator.translate(e, l10n);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ticketsLoading = false;
        _ticketsError = l10n?.supportTicketsLoadFailed ?? 'تعذّر تحميل رسائلك السابقة';
      });
    }
  }

  String _formatDateTime(Object? raw) {
    final dt = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _kindLabel(String kind, bool isArabic) {
    switch (kind) {
      case 'suggestion':
        return isArabic ? 'اقتراح' : 'Suggestion';
      case 'inquiry':
        return isArabic ? 'استفسار' : 'Inquiry';
      default:
        return isArabic ? 'شكوى' : 'Complaint';
    }
  }

  String _statusLabel(String status, AppLocalizations? l10n) {
    switch (status) {
      case 'replied':
        return l10n?.supportStatusReplied ?? 'تم الرد';
      case 'closed':
        return l10n?.supportStatusClosed ?? 'مغلقة';
      default:
        return l10n?.supportStatusOpen ?? 'قيد المراجعة';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'replied':
        return AppColors.success;
      case 'closed':
        return AppColors.lightTextSecondary;
      default:
        return AppColors.orangePrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark, isArabic, l10n),
              const SizedBox(height: 16),
              if (_isLoggedInUser) ...[
                _buildViewTabs(isDark, isArabic, l10n),
                const SizedBox(height: 16),
              ],
              if (_showTickets && _isLoggedInUser)
                _buildTickets(isDark, isArabic, l10n)
              else if (_sentTicketId != null)
                _buildSuccess(isDark, isArabic, l10n)
              else
                _buildComposer(isDark, isArabic, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool isArabic, AppLocalizations? l10n) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.orangePrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.headset_mic_rounded,
            color: AppColors.orangePrimary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      isArabic ? 'الدعم والشكاوى والاقتراحات' : 'Support & Complaints',
                      style: TextStyle(
                        fontFamily: isArabic ? 'Zain' : 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  if (_isLoggedInUser) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        isArabic ? 'حساب موثق ⚡' : 'Verified ⚡',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                l10n?.supportInboxSubtitle ??
                    'رسالتك تصل لفريق الدعم داخل التطبيق، وتقدر تتابع الرد من «تذاكراتي».',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  height: 1.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildViewTabs(bool isDark, bool isArabic, AppLocalizations? l10n) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          _buildViewTab(
            label: l10n?.supportNewMessage ?? 'رسالة جديدة',
            selected: !_showTickets,
            isDark: isDark,
            isArabic: isArabic,
            onTap: () => setState(() => _showTickets = false),
          ),
          const SizedBox(width: 4),
          _buildViewTab(
            label: l10n?.supportMyTickets ?? 'تذاكراتي',
            selected: _showTickets,
            isDark: isDark,
            isArabic: isArabic,
            onTap: _openTickets,
          ),
        ],
      ),
    );
  }

  Widget _buildViewTab({
    required String label,
    required bool selected,
    required bool isDark,
    required bool isArabic,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.orangePrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: isArabic ? 'Cairo' : 'Poppins',
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.w600,
              color: selected
                  ? Colors.white
                  : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(bool isDark, bool isArabic, AppLocalizations? l10n) {
    final categoryOptions = isArabic ? _categoryOptionsAr[_type]! : _categoryOptionsEn[_type]!;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Section Selector (Complaint, Suggestion, Inquiry)
          Row(
            children: [
              _buildSectionTab(
                type: SupportMessageType.complaint,
                label: isArabic ? 'تقديم شكوى' : 'Complaint',
                outlinedIcon: Icons.report_problem_outlined,
                filledIcon: Icons.report_problem_rounded,
                isDark: isDark,
                isArabic: isArabic,
              ),
              const SizedBox(width: 8),
              _buildSectionTab(
                type: SupportMessageType.suggestion,
                label: isArabic ? 'اقتراح فكرة' : 'Suggestion',
                outlinedIcon: Icons.lightbulb_outline_rounded,
                filledIcon: Icons.lightbulb_rounded,
                isDark: isDark,
                isArabic: isArabic,
              ),
              const SizedBox(width: 8),
              _buildSectionTab(
                type: SupportMessageType.inquiry,
                label: isArabic ? 'دعم واستفسار' : 'Inquiry',
                outlinedIcon: Icons.help_outline_rounded,
                filledIcon: Icons.help_rounded,
                isDark: isDark,
                isArabic: isArabic,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Helper Sub-categories (ChoiceChips)
          Text(
            isArabic ? 'اختر التقييم/التصنيف المساعد:' : 'Select helper topic:',
            style: TextStyle(
              fontFamily: isArabic ? 'Cairo' : 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categoryOptions.map((cat) {
              final selected = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(
                  cat,
                  style: TextStyle(
                    fontFamily: isArabic ? 'Cairo' : 'Poppins',
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected
                        ? Colors.white
                        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  ),
                ),
                selected: selected,
                selectedColor: AppColors.orangePrimary,
                backgroundColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: selected
                        ? AppColors.orangePrimary
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
                onSelected: (val) {
                  if (val) setState(() => _selectedCategory = cat);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Realistic Envelope Letter Container (ظرف الرسالة)
          _buildEnvelope(isDark, isArabic, l10n),
          const SizedBox(height: 14),

          if (_errorText != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Text(
                _errorText!,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.error,
                ),
              ),
            ),
          if (_errorText != null) const SizedBox(height: 12),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orangePrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isSending ? null : _submit,
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              label: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      l10n?.supportSendButton ?? 'إرسال الرسالة',
                      style: TextStyle(
                        fontFamily: isArabic ? 'Cairo' : 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvelope(bool isDark, bool isArabic, AppLocalizations? l10n) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFCFAF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.orangePrimary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Letter Header / Postal Seal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.orangePrimary.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.mark_email_unread_rounded,
                  size: 18,
                  color: AppColors.orangePrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  isArabic ? 'مكتوب الدعم والشكاوى — مِحْوَر' : 'Official Support Letter — Mahwar',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.orangePrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.orangePrimary.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _typeLabel(isArabic).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: AppColors.orangePrimary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.orangePrimary.withValues(alpha: 0.15),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Name
                TextFormField(
                  controller: _nameController,
                  enabled: !_contactLocked,
                  maxLength: supportContactNameMaxLength,
                  decoration: _buildLetterInputDecoration(
                    label: isArabic ? 'الاسم الكامل' : 'Full Name',
                    icon: Icons.person_rounded,
                    isDark: isDark,
                  ),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                  validator: (value) {
                    if (_contactLocked) return null;
                    final name = value?.trim() ?? '';
                    if (name.length < supportContactNameMinLength) {
                      return isArabic ? 'يرجى إدخال اسمك الكامل' : 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // 2. Registered Phone
                TextFormField(
                  controller: _phoneController,
                  enabled: !_contactLocked,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: _buildLetterInputDecoration(
                    label: _contactLocked
                        ? (isArabic ? 'رقم الهاتف المسجل بالتطبيق 🔒' : 'Registered Phone 🔒')
                        : (isArabic ? 'رقم الهاتف المسجل بالتطبيق' : 'Registered Phone'),
                    hintText: '01xxxxxxxxx',
                    icon: Icons.phone_android_rounded,
                    isDark: isDark,
                  ),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                  validator: (value) {
                    if (_contactLocked) return null;
                    final phone = value?.trim() ?? '';
                    if (!RegExp(r'^01[0-9]{9}$').hasMatch(phone)) {
                      return isArabic
                          ? 'أدخل رقم هاتف صحيح مكوّن من 11 رقمًا ويبدأ بـ 01'
                          : 'Enter a valid 11-digit phone number starting with 01';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // 3. Subject / Title
                TextFormField(
                  controller: _subjectController,
                  maxLength: supportSubjectMaxLength,
                  decoration: _buildLetterInputDecoration(
                    label: isArabic ? 'عنوان الموضوع أو الشكوى' : 'Subject / Title',
                    icon: Icons.subject_rounded,
                    isDark: isDark,
                  ),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                  validator: (value) {
                    final subject = value?.trim() ?? '';
                    if (subject.length < supportSubjectMinLength) {
                      return isArabic
                          ? 'يرجى إدخال عنوان الشكوى/الموضوع'
                          : 'Please enter subject';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 4),

                // 4. Details / Body
                TextFormField(
                  controller: _detailsController,
                  maxLines: 4,
                  minLines: 3,
                  maxLength: supportBodyMaxLength,
                  decoration: _buildLetterInputDecoration(
                    label: isArabic ? 'تفاصيل الرسالة (اكتب هنا...)' : 'Message details...',
                    icon: Icons.description_rounded,
                    isDark: isDark,
                  ),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                  validator: (value) {
                    final body = value?.trim() ?? '';
                    if (body.length < supportBodyMinLength) {
                      return isArabic
                          ? 'يرجى كتابة تفاصيل الرسالة'
                          : 'Please write message details';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Image Attachment Section
                if (!_isLoggedInUser)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n?.supportAttachmentNeedsLogin ??
                              'لإرفاق صورة، سجّل الدخول أولًا. يمكنك إرسال الرسالة بدون مرفق الآن.',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            height: 1.5,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  )
                else if (_attachedImage == null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.orangePrimary.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _pickImage,
                    icon: const Icon(
                      Icons.add_photo_alternate_rounded,
                      color: AppColors.orangePrimary,
                      size: 18,
                    ),
                    label: Text(
                      isArabic ? 'إرفاق صورة أو لقطة شاشة' : 'Attach Screenshot/Image',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.orangePrimary,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.orangePrimary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            File(_attachedImage!.path),
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isArabic ? 'صورة مرفقة' : 'Image Attached',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                              Text(
                                _attachedImage!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            color: AppColors.error,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _attachedImage = null),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(bool isDark, bool isArabic, AppLocalizations? l10n) {
    final shortId = (_sentTicketId ?? '').length >= 8
        ? _sentTicketId!.substring(0, 8)
        : (_sentTicketId ?? '');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.mark_email_read_rounded, color: AppColors.success, size: 44),
          const SizedBox(height: 10),
          Text(
            l10n?.supportSendSuccess ?? 'تم إرسال رسالتك',
            style: TextStyle(
              fontFamily: isArabic ? 'Cairo' : 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n?.supportTicketNumber(shortId) ?? 'رقم التذكرة: $shortId',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.supportFollowReplyHint ??
                'تقدر تتابع رد فريق الدعم من «تذاكراتي» في أي وقت.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              height: 1.6,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _sentTicketId = null),
                  child: Text(
                    l10n?.supportSendAnother ?? 'إرسال رسالة أخرى',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.orangePrimary,
                    ),
                  ),
                ),
              ),
              if (_isLoggedInUser)
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orangePrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _openTickets,
                    child: Text(
                      l10n?.supportMyTickets ?? 'تذاكراتي',
                      style: TextStyle(
                        fontFamily: isArabic ? 'Cairo' : 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTickets(bool isDark, bool isArabic, AppLocalizations? l10n) {
    if (_ticketsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.orangePrimary),
        ),
      );
    }

    if (_ticketsError != null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              _ticketsError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                height: 1.6,
                color: AppColors.error,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: _loadTickets,
            child: Text(
              isArabic ? 'إعادة المحاولة' : 'Retry',
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: AppColors.orangePrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }

    if (_tickets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(
              Icons.forum_outlined,
              size: 40,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            const SizedBox(height: 10),
            Text(
              l10n?.supportTicketsEmpty ?? 'لا توجد رسائل سابقة',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _tickets.map((ticket) {
        final status = ticket['status']?.toString() ?? 'open';
        final reply = ticket['reply_body']?.toString();
        final statusColor = _statusColor(status);
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      _statusLabel(status, l10n),
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _kindLabel(ticket['kind']?.toString() ?? 'complaint', isArabic),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDateTime(ticket['created_at']),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                ticket['subject']?.toString() ?? '',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ticket['body']?.toString() ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  height: 1.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              if (reply != null && reply.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.supportReplyLabel ?? 'رد فريق الدعم',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reply,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          height: 1.5,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTab({
    required SupportMessageType type,
    required String label,
    required IconData outlinedIcon,
    required IconData filledIcon,
    required bool isDark,
    required bool isArabic,
  }) {
    final selected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTypeChanged(type, isArabic),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.orangePrimary
                : (isDark ? AppColors.darkCard : AppColors.lightSurface),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.orangePrimary
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: selected ? 1.5 : 1.0,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.orangePrimary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                selected ? filledIcon : outlinedIcon,
                size: 22,
                color: selected
                    ? Colors.white
                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: isArabic ? 'Cairo' : 'Poppins',
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildLetterInputDecoration({
    required String label,
    required IconData icon,
    required bool isDark,
    String? hintText,
  }) {
    final borderColor = isDark
        ? AppColors.darkBorder
        : AppColors.orangePrimary.withValues(alpha: 0.2);
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      counterText: '',
      prefixIcon: Icon(icon, color: AppColors.orangePrimary, size: 20),
      filled: true,
      fillColor: isDark ? const Color(0xFF242424) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.orangePrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }
}
