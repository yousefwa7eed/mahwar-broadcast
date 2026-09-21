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
    if (userId != null) {
      // 1) فصل الارتباط على الخادم أولًا. فشله لا يمنع الخروج أبدًا، لكنه
      //    الحلقة الوحيدة التي تُبقي توكن هذا الجهاز مرتبطًا بالحساب — لذلك
      //    يُسجَّل بعلامة مميزة بدل الابتلاع الصامت (A3).
      try {
        await _client.from('profiles').update({'fcm_token': null}).eq('id', userId);
      } catch (e) {
        AuthService.fcmTokenClearFailureCount++;
        debugPrint(
          '[AuthService] FCM_TOKEN_CLEAR_FAILED '
          '(count=${AuthService.fcmTokenClearFailureCount}, userId=$userId): $e '
          '- proceeding with signOut; device may still receive this account notifications.',
        );
      }
      // 2) إبطال التوكن لدى FCM نفسه حتى لا يبقى صالحًا لهذا الجهاز (A2).
      //    أفضل جهد — فشله لا يمنع الخروج أبدًا، ويُسجَّل فقط.
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (e) {
        debugPrint('[AuthService] FCM deleteToken failed: $e');
      }
      // 3) إلغاء اشتراك الـ topics (أفضل جهد، يُسجَّل عند الفشل بدل الابتلاع).
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic('car_owners');
        await FirebaseMessaging.instance.unsubscribeFromTopic('providers');
      } catch (e) {
        debugPrint('[AuthService] FCM topic unsubscribe failed: $e');
      }
    }
    await _client.auth.signOut();
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
    final userId = currentUser?.id;
    if (userId == null) return;
    await _client
        .from('profiles')
        .update({'phone_number': localPhone})
        .eq('id', userId);
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
