import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_cubit.dart';
import '../../core/auth/home_route.dart';
import '../../core/auth/last_account_store.dart';
import '../../core/auth/otp_error_mapper.dart';
import '../../core/auth/phone_utils.dart';
import '../../core/auth/role_gate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/settings/app_settings_cubit.dart';
import '../../core/settings/app_settings_state.dart';
import '../../core/theme/surface_palette.dart';
import '../../core/widgets/legal_footer.dart';
import '../../core/widgets/support_dialog.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/error_dialog.dart';
import 'widgets/login_form_widget.dart';
import 'widgets/login_header_widget.dart';

/// شاشة الدخول: شريط علوي خفيف (رجوع + هوية)، ثم كرت المحتوى ممتد حتى أسفل
/// الشاشة بحواف علوية دائرية — بنفس لغة شاشة اختيار نوع المستخدم، مع انتقال
/// لوني سلس بين الوضعين وظهور متدرّج ناعم للعناصر.
class LoginScreen extends StatefulWidget {
  final String role;

  /// مسار داخلي يُفتح بعد نجاح الدخول (رابط QR مثلًا). يُمرَّر عبر
  /// [safeInternalRoute] قبل الاستخدام، وأي قيمة غير آمنة تُتجاهل.
  final String? next;

  /// المهلة القصوى لقراءة الدور من الخادم (كل محاولة). قابلة للحقن للاختبارات.
  final Duration roleFetchTimeout;

  /// عدد محاولات قراءة الدور قبل اعتباره غير معروف.
  final int roleFetchAttempts;

  const LoginScreen({
    super.key,
    required this.role,
    this.next,
    this.roleFetchTimeout = const Duration(seconds: 10),
    this.roleFetchAttempts = 2,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _themeTransition = Duration(milliseconds: 450);

  /// يمنع إعادة الدخول للمستمع أثناء معالجة توجيه/خروج (خاصةً خطأ الخروج
  /// الذي ينبعث نتيجة تسجيل خروج عدم التطابق — لا نعرضه فوق رسالة عدم التطابق).
  bool _resolving = false;

  /// مفتاح لقراءة ارتفاع محتوى النموذج بعد التخطيط، لتقرير «لوحة مدمجة» في
  /// التابلت فقط (لا يُستخدم مطلقًا على الموبايل).
  final GlobalKey _formContentKey = GlobalKey(debugLabel: 'loginFormContent');
  bool _compactCard = false;

  final LastAccountStore _lastAccountStore = LastAccountStore();

  /// آخر حساب معروف على الجهاز (لنفس دور هذه الصفحة) — تلميح «العودة إلى
  /// حسابك». يبقى بعد تسجيل الخروج ويُمسح فقط عند حذف الحساب.
  LastAccount? _lastAccount;

  /// جارٍ إرسال كود دخول بالهاتف — يمنع نقرتين ورسالتي SMS.
  bool _sendingOtp = false;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void initState() {
    super.initState();
    _loadLastAccount();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _loadLastAccount() async {
    final account = await _lastAccountStore.read();
    // لا تلميح لدور آخر: صفحة دخول المالك لا تقترح حساب مزوّد والعكس.
    if (!mounted || account == null || account.role != widget.role) return;
    setState(() => _lastAccount = account);
  }

  /// يرسل كود دخول لحساب موجود ثم يفتح شاشة OTP العادية (mode=login) — نفس
  /// نمط شاشة الاستعادة: الإرسال هنا، والتحقق والتوجيه هناك.
  Future<void> _startOtpLogin(String rawPhone) async {
    if (_sendingOtp) return;
    final l10n = AppLocalizations.of(context);
    if (!PhoneUtils.isValidEgyptianMobile(rawPhone)) {
      showErrorDialog(
        context,
        l10n?.enterValidEgyptianPhone ?? 'أدخل رقم هاتف مصري صحيح',
      );
      return;
    }
    final normalized = PhoneUtils.normalize(rawPhone);
    setState(() => _sendingOtp = true);
    try {
      await context.read<AuthCubit>().requestLoginOtp(normalized);
      if (!mounted) return;
      context.push(
        '/otp-verify?mode=login&phone=$normalized&role=${widget.role}',
      );
    } catch (e) {
      if (!mounted) return;
      // رسالة محايدة: لا تكشف ما إذا كان الرقم يخص حسابًا.
      showErrorDialog(context, mapRecoverySendError(e, l10n));
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Color _accent(SurfacePalette palette) {
    if (widget.role == 'provider') {
      return Color.lerp(
        const Color(0xFF262626),
        const Color(0xFFD9D9D9),
        palette.themeT,
      )!;
    }
    return AppColors.orangePrimary;
  }

  /// بطاقة تلميح أخيرة: اسم آخر حساب ورقمه المقنّع، والنقر عليها يرسل كود
  /// دخول إلى ذلك الرقم مباشرة.
  Widget _buildLastAccountCard(LastAccount account, SurfacePalette palette) {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final accent = _accent(palette);
    final font = isArabic ? 'Cairo' : 'Poppins';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _sendingOtp ? null : () => _startOtpLogin(account.phone),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: palette.highlightBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.highlightBorder),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: accent.withValues(alpha: 0.14),
                child: Text(
                  account.name.substring(0, 1),
                  style: TextStyle(
                    fontFamily: font,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.returnToAccount ?? 'العودة إلى حسابك',
                      style: TextStyle(
                        fontFamily: font,
                        fontSize: 12.5,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${account.name} · ${account.maskedPhone}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: font,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_sendingOtp)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                )
              else
                Icon(Icons.login_rounded, size: 18, color: accent),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) async {
        if (_resolving) return;

        // لا نتنقل أبدًا إلا على AuthAuthenticated. أي حالة أخرى (تحميل/خطأ/
        // غير مصادق) لا توجّه — كان السبب الأصلي في التوجيه المبكر إلى شاشة
        // المالك قبل اكتمال الجلسة. نعرض أخطاء الدخول فقط ونحن على شاشة الدخول.
        if (state is! AuthAuthenticated) {
          if (state is AuthError && isTopmostRoute(context, '/login')) {
            showErrorDialog(context, state.message);
          }
          return;
        }

        // شاشة OTP أعلى هذه الشاشة أثناء تدفق التسجيل/الاستعادة هي المسؤولة
        // الوحيدة عن التنقل بعد التحقق — لا نتحرك إلا إذا كانت شاشة الدخول هي
        // الشاشة الظاهرة فعلًا.
        if (!isTopmostRoute(context, '/login')) return;

        setState(() => _resolving = true);
        try {
          // الدور الفعلي مع مهلة وإعادة محاولة — لا نُبقي الزر قابلاً للضغط
          // ولا نترك المستخدم بلا مؤشر أثناء تحديد الدور.
          final actualRole = AppRole.tryParse(
            await context.read<AuthCubit>().resolveCurrentRoleWithRetry(
              timeout: widget.roleFetchTimeout,
              attempts: widget.roleFetchAttempts,
            ),
          );
          if (!context.mounted) return;

          final l10n = AppLocalizations.of(context);

          // تعذّر تحديد الدور → رسالة فورية ثم رفض الجلسة في الخلفية (بلا
          // انتظار أي طلب شبكي حتى لا تتأخر الرسالة).
          if (actualRole == null) {
            showErrorDialog(context, roleUnresolvedMessage(l10n: l10n));
            context.read<AuthCubit>().rejectSession();
            return;
          }

          final expectedRole = AppRole.tryParse(widget.role);

          // نقطة الدخول مقيّدة بالدور: حساب بدور مختلف عن صفحة الدخول التي
          // استُخدمت يُرفض — نعرض الرسالة فورًا ثم نرفض الجلسة في الخلفية.
          if (expectedRole != null && actualRole != expectedRole) {
            showErrorDialog(
              context,
              roleMismatchMessage(actualRole: actualRole, l10n: l10n),
            );
            context.read<AuthCubit>().rejectSession();
            return;
          }

          context.go(safeInternalRoute(widget.next) ?? actualRole.homeRoute);
        } finally {
          if (mounted) setState(() => _resolving = false);
        }
      },
      child: BlocBuilder<AppSettingsCubit, AppSettingsState>(
        builder: (context, settings) {
          final isDarkMode = settings.themeMode == ThemeMode.dark;
          final isArabic = settings.locale.languageCode == 'ar';

          // الألوان تتدرّج بين الوضعين بدل التبديل الفوري، فيبدو تغيير الثيم
          // انتقالًا ناعمًا (نفس سلوك شاشة اختيار النوع).
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(end: isDarkMode ? 1.0 : 0.0),
            duration: _themeTransition,
            curve: Curves.easeInOutCubic,
            builder: (context, themeT, _) {
              final palette = SurfacePalette.lerp(themeT);

              return Scaffold(
                backgroundColor: palette.background,
                // بلا SafeArea سفلية: الكرت يمتد حتى حافة الشاشة، ويُعوَّض
                // شريط الإيماءات داخل حشو المحتوى.
                body: SafeArea(
                  bottom: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final screenW = constraints.maxWidth;
                      final availableH = constraints.maxHeight;
                      final maxBodyWidth = screenW >= 1100
                          ? 780.0
                          : screenW >= 760
                          ? screenW * 0.78
                          : screenW >= 600
                          ? screenW * 0.90
                          : screenW * 0.92;

                      final bottomInset = MediaQuery.paddingOf(context).bottom;
                      const horizontal = 20.0;

                      // رأس البطاقة: رجوع + شارة النسخة التجريبية.
                      Widget cardTopBar() => _LoginCardTopBar(
                        palette: palette,
                        isArabic: isArabic,
                        onBack: () => context.go('/select-user-type'),
                      );

                      // كتلة الرسمة + النموذج (المحتوى الفعلي للبطاقة).
                      Widget formBlock() => Column(
                        key: _formContentKey,
                        children: [
                          _buildEntrance(
                            interval: const Interval(0.15, 0.8),
                            offset: 22,
                            child: LoginHeaderWidget(
                              role: widget.role,
                              palette: palette,
                              isArabic: isArabic,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_lastAccount != null) ...[
                            _buildLastAccountCard(_lastAccount!, palette),
                            const SizedBox(height: 16),
                          ],
                          _buildEntrance(
                            interval: const Interval(0.25, 0.95),
                            offset: 22,
                            child: LoginFormWidget(
                              role: widget.role,
                              palette: palette,
                              isArabic: isArabic,
                              isBusy: _resolving || _sendingOtp,
                              onSubmit: (identifier, password) {
                                context.read<AuthCubit>().signIn(
                                  identifier: identifier,
                                  password: password,
                                );
                              },
                              onSignupTap: () =>
                                  context.push('/signup?role=${widget.role}'),
                              onForgotPasswordTap: () => context.push(
                                '/forgot-password?role=${widget.role}',
                              ),
                              onOtpLoginTap: _startOtpLogin,
                            ),
                          ),
                        ],
                      );

                      // روابط الدعم والشروط والخصوصية — مثبّتة أسفل الكرت.
                      Widget legalFooterRow({required double bottomPadding}) =>
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              horizontal,
                              4,
                              horizontal,
                              bottomPadding,
                            ),
                            child: LegalFooter(
                              textColor: palette.footerText,
                              isArabic: isArabic,
                              onSupportTap: () => showSupportDialog(context),
                              onTermsTap: () => context.push('/terms'),
                              onPrivacyTap: () => context.push('/privacy'),
                            ),
                          );

                      // البطاقة بحد ذاتها: [compact] = لوحة بحجم محتواها وحواف
                      // دائرية من كل الجهات (للتابلت)؛ وإلا فهي ممتدة حتى أسفل
                      // الشاشة بحواف علوية دائرية فقط (للموبايل — بلا تغيير).
                      Widget card({required bool compact}) {
                        final radius = compact
                            ? BorderRadius.circular(28)
                            : const BorderRadius.vertical(
                                top: Radius.circular(32),
                              );

                        final Widget body;
                        if (compact) {
                          // المحتوى يدخل بالكامل في المتاح، فلا حاجة للتمرير.
                          body = Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              cardTopBar(),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  horizontal,
                                  6,
                                  horizontal,
                                  16,
                                ),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 520,
                                  ),
                                  child: formBlock(),
                                ),
                              ),
                              legalFooterRow(bottomPadding: 18),
                            ],
                          );
                        } else {
                          body = Column(
                            children: [
                              cardTopBar(),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, inner) {
                                    final minContentHeight =
                                        (inner.maxHeight - 22 - bottomInset)
                                            .clamp(0.0, double.infinity);
                                    return SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      padding: EdgeInsets.fromLTRB(
                                        horizontal,
                                        6,
                                        horizontal,
                                        16,
                                      ),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minHeight: minContentHeight,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 520,
                                              ),
                                              child: formBlock(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              legalFooterRow(bottomPadding: 12 + bottomInset),
                            ],
                          );
                        }

                        return Container(
                          width: double.infinity,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: radius,
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
                            border: Border.all(color: palette.cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: palette.cardShadow,
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: body,
                        );
                      }

                      // تمييز التابلت/الشاشات الكبيرة عن الموبايل بالعرض فقط،
                      // حتى لا يلمس المسار الممتدَّ أدناه أيَّ موبايل: الموبايل
                      // يبقى ممتدًا بكل محتواه بلا فراغات ولا تصغير.
                      final isLargeScreen = screenW >= 600;

                      if (isLargeScreen) {
                        // نقيس ارتفاع المحتوى بعد التخطيط ثم نُقرّر: لوحة مدمجة
                        // فقط إن زاد المتاح عنه بفارق واضح (الفراغ القاتل في
                        // التابلت). الموبايل لا يدخل هذا المسار أصلًا.
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          final ro = _formContentKey.currentContext
                              ?.findRenderObject();
                          if (ro is! RenderBox || !ro.hasSize) return;
                          // نضيف حصة رأس البطاقة والحشو (~150) للمقارنة العادلة.
                          final want = ro.size.height + 150 < availableH;
                          if (want != _compactCard) {
                            setState(() => _compactCard = want);
                          }
                        });
                      }

                      if (isLargeScreen && _compactCard) {
                        // التوسيط «البصري» يكون داخل المنطقة الآمنة (بين شريط
                        // الحالة وشريط التنقّل السفلي). الحشو العلوي استهلكته
                        // SafeArea، فنعوّض شريط التنقّل بحشو سفلي مماثل؛ وإلا
                        // بدا الكرت مائلًا للأسفل رغم توسيطه هندسيًا.
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.only(bottom: bottomInset),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: screenW,
                              minHeight: availableH - bottomInset,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: maxBodyWidth,
                                  child: _buildEntrance(
                                    interval: const Interval(0.0, 0.75),
                                    offset: 30,
                                    child: card(compact: true),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Center(
                        child: SizedBox(
                          width: maxBodyWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _buildEntrance(
                                  interval: const Interval(0.0, 0.75),
                                  offset: 30,
                                  child: card(compact: false),
                                ),
                              ),
                            ],
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
  Widget _buildEntrance({
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

/// رأس البطاقة: زر رجوع مع كلمة "رجوع" في الطرف، وشارة النسخة التجريبية
/// في الوسط.
class _LoginCardTopBar extends StatelessWidget {
  final SurfacePalette palette;
  final bool isArabic;
  final VoidCallback onBack;

  const _LoginCardTopBar({
    required this.palette,
    required this.isArabic,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final backLabel = l10n?.backLabel ?? 'رجوع';

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 8, 6, 0),
      child: Row(
        children: [
          Tooltip(
            message: backLabel,
            child: InkResponse(
              onTap: onBack,
              containedInkWell: true,
              highlightShape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(14),
              splashColor: palette.textPrimary.withValues(alpha: 0.10),
              highlightColor: palette.textPrimary.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: palette.textPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      backLabel,
                      style: TextStyle(
                        fontFamily: isArabic ? 'Cairo' : 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _BetaBadge(palette: palette, isArabic: isArabic),
            ),
          ),
          // يوازن عرض زر الرجوع حتى تبقى الشارة في منتصف البطاقة.
          const SizedBox(width: 70),
        ],
      ),
    );
  }
}

/// شارة "نسخة تجريبية" بنفس شكل شارة الصفحة السابقة (كبسولة ممتلئة بلا حد)،
/// مع نقطة صغيرة تلمع وتخفت لجذب الانتباه بدل أيقونة التجارب.
class _BetaBadge extends StatefulWidget {
  final SurfacePalette palette;
  final bool isArabic;

  const _BetaBadge({required this.palette, required this.isArabic});

  @override
  State<_BetaBadge> createState() => _BetaBadgeState();
}

class _BetaBadgeState extends State<_BetaBadge>
    with SingleTickerProviderStateMixin {
  // ثلاث نبضات ثم تستقر مضيئة — لا نتركها لا نهائية حتى لا تمنع استقرار
  // الاختبارات (pumpAndSettle) ولا تستهلك إطارات بلا نهاية.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true, count: 3);

  late final Animation<double> _glow = CurvedAnimation(
    parent: _pulse,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AnimatedBuilder(
      animation: _glow,
      builder: (context, _) {
        final t = _glow.value;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Color.lerp(
              const Color(0xFF2E2E2E),
              Colors.white.withValues(alpha: 0.14),
              widget.palette.themeT,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.30 + 0.70 * t),
                  boxShadow: [
                    if (t > 0.05)
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.45 * t),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                l10n?.betaBadge ?? 'نسخة تجريبية',
                style: TextStyle(
                  fontFamily: widget.isArabic ? 'Cairo' : 'Poppins',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
