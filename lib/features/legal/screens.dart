import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mahwar/l10n/app_localizations.dart';
import '../../core/constants/app_colors.dart';
import '../../core/settings/app_settings_cubit.dart';
import '../../core/settings/app_settings_state.dart';

// ──────────────────────────────────────────
//  Shared Legal Screen Shell
// ──────────────────────────────────────────

class _LegalScreen extends StatelessWidget {
  final String title;
  final String intro;
  final List<_LegalSection> sections;
  final Color accentColor;
  final IconData headerIcon;

  const _LegalScreen({
    required this.title,
    required this.intro,
    required this.sections,
    required this.accentColor,
    required this.headerIcon,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<AppSettingsCubit, AppSettingsState>(
      builder: (context, settings) {
        final isArabic = settings.locale.languageCode == 'ar';
        final isDark = settings.themeMode == ThemeMode.dark;

        final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
        final surface = isDark ? AppColors.darkSurface : Colors.white;
        final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
        final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
        final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

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
                              l10n?.legalLastUpdated ?? 'آخر تحديث: أغسطس 2025',
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
                                  l10n?.legalContactTitle ?? 'للتواصل معنا',
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
                              l10n?.legalContactBody ??
                                  'إذا كان لديك أي استفسارات حول هذه السياسة، يرجى التواصل معنا على:\nsupport@mahwar.app\nأو الاتصال بخط الدعم: 19000',
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
    final title = section.title;
    final content = section.content;

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
  final String title;
  final String content;

  const _LegalSection({
    required this.number,
    required this.title,
    required this.content,
  });
}

// ──────────────────────────────────────────
//  Terms of Use Screen
// ──────────────────────────────────────────

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _LegalScreen(
      title: l10n?.termsOfUse ?? 'شروط الاستخدام',
      intro: l10n?.legalTermsIntro ??
          'مرحباً بك في تطبيق مِحْوَر لخدمات طوارئ السيارات. باستخدامك لهذا التطبيق، أنت توافق على الشروط والأحكام التالية التي تنظم العلاقة بينك وبين منصة مِحْوَر.',
      sections: [
        _LegalSection(
          number: '1',
          title: l10n?.legalTermsSection1Title ?? 'قبول الشروط',
          content: l10n?.legalTermsSection1Body ??
              'باستخدامك لتطبيق مِحْوَر، أنت تُقر بأنك قرأت هذه الشروط وفهمتها وتوافق على الالتزام بها. إذا كنت لا توافق على أي من هذه الشروط، يرجى عدم استخدام التطبيق.',
        ),
        _LegalSection(
          number: '2',
          title: l10n?.legalTermsSection2Title ?? 'الاستخدام المقبول',
          content: l10n?.legalTermsSection2Body ??
              'يُسمح باستخدام التطبيق فقط للأغراض القانونية ووفقاً للقوانين المعمول بها في جمهورية مصر العربية. يُحظر استخدام التطبيق لأي غرض احتيالي أو ضار أو مخالف للآداب العامة.',
        ),
        _LegalSection(
          number: '3',
          title: l10n?.legalTermsSection3Title ?? 'الحسابات والمسؤولية',
          content: l10n?.legalTermsSection3Body ??
              'أنت مسؤول عن الحفاظ على سرية بيانات حسابك وكلمة مرورك. كما أنت مسؤول عن جميع الأنشطة التي تحدث تحت حسابك. يجب إبلاغنا فوراً عن أي استخدام غير مصرح به لحسابك.',
        ),
        _LegalSection(
          number: '4',
          title: l10n?.legalTermsSection4Title ?? 'طبيعة خدمات التطبيق',
          content: l10n?.legalTermsSection4Body ??
              'يوفر تطبيق مِحْوَر منصة رقمية لربط مالكي السيارات بمقدمي خدمات الطوارئ. نحن لسنا طرفاً في الاتفاق بين العميل ومقدم الخدمة، ولا نتحمل المسؤولية عن جودة الخدمات المقدمة.',
        ),
        _LegalSection(
          number: '5',
          title: l10n?.legalTermsSection5Title ?? 'التسعير والمدفوعات',
          content: l10n?.legalTermsSection5Body ??
              'جميع المدفوعات تتم مباشرةً بين مالك السيارة ومقدم الخدمة. يتيح التطبيق عملية التفاوض على السعر والموافقة عليه. التطبيق لا يتحصل على عمولة أو رسوم مالية من المعاملات.',
        ),
        _LegalSection(
          number: '6',
          title: l10n?.legalTermsSection6Title ?? 'الإلغاء والرفض',
          content: l10n?.legalTermsSection6Body ??
              'يمكن لمالك السيارة إلغاء الطلب في أي وقت قبل قبول السعر. يمكن لمقدم الخدمة رفض الطلب قبل تقديم عرض السعر. بعد قبول السعر من قبل العميل، يُعتبر الطلب مُلزِماً.',
        ),
        _LegalSection(
          number: '7',
          title: l10n?.legalTermsSection7Title ?? 'الملكية الفكرية',
          content: l10n?.legalTermsSection7Body ??
              'جميع حقوق الملكية الفكرية للتطبيق بما في ذلك التصاميم والشعارات والمحتوى محفوظة لشركة مِحْوَر. لا يُسمح بإعادة إنتاج أي جزء من التطبيق أو استخدامه تجارياً دون إذن مسبق.',
        ),
        _LegalSection(
          number: '8',
          title: l10n?.legalTermsSection8Title ?? 'التعديلات على الشروط',
          content: l10n?.legalTermsSection8Body ??
              'نحتفظ بحقنا في تعديل هذه الشروط والأحكام في أي وقت. سيتم إشعار المستخدمين بأي تغييرات جوهرية من خلال التطبيق. استمرارك في استخدام التطبيق بعد التعديلات يُعدّ قبولاً لها.',
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _LegalScreen(
      title: l10n?.privacyPolicy ?? 'سياسة الخصوصية',
      intro: l10n?.legalPrivacyIntro ??
          'نحن في تطبيق مِحْوَر نُقدّر ثقتك ونلتزم التزاماً تاماً بحماية بياناتك الشخصية. توضح هذه السياسة كيفية جمع البيانات واستخدامها وحمايتها.',
      sections: [
        _LegalSection(
          number: '1',
          title: l10n?.legalPrivacySection1Title ?? 'البيانات التي نجمعها',
          content: l10n?.legalPrivacySection1Body ??
              'نجمع البيانات الضرورية لتقديم خدماتنا، وتشمل: الاسم الكامل، رقم الهاتف، البريد الإلكتروني، الموقع الجغرافي الحي، الرقم القومي (لمقدمي الخدمة)، وبيانات السيارة (الماركة، الموديل، السنة). لا نجمع أي بيانات غير ضرورية.',
        ),
        _LegalSection(
          number: '2',
          title: l10n?.legalPrivacySection2Title ?? 'كيفية استخدام بياناتك',
          content: l10n?.legalPrivacySection2Body ??
              'نستخدم بياناتك للأغراض التالية: تقديم خدمات الطوارئ، ربطك بأقرب مقدمي الخدمة جغرافياً، إرسال الإشعارات ذات الصلة بطلباتك، تحسين جودة التطبيق وتجربة المستخدم، وضمان أمان المنصة.',
        ),
        _LegalSection(
          number: '3',
          title: l10n?.legalPrivacySection3Title ?? 'مشاركة البيانات',
          content: l10n?.legalPrivacySection3Body ??
              'لا نشارك بياناتك مع أطراف ثالثة إلا في الحالات التالية: عند ضرورة تقديم الخدمة (مشاركة موقعك مع مقدم الخدمة المختار)، أو عند الإلزام القانوني من الجهات الحكومية المختصة، أو بموافقتك الصريحة.',
        ),
        _LegalSection(
          number: '4',
          title: l10n?.legalPrivacySection4Title ?? 'أمان البيانات',
          content: l10n?.legalPrivacySection4Body ??
              'نستخدم أحدث تقنيات التشفير والأمان لحماية بياناتك. نعتمد على Supabase كبنية تحتية آمنة مع تشفير SSL/TLS لجميع الاتصالات. يتم تطبيق سياسات Row Level Security (RLS) لضمان عدم الوصول غير المصرح به لبياناتك.',
        ),
        _LegalSection(
          number: '5',
          title: l10n?.legalPrivacySection5Title ?? 'حقوقك على بياناتك',
          content: l10n?.legalPrivacySection5Body ??
              'لديك الحقوق التالية بشأن بياناتك: حق الوصول والاطلاع على بياناتك المخزنة، حق التصحيح والتعديل، حق حذف حسابك وبياناتك كاملاً، وحق الاعتراض على معالجة بياناتك في حالات معينة.',
        ),
        _LegalSection(
          number: '6',
          title: l10n?.legalPrivacySection6Title ?? 'بيانات الموقع الجغرافي',
          content: l10n?.legalPrivacySection6Body ??
              'نستخدم الموقع الجغرافي فقط خلال جلسة الطلب النشطة لإيجاد أقرب مقدمي الخدمة. لا نتتبع موقعك في الخلفية خارج طلبات الخدمة. يمكنك التحكم في صلاحيات الموقع من إعدادات هاتفك في أي وقت.',
        ),
        _LegalSection(
          number: '7',
          title: l10n?.legalPrivacySection7Title ?? 'الاحتفاظ بالبيانات',
          content: l10n?.legalPrivacySection7Body ??
              'نحتفظ ببيانات حسابك طالما كان حسابك نشطاً. عند حذف حسابك، يتم حذف جميع بياناتك الشخصية خلال 30 يوماً. قد نحتفظ ببعض البيانات المجهولة للتحليل الإحصائي.',
        ),
        _LegalSection(
          number: '8',
          title: l10n?.legalPrivacySection8Title ?? 'التحديثات على السياسة',
          content: l10n?.legalPrivacySection8Body ??
              'قد نقوم بتحديث سياسة الخصوصية هذه من وقت لآخر لتعكس التغييرات في ممارساتنا أو لأسباب تشغيلية أو قانونية. سنُشعرك بأي تغييرات جوهرية عبر إشعار داخل التطبيق قبل دخول التغييرات حيز التنفيذ.',
        ),
      ],
      accentColor: const Color(0xFF1E1E1E),
      headerIcon: Icons.shield_rounded,
    );
  }
}
