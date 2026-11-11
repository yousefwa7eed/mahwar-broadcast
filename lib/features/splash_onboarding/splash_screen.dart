import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/auth_cubit.dart';
import '../../core/auth/install_login_store.dart';
import '../../core/auth/phone_utils.dart';
import '../../core/auth/role_hint_cache.dart';
import '../../core/auth/role_gate.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/splash_animation_widget.dart';
import 'widgets/splash_logo_widget.dart';
import 'widgets/splash_version_widget.dart';

enum SplashStatus { initial, resolving, error }

class SplashScreen extends StatefulWidget {
  /// المهلة القصوى لقراءة الدور من الخادم. قابلة للحقن لتسريع الاختبارات.
  final Duration roleFetchTimeout;

  const SplashScreen({
    super.key,
    this.roleFetchTimeout = const Duration(seconds: 10),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _fadeInDuration = Duration(milliseconds: 650);
  static const Duration _fadeOutDuration = Duration(milliseconds: 300);

  SplashStatus _status = SplashStatus.initial;

  late final AnimationController _fadeController;
  late final CurvedAnimation _fade;
  late final Animation<double> _scale;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: _fadeInDuration,
      reverseDuration: _fadeOutDuration,
    );
    _fade = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _scale = Tween<double>(begin: 0.96, end: 1).animate(_fade);
    _fadeController.forward();
    _bootstrap();
  }

  @override
  void dispose() {
    _fade.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  /// تلاشٍ ناعم للخروج قبل التوجيه، ثم الانتقال للوجهة.
  Future<void> _leave(String location) async {
    if (_leaving) return;
    _leaving = true;
    if (!_fadeController.isDismissed) {
      await _fadeController.reverse();
    }
    if (!mounted) return;
    context.go(location);
  }

  /// تدفّق الإقلاع الصارم:
  /// 1) لا جلسة → /select-user-type.
  /// 2) تحقّق من الجلسة لدى الخادم (auth.getUser):
  ///    - AuthException (منتهية/ملغاة) → signOut + تفريغ الـ hint + /select-user-type.
  ///    - فشل شبكة → حالة خطأ قابلة لإعادة المحاولة.
  /// 3) الدور من profiles.role فقط خلال مهلة زمنية؛ أي null/فشل/انتهاء مهلة →
  ///    حالة خطأ (إعادة محاولة + تسجيل خروج). لا توجيه صامت ولا دور افتراضي.
  Future<void> _bootstrap() async {
    final cubit = context.read<AuthCubit>();

    // 1) + 2) التحقّق من الجلسة لدى الخادم.
    User? serverUser;
    try {
      serverUser = await cubit.validateServerSession();
    } on AuthException {
      // جلسة منتهية/ملغاة → إنهاء الجلسة، تفريغ الـ hint، صفحة اختيار النوع.
      await cubit.signOut();
      await RoleHintCache().clear();
      if (!mounted) return;
      await _leave('/select-user-type');
      return;
    } catch (_) {
      // تعذّر التحقّق (شبكة) → حالة خطأ قابلة لإعادة المحاولة.
      if (!mounted) return;
      setState(() => _status = SplashStatus.error);
      return;
    }

    if (serverUser == null) {
      // لا مستخدم خادمي → لا جلسة صالحة.
      await RoleHintCache().clear();
      if (!mounted) return;
      await _leave('/select-user-type');
      return;
    }

    // جلسة نجت من إعادة تشغيل/تحديث التطبيق = نفس النسخة المثبّتة (الحذف
    // يمحو الجلسة والعلامة معًا). نسجّل العلامة حتى لا يُفرض رمز التحقق على
    // مستخدم كان داخل التطبيق قبل التحديث — إلا رقمًا فُرض عليه الرمز ولم
    // يُكمله، فيبقى محتاجًا له (جلسة كلمة المرور وحدها لا تكفي).
    final localPhone = PhoneUtils.normalize(cubit.currentUserPhone ?? '');
    if (PhoneUtils.isValidEgyptianMobile(localPhone) &&
        !await InstallLoginStore.instance.isPending(localPhone)) {
      await InstallLoginStore.instance.markVerified(localPhone);
    }

    // 3) الدور من الخادم فقط (profiles.role) خلال مهلة زمنية.
    String? rawRole;
    try {
      rawRole = await cubit
          .resolveCurrentRole()
          .timeout(widget.roleFetchTimeout);
    } catch (_) {
      rawRole = null; // فشل أو انتهاء مهلة → نفس حالة الخطأ.
    }

    final role = AppRole.tryParse(rawRole);
    if (role == null) {
      if (!mounted) return;
      setState(() => _status = SplashStatus.error);
      return;
    }

    // الدور الخادمي هو المصدر الوحيد للتوجيه؛ نُحدّث الـ hint (للهيكل فقط)
    // ونوجّه حسب الدور الخادمي حتى لو اختلف عن الـ hint المخزّن مسبقًا.
    await RoleHintCache().write(role);
    if (!mounted) return;
    await _leave(role.homeRoute);
  }

  void _onRetry() {
    setState(() => _status = SplashStatus.resolving);
    _bootstrap();
  }

  Future<void> _onSignOut() async {
    await context.read<AuthCubit>().signOut();
    await RoleHintCache().clear();
    if (!mounted) return;
    context.go('/select-user-type');
  }

  Widget _buildError() {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Color(0xFFE53935)),
              const SizedBox(height: 16),
              Text(
                roleUnresolvedMessage(l10n: l10n),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _onRetry,
                child: Text(l10n?.retry ?? 'إعادة المحاولة'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _onSignOut,
                child: Text(l10n?.signOut ?? 'تسجيل الخروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    // هيكل الإقلاع فقط — لا يُعرض أي دور للمستخدم.
    // الخلفية مطابقة لخلفية الـ GIF حتى لا تظهر حواف المربّع، والنصوص في الأسفل.
    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: const Column(
              children: [
                Expanded(child: Center(child: SplashAnimationWidget())),
                Padding(
                  padding: EdgeInsetsDirectional.only(bottom: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SplashLogoWidget(),
                      SizedBox(height: 10),
                      SplashVersionWidget(versionText: 'v1.0.0'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_status == SplashStatus.error) return _buildError();
    return _buildSkeleton();
  }
}
