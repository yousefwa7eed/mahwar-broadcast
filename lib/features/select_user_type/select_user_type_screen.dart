import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/legal_footer.dart';
import '../../core/settings/app_settings_cubit.dart';
import '../../core/settings/app_settings_state.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/feature_highlights_bar.dart';
import 'widgets/select_type_banner.dart';
import 'widgets/select_type_header.dart';
import '../../core/theme/surface_palette.dart';
import 'widgets/user_type_card.dart';

/// شاشة اختيار نوع المستخدم: كل المحتوى داخل كرت بحواف دائرية ناعمة —
/// فاتح في الوضع الفاتح وداكن في الوضع الداكن مع انتقال لوني سلس — وظهور
/// متدرج ناعم عند فتح الشاشة (staggered fade + slide).
class SelectUserTypeScreen extends StatefulWidget {
  const SelectUserTypeScreen({super.key});

  @override
  State<SelectUserTypeScreen> createState() => _SelectUserTypeScreenState();
}

class _SelectUserTypeScreenState extends State<SelectUserTypeScreen>
    with TickerProviderStateMixin {
  static const Duration _themeTransition = Duration(milliseconds: 450);
  static const Duration _languageTransition = Duration(milliseconds: 320);

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  /// 0 = تخطيط إنجليزي (LTR)، 1 = عربي (RTL). يتدرّج عند تبديل اللغة فتنزلق
  /// دائرة السهم في كروت النوع إلى حافتها الجديدة وتدور أيقونتها بسلاسة.
  late final AnimationController _languageFlip;
  late bool _lastIsArabic;

  @override
  void initState() {
    super.initState();
    _lastIsArabic =
        context.read<AppSettingsCubit>().state.locale.languageCode == 'ar';
    _languageFlip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: _lastIsArabic ? 1.0 : 0.0,
    )..addListener(_onLanguageFlipTick);
  }

  void _onLanguageFlipTick() => setState(() {});

  @override
  void dispose() {
    _languageFlip
      ..removeListener(_onLanguageFlipTick)
      ..dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _onSelectRole(BuildContext context, String role) {
    context.go('/login?role=$role');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocListener<AppSettingsCubit, AppSettingsState>(
      listenWhen: (previous, current) =>
          previous.locale.languageCode != current.locale.languageCode,
      listener: (context, settings) {
        final isArabic = settings.locale.languageCode == 'ar';
        if (isArabic == _lastIsArabic) return;
        _lastIsArabic = isArabic;
        // animateTo يتعامل مع الاتجاه المعاكس (رجوع في منتصف الحركة) بسلاسة.
        _languageFlip.animateTo(
          isArabic ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubic,
        );
      },
      child: BlocBuilder<AppSettingsCubit, AppSettingsState>(
        builder: (context, settings) {
          final isDarkMode = settings.themeMode == ThemeMode.dark;
          final currentLang = settings.locale.languageCode;
          final isArabic = currentLang == 'ar';
          final arrowProgress = _languageFlip.value;

          // الألوان تتدرّج بين الوضعين (themeT: 0 فاتح → 1 داكن) بدل التبديل
          // الفوري، فيبدو تغيير الثيم انتقالًا ناعمًا.
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(end: isDarkMode ? 1.0 : 0.0),
            duration: _themeTransition,
            curve: Curves.easeInOutCubic,
            builder: (context, themeT, _) {
              final palette = SurfacePalette.lerp(themeT);

              return Scaffold(
                backgroundColor: palette.background,
                // بلا SafeArea سفلية: الكرت الرئيسي يمتد حتى حافة الشاشة،
                // ويُعوَّض شريط الإيماءات داخل حشو التذييل.
                body: SafeArea(
                  bottom: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // تتلاءم مع مختلف أحجام الشاشات: في الهاتف يأخذ عرض
                      // الشاشة، وفي التابلت/الويب يتمدد حتى سقف أعلى مع بقائه
                      // في الوسط.
                      final screenW = constraints.maxWidth;
                      final maxBodyWidth = screenW >= 1100
                          ? 780.0
                          : screenW >= 760
                          ? screenW * 0.78
                          : screenW >= 600
                          ? screenW * 0.90
                          : screenW * 0.92;
                      final titleFont = (constraints.maxWidth * 0.068).clamp(
                        24.0,
                        38.0,
                      );

                      return Center(
                        child: SizedBox(
                          width: maxBodyWidth,
                          // تبديل اللغة يعيد بناء الشجرة بمفتاح اللغة الجديد،
                          // فيتم التحول بـ fade + slide خفيف بدل قفزة نصية.
                          child: AnimatedSwitcher(
                            duration: _languageTransition,
                            layoutBuilder: (currentChild, previousChildren) {
                              return Stack(
                                alignment: Alignment.topCenter,
                                children: [...previousChildren, ?currentChild],
                              );
                            },
                            transitionBuilder: (child, animation) {
                              // الفرعان منحنيان بذاتيهما: الداخل يظهر سريعاً
                              // والخارج يخبو سريعاً، فلا تتراكب اللغتان بوضوح
                              // كامل في منتصف الانتقال.
                              final curved = CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                                reverseCurve: Curves.easeInCubic,
                              );
                              return FadeTransition(
                                opacity: curved,
                                child: SlideTransition(
                                  // اللغة الجديدة تنزلق من حافتها القيادية:
                                  // العربية من اليمين، الإنجليزية من اليسار.
                                  position: Tween<Offset>(
                                    begin: Offset(isArabic ? 0.04 : -0.04, 0),
                                    end: Offset.zero,
                                  ).animate(curved),
                                  child: child,
                                ),
                              );
                            },
                            // اتجاه ثابت لكل لغة داخل شجرتها: الشجرة القديمة
                            // تحافظ على RTL/LTR الخاص بها أثناء التلاشي بدل
                            // الانقلاب فجأة مع الشجرة الجديدة.
                            child: Directionality(
                              key: ValueKey<String>(currentLang),
                              textDirection: isArabic
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header Row (App Logo + Language Switcher +
                                  // Theme Toggle)
                                  SelectTypeHeader(
                                    palette: palette,
                                    isDarkMode: isDarkMode,
                                    currentLang: currentLang,
                                    onToggleTheme: () {
                                      context
                                          .read<AppSettingsCubit>()
                                          .toggleTheme();
                                    },
                                    onToggleLang: () {
                                      context
                                          .read<AppSettingsCubit>()
                                          .toggleLocale();
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  // الكرت الرئيسي: لون متدرّج بين الفاتح والداكن
                                  // بحواف دائرية كبيرة بلا أي زوايا حادة.
                                  Expanded(
                                    child: _buildFadeSlide(
                                      interval: const Interval(0.0, 0.7),
                                      offset: 36,
                                      child: Container(
                                        width: double.infinity,
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          // الحواف العلوية فقط دائرية، والسفلى
                                          // ممتدة حتى حافة الشاشة دون انقطاع.
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(32),
                                              ),
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              palette.cardTop,
                                              palette.cardMid,
                                              palette.cardBottom,
                                            ],
                                            stops: const [0.0, 0.45, 1.0],
                                          ),
                                          border: Border.all(
                                            color: palette.cardBorder,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: palette.cardShadow,
                                              blurRadius: 28,
                                              offset: const Offset(0, 12),
                                            ),
                                          ],
                                        ),
                                        // المحتوى يتمدد، والتذييل (الشروط والخصوصية)
                                        // مثبّت في أسفل الكرت دائماً.
                                        child: Column(
                                          children: [
                                            Expanded(
                                              child: SingleChildScrollView(
                                                physics:
                                                    const BouncingScrollPhysics(),
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      18,
                                                      18,
                                                      18,
                                                      6,
                                                    ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    // Top Hero Banner (مبني بالكود +
                                                    // شارة النسخة التجريبية)
                                                    _buildFadeSlide(
                                                      interval: const Interval(
                                                        0.1,
                                                        0.8,
                                                      ),
                                                      offset: 24,
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              24,
                                                            ),
                                                        child: SelectTypeBanner(
                                                          isArabic: isArabic,
                                                          themeT:
                                                              palette.themeT,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 14),

                                                    // Feature Highlights Pills Bar
                                                    _buildFadeSlide(
                                                      interval: const Interval(
                                                        0.25,
                                                        0.85,
                                                      ),
                                                      offset: 20,
                                                      child:
                                                          FeatureHighlightsBar(
                                                            palette: palette,
                                                            isArabic: isArabic,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 18),

                                                    // Welcoming Title Section
                                                    _buildFadeSlide(
                                                      interval: const Interval(
                                                        0.3,
                                                        0.9,
                                                      ),
                                                      offset: 20,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            l10n?.welcomeToMahwar ??
                                                                'أهلاً بك في محور',
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  isArabic
                                                                  ? 'Zain'
                                                                  : 'Poppins',
                                                              fontSize:
                                                                  titleFont,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: palette
                                                                  .textPrimary,
                                                              height: 1.1,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 6,
                                                          ),
                                                          Text(
                                                            l10n?.chooseAccountTypeSubtitle ??
                                                                'اختر نوع حسابك للبدء في استخدام التطبيق واستكشاف الخدمات المتاحة',
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  isArabic
                                                                  ? 'Cairo'
                                                                  : 'Poppins',
                                                              fontSize: 13,
                                                              color: palette
                                                                  .textSecondary,
                                                              height: 1.4,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 20),

                                                    // Car Owner Selection Card
                                                    _buildFadeSlide(
                                                      interval: const Interval(
                                                        0.4,
                                                        0.95,
                                                      ),
                                                      offset: 24,
                                                      child: UserTypeCard(
                                                        title:
                                                            l10n?.carOwner ??
                                                            (isArabic
                                                                ? 'مالك السيارة'
                                                                : 'Car Owner'),
                                                        subtitle:
                                                            l10n?.carOwnerDesc ??
                                                            (isArabic
                                                                ? 'اطلب أقرب خدمات الطوارئ لسيارتك بكل سهولة'
                                                                : 'Request nearby emergency roadside assistance easily for tow truck, tires, fuel, and batteries'),
                                                        iconData: Icons
                                                            .directions_car_rounded,
                                                        gradient: AppColors
                                                            .orangeGradient,
                                                        shadowColor:
                                                            const Color(
                                                              0xFFFF6B00,
                                                            ),
                                                        themeT: palette.themeT,
                                                        isArabic: isArabic,
                                                        arrowProgress:
                                                            arrowProgress,
                                                        onTap: () =>
                                                            _onSelectRole(
                                                              context,
                                                              'car_owner',
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),

                                                    // Service Provider Selection Card
                                                    _buildFadeSlide(
                                                      interval: const Interval(
                                                        0.5,
                                                        1.0,
                                                      ),
                                                      offset: 24,
                                                      child: UserTypeCard(
                                                        title:
                                                            l10n?.serviceProvider ??
                                                            (isArabic
                                                                ? 'مقدم الخدمة'
                                                                : 'Service Provider'),
                                                        subtitle:
                                                            l10n?.serviceProviderDesc ??
                                                            (isArabic
                                                                ? 'استقبل طلبات الطوارئ وقدم خدماتك للعملاء'
                                                                : 'Receive location-based emergency requests from customers and quote prices directly'),
                                                        iconData: Icons
                                                            .build_circle_rounded,
                                                        gradient: AppColors
                                                            .darkGradient,
                                                        shadowColor:
                                                            const Color(
                                                              0xFF1E1E1E,
                                                            ),
                                                        themeT: palette.themeT,
                                                        isArabic: isArabic,
                                                        arrowProgress:
                                                            arrowProgress,
                                                        onTap: () =>
                                                            _onSelectRole(
                                                              context,
                                                              'provider',
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            // روابط الشروط والخصوصية أسفل الصفحة
                                            Padding(
                                              padding: EdgeInsets.fromLTRB(
                                                18,
                                                6,
                                                18,
                                                12 +
                                                    MediaQuery.paddingOf(
                                                      context,
                                                    ).bottom,
                                              ),
                                              child: _buildFadeSlide(
                                                interval: const Interval(
                                                  0.55,
                                                  1.0,
                                                ),
                                                offset: 16,
                                                child: LegalFooter(
                                                  textColor:
                                                      palette.footerText,
                                                  isArabic: isArabic,
                                                  onTermsTap: () =>
                                                      context.push('/terms'),
                                                  onPrivacyTap: () =>
                                                      context.push('/privacy'),
                                                ),
                                              ),
                                            ),
                                          ],
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
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// ظهور ناعم لعنصر واحد: شفافية + انزلاق لأعلى، متزامن مع دخول الشاشة
  /// عبر مجال زمني [interval] داخل كنترولر الشاشة (تدرّج الظهور).
  Widget _buildFadeSlide({
    required Interval interval,
    required double offset,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: _entrance,
      child: child,
      builder: (context, builtChild) {
        final curved = CurvedAnimation(parent: _entrance, curve: interval);
        return Opacity(
          opacity: curved.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, offset * (1 - curved.value)),
            child: builtChild,
          ),
        );
      },
    );
  }
}
