import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_cubit.dart';
import '../../core/auth/home_route.dart';
import '../../core/auth/otp_error_mapper.dart';
import '../../core/auth/phone_utils.dart';
import '../../core/settings/app_settings_cubit.dart';
import '../../core/settings/app_settings_state.dart';
import '../../l10n/app_localizations.dart';
import 'otp_cooldown_store.dart';

enum OtpMode { signup, changeNumber, forgot }

/// مسار شاشة التحقق لوضع تغيير الرقم (بلا رقم مسبق → تبدأ بإدخال الرقم الجديد).
const String changePhoneRoute = '/otp-verify?mode=change-number';

/// يترجم قيمة `mode` في الـ query إلى [OtpMode]. أي قيمة غير معروفة → signup،
/// فلا تُخمّن شاشةٌ مسارًا غير مطلوب.
OtpMode otpModeFromQuery(String? modeName) {
  switch (modeName) {
    case 'change-number':
      return OtpMode.changeNumber;
    case 'forgot':
      return OtpMode.forgot;
    default:
      return OtpMode.signup;
  }
}

class OtpScreen extends StatefulWidget {
  final OtpMode mode;
  final String? phone;
  final String? role;

  const OtpScreen({super.key, required this.mode, this.phone, this.role});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const int _codeLength = 6;

  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  final TextEditingController _newPhoneController = TextEditingController();

  String? _phone;
  bool _showPhoneEntry = false;
  bool _isBusy = false;
  String? _errorText;
  Timer? _ticker;
  Duration _cooldown = Duration.zero;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onCodeChanged);

    final initialPhone = widget.phone;
    if (initialPhone == null || initialPhone.isEmpty) {
      _showPhoneEntry = true;
    } else {
      _phone = initialPhone;
      _cooldown = OtpCooldownStore.remainingFor(initialPhone);
      if (_cooldown == Duration.zero) {
        OtpCooldownStore.start(initialPhone);
        _cooldown = OtpCooldownStore.remainingFor(initialPhone);
      }
      _startTicker();
      if (widget.mode == OtpMode.signup || widget.mode == OtpMode.forgot) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _codeFocusNode.requestFocus();
        });
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    _codeFocusNode.dispose();
    _newPhoneController.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _syncCooldown());
  }

  void _syncCooldown() {
    if (!mounted || _phone == null || _phone!.isEmpty) return;
    final remaining = OtpCooldownStore.remainingFor(_phone!);
    if (remaining != _cooldown) setState(() => _cooldown = remaining);
    if (_cooldown <= Duration.zero) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  String _maskedPhone(String phone) {
    if (phone.length < 4) return phone;
    final tail = phone.substring(phone.length - 4);
    return phone.length == 11 ? '•••• ••• $tail' : '•••• $tail';
  }

  void _onCodeChanged() {
    if (!mounted || _isBusy) return;
    final code = _codeController.text;
    if (code.isNotEmpty) {
      setState(() {
        if (_errorText != null) _errorText = null;
      });
    } else {
      // إعادة الرسم لعرض الصناديق فارغة دون محو رسالة الخطأ الحالية.
      setState(() {});
    }
    if (code.length == _codeLength) {
      _verify();
    }
  }

  void _resetCode() {
    _codeController.clear();
    _codeFocusNode.requestFocus();
  }

  Future<void> _verify() async {
    final phone = _phone;
    if (_isBusy || phone == null || phone.isEmpty) return;
    final code = _codeController.text.trim();
    if (code.length != _codeLength) return;

    final l10n = AppLocalizations.of(context);
    setState(() {
      _isBusy = true;
      _errorText = null;
    });
    final cubit = context.read<AuthCubit>();
    try {
      if (widget.mode == OtpMode.forgot) {
        await cubit.verifyForgotPasswordOtp(localPhone: phone, otp: code);
      } else {
        await cubit.verifyPhoneOtp(localPhone: phone, otp: code);
      }
      if (!mounted) return;
      await _onVerified(cubit);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorText = mapOtpError(e, l10n);
      });
      _resetCode();
    }
  }

  Future<void> _onVerified(AuthCubit cubit) async {
    if (widget.mode != OtpMode.forgot) {
      // مزامنة الرقم مع profiles عملية جهد أفضل — فشلها لا يمنع الدخول لأن
      // GoTrue يُعدِّل phone موثقًا في auth.users من تلقاء نفسه. في مسار
      // الاستعادة الرقم معلوم وموثّق أصلًا فلا شأن للمزامنة هنا.
      try {
        await cubit.syncPhoneToProfile(_phone!);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _isBusy = false);

    switch (widget.mode) {
      case OtpMode.signup: {
        // يُمرَّر الدور بنصه الفعلي في قاعدة البيانات (car_owner/provider)،
        // ويُترجَم هنا إلى المسار المسجّل عبر الدالة الموحّدة — بدلاً من بناء
        // مسار /home/$role قد لا يكون له مقابل في الـ router. بدون دور صالح
        // لا نتنقل (بدل افتراض car_owner بصمت).
        //
        // بوابة توثيق الهاتف توجّه لجلسة غير موثّقة إلى هذه الشاشة بلا دور في
        // الـ query؛ في هذه الحالة نقرأ الدور الحقيقي من الخادم قبل التنقل حتى
        // لا يبقى المستخدم عالقًا بلا توجيه بعد نجاح التحقق.
        var role = widget.role;
        if (homeRouteForRole(role) == null) {
          role = await cubit.resolveCurrentRole();
          if (!mounted) return;
        }
        final homeRoute = homeRouteForRole(role);
        if (homeRoute != null) context.go(homeRoute);
      }
      case OtpMode.changeNumber:
        context.pop();
      case OtpMode.forgot:
        // نجح التحقق → جلسة دخول صالحة → شاشة تعيين كلمة مرور جديدة.
        context.go('/set-new-password');
    }
  }

  Future<void> _onResendPressed() async {
    final phone = _phone;
    if (_isBusy || phone == null || phone.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isBusy = true;
      _errorText = null;
    });
    try {
      final cubit = context.read<AuthCubit>();
      if (widget.mode == OtpMode.forgot) {
        await cubit.resendForgotPasswordOtp(phone);
      } else {
        await cubit.resendPhoneOtp(phone);
      }
      if (!mounted) return;
      OtpCooldownStore.start(phone);
      setState(() {
        _isBusy = false;
        _cooldown = OtpCooldownStore.remainingFor(phone);
      });
      _startTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorText = mapOtpError(e, l10n);
      });
    }
  }

  Future<void> _onNewPhoneSubmit() async {
    if (_isBusy) return;
    final raw = _newPhoneController.text.trim();
    final l10n = AppLocalizations.of(context);
    if (!PhoneUtils.isValidEgyptianMobile(raw)) {
      setState(() {
        _errorText = l10n?.enterValidEgyptianPhone ?? 'أدخل رقم هاتف مصري صحيح';
      });
      return;
    }

    final normalized = PhoneUtils.normalize(raw);
    setState(() {
      _isBusy = true;
      _errorText = null;
    });
    try {
      // وضع الاستعادة يُرسل كود دخول SMS للرقم؛ وضع تغيير الرقم يربط الرقم
      // بحساب المستخدم الحالي. كلاهما يفتح شاشة الكود بعد النجاح.
      final cubit = context.read<AuthCubit>();
      if (widget.mode == OtpMode.forgot) {
        await cubit.requestForgotPasswordOtp(normalized);
      } else {
        // فحص تفرّد مسبق: لا نرسل كودًا لرقم مملوك لحساب آخر (تفادي إهدار SMS).
        // مسار تغيير الرقم يفشل مُغلقًا: أي خطأ/انتهاء مهلة/حدّ معدّل في الفحص
        // يعني أن التفرّد لم يُتحقَّق منه ⇒ لا نرسل الكود ولا نربط الرقم.
        final isChangeNumber = widget.mode == OtpMode.changeNumber;
        String? ownerEmail;
        var lookupFailed = false;
        try {
          ownerEmail = await cubit.emailForPhone(normalized);
        } catch (e) {
          lookupFailed = true;
          if (isChangeNumber) {
            setState(() {
              _isBusy = false;
              _errorText = mapChangePhoneLookupError(e, l10n);
            });
            return;
          }
          // مسار التسجيل (بلا رقم مسبق) يبقى على سلوكه السابق: فشل الفحص لا
          // يحجب المستخدم — الحارس الخادمي (PHONE_CHANGE_REQUIRES_OTP + قيد
          // التفرّد) خط الدفاع الأخير.
        }
        if (!lookupFailed &&
            ownerEmail != null &&
            ownerEmail != cubit.currentUserEmail) {
          setState(() {
            _isBusy = false;
            _errorText = l10n?.phoneAlreadyRegistered ??
                'رقم الهاتف مسجل بالفعل لدى مستخدم آخر';
          });
          return;
        }
        await cubit.attachPhone(normalized);
      }
      if (!mounted) return;
      OtpCooldownStore.start(normalized);
      setState(() {
        _phone = normalized;
        _showPhoneEntry = false;
        _isBusy = false;
        _cooldown = OtpCooldownStore.remainingFor(normalized);
        _codeController.clear();
      });
      _startTicker();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _codeFocusNode.requestFocus();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorText = mapOtpError(e, l10n);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppSettingsCubit, AppSettingsState>(
      builder: (context, settings) {
        final isArabic = settings.locale.languageCode == 'ar';
        final isDarkMode = settings.themeMode == ThemeMode.dark;
        final l10n = AppLocalizations.of(context);

        return Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
          appBar: AppBar(
            backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_rounded,
                color: isDarkMode ? Colors.white : const Color(0xFF1E1E1E),
              ),
              onPressed: () => context.pop(),
            ),
            title: Text(
              l10n?.otpTitle ?? 'تأكيد رقم الهاتف',
              style: TextStyle(
                fontFamily: isArabic ? 'Cairo' : 'Poppins',
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : const Color(0xFF1E1E1E),
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _showPhoneEntry
                  ? _buildPhoneEntry(isArabic, isDarkMode, l10n)
                  : _buildCodeEntry(isArabic, isDarkMode, l10n),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCodeEntry(
      bool isArabic, bool isDarkMode, AppLocalizations? l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          l10n?.otpTitle ?? 'تأكيد رقم الهاتف',
          style: TextStyle(
            fontFamily: isArabic ? 'Zain' : 'Poppins',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFF6B00),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n?.otpCodeSentTo(_maskedPhone(_phone ?? '')) ??
              'أدخل الرمز المكوّن من 6 أرقام الذي أُرسل إلى ${_maskedPhone(_phone ?? '')}',
          style: TextStyle(
            fontFamily: isArabic ? 'Cairo' : 'Poppins',
            fontSize: 14,
            color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: () => _codeFocusNode.requestFocus(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < _codeLength; i++)
                    _buildDigitBox(
                      i,
                      digit: _codeController.text.length > i
                          ? _codeController.text[i]
                          : '',
                      isDarkMode: isDarkMode,
                      hasError: _errorText != null,
                    ),
                ],
              ),
              Opacity(
                opacity: 0,
                child: TextField(
                  key: const ValueKey('otp_hidden_field'),
                  controller: _codeController,
                  focusNode: _codeFocusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_codeLength),
                  ],
                  style: const TextStyle(fontSize: 20),
                  decoration: const InputDecoration.collapsed(hintText: ''),
                ),
              ),
            ],
          ),
        ),
        if (_isBusy) ...[
          const SizedBox(height: 20),
          const LinearProgressIndicator(
            minHeight: 2,
            color: Color(0xFFFF6B00),
            backgroundColor: Color(0x33FF6B00),
          ),
        ],
        if (_errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              _errorText!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: Color(0xFFE53935),
                height: 1.5,
              ),
            ),
          ),
        const SizedBox(height: 24),
        Column(
          children: [
            Text(
              l10n?.didNotReceiveCode ?? 'لم يصلك الرمز؟',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            if (_cooldown > Duration.zero)
              Text(
                l10n?.resendCodeIn(_cooldown.inSeconds) ??
                    'إعادة الإرسال بعد ${_cooldown.inSeconds} ثانية',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: Color(0xFFFF6B00),
                ),
              )
            else
              OutlinedButton(
                onPressed: _isBusy ? null : _onResendPressed,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFF6B00)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  l10n?.resendCode ?? 'إعادة إرسال الرمز',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6B00),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _showPhoneEntry = true;
              _errorText = null;
            }),
            child: Text(
              l10n?.useAnotherNumber ?? 'استخدام رقم آخر',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: Color(0xFFFF6B00),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDigitBox(int index, {required String digit, required bool isDarkMode, required bool hasError}) {
    return Container(
      width: 46,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white10 : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError
              ? const Color(0xFFE53935)
              : _codeController.text.length == index && !_isBusy
                  ? const Color(0xFFFF6B00)
                  : Colors.transparent,
          width: 1.6,
        ),
      ),
      child: Text(
        digit,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildPhoneEntry(
      bool isArabic, bool isDarkMode, AppLocalizations? l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          widget.mode == OtpMode.forgot
              ? (l10n?.resetPasswordTitle ?? 'استعادة كلمة المرور')
              : (l10n?.changeNumberTitle ?? 'تغيير رقم الهاتف'),
          style: TextStyle(
            fontFamily: isArabic ? 'Zain' : 'Poppins',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFF6B00),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.mode == OtpMode.forgot
              ? (l10n?.forgotPhoneEntrySubtitle ??
                  'أدخل رقم الهاتف المرتبط بحسابك وسنرسل إليه رمز تحقق')
              : (l10n?.changeNumberSubTitle ??
                  'أدخل رقم الهاتف الجديد وسنرسل إليه رمز تحقق'),
          style: TextStyle(
            fontFamily: isArabic ? 'Cairo' : 'Poppins',
            fontSize: 14,
            color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _newPhoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(15),
          ],
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            labelText: l10n?.phoneNumber ?? 'رقم الهاتف',
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
            hintText: '01xxxxxxxxx',
            hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
            filled: true,
            fillColor: isDarkMode ? Colors.white10 : const Color(0xFFF3F4F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.4),
            ),
            errorText: _errorText,
            errorMaxLines: 2,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        if (_isBusy) ...[
          const SizedBox(height: 20),
          const LinearProgressIndicator(
            minHeight: 2,
            color: Color(0xFFFF6B00),
            backgroundColor: Color(0x33FF6B00),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _isBusy ? null : _onNewPhoneSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              l10n?.sendCode ?? 'إرسال الرمز',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}