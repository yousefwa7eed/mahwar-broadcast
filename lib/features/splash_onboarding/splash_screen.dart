import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/auth_cubit.dart';
import '../../core/auth/role_hint_cache.dart';
import '../../core/auth/role_gate.dart';
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

class _SplashScreenState extends State<SplashScreen> {
  SplashStatus _status = SplashStatus.initial;

  @override
  void initState() {
    super.initState();
    _bootstrap();
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
      context.go('/select-user-type');
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
      context.go('/select-user-type');
      return;
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
    context.go(role.homeRoute);
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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Color(0xFFE53935)),
              const SizedBox(height: 16),
              Text(
                roleUnresolvedMessage(isArabic: isArabic),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _onRetry,
                child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _onSignOut,
                child: Text(isArabic ? 'تسجيل الخروج' : 'Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    // هيكل الإقلاع فقط — لا يُعرض أي دور للمستخدم.
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SplashAnimationWidget(),
            SplashLogoWidget(),
            SizedBox(height: 8),
            SplashVersionWidget(versionText: 'v1.0.0'),
            SizedBox(height: 24),
          ],
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
