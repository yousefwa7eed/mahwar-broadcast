import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/settings/app_settings_cubit.dart';
import '../../core/settings/app_settings_state.dart';

// ──────────────────────────────────────────
//  Shared Legal Screen Shell
// ──────────────────────────────────────────

class _LegalScreen extends StatelessWidget {
  final String titleAr;
  final String titleEn;
  final String introAr;
  final String introEn;
  final List<_LegalSection> sections;
  final Color accentColor;
  final IconData headerIcon;

  const _LegalScreen({
    required this.titleAr,
    required this.titleEn,
    required this.introAr,
    required this.introEn,
    required this.sections,
    required this.accentColor,
    required this.headerIcon,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppSettingsCubit, AppSettingsState>(
      builder: (context, settings) {
        final isArabic = settings.locale.languageCode == 'ar';
        final isDark = settings.themeMode == ThemeMode.dark;

        final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
        final surface = isDark ? AppColors.darkSurface : Colors.white;
        final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
        final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

        final title = isArabic ? titleAr : titleEn;
        final intro = isArabic ? introAr : introEn;

        return Scaffold(
          backgroundColor: bg,
          body: CustomScrollView(
            slivers: [
              // ── Collapsible Header ──────────────────────
              SliverAppBar(
                expandedHeight: 180,
                floating: false,
                pinned: true,
                backgroundColor: accentColor,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 56, bottom: 14, right: 16),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontFamily: isArabic ? 'Zain' : 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.9),
                          accentColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40, left: 24, right: 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(headerIcon, color: Colors.white, size: 30),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontFamily: isArabic ? 'Zain' : 'Poppins',
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Body Content ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Last Updated Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 14, color: accentColor),
                            const SizedBox(width: 6),
                            Text(
                              isArabic ? 'آخر تحديث: أغسطس 2025' : 'Last Updated: August 2025',
                              style: TextStyle(
                                fontFamily: isArabic ? 'Cairo' : 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Intro Paragraph
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          intro,
                          style: TextStyle(
                            fontFamily: isArabic ? 'Cairo' : 'Poppins',
                            fontSize: 14,
                            height: 1.8,
                            color: secondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sections
                      ...sections.map((section) => _buildSectionCard(
                            section: section,
                            isArabic: isArabic,
                            isDark: isDark,
                            surface: surface,
                            primary: primary,
                            secondary: secondary,
                            border: border,
                            accentColor: accentColor,
                          )),

                      const SizedBox(height: 16),

                      // Footer Contact Info
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentColor.withValues(alpha: 0.08),
                              accentColor.withValues(alpha: 0.04),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.contact_support_rounded, color: accentColor, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  isArabic ? 'للتواصل معنا' : 'Contact Us',
                                  style: TextStyle(
                                    fontFamily: isArabic ? 'Zain' : 'Poppins',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              isArabic
                                  ? 'إذا كان لديك أي استفسارات حول هذه السياسة، يرجى التواصل معنا على:\nsupport@mahwar.app\nأو الاتصال بخط الدعم: 19000'
                                  : 'If you have any questions about this policy, please contact us at:\nsupport@mahwar.app\nOr call our support line: 19000',
                              style: TextStyle(
                                fontFamily: isArabic ? 'Cairo' : 'Poppins',
                                fontSize: 13,
                                height: 1.8,
                                color: secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required _LegalSection section,
    required bool isArabic,
    required bool isDark,
    required Color surface,
    required Color primary,
    required Color secondary,
    required Color border,
    required Color accentColor,
  }) {
    final title = isArabic ? section.titleAr : section.titleEn;
    final content = isArabic ? section.contentAr : section.contentEn;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Title Bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        section.number,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: isArabic ? 'Zain' : 'Poppins',
                        fontSize: isArabic ? 18 : 15,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Section Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                content,
                style: TextStyle(
                  fontFamily: isArabic ? 'Cairo' : 'Poppins',
                  fontSize: 13,
                  height: 1.8,
                  color: secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalSection {
  final String number;
  final String titleAr;
  final String titleEn;
  final String contentAr;
  final String contentEn;

  const _LegalSection({
    required this.number,
    required this.titleAr,
    required this.titleEn,
    required this.contentAr,
    required this.contentEn,
  });
}

// ──────────────────────────────────────────
//  Terms of Use Screen
// ──────────────────────────────────────────

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const List<_LegalSection> _sections = [
    _LegalSection(
      number: '1',
      titleAr: 'قبول الشروط',
      titleEn: 'Acceptance of Terms',
      contentAr:
          'باستخدامك لتطبيق مِحْوَر، أنت تُقر بأنك قرأت هذه الشروط وفهمتها وتوافق على الالتزام بها. إذا كنت لا توافق على أي من هذه الشروط، يرجى عدم استخدام التطبيق.',
      contentEn:
          'By using the Mahwar app, you acknowledge that you have read, understood, and agree to be bound by these terms. If you do not agree to any of these terms, please do not use the application.',
    ),
    _LegalSection(
      number: '2',
      titleAr: 'الاستخدام المقبول',
      titleEn: 'Acceptable Use',
      contentAr:
          'يُسمح باستخدام التطبيق فقط للأغراض القانونية ووفقاً للقوانين المعمول بها في جمهورية مصر العربية. يُحظر استخدام التطبيق لأي غرض احتيالي أو ضار أو مخالف للآداب العامة.',
      contentEn:
          'The application may only be used for lawful purposes and in accordance with applicable laws in Egypt. Use of the application for any fraudulent, harmful, or inappropriate purpose is strictly prohibited.',
    ),
    _LegalSection(
      number: '3',
      titleAr: 'الحسابات والمسؤولية',
      titleEn: 'Accounts & Responsibility',
      contentAr:
          'أنت مسؤول عن الحفاظ على سرية بيانات حسابك وكلمة مرورك. كما أنت مسؤول عن جميع الأنشطة التي تحدث تحت حسابك. يجب إبلاغنا فوراً عن أي استخدام غير مصرح به لحسابك.',
      contentEn:
          'You are responsible for maintaining the confidentiality of your account credentials and password, as well as all activities occurring under your account. You must notify us immediately of any unauthorized use of your account.',
    ),
    _LegalSection(
      number: '4',
      titleAr: 'طبيعة خدمات التطبيق',
      titleEn: 'Nature of App Services',
      contentAr:
          'يوفر تطبيق مِحْوَر منصة رقمية لربط مالكي السيارات بمقدمي خدمات الطوارئ. نحن لسنا طرفاً في الاتفاق بين العميل ومقدم الخدمة، ولا نتحمل المسؤولية عن جودة الخدمات المقدمة.',
      contentEn:
          'Mahwar provides a digital platform connecting car owners with emergency service providers. We are not a party to the agreement between the client and the provider, and we are not responsible for the quality of services rendered.',
    ),
    _LegalSection(
      number: '5',
      titleAr: 'التسعير والمدفوعات',
      titleEn: 'Pricing & Payments',
      contentAr:
          'جميع المدفوعات تتم مباشرةً بين مالك السيارة ومقدم الخدمة. يتيح التطبيق عملية التفاوض على السعر والموافقة عليه. التطبيق لا يتحصل على عمولة أو رسوم مالية من المعاملات.',
      contentEn:
          'All payments are made directly between the car owner and the service provider. The app facilitates the price negotiation and acceptance process. The application does not collect any commission or fees from transactions.',
    ),
    _LegalSection(
      number: '6',
      titleAr: 'الإلغاء والرفض',
      titleEn: 'Cancellation & Rejection',
      contentAr:
          'يمكن لمالك السيارة إلغاء الطلب في أي وقت قبل قبول السعر. يمكن لمقدم الخدمة رفض الطلب قبل تقديم عرض السعر. بعد قبول السعر من قبل العميل، يُعتبر الطلب مُلزِماً.',
      contentEn:
          'Car owners may cancel requests at any time before accepting the price. Service providers may reject requests before submitting a quote. Once the price is accepted by the client, the order is considered binding.',
    ),
    _LegalSection(
      number: '7',
      titleAr: 'الملكية الفكرية',
      titleEn: 'Intellectual Property',
      contentAr:
          'جميع حقوق الملكية الفكرية للتطبيق بما في ذلك التصاميم والشعارات والمحتوى محفوظة لشركة مِحْوَر. لا يُسمح بإعادة إنتاج أي جزء من التطبيق أو استخدامه تجارياً دون إذن مسبق.',
      contentEn:
          'All intellectual property rights in the app, including designs, logos, and content, are reserved to Mahwar. No part of the application may be reproduced or used commercially without prior permission.',
    ),
    _LegalSection(
      number: '8',
      titleAr: 'التعديلات على الشروط',
      titleEn: 'Amendments to Terms',
      contentAr:
          'نحتفظ بحقنا في تعديل هذه الشروط والأحكام في أي وقت. سيتم إشعار المستخدمين بأي تغييرات جوهرية من خلال التطبيق. استمرارك في استخدام التطبيق بعد التعديلات يُعدّ قبولاً لها.',
      contentEn:
          'We reserve the right to modify these terms and conditions at any time. Users will be notified of any material changes through the application. Continued use of the app after modifications constitutes acceptance of the changes.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _LegalScreen(
      titleAr: 'شروط الاستخدام',
      titleEn: 'Terms of Use',
      introAr:
          'مرحباً بك في تطبيق مِحْوَر لخدمات طوارئ السيارات. باستخدامك لهذا التطبيق، أنت توافق على الشروط والأحكام التالية التي تنظم العلاقة بينك وبين منصة مِحْوَر.',
      introEn:
          'Welcome to Mahwar, the roadside emergency services app. By using this application, you agree to the following terms and conditions that govern the relationship between you and the Mahwar platform.',
      sections: _sections,
      accentColor: const Color(0xFFFF6B00),
      headerIcon: Icons.gavel_rounded,
    );
  }
}

// ──────────────────────────────────────────
//  Privacy Policy Screen
// ──────────────────────────────────────────

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const List<_LegalSection> _sections = [
    _LegalSection(
      number: '1',
      titleAr: 'البيانات التي نجمعها',
      titleEn: 'Data We Collect',
      contentAr:
          'نجمع البيانات الضرورية لتقديم خدماتنا، وتشمل: الاسم الكامل، رقم الهاتف، البريد الإلكتروني، الموقع الجغرافي الحي، الرقم القومي (لمقدمي الخدمة)، وبيانات السيارة (الماركة، الموديل، السنة). لا نجمع أي بيانات غير ضرورية.',
      contentEn:
          'We collect data necessary for providing our services, including: full name, phone number, email address, live GPS location, national ID (for service providers), and vehicle details (make, model, year). We do not collect any unnecessary data.',
    ),
    _LegalSection(
      number: '2',
      titleAr: 'كيفية استخدام بياناتك',
      titleEn: 'How We Use Your Data',
      contentAr:
          'نستخدم بياناتك للأغراض التالية: تقديم خدمات الطوارئ، ربطك بأقرب مقدمي الخدمة جغرافياً، إرسال الإشعارات ذات الصلة بطلباتك، تحسين جودة التطبيق وتجربة المستخدم، وضمان أمان المنصة.',
      contentEn:
          'We use your data for the following purposes: providing emergency services, connecting you to the nearest service providers geographically, sending notifications related to your requests, improving app quality and user experience, and ensuring platform security.',
    ),
    _LegalSection(
      number: '3',
      titleAr: 'مشاركة البيانات',
      titleEn: 'Data Sharing',
      contentAr:
          'لا نشارك بياناتك مع أطراف ثالثة إلا في الحالات التالية: عند ضرورة تقديم الخدمة (مشاركة موقعك مع مقدم الخدمة المختار)، أو عند الإلزام القانوني من الجهات الحكومية المختصة، أو بموافقتك الصريحة.',
      contentEn:
          'We do not share your data with third parties except in the following cases: when necessary to provide the service (sharing your location with the selected service provider), legal obligation by competent government authorities, or with your explicit consent.',
    ),
    _LegalSection(
      number: '4',
      titleAr: 'أمان البيانات',
      titleEn: 'Data Security',
      contentAr:
          'نستخدم أحدث تقنيات التشفير والأمان لحماية بياناتك. نعتمد على Supabase كبنية تحتية آمنة مع تشفير SSL/TLS لجميع الاتصالات. يتم تطبيق سياسات Row Level Security (RLS) لضمان عدم الوصول غير المصرح به لبياناتك.',
      contentEn:
          'We use the latest encryption and security technologies to protect your data. We rely on Supabase as a secure infrastructure with SSL/TLS encryption for all communications. Row Level Security (RLS) policies are applied to ensure no unauthorized access to your data.',
    ),
    _LegalSection(
      number: '5',
      titleAr: 'حقوقك على بياناتك',
      titleEn: 'Your Data Rights',
      contentAr:
          'لديك الحقوق التالية بشأن بياناتك: حق الوصول والاطلاع على بياناتك المخزنة، حق التصحيح والتعديل، حق حذف حسابك وبياناتك كاملاً، وحق الاعتراض على معالجة بياناتك في حالات معينة.',
      contentEn:
          'You have the following rights regarding your data: right to access and view your stored data, right to correction and modification, right to delete your account and all data, and right to object to data processing in certain cases.',
    ),
    _LegalSection(
      number: '6',
      titleAr: 'بيانات الموقع الجغرافي',
      titleEn: 'Location Data',
      contentAr:
          'نستخدم الموقع الجغرافي فقط خلال جلسة الطلب النشطة لإيجاد أقرب مقدمي الخدمة. لا نتتبع موقعك في الخلفية خارج طلبات الخدمة. يمكنك التحكم في صلاحيات الموقع من إعدادات هاتفك في أي وقت.',
      contentEn:
          'We use location data only during active service request sessions to find the nearest providers. We do not track your location in the background outside of service requests. You can control location permissions from your phone settings at any time.',
    ),
    _LegalSection(
      number: '7',
      titleAr: 'الاحتفاظ بالبيانات',
      titleEn: 'Data Retention',
      contentAr:
          'نحتفظ ببيانات حسابك طالما كان حسابك نشطاً. عند حذف حسابك، يتم حذف جميع بياناتك الشخصية خلال 30 يوماً. قد نحتفظ ببعض البيانات المجهولة للتحليل الإحصائي.',
      contentEn:
          'We retain your account data as long as your account is active. Upon account deletion, all your personal data is deleted within 30 days. We may retain some anonymized data for statistical analysis.',
    ),
    _LegalSection(
      number: '8',
      titleAr: 'التحديثات على السياسة',
      titleEn: 'Policy Updates',
      contentAr:
          'قد نقوم بتحديث سياسة الخصوصية هذه من وقت لآخر لتعكس التغييرات في ممارساتنا أو لأسباب تشغيلية أو قانونية. سنُشعرك بأي تغييرات جوهرية عبر إشعار داخل التطبيق قبل دخول التغييرات حيز التنفيذ.',
      contentEn:
          'We may update this Privacy Policy from time to time to reflect changes in our practices or for operational or legal reasons. We will notify you of any material changes via an in-app notification before the changes take effect.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _LegalScreen(
      titleAr: 'سياسة الخصوصية',
      titleEn: 'Privacy Policy',
      introAr:
          'نحن في تطبيق مِحْوَر نُقدّر ثقتك ونلتزم التزاماً تاماً بحماية بياناتك الشخصية. توضح هذه السياسة كيفية جمع البيانات واستخدامها وحمايتها.',
      introEn:
          'At Mahwar, we value your trust and are fully committed to protecting your personal data. This policy explains how we collect, use, and protect your information.',
      sections: _sections,
      accentColor: const Color(0xFF1E1E1E),
      headerIcon: Icons.shield_rounded,
    );
  }
}
