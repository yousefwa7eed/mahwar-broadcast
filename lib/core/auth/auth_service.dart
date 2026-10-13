import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'phone_utils.dart';

abstract class AuthService {
  /// مراقبة (A3): عدد مرات فشل تصفير profiles.fcm_token عند الخروج.
  /// لو استمر في الزيادة فهناك أجهزة بقيت مرتبطة بحسابات خرجت.
  static int fcmTokenClearFailureCount = 0;

  User? get currentUser;
  Session? get currentSession;
  Stream<AuthState> get authStateChanges;

  Future<String?> getUserRole();

  /// يتحقق من صلاحية الجلسة الحالية لدى الخادم (`auth.getUser`) ويعيد المستخدم
  /// الخادمي. يرمي [AuthException] عند انتهاء/بطلان التوكن. تُرجع null إذا لم
  /// يكن هناك مستخدم.
  Future<User?> getServerUser();

  /// الدور من جدول `profiles.role` فقط — المصدر الموثوق الوحيد للتوجيه
  /// والـ Authorization. تُرجع null عند أي فشل أو غياب مستخدم، بلا أي رجوع
  /// إلى `user_metadata` (حتى لا يُوجَّه المزوّد إلى رئيسية مالك السيارة).
  Future<String?> getServerRole();

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
  });

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signOut();

  /// يسحب الجلسة من الجهاز محليًا فقط (بدون إبطال لدى الخادم) — احتياطي
  /// يُستخدم عند فشل [signOut] الشبكي/مهلة الـ best-effort حتى لا يبقى
  /// الجهاز مسجّل دخول أبدًا.
  Future<void> clearLocalSession();

  /// مسار رفض الجلسة من نقطة دخول مقيّدة بالدور: ينظّف الجهاز/الخادم ثم يُبطل
  /// الجلسة لدى الخادم فقط إن بقيت هي نفسها (لا يُبطل جلسة جديدة أنشأها
  /// المستخدم بعد الرفض). منفصل عن [signOut] حتى يبقى سلوك الخروج العادي كما هو.
  Future<void> signOutFromRejection();

  /// تنظيف الخروج الخلفي بعد خروج محلي فوري (استدعاء بلا انتظار من منسّق
  /// الخروج): يصفّر fcm_token لصفّ المستخدم القديم — يُبدأ قبل سحب الجلسة
  /// المحلية فيلتقط الطلب رمز الوصول الصالح لحظيًا — ويفصل الجهاز من FCM،
  /// ثم يُبطل الجلسة القديمة لدى الخادم عبر `signOut(scope: global)` الذي
  /// يلتقط توكنها متزامنًا قبل مسحها محليًا (لا يمسّ جلسة جديدة إن سجّل
  /// المستخدم دخولًا مرة أخرى). لا يمسّ الجلسة المحلية إطلاقًا بعد البدء.
  Future<void> signOutInBackground(String? oldUserId);

  /// يحوّل identifier (إيميل أو رقم هاتف محلي) إلى الإيميل الحقيقي المرتبط
  /// بالحساب. يعيد null عندما يكون الإدخال فارغًا أو لا يوجد حساب مرتبط.
  Future<String?> resolveEmail(String identifier);

  /// يضبط كلمة مرور جديدة للمستخدم الحالي (جلسة دخول OTP من استعادة كلمة المرور).
  Future<void> setNewPassword(String newPassword);

  /// يرسل كود OTP لتسجيل الدخول عبر SMS (استعادة كلمة المرور) إلى الرقم المحلي.
  /// [shouldCreateUser] = false في الخدمة حتى يرفض GoTrue الأرقام غير المسجّلة.
  Future<void> requestForgotPasswordOtp(String localPhone);

  /// يتحقق من كود OTP الخاص باستعادة كلمة المرور (OtpType.sms). يُنجز الدخول
  /// الفعلي (جلسة) عند النجاح فينسدل مسار تعيين كلمة مرور جديدة.
  Future<void> verifyForgotPasswordOtp({required String localPhone, required String otp});

  /// يعيد إرسال كود OTP الخاص باستعادة كلمة المرور.
  Future<void> resendForgotPasswordOtp(String localPhone);

  Future<String?> getUserName();
  Future<void> deleteAccount();

  /// يربط رقم هاتف محلي (01xxxxxxxxx) بحساب المستخدم الحالي ويفعّل إرسال
  /// كود التحقق (phoneChange OTP) إليه.
  Future<void> attachPhone(String localPhone);

  /// يتحقق من كود OTP المرسل إلى الرقم المذكور (OtpType.phoneChange).
  Future<void> verifyPhoneOtp({required String localPhone, required String otp});

  /// يعيد إرسال كود OTP الخاص بتفعيل الرقم.
  Future<void> resendPhoneOtp(String localPhone);

  /// يزامن الرقم المؤكَّد محليًا في جدول profiles.
  Future<void> syncPhoneToProfile(String localPhone);
}

class SupabaseAuthService extends AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  User? get currentUser => _client.auth.currentUser;
  @override
  Session? get currentSession => _client.auth.currentSession;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  Future<String?> getUserRole() async {
    if (currentUser == null) return null;

    final response = await _client
        .from('profiles')
        .select('role')
        .eq('id', currentUser!.id)
        .maybeSingle();

    return response?['role'] as String?;
  }

  @override
  Future<User?> getServerUser() async {
    final res = await _client.auth.getUser();
    return res.user;
  }

  @override
  Future<String?> getServerRole() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final response = await _client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      return response?['role'] as String?;
    } catch (_) {
      // فشل قراءة الدور من الخادم → null. لا رجوع إلى user_metadata إطلاقًا.
      return null;
    }
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
    String? carMake,
    String? carModel,
    int? carYear,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'role': role,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'national_id': nationalId,
        'specializations': specializations,
        'workshop_name': workshopName,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'support_scope': supportScope,
        'has_vehicle': hasVehicle,
        'vehicle_specs': vehicleSpecs,
        'vehicle_make': vehicleMake,
        'vehicle_model': vehicleModel,
        'vehicle_year': vehicleYear,
        'vehicle_plate': vehiclePlate,
        'vehicle_color': vehicleColor,
        'car_make': carMake,
        'car_model': carModel,
        'car_year': carYear,
      },
    );
  }

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signOut() async {
    final userId = _client.auth.currentUser?.id;
    await _cleanupDevice(userId);
    // مسار الخروج العادي: الإبطال العام يبقى دائمًا (بلا حارس) — سلوك غير مُتغيّر.
    await _client.auth.signOut();
  }

  @override
  Future<void> signOutFromRejection() async {
    final userId = _client.auth.currentUser?.id;
    await _cleanupDevice(userId);
    // الحارس هنا فقط: لا نُبطل إن تغيّرت الجلسة (تسجيل دخول جديد بعد الرفض).
    if (userId != null && _client.auth.currentUser?.id == userId) {
      await _client.auth.signOut();
    }
  }

  /// فصل ارتباط الجهاز بالحساب (fcm_token + device_id + توكن FCM + الـ topics)
  /// بأفضل جهد. لا يمسّ الجلسة المحلية. فشل أي خطوة يُسجَّل ولا يُوقف الباقي.
  Future<void> _cleanupDevice(String? userId) async {
    if (userId == null) return;
    try {
      await _client
          .from('profiles')
          .update({'fcm_token': null, 'device_id': null})
          .eq('id', userId);
    } catch (e) {
      AuthService.fcmTokenClearFailureCount++;
      debugPrint(
        '[AuthService] FCM_TOKEN_CLEAR_FAILED '
        '(count=${AuthService.fcmTokenClearFailureCount}, userId=$userId): $e '
        '- proceeding with signOut; device may still receive this account notifications.',
      );
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('[AuthService] FCM deleteToken failed: $e');
    }
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic('car_owners');
      await FirebaseMessaging.instance.unsubscribeFromTopic('providers');
    } catch (e) {
      debugPrint('[AuthService] FCM topic unsubscribe failed: $e');
    }
  }

  @override
  Future<void> clearLocalSession() async {
    // `SignOutScope.local`: يزيل الجلسة من الجهاز (ويبث signedOut) ويطلب
    // إبطالها لدى الخادم بأفضل جهد — إن فشل الطلب الشبكي تبقى المحلية مُسحوبة.
    await _client.auth.signOut(scope: SignOutScope.local);
  }

  /// مهلة قصيرة لكل خطوة من تنظيف الخروج الخلفي، حتى لا تُعلّق العملية
  /// بلا فائدة عند بطء الشبكة/انقطاعها (كل خطوة تُنتظَر مع مهلة).
  static const Duration _backgroundStepTimeout = Duration(seconds: 3);

  @override
  Future<void> signOutInBackground(String? oldUserId) async {
    // بداية متزامنة قبل أي await — طالما الجلسة المحلية القديمة ما زالت
    // قائمة يلتقط gotrue توكنها متزامنًا (انظر أدناه). كل خطوة تُنتظَر
    // ووراءها مهلة حتى لا تُعلّق العملية عند بطء الشبكة/انقطاعها.
    //
    // 1) مسح fcm_token + device_id لصفّ المستخدم القديم: يقرأ
    //    Postgrest/AuthHttpClient توكن الجلسة الحالية متزامنًا لحظة إطلاق
    //    الطلب، فيلتقط التوكن الصالح قبل أي مسح محلي. فشله يُسجَّل فقط
    //    (لا يمنع الخروج المحلي).
    if (oldUserId != null) {
      try {
        await _client
            .from('profiles')
            .update({'fcm_token': null, 'device_id': null})
            .eq('id', oldUserId)
            .timeout(_backgroundStepTimeout);
      } catch (e) {
        AuthService.fcmTokenClearFailureCount++;
        debugPrint(
          '[AuthService] background FCM_TOKEN_CLEAR_FAILED '
          '(count=${AuthService.fcmTokenClearFailureCount}, userId=$oldUserId): $e',
        );
      }
    }
    // 2) إبطال الجلسة القديمة لدى الخادم: `signOut(scope: global)` يقرأ
    //    `currentSession` متزامنًا في أول سطر له، فيلتقط توكن الجلسة
    //    القديمة، يمسح الجلسة المحلية محليًا، ثم يستدعي /logout بالتوكن
    //    القديم نفسه (بدون مفتاح خدمة/أدمن). بعد ذلك لا يمسّ gotrue
    //    `currentSession` أبدًا — جلسة إعادة الدخول أثناء الشبكة تبقى سليمة.
    //    هذه الخطوة وحدها تنقل نجاح الخروج إلى المنسّق؛ فشلها يُرمى فيمنع
    //    عرض رسالة الخروج (الخروج المحلي تم فعلًا).
    await _client.auth
        .signOut(scope: SignOutScope.global)
        .timeout(_backgroundStepTimeout);
    // 3) فصل الجهاز من FCM — لا يحتاج جلسة. أفضل جهد.
    try {
      await FirebaseMessaging.instance.deleteToken().timeout(_backgroundStepTimeout);
    } catch (e) {
      debugPrint('[AuthService] background FCM deleteToken failed: $e');
    }
    try {
      await FirebaseMessaging.instance
          .unsubscribeFromTopic('car_owners')
          .timeout(_backgroundStepTimeout);
      await FirebaseMessaging.instance
          .unsubscribeFromTopic('providers')
          .timeout(_backgroundStepTimeout);
    } catch (e) {
      debugPrint('[AuthService] background FCM topic unsubscribe failed: $e');
    }
  }

  /// يحوّل رقمًا محليًا (01012345678) إلى الصيغة الدولية التي تتطلبها GoTrue
  /// (+201012345678).
  static String _toInternational(String localPhone) => '+20${localPhone.substring(1)}';

  @override
  Future<void> attachPhone(String localPhone) async {
    await _client.auth.updateUser(UserAttributes(phone: _toInternational(localPhone)));
  }

  @override
  Future<void> verifyPhoneOtp({required String localPhone, required String otp}) async {
    await _client.auth.verifyOTP(
      type: OtpType.phoneChange,
      phone: _toInternational(localPhone),
      token: otp,
    );
  }

  @override
  Future<void> resendPhoneOtp(String localPhone) async {
    await _client.auth.resend(
      type: OtpType.phoneChange,
      phone: _toInternational(localPhone),
    );
  }

  @override
  Future<void> syncPhoneToProfile(String localPhone) async {
    // مزامنة الرقم أصبحت مسؤولية الخادم: مُشغِّل sync_phone_number_from_auth
    // يحدّث profiles.phone_number بعد تأكيد auth.users.phone. لا نكتب مباشرة من
    // العميل لأن الكتابة المباشرة يحظرها الحارس profiles_phone_requires_verified.
  }

  @override
  Future<String?> resolveEmail(String identifier) async {
    final value = identifier.trim();
    if (value.isEmpty) return null;

    // إيميل → نستخدمه مباشرة (مقصوص الأطراف ومنزوع الحروف الكبيرة).
    if (value.contains('@')) return value.toLowerCase();

    // رقم هاتف محلي → استعلام RPC عن الإيميل المرتبط به.
    final sanitized = PhoneUtils.normalize(value);
    try {
      final response = await _client.rpc(
        'get_email_by_phone',
        params: {'p_phone': sanitized},
      );
      final email = response as String?;
      if (email == null || email.isEmpty) return null;
      return email;
    } catch (e) {
      // لا نبتلع أخطاء الشبكة/الخادم الحقيقية خلف رسالة "لا يوجد حساب" عامة.
      rethrow;
    }
  }

  @override
  Future<void> setNewPassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Future<void> requestForgotPasswordOtp(String localPhone) async {
    await _client.auth.signInWithOtp(
      phone: _toInternational(localPhone),
      shouldCreateUser: false,
    );
  }

  @override
  Future<void> verifyForgotPasswordOtp({
    required String localPhone,
    required String otp,
  }) async {
    await _client.auth.verifyOTP(
      type: OtpType.sms,
      phone: _toInternational(localPhone),
      token: otp,
    );
  }

  @override
  Future<void> resendForgotPasswordOtp(String localPhone) async {
    await _client.auth.resend(
      type: OtpType.sms,
      phone: _toInternational(localPhone),
    );
  }

  @override
  Future<String?> getUserName() async {
    if (currentUser == null) return null;

    final response = await _client
        .from('profiles')
        .select('full_name')
        .eq('id', currentUser!.id)
        .maybeSingle();

    final name = response?['full_name'] as String?;
    if (name != null && name.isNotEmpty) return name;

    return currentUser!.userMetadata?['full_name'] as String?;
  }

  @override
  Future<void> deleteAccount() async {
    final session = _client.auth.currentSession;
    if (session == null) throw Exception('No active session');

    final response = await _client.functions.invoke(
      'delete-account',
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
      },
    );

    if (response.status != 200) {
      final body = response.data;
      throw Exception(body?['error'] ?? 'Failed to delete account');
    }

    await _client.auth.signOut();
  }
}

/// الدور الحقيقي للمستخدم المسجّل من `profiles.role` (المصدر الموثوق) بلا بناء
/// `AuthCubit` — كان `PushNotificationService` يبني cubitًا رميًا لكل نداء
/// فيسجّل اشتراكًا في تدفق المصادقة لا يُلغى أبدًا (تسريب مستمعين). نفس منطق
/// `AuthCubit.resolveCurrentRole` بالضبط. تُرجع null عند غياب مستخدم مسجّل أو
/// تعذّر تحديد الدور من الخادم.
Future<String?> resolveCurrentUserRole(AuthService service) async {
  if (service.currentUser == null) return null;
  return service.getServerRole();
}
