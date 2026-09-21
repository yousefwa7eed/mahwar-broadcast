import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mahwar/core/auth/auth_service.dart';

/// خدمة مصغّرة تحاكي تدفق OTP الخاص بهاتف Mahwar بدون أي شبكة أو SMS.
/// كل عملية تُسجِّل عدّادًا قابلاً للفحص في الاختبار، ويمكن حقن أخطاء
/// معلّبة لكل عملية عبر الحقول العامة.
class FakeAuthService extends AuthService {
  User? user;
  String expectedOtp = '123456';

  /// خريطة (رقم محلي → إيميل) يستخدمها resolveEmail للرقم،
  /// ومحاكاة لجدول get_email_by_phone في السيرفر.
  final Map<String, String> emailByPhone = {};

  /// قــاعدة fallback لـ resolveEmail مع الإيميل: يُرجَع الإيميل نفسه.
  String normalizeEmail(String input) => input.trim().toLowerCase();

  Object? attachError;
  Object? verifyError;
  Object? resendError;
  Object? forgotOtpError;
  Object? forgotVerifyError;
  Object? forgotResendError;
  Object? setPasswordError;

  int attachCount = 0;
  int verifyCount = 0;
  int resendCount = 0;
  int syncCount = 0;
  int forgotOtpCount = 0;
  int forgotVerifyCount = 0;
  int forgotResendCount = 0;
  int setPasswordCount = 0;

  String? attachedPhone;
  String? lastVerifiedPhone;
  String? syncedPhone;
  String? lastForgotOtpPhone;
  String? lastForgotVerifiedPhone;
  String? lastForgotResendPhone;
  String? lastSetPassword;
  final List<String> verifiedOtps = [];
  final List<String> verifiedForgotOtps = [];

  /// الأرقام المحلية المصريّة التي لها حسابات مؤكَّدة فعليًا. أي طلب
  /// استعادة لرقم خارجها يحاكي رد GoTrue: user_not_found. تُستخدم لضمان
  /// أن كود الاستعادة يصل فقط للحسابات الموجودة.
  final Set<String> confirmedPhones = {};

  @override
  User? get currentUser => user;

  @override
  Session? get currentSession => null;

  /// بثّ قابلٍ للتحكم لأحداث حالة الدخول — للاختبارات التي تريد محاكاة
  /// onAuthStateChange الحقيقي من GoTrue (مثل تنقل شاشة الدخول بعد التحقق
  /// من OTP). الافتراضي لا يبث شيئًا فيبقى سلوك بقية الاختبارات كما هو.
  final StreamController<AuthState> authStateController =
      StreamController<AuthState>.broadcast();

  @override
  Stream<AuthState> get authStateChanges => authStateController.stream;

  @override
  Future<String?> getUserRole() async => user?.userMetadata?['role'] as String?;

  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String role,
    required String fullName,
    required String phoneNumber,
    String? nationalId,
    String? workshopName,
    String? address,
    double? latitude,
    double? longitude,
    String? supportScope,
    bool? hasVehicle,
    String? vehicleSpecs,
    String? vehicleMake,
    String? vehicleModel,
    int? vehicleYear,
    String? vehiclePlate,
    String? vehicleColor,
    List<String>? specializations,
    String? carMake,
    String? carModel,
    int? carYear,
  }) async {
    user = User(
      id: 'fake-user-id',
      appMetadata: const {},
      userMetadata: {
        'role': role,
        'full_name': fullName,
        'phone_number': phoneNumber,
      },
      aud: 'authenticated',
      createdAt: 'now',
      email: email,
    );
    return AuthResponse(user: user!, session: null);
  }

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {
    user = null;
  }

  @override
  Future<String?> resolveEmail(String identifier) async {
    final value = identifier.trim();
    if (value.isEmpty) return null;
    if (value.contains('@')) return normalizeEmail(value);
    final phone = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return emailByPhone[phone.startsWith('0') ? phone : '0${phone.substring(3)}'];
  }

  @override
  Future<void> requestForgotPasswordOtp(String localPhone) async {
    forgotOtpCount++;
    if (forgotOtpError != null) throw forgotOtpError!;
    // محاكاة رد GoTrue signInWithOtp(shouldCreateUser: false): الرقم غير
    // المسجّل مرفوض برمز user_not_found قبل إرسال أي SMS.
    if (!confirmedPhones.contains(localPhone)) {
      throw AuthApiException('No user found for this phone',
          code: 'user_not_found');
    }
    lastForgotOtpPhone = localPhone;
  }

  @override
  Future<void> verifyForgotPasswordOtp({
    required String localPhone,
    required String otp,
  }) async {
    forgotVerifyCount++;
    if (forgotVerifyError != null) throw forgotVerifyError!;
    lastForgotVerifiedPhone = localPhone;
    verifiedForgotOtps.add(otp);
    if (otp != expectedOtp) {
      throw AuthApiException('OTP expired', code: 'otp_expired');
    }
  }

  @override
  Future<void> resendForgotPasswordOtp(String localPhone) async {
    forgotResendCount++;
    if (forgotResendError != null) throw forgotResendError!;
    if (!confirmedPhones.contains(localPhone)) {
      throw AuthApiException('No user found for this phone',
          code: 'user_not_found');
    }
    lastForgotResendPhone = localPhone;
  }

  @override
  Future<void> setNewPassword(String newPassword) async {
    setPasswordCount++;
    if (setPasswordError != null) throw setPasswordError!;
    lastSetPassword = newPassword;
  }

  @override
  Future<String?> getUserName() async =>
      user?.userMetadata?['full_name'] as String?;

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> attachPhone(String localPhone) async {
    attachCount++;
    if (attachError != null) throw attachError!;
    attachedPhone = localPhone;
  }

  @override
  Future<void> verifyPhoneOtp({
    required String localPhone,
    required String otp,
  }) async {
    verifyCount++;
    if (verifyError != null) throw verifyError!;
    lastVerifiedPhone = localPhone;
    verifiedOtps.add(otp);
    if (otp != expectedOtp) {
      throw AuthApiException('OTP expired', code: 'otp_expired');
    }
  }

  @override
  Future<void> resendPhoneOtp(String localPhone) async {
    resendCount++;
    if (resendError != null) throw resendError!;
  }

  @override
  Future<void> syncPhoneToProfile(String localPhone) async {
    syncCount++;
    syncedPhone = localPhone;
  }
}