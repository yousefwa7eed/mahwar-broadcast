import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/profile_cubit.dart';
import '../constants/app_colors.dart';

/// تعرض نافذة الدعم الفني والشكاوى والاقتراحات ذات تصميم محاكاة ظرف الرسالة.
/// تفرّق تلقائياً بين الحساب الموثق (المسجّل) وتمنحه شارة أولوية قصوى، وبين الزائر،
/// مع تحويل البريد بدون علامات (+) ورفع الصور السحابية.
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

enum SupportMessageType { complaint, suggestion, inquiry }

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

  final ImagePicker _picker = ImagePicker();

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

    final profileState = context.read<ProfileCubit>().state;
    if (profileState is ProfileLoaded && profileState.profile.fullName.isNotEmpty) {
      _isLoggedInUser = true;
      initialName = profileState.profile.fullName;
      initialPhone = profileState.profile.phoneNumber ?? '';
    }

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

  /// ترميز قيم المعلمات لنص `mailto` باستبدال `+` بـ `%20` لضمان عدم ظهور
  /// علامة الزائد بين الكلمات عند فتح تطبيقات البريد الإلكتروني.
  String _encodeMailtoParam(String value) {
    return Uri.encodeComponent(value).replaceAll('+', '%20');
  }

  Future<void> _sendEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final subject = _subjectController.text.trim();
    final details = _detailsController.text.trim();
    final typeStr = _typeLabel(isArabic);
    final categoryStr = _selectedCategory ?? '';

    String? imageUrl;

    // 1. رفع الصورة المرفقة إلى تخزين Supabase لاستخراج رابط مباشر وعرضها داخل البريد
    if (_attachedImage != null) {
      try {
        final client = Supabase.instance.client;
        final fileExt = _attachedImage!.path.split('.').last;
        final fileName = 'support_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = 'support/$fileName';

        await client.storage.from('order-attachments').upload(
          filePath,
          File(_attachedImage!.path),
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
        imageUrl = client.storage.from('order-attachments').getPublicUrl(filePath);
      } catch (e) {
        // في حال تعثر الرفع، استكمال الإرسال وتوضيح وجود صورة محلية
      }
    }

    final String accountPriorityTag = _isLoggedInUser
        ? (isArabic ? '⚡ [حساب موثق - أولوية قصوى]' : '⚡ [Verified Account - High Priority]')
        : (isArabic ? '💬 [رسالة زائر / استفسار]' : '💬 [Visitor Message]');

    final fullSubject = '$accountPriorityTag [$typeStr - $categoryStr]: $subject';
    final String imageSection = imageUrl != null
        ? '===========================================\n📷 رابط الصورة المرفقة بالرسالة:\n$imageUrl\n==========================================='
        : (_attachedImage != null
        ? '===========================================\n📷 صورة مرفقة: تم اختيار صورة من الجهاز (${_attachedImage!.name})\n==========================================='
        : '===========================================\n📷 المرفقات: لا يوجد مرفقات صور\n===========================================');

    final body = '''
===========================================
✉️ رسالة دعم فني جديدة - منصة مِحْوَر
===========================================
حالة الحساب: ${_isLoggedInUser ? 'مستخدم مسجّل في التطبيق (حساب موثق ⚡)' : 'زائر / غير مسجّل'}

👤 اسم المستخدم: $name
📱 رقم الهاتف المسجل: $phone
📌 نوع الرسالة: $typeStr
📂 تصنيف الموضوع: $categoryStr
📅 تاريخ الإرسال: ${DateTime.now().toString().split('.').first}

-------------------------------------------
📝 موضوع الرسالة:
$subject

💬 التفاصيل الكاملة:
$details

$imageSection
''';

    final encodedSubject = _encodeMailtoParam(fullSubject);
    final encodedBody = _encodeMailtoParam(body);
    final mailtoUrl = 'mailto:support@mahwar.app?subject=$encodedSubject&body=$encodedBody';
    final emailUri = Uri.parse(mailtoUrl);

    try {
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await Clipboard.setData(const ClipboardData(text: 'support@mahwar.app'));
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'تم نسخ البريد الإلكتروني support@mahwar.app. يمكنك مراسلتنا من تطبيق البريد الخاص بك.'
                  : 'Copied support@mahwar.app to clipboard. Please send an email from your mail app.',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: AppColors.orangePrimary,
          ),
        );
      } else {
        navigator.pop();
      }
    } catch (e) {
      await Clipboard.setData(const ClipboardData(text: 'support@mahwar.app'));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تعذر فتح البريد تلقائياً. تم نسخ البريد support@mahwar.app'
                : 'Unable to open mail client. Copied support@mahwar.app',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.orangePrimary,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final categoryOptions = isArabic ? _categoryOptionsAr[_type]! : _categoryOptionsEn[_type]!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
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
                          const Text(
                            'support@mahwar.app',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: AppColors.orangePrimary,
                              fontWeight: FontWeight.bold,
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
                ),
                const SizedBox(height: 16),

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
                Container(
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
                              child: const Text(
                                'MAHWAR',
                                style: TextStyle(
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
                              enabled: !_isLoggedInUser,
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
                                if (value == null || value.trim().isEmpty) {
                                  return isArabic ? 'يرجى إدخال اسمك الكامل' : 'Please enter your name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // 2. Registered Phone
                            TextFormField(
                              controller: _phoneController,
                              enabled: !_isLoggedInUser,
                              keyboardType: TextInputType.phone,
                              textDirection: TextDirection.ltr,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: _buildLetterInputDecoration(
                                label: _isLoggedInUser
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
                                if (value == null || value.trim().isEmpty) {
                                  return isArabic
                                      ? 'يرجى إدخال رقم هاتفك المسجل'
                                      : 'Please enter registered phone number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // 3. Subject / Title
                            TextFormField(
                              controller: _subjectController,
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
                                if (value == null || value.trim().isEmpty) {
                                  return isArabic
                                      ? 'يرجى إدخال عنوان الشكوى/الموضوع'
                                      : 'Please enter subject';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // 4. Details / Body
                            TextFormField(
                              controller: _detailsController,
                              maxLines: 4,
                              minLines: 3,
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
                                if (value == null || value.trim().isEmpty) {
                                  return isArabic
                                      ? 'يرجى كتابة تفاصيل الرسالة'
                                      : 'Please write message details';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Image Attachment Section
                            if (_attachedImage == null)
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
                ),
                const SizedBox(height: 20),

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
                    onPressed: _isSending ? null : _sendEmail,
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
                      isArabic ? 'إرسال عبر البريد الإلكتروني' : 'Send via Email',
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
          ),
        ),
      ),
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
