import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mahwar/core/auth/auth_service.dart';

/// خدمة مصغّرة تحاكي تدفق OTP الخاص بهاتف Mahwar بدون أي شبكة أو SMS.
/// كل عملية تُسجِّل عدّادًا قابلاً للفحص في الاختبار، ويمكن حقن أخطاء
/// معلّبة لكل عملية عبر الحقول العامة.
class FakeAuthService extends AuthService {
  User? user;
  String expectedOtp = '123456';

  /// المستخدم العائد من `getServerUser` (تحقّق الخادم). منفصل عن [user] حتى
  /// تحاكي الاختبارات جلسة محلية موجودة لكنها منتهية/ملغاة لدى الخادم.
  User? serverUser;

  /// إن كان مضبوطًا فإن `getServerUser` يرميه (جلسة منتهية/ملغاة/فشل شبكة).
  Object? serverUserError;

  /// الدور العائد من `getServerRole` (جدول profiles). null = فشل/غياب الدور.
  String? serverRole;

  /// إن كان مضبوطًا فإن `getServerRole` يرميه قبل إرجاع [serverRole].
  Object? serverRoleError;

  /// حالة توثيق الهاتف العائدة من `getMyPhoneVerified`. الافتراضي `true`
  /// (موثّق) حتى لا تتأثر اختبارات لا تعنى ببوابة التوثيق.
  bool phoneVerified = true;

  /// إن كان مضبوطًا فإن `getMyPhoneVerified` يرميه (محاكاة فشل شبكة).
  Object? phoneVerifiedError;

  int phoneVerifiedCount = 0;

  /// تأخير مُصطنع في `getServerRole` لمحاكاة انتهاء المهلة في شاشة الإقلاع.
  Duration? serverRoleDelay;

  /// تأخيرات `getServerRole` بالترتيب (تُستهلك من الأمام)؛ ما زاد يرجع إلى
  /// [serverRoleDelay] أو بلا تأخير. تُستخدم لاختبار إعادة المحاولة بعد المهلة.
  final List<Duration> serverRoleDelays = [];

  int serverUserCount = 0;
  int serverRoleCount = 0;

  /// آخر metadata سيارة أُرسلت في [signUpWithEmail] — لاختبار ربط سيارة
  /// المالك بالكتالوج دون شبكة.
  Map<String, dynamic>? lastVehicleMetadata;
  int signOutCount = 0;
  int clearLocalSessionCount = 0;
  int signOutFromRejectionCount = 0;

  /// إن كان مضبوطًا فإن `signOut` يرميه (فشل شبكة/خادم) بعد تمرير التنظيف
  /// المحلي لدى GoTrue (الجلسة المحلية تُسحب قبل الطلب الشبكي).
  Object? signOutError;

  /// تأخير مُصطنع في `signOut` و`signOutFromRejection` لمحاكاة خروج بطيء.
  Duration? signOutDelay;

  /// إن كان مضبوطًا فإن `signOutFromRejection` يرميه.
  Object? signOutFromRejectionError;

  /// إن كان مضبوطًا فإن `clearLocalSession` يرميه.
  Object? clearLocalSessionError;

  /// إن كان مضبوطًا فإن `clearLocalSession` ينتظر إكماله قبل متابعة التنظيف.
  /// يُستخدم لاختبار أن التنظيف المحلي يتحقق قبل الانتقال/الحارس.
  Completer<void>? clearLocalSessionGate;

  /// الجلسة العائدة من `currentSession` (افتراضيًا null = لا جلسة محلية).
  /// تُضبط لاختبار التقاط توكن الجلسة القديمة في الخروج.
  Session? session;

  int signOutInBackgroundCount = 0;

  /// إن كان مضبوطًا فإن `signOutInBackground` يرميه بعد الانتظار —
  /// لمحاكاة فشل الخادم في إبطال الجلسة القديمة.
  Object? signOutInBackgroundError;

  /// إن كان مضبوطًا فإن `signOutInBackground` ينتظر إكماله قبل إكمال نفسه —
  /// لإمساك الخلفية معلّقة أثناء فحص الخروج المحلي الفوري.
  Completer<void>? signOutInBackgroundGate;

  /// خريطة (رقم محلي → إيميل) يستخدمها resolveEmail للرقم،
  /// ومحاكاة لجدول get_email_by_phone في السيرفر.
  final Map<String, String> emailByPhone = {};

  /// قــاعدة fallback لـ resolveEmail مع الإيميل: يُرجَع الإيميل نفسه.
  String normalizeEmail(String input) => input.trim().toLowerCase();

  /// إن كان مضبوطًا فإن `resolveEmail` يرميه عند البحث برقم هاتف — لمحاكاة
  /// فشل/انتهاء مهلة/حدّ معدّل RPC `get_email_by_phone`. لا يؤثر على البحث
  /// بالإيميل.
  Object? resolveEmailError;

  Object? attachError;
  Object? verifyError;
  Object? resendError;
  Object? forgotOtpError;
  Object? forgotVerifyError;
  Object? forgotResendError;
  Object? setPasswordError;

  /// إن كان مضبوطًا فإن `changePassword` يرميه.
  Object? changePasswordError;

  /// إن كان مضبوطًا فإن `deleteAccount` يرميه.
  Object? deleteAccountError;

  int attachCount = 0;
  int verifyCount = 0;
  int resendCount = 0;
  int syncCount = 0;
  int forgotOtpCount = 0;
  int forgotVerifyCount = 0;
  int forgotResendCount = 0;
  int setPasswordCount = 0;
  int changePasswordCount = 0;
  int deleteAccountCount = 0;

  String? lastChangeCurrentPassword;
  String? lastChangeNewPassword;
  String? lastDeletePassword;

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
  Session? get currentSession => session;

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
  Future<User?> getServerUser() async {
    serverUserCount++;
    if (serverUserError != null) throw serverUserError!;
    return serverUser;
  }

  @override
  Future<String?> getServerRole() async {
    serverRoleCount++;
    final delay = serverRoleDelays.isNotEmpty
        ? serverRoleDelays.removeAt(0)
        : serverRoleDelay;
    if (delay != null) await Future<void>.delayed(delay);
    if (serverRoleError != null) throw serverRoleError!;
    return serverRole;
  }

  @override
  Future<bool> getMyPhoneVerified() async {
    phoneVerifiedCount++;
    if (phoneVerifiedError != null) throw phoneVerifiedError!;
    return phoneVerified;
  }

  /// قيمة `isSessionRevoked` المعلّبة: true = محظور، false = سليم،
  /// null = فشل شبكة (لا يجوز أن يُخرج المستخدم). الافتراضي سليم.
  bool? sessionRevoked = false;
  int sessionRevokedCount = 0;

  /// يُبثّ عبره حدث الحظر الفوري لمحاكاة قناة Realtime.
  final StreamController<bool> sessionRevokedController =
      StreamController<bool>.broadcast();
  int watchSessionRevokedCount = 0;

  @override
  Future<bool?> isSessionRevoked(String uid) async {
    sessionRevokedCount++;
    return sessionRevoked;
  }

  @override
  Stream<bool> watchSessionRevoked(String uid) {
    watchSessionRevokedCount++;
    return sessionRevokedController.stream;
  }

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
    Map<String, dynamic>? vehicleMetadata,
  }) async {
    lastVehicleMetadata = vehicleMetadata;
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
    signOutCount++;
    if (signOutDelay != null) await Future<void>.delayed(signOutDelay!);
    if (signOutError != null) throw signOutError!;
    user = null;
  }

  @override
  Future<void> signOutFromRejection() async {
    signOutFromRejectionCount++;
    if (signOutDelay != null) await Future<void>.delayed(signOutDelay!);
    if (signOutFromRejectionError != null) throw signOutFromRejectionError!;
  }

  @override
  Future<void> clearLocalSession() async {
    clearLocalSessionCount++;
    if (clearLocalSessionGate != null) await clearLocalSessionGate!.future;
    if (clearLocalSessionError != null) throw clearLocalSessionError!;
    user = null;
    serverUser = null;
  }

  @override
  Future<String?> resolveEmail(String identifier) async {
    final value = identifier.trim();
    if (value.isEmpty) return null;
    if (value.contains('@')) return normalizeEmail(value);
    if (resolveEmailError != null) throw resolveEmailError!;
    final phone = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return emailByPhone[phone.startsWith('0')
        ? phone
        : '0${phone.substring(3)}'];
  }

  @override
  Future<void> requestForgotPasswordOtp(String localPhone) async {
    forgotOtpCount++;
    if (forgotOtpError != null) throw forgotOtpError!;
    // محاكاة رد GoTrue signInWithOtp(shouldCreateUser: false): الرقم غير
    // المسجّل مرفوض برمز user_not_found قبل إرسال أي SMS.
    if (!confirmedPhones.contains(localPhone)) {
      throw AuthApiException(
        'No user found for this phone',
        code: 'user_not_found',
      );
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
      throw AuthApiException(
        'No user found for this phone',
        code: 'user_not_found',
      );
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
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changePasswordCount++;
    lastChangeCurrentPassword = currentPassword;
    lastChangeNewPassword = newPassword;
    if (changePasswordError != null) throw changePasswordError!;
  }

  @override
  Future<void> deleteAccount({required String currentPassword}) async {
    deleteAccountCount++;
    lastDeletePassword = currentPassword;
    if (deleteAccountError != null) throw deleteAccountError!;
  }

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

  @override
  Future<void> signOutInBackground() async {
    signOutInBackgroundCount++;
    if (signOutDelay != null) await Future<void>.delayed(signOutDelay!);
    if (signOutInBackgroundGate != null) await signOutInBackgroundGate!.future;
    if (signOutInBackgroundError != null) throw signOutInBackgroundError!;
  }
}
