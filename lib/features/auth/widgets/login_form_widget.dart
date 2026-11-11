import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import '../../../core/auth/auth_cubit.dart';
import '../../../core/auth/phone_utils.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/surface_palette.dart';
import '../../../core/widgets/loading_form_lock.dart';
import '../../../l10n/app_localizations.dart';

class LoginFormWidget extends StatefulWidget {
  final String role;
  final SurfacePalette palette;
  final bool isArabic;

  /// يعكس انشغال الشاشة (تحديد الدور/الرفض) بعد نجاح المصادقة — يُبقي زر
  /// الدخول في حالة تحميل حتى نتّخذ قرار التوجيه أو الرفض.
  final bool isBusy;
  final Function(String identifier, String password) onSubmit;
  final VoidCallback onSignupTap;
  final VoidCallback onForgotPasswordTap;

  /// يُستدعى برقم الهاتف المكتوب لطلب كود دخول بدل كلمة المرور. يظهر الخيار
  /// في وضع الهاتف فقط، ولا يظهر إطلاقًا إن لم يُمرَّر.
  final ValueChanged<String>? onOtpLoginTap;

  const LoginFormWidget({
    super.key,
    required this.role,
    required this.palette,
    required this.isArabic,
    this.isBusy = false,
    required this.onSubmit,
    required this.onSignupTap,
    required this.onForgotPasswordTap,
    this.onOtpLoginTap,
  });

  @override
  State<LoginFormWidget> createState() => _LoginFormWidgetState();
}

class _LoginFormWidgetState extends State<LoginFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isPhoneMode = true; // true = phone, false = email

  @override
  void initState() {
    super.initState();
    // نعيد البناء عند الكتابة حتى تتحوّل أيقونة الحقل إلى النسخة الممتلئة.
    _identifierController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _identifierController
      ..removeListener(_onFieldChanged)
      ..dispose();
    _passwordController
      ..removeListener(_onFieldChanged)
      ..dispose();
    super.dispose();
  }

  TextInputType get _identifierKeyboardType =>
      _isPhoneMode ? TextInputType.phone : TextInputType.emailAddress;

  List<TextInputFormatter> get _identifierInputFormatters {
    if (_isPhoneMode) {
      return [FilteringTextInputFormatter.digitsOnly];
    }
    return [];
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onSubmit(
        _identifierController.text.trim(),
        _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = widget.isArabic;
    final palette = widget.palette;
    final l10n = AppLocalizations.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    final String labelFont = isArabic ? 'Cairo' : 'Poppins';

    final bool isAuthLoading =
        context.watch<AuthCubit>().state is AuthLoading || widget.isBusy;

    // المزوّد بهوية رمادية فحمية بدل البرتقالي؛ وفي الوضع الداكن يميل لرمادي
    // فاتح حتى يبقى الرابط والأيقونة مقروءين فوق السطح الداكن.
    final isProvider = widget.role == 'provider';
    final accent = isProvider
        ? Color.lerp(
            const Color(0xFF262626),
            const Color(0xFFD9D9D9),
            palette.themeT,
          )!
        : AppColors.orangePrimary;

    final buttonGradient = isProvider
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(
                const Color(0xFF3C3C3C),
                const Color(0xFF4A4A4A),
                palette.themeT,
              )!,
              Color.lerp(
                const Color(0xFF1E1E1E),
                const Color(0xFF262626),
                palette.themeT,
              )!,
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFA95C), Color(0xFFF76F00)],
          );
    final buttonGlow = isProvider
        ? Colors.black.withValues(alpha: palette.themeT > 0.5 ? 0.30 : 0.16)
        : AppColors.orangePrimary.withValues(alpha: 0.13);

    UnderlineInputBorder underline(Color color, double width) {
      return UnderlineInputBorder(
        borderSide: BorderSide(color: color, width: width),
      );
    }

    InputDecoration fieldDecoration({
      required String hint,
      required Widget prefixIcon,
      Widget? suffixIcon,
    }) {
      return InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: labelFont,
          fontSize: 14,
          color: palette.textSecondary.withValues(alpha: 0.55),
        ),
        prefixIcon: Padding(
          padding: const EdgeInsetsDirectional.only(end: 12),
          child: prefixIcon,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 30,
          minHeight: 30,
        ),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: underline(palette.highlightBorder, 1),
        enabledBorder: underline(palette.highlightBorder, 1),
        focusedBorder: underline(accent, 1.6),
        errorBorder: underline(errorColor, 1),
        focusedErrorBorder: underline(errorColor, 1.6),
        errorStyle: TextStyle(
          fontFamily: labelFont,
          fontSize: 12,
          color: errorColor,
        ),
      );
    }

    // مجوّفة عند الفراغ، وممتلئة وأكبر قليلاً بعد الكتابة لتبيّن أن الحقل
    // صار يحتوي إدخالاً.
    Widget fieldIcon({
      required bool hasText,
      required IconData outlined,
      required IconData solid,
    }) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: Icon(
          hasText ? solid : outlined,
          key: ValueKey<bool>(hasText),
          size: hasText ? 23 : 21,
          color: accent,
        ),
      );
    }

    final hasIdentifier = _identifierController.text.trim().isNotEmpty;

    return LoadingFormLock(
      loading: isAuthLoading,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // طريقة الدخول: أيقونتان بلا خلفية، والمختارة أكبر من الأخرى.
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n?.loginMethod ?? 'طريقة الدخول',
                    style: TextStyle(
                      fontFamily: labelFont,
                      fontSize: 13,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
                _MethodToggle(
                  isPhoneMode: _isPhoneMode,
                  onChanged: (isPhone) =>
                      setState(() => _isPhoneMode = isPhone),
                  palette: palette,
                  phoneLabel: l10n?.phoneTab ?? 'هاتف',
                  emailLabel: l10n?.emailTab ?? 'بريد',
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _identifierController,
              keyboardType: _identifierKeyboardType,
              inputFormatters: _identifierInputFormatters,
              textDirection: TextDirection.ltr,
              style: TextStyle(color: palette.textPrimary, fontSize: 15),
              cursorColor: accent,
              decoration: fieldDecoration(
                hint: _isPhoneMode ? '01xxxxxxxxx' : 'example@domain.com',
                prefixIcon: fieldIcon(
                  hasText: hasIdentifier,
                  outlined: _isPhoneMode
                      ? Icons.phone_outlined
                      : Icons.mail_outlined,
                  solid: _isPhoneMode ? Icons.phone : Icons.mail,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return _isPhoneMode
                      ? (l10n?.enterPhonePrompt ?? 'يرجى إدخال رقم الهاتف')
                      : (l10n?.enterEmailPrompt ??
                            'يرجى إدخال البريد الإلكتروني');
                }
                if (_isPhoneMode &&
                    !PhoneUtils.isValidEgyptianMobile(value.trim())) {
                  return l10n?.invalidPhoneShort ??
                      'رقم هاتف مصري غير صحيح (مثال: 01012345678)';
                }
                if (!_isPhoneMode &&
                    !RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value.trim())) {
                  return l10n?.invalidEmailFormat ??
                      'صيغة البريد الإلكتروني غير صحيحة';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // كلمة المرور
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(color: palette.textPrimary, fontSize: 15),
              cursorColor: accent,
              decoration: fieldDecoration(
                hint: l10n?.password ?? 'كلمة المرور',
                prefixIcon: fieldIcon(
                  hasText: _passwordController.text.isNotEmpty,
                  outlined: Icons.lock_outline,
                  solid: Icons.lock,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 21,
                    color: palette.textSecondary,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n?.enterPasswordPrompt ?? 'يرجى إدخال كلمة المرور';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                if (_isPhoneMode && widget.onOtpLoginTap != null)
                  GestureDetector(
                    onTap: isAuthLoading
                        ? null
                        : () => widget.onOtpLoginTap!(
                            _identifierController.text.trim(),
                          ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        l10n?.loginWithOtp ?? 'الدخول برمز التحقق',
                        style: TextStyle(
                          fontFamily: labelFont,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onForgotPasswordTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      l10n?.forgotPassword ?? 'نسيت كلمة المرور؟',
                      style: TextStyle(
                        fontFamily: labelFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            _PrimaryActionButton(
              isBusy: isAuthLoading,
              isArabic: isArabic,
              label: l10n?.login ?? 'تسجيل الدخول',
              gradient: buttonGradient,
              glow: buttonGlow,
              onTap: _submit,
            ),
            const SizedBox(height: 20),

            // الانتقال لإنشاء حساب
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Text(
                  l10n?.dontHaveAccount ?? 'ليس لديك حساب؟ ',
                  style: TextStyle(
                    fontFamily: labelFont,
                    fontSize: 14,
                    color: palette.textSecondary,
                  ),
                ),
                GestureDetector(
                  onTap: widget.onSignupTap,
                  child: Text(
                    l10n?.signup ?? 'إنشاء حساب جديد',
                    style: TextStyle(
                      fontFamily: labelFont,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: accent,
                      decoration: TextDecoration.underline,
                      decorationColor: accent.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// مبدّل هاتف/بريد بأيقونتين فقط وبلا خلفية — مثل زرّي الثيم واللغة في شاشة
/// اختيار النوع. المختار أكبر وأوضح، والآخر أصغر وأخفت.
class _MethodToggle extends StatelessWidget {
  final bool isPhoneMode;
  final ValueChanged<bool> onChanged;
  final SurfacePalette palette;
  final String phoneLabel;
  final String emailLabel;

  const _MethodToggle({
    required this.isPhoneMode,
    required this.onChanged,
    required this.palette,
    required this.phoneLabel,
    required this.emailLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MethodIcon(
          selected: isPhoneMode,
          outlined: Icons.phone_outlined,
          solid: Icons.phone,
          tooltip: phoneLabel,
          palette: palette,
          onTap: () => onChanged(true),
        ),
        const SizedBox(width: 2),
        _MethodIcon(
          selected: !isPhoneMode,
          outlined: Icons.mail_outlined,
          solid: Icons.mail,
          tooltip: emailLabel,
          palette: palette,
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}

class _MethodIcon extends StatelessWidget {
  final bool selected;
  final IconData outlined;
  final IconData solid;
  final String tooltip;
  final SurfacePalette palette;
  final VoidCallback onTap;

  const _MethodIcon({
    required this.selected,
    required this.outlined,
    required this.solid,
    required this.tooltip,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        containedInkWell: true,
        highlightShape: BoxShape.circle,
        splashColor: palette.textPrimary.withValues(alpha: 0.08),
        highlightColor: palette.textPrimary.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: selected ? 1.0 : 0.0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) {
              return Transform.scale(
                scale: 1.0 + 0.22 * v,
                child: Icon(
                  selected ? solid : outlined,
                  size: 21,
                  color: Color.lerp(
                    palette.textSecondary.withValues(alpha: 0.55),
                    palette.textPrimary,
                    v,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// زر الإجراء الرئيسي: تدرّج حسب دور الحساب وظل خفيف جداً، وينضغط قليلاً عند
/// اللمس. أثناء التحميل يعرض مؤشراً بدل النص (لا نص قابل للضغط).
class _PrimaryActionButton extends StatefulWidget {
  final bool isBusy;
  final bool isArabic;
  final String label;
  final Gradient gradient;
  final Color glow;
  final VoidCallback onTap;

  const _PrimaryActionButton({
    required this.isBusy,
    required this.isArabic,
    required this.label,
    required this.gradient,
    required this.glow,
    required this.onTap,
  });

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.isBusy ? null : widget.onTap,
      child: AnimatedScale(
        scale: _pressed && !widget.isBusy ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 54,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: widget.glow,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: widget.isBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                : Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: widget.isArabic ? 'Cairo' : 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
