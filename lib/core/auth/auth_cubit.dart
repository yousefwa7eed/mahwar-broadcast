import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/device_identity.dart';
import 'auth_service.dart';
import 'phone_utils.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String fullName;
  final String phoneNumber;
  final String role;
  final String? nationalId;

  const AuthSignUpRequested({
    required this.email,
    required this.password,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    this.nationalId,
  });

  @override
  List<Object?> get props => [email, password, fullName, phoneNumber, role, nationalId];
}

class AuthSignInRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthSignInRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final User user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user.id];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService;

  /// اشتراك مستمع `onAuthStateChange`. يُخزَّن ليُلغى في [close] —
  /// بدون ذلك يبقى المستمع حيًّا بعد إغلاق الـ cubit (تسريب/أحداث مكررة).
  /// النوع `Object?` لأن `AuthState` هنا اسم الحالة المحلية لا حالة Supabase.
  StreamSubscription<Object?>? _authSub;

  /// حالة توثيق هاتف المستخدم الحالي مخزّنة مؤقتًا (tri-state):
  /// null = غير معروفة بعد، true = موثّق، false = غير موثّق. تُصفَّر عند كل
  /// تغيّر جلسة وتُضبط true بعد نجاح تحقق OTP. تربط بوابة التوجيه بحالة
  /// موثوقة واحدة بلا سؤال الخادم عند كل تنقّل.
  bool? _phoneVerified;

  /// اشتراك «قاطع الجلسة» (Realtime kill switch) — يصغي لتحديثات
  /// `session_revoked_at` على صف المستخدم. عندما يحظر الأدمن المستخدم فجأة
  /// (عبر admin_ban_user) يصل الحدث خلال لحظات ويسجّل خروجًا فوريًا — عوض
  /// الاعتماد على انتهاء صلاحية الـ JWT أو محاولة refresh لاحقًا (حتى خمسين
  /// دقيقة). يُلغى عند الخروج أو عند تبديل الحساب.
  ///
  /// القناة نفسها خلف [AuthService.watchSessionRevoked] حتى يبقى الـ cubit
  /// قابلًا للاختبار عبر [FakeAuthService] بلا Supabase مُهيّأ.
  StreamSubscription<bool>? _sessionWatch;
  String? _sessionWatchFor;

  /// صمام أمان دوري (Resumption Safeguard): قناة Realtime قد تقع أحيانًا
  /// (شبكة ضعيفة/إيقاف مؤقت للنظام) — فحص الإشارة كل [revocationPollInterval]
  /// يضمن إنهاء الجلسة حتى لو فات حدث القناة. استعلام خفيف جدًا على صف واحد.
  ///
  /// يعمل فقط أثناء وجود جلسة؛ بلا مستخدم مسجّل لا مؤقّت إطلاقًا.
  ///
  /// [revocationPollInterval] = null يُعطّل المؤقّت تمامًا، وهو الافتراضي:
  /// المؤقّت الدوري أثرٌ جانبي على مستوى العملية يخصّ تركيب التطبيق، فيُشغّله
  /// `main()` صراحةً (نفس نمط `ScreenTimeService.start`). الاختبارات تُنشئ
  /// الـ cubit عشرات المرات بلا إغلاق، فمؤقّت يبدأ تلقائيًا يسرّب
  /// «pending timer» إلى كل اختبار widget يمرّ بجلسة مسجّلة.
  Timer? _revocationPoll;
  final Duration? revocationPollInterval;

  AuthCubit({
    AuthService? service,
    this.revocationPollInterval,
  })  : _authService = service ?? SupabaseAuthService(),
        super(const AuthInitial()) {
    _init();
  }

  void _init() {
    // Check current auth state
    final user = _authService.currentUser;
    if (user != null) {
      emit(AuthAuthenticated(user));
      _beginSessionGuard(user.id);
    } else {
      emit(const AuthUnauthenticated());
    }

    // Listen to auth state changes
    _authSub = _authService.authStateChanges.listen((authState) {
      final event = authState.event;
      final session = authState.session;

      if ((event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.initialSession) &&
          session != null) {
        // جلسة جديدة (أو تبديل حساب) → حالة التوثيق المخزّنة لا تصحّ لها.
        _phoneVerified = null;
        emit(AuthAuthenticated(session.user));
        // حراسة الجلسة للمعرف الجديد (يشترك على قناة معرف المستخدم الحالي).
        _beginSessionGuard(session.user.id);
        // عمل غير حرج بعد الدخول — لا يُنتظر حتى لا يؤخّر التوجيه/الرفض.
        unawaited(_saveFcmToken(session.user.id));
        unawaited(_subscribeToRoleTopic(session.user));
      } else if (event == AuthChangeEvent.signedOut) {
        _phoneVerified = null;
        _endSessionGuard();
        emit(const AuthUnauthenticated());
      }
    });
  }

  /// يبدأ حراسة جلسة [uid]: فحص فوري للإشارة (يغطي حالة الحظر أثناء إغلاق
  /// التطبيق حيث لم يصل حدث Realtime)، ثم فتح القناة، ثم المؤقّت الدوري.
  void _beginSessionGuard(String uid) {
    unawaited(_checkAndApplyRevokedSession(uid));
    _startSessionWatch(uid);
    _startRevocationPoll();
  }

  /// يوقف كل حراسة للجلسة — عند الخروج أو إغلاق الـ cubit.
  void _endSessionGuard() {
    _stopSessionWatch();
    _stopRevocationPoll();
  }

  /// يشترك على قناة الإبطال لمعرّف واحد. تُستبدل القناة عند تبديل الحساب أو
  /// إعادة الاشتراك القسري ([forceResubscribe] عند الرجوع من الخلفية، لضمان
  /// اتصال حي).
  void _startSessionWatch(String uid, {bool forceResubscribe = false}) {
    if (!forceResubscribe && _sessionWatchFor == uid && _sessionWatch != null) {
      return;
    }
    _stopSessionWatch();
    _sessionWatchFor = uid;
    _sessionWatch = _authService.watchSessionRevoked(uid).listen((_) {
      unawaited(_enforceSignOutOnRevokedSession());
    });
  }

  /// يقرأ الإشارة المخزنية — [AuthService.isSessionRevoked] يبتلع فشل الشبكة
  /// ويعيد null، فلا يُخرج المستخدم انقطاعٌ عابر (الحارس الحقيقي هو بوابة
  /// الخادم عند كل طلب).
  Future<void> _checkAndApplyRevokedSession(String uid) async {
    if (await _authService.isSessionRevoked(uid) == true) {
      await _enforceSignOutOnRevokedSession();
    }
  }

  /// يوقع الخروج عند الإشارة المحفوظة: تسجيل خروج محلي (محتوى جلسة). الخروج
  /// يبعث signedOut عبر المستمع — لا حاجة إلى emit يدوي هنا.
  Future<void> _enforceSignOutOnRevokedSession() async {
    try {
      await _authService.signOut();
    } catch (e) {
      debugPrint('[AuthCubit] revocation signOut failed: $e');
    }
  }

  /// يلغي الاشتراك في قناة «قاطع الجلسة» (عند الخروج/إغلاق الـ cubit/تبديل حساب).
  void _stopSessionWatch() {
    unawaited(_sessionWatch?.cancel());
    _sessionWatch = null;
    _sessionWatchFor = null;
  }

  void _startRevocationPoll() {
    final interval = revocationPollInterval;
    if (interval == null || _revocationPoll != null) return;
    _revocationPoll = Timer.periodic(interval, (_) {
      final u = _authService.currentUser;
      if (u != null) unawaited(_checkAndApplyRevokedSession(u.id));
    });
  }

  void _stopRevocationPoll() {
    _revocationPoll?.cancel();
    _revocationPoll = null;
  }

  /// يعيد التحقق من الجلسة عند رجوع التطبيق من الخلفية: أثناء تعليق النظام
  /// للتطبيق قد يسقط socket الـ Realtime فتفوت أحداث الحظر — نعيد إنشاء القناة
  /// ونتفقّد الإشارة مباشرة، فيتم الخروج لحظة العودة بدل انتظار المؤقّت الدوري.
  ///
  /// يُستدعى من مراقب دورة حياة في `main.dart`؛ الـ cubit نفسه لا يراقب
  /// `WidgetsBinding` حتى يبقى قابلًا للبناء في اختبارات الوحدة بلا binding.
  void revalidateSessionOnResume() {
    final u = _authService.currentUser;
    if (u == null) return;
    _startSessionWatch(u.id, forceResubscribe: true);
    unawaited(_checkAndApplyRevokedSession(u.id));
  }

  /// يلغي الاشتراك في تدفق المصادقة قبل إغلاق الـ cubit — وإلّا ظل المستمع
  /// مسجّلًا في `onAuthStateChange` ويستقبل أحداثًا ويبثّ حالات بعد الإغلاق.
  @override
  Future<void> close() async {
    await _authSub?.cancel();
    _authSub = null;
    _endSessionGuard();
    return super.close();
  }

  /// يجلب FCM token الخاص بالجهاز الحالي ويحفظه في عمود fcm_token
  /// جوه جدول profiles، مرتبطًا بمعرّف المستخدم الحقيقي (userId).
  /// لو فشلت العملية، ماينفعش نوقف تسجيل الدخول بسببها - بنكتفي بتجاهل الخطأ.
  Future<void> _saveFcmToken(String userId) async {
    try {
      final messaging = FirebaseMessaging.instance;
      // أول دخول → طلب إذن إشعارات النظام (Android 13+) قبل أخذ التوكن
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final String? token = await messaging.getToken();
      if (token == null) return;

      final deviceId = await DeviceIdentity.instance.get();
      if (Supabase.instance.client.auth.currentUser?.id != userId) return;

      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token, 'device_id': deviceId})
          .eq('id', userId);
    } catch (e) {
      // تجاهل الخطأ هنا عمدًا - فشل حفظ التوكن مش المفروض يمنع تسجيل الدخول
    }
  }

  /// يشترك الجهاز في FCM Topic المناسب حسب دور المستخدم (car_owner / provider)
  /// عشان نقدر نبعت إشعارات جماعية لكل فئة من غير ما نجمع كل الـ tokens يدويًا.
  /// الدور يُقرأ من `profiles.role` فقط (المصدر الموثوق)، بلا أي اعتماد على
  /// `user_metadata` — حتى لا يُشترك الجهاز في موضوع الفئة الخاطئة.
  Future<void> _subscribeToRoleTopic(User user) async {
    try {
      final role = await _authService.getServerRole();

      if (role == null) return;

      // نلغي الاشتراك في الموضوع التاني احتياطيًا (لو حصل تغيير دور نادر)
      if (role == 'provider') {
        await FirebaseMessaging.instance.subscribeToTopic('providers');
        await FirebaseMessaging.instance.unsubscribeFromTopic('car_owners');
      } else if (role == 'car_owner') {
        await FirebaseMessaging.instance.subscribeToTopic('car_owners');
        await FirebaseMessaging.instance.unsubscribeFromTopic('providers');
      }
    } catch (e) {
      // تجاهل الخطأ هنا عمدًا - فشل الاشتراك مش المفروض يمنع تسجيل الدخول
    }
  }

  /// يتحقق من الجلسة الحالية لدى الخادم (`auth.getUser`) ويعيد المستخدم
  /// الخادمي. يمرّر [AuthException] للأعلى حتى تفرّق الشاشة بين جلسة
  /// منتهية/ملغاة (تُخرج المستخدم) وفشل شبكة (قابل لإعادة المحاولة).
  Future<User?> validateServerSession() => _authService.getServerUser();

  /// يحدّد الدور الحقيقي للمستخدم المسجّل من `profiles.role` فقط (المصدر
  /// الموثوق للتوجيه). تُرجع null عندما لا يوجد مستخدم مسجّل، أو عندما يتعذّر
  /// تحديد الدور من الخادم — بلا أي افتراضي إلى `car_owner` وبلا رجوع إلى
  /// `user_metadata` (كان السبب في توجيه المزوّد إلى رئيسية مالك السيارة).
  Future<String?> resolveCurrentRole() => resolveCurrentUserRole(_authService);

  /// يحدّد الدور مع مهلة زمنية وإعادة محاولة — لمسار الدخول. أي انتهاء مهلة
  /// أو خطأ عابر يُعاد معه المحاولة حتى [attempts] مرة، ثم يُرجع null (يُعامل
  /// كدور غير معروف). دور `null` صريح من الخادم لا يُعاد معه المحاولة (حالة
  /// نهائية). لا يُغيّر [resolveCurrentRole] المستخدم في شاشة الإقلاع.
  Future<String?> resolveCurrentRoleWithRetry({
    Duration timeout = const Duration(seconds: 10),
    int attempts = 2,
  }) async {
    if (_authService.currentUser == null) return null;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        return await resolveCurrentRole().timeout(timeout);
      } on TimeoutException {
        // انتهت المهلة — أعد المحاولة.
      } catch (_) {
        // فشل شبكي/خادمي عابر — أعد المحاولة.
      }
    }
    return null;
  }

  /// يحدّد هل identifier ده إيميل أو رقم هاتف، ويرجع الإيميل الحقيقي الصالح
  /// للاستخدام في signInWithPassword في الحالتين:
  /// - لو فيه علامة @، بنعتبره إيميل (مقصوص الأطراف ومنزوع الحروف الكبيرة).
  /// - لو مش فيه، بنعتبره رقم هاتف ونوحّد صيغته وبندوّر على الإيميل المرتبط
  ///   بيه فعليًا.
  /// حُوِّل تنفيذه إلى طبقة الخدمة (AuthService.resolveEmail) لسهولة الاختبار.
  Future<String?> _resolveEmail(String identifier) {
    return _authService.resolveEmail(identifier);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String role,
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
    try {
      emit(const AuthLoading());

      final normalizedPhone = PhoneUtils.normalize(phoneNumber.trim());

      final response = await _authService.signUpWithEmail(
        email: email,
        password: password,
        role: role,
        fullName: fullName,
        phoneNumber: normalizedPhone,
        nationalId: nationalId,
        workshopName: workshopName,
        address: address,
        latitude: latitude,
        longitude: longitude,
        supportScope: supportScope,
        hasVehicle: hasVehicle,
        vehicleSpecs: vehicleSpecs,
        vehicleMake: vehicleMake,
        vehicleModel: vehicleModel,
        vehicleYear: vehicleYear,
        vehiclePlate: vehiclePlate,
        vehicleColor: vehicleColor,
        specializations: specializations,
        carMake: carMake,
        carModel: carModel,
        carYear: carYear,
      );

      final user = response.user;
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } on AuthException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      debugPrint('[AuthCubit] signUp unexpected error: $e');
      emit(AuthError('UNEXPECTED_ERROR'));
    }
  }

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    try {
      emit(const AuthLoading());

      String email;
      try {
        final resolved = await _resolveEmail(identifier.trim());
        if (resolved == null) {
          emit(AuthError('NO_ACCOUNT_FOUND'));
          return;
        }
        email = resolved;
      } on AuthException catch (e) {
        emit(AuthError(e.message));
        return;
      } on Exception {
        emit(AuthError('NETWORK_ERROR'));
        return;
      }

      await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      // Auth state will be updated via the listener
    } on AuthException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      debugPrint('[AuthCubit] signIn unexpected error: $e');
      emit(AuthError('UNEXPECTED_ERROR'));
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _phoneVerified = null;
      emit(const AuthUnauthenticated());
    } catch (e) {
      debugPrint('[AuthCubit] signOut failed: $e');
      emit(AuthError('SIGN_OUT_FAILED'));
    }
  }

  /// يرفض الجلسة التي أُنشئت من نقطة دخول مقيّدة بالدور. يُنتظَر تنظيف الخادم/
  /// الجهاز (مسح fcm_token + device_id + سحب الجلسة) مع مهلة قصيرة حتى يُضمن
  /// قطع ارتباط الجهاز قبل سحب الجلسة محليًا، دون أن يعلّق الواجهة عند بطء
  /// الشبكة. لا يبثّ [AuthError] أبدًا — حتى لا تظهر رسالة خطأ خروج فوق
  /// رسالة عدم التطابق.
  Future<void> rejectSession() async {
    try {
      await _authService
          .signOutFromRejection()
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // فشل التنظيف/الإبطال — نتابع السحب المحلي على كل حال.
    }
    try {
      await _authService.clearLocalSession();
    } catch (_) {
      // فشل السحب المحلي — لا يُبث خطأ (الواجهة ستُخرج على كل حال).
    }
    if (!isClosed) emit(const AuthUnauthenticated());
  }

  /// يبثّ [AuthUnauthenticated] فورًا — الاستدعاء المحلي الوحيد الذي يسمّيه
  /// منسّق الخروج بعد التنظيف المحلي وقبل الانتقال (بلا أي شبكة). بلا تأثير
  /// عند إغلاق الـ cubit.
  void markUnauthenticated() {
    _phoneVerified = null;
    if (!isClosed) emit(const AuthUnauthenticated());
  }

  /// يرسل كود استعادة كلمة المرور عبر SMS للرقم المحلي. لا يبث حالات — الشاشة
  /// تتحكم في الـ loading محليًا وتعالج الأخطاء عبر استثناءات تُمرَّر لها (نفس
  /// نمط attachPhone/verifyPhoneOtp). أخطاء GoTrue (user_not_found /
  /// phone_not_confirmed) تُرسم رسالة عربية لا تكشف ما إذا كان الرقم مسجّلًا
  /// عبر [mapRecoverySendError] في الشاشة.
  Future<void> requestForgotPasswordOtp(String localPhone) async {
    await _authService.requestForgotPasswordOtp(localPhone);
  }

  Future<void> verifyForgotPasswordOtp({
    required String localPhone,
    required String otp,
  }) async {
    await _authService.verifyForgotPasswordOtp(localPhone: localPhone, otp: otp);
  }

  Future<void> resendForgotPasswordOtp(String localPhone) async {
    await _authService.resendForgotPasswordOtp(localPhone);
  }

  /// يضبط كلمة المرور الجديدة للمستخدم (جلسة استعادة) ثم يخرج تلقائيًا
  /// حتى يعود المستخدم لشاشة الدخول ويجرب كلمة المرور الجديدة.
  Future<void> setNewPassword(String newPassword) async {
    await _authService.setNewPassword(newPassword);
    await signOut();
  }

  String? _attachedPhone;
  DateTime? _attachedAt;

  /// يربط رقم الهاتف بحساب المستخدم ويفعّل إرسال كود OTP إليه.
  ///
  /// شاشات التسجيل تستمع لحالة AuthAuthenticated التي قد تُبث مرتين في
  /// نفس التدفق (من قِبل signUp نفسها ومن قِبل مستمع onAuthStateChange) —
  /// الحارس هنا يمنع إرسال رسالة OTP مكررة ورسوم SMS مزدوجة.
  Future<void> attachPhone(String localPhone) async {
    final recentlyAttached = _attachedPhone == localPhone &&
        _attachedAt != null &&
        DateTime.now().difference(_attachedAt!) < const Duration(seconds: 30);
    if (recentlyAttached) return;

    await _authService.attachPhone(localPhone);
    _attachedPhone = localPhone;
    _attachedAt = DateTime.now();
  }

  Future<void> verifyPhoneOtp({required String localPhone, required String otp}) async {
    await _authService.verifyPhoneOtp(localPhone: localPhone, otp: otp);
    // نجح التحقق → الرقم موثّق الآن؛ نحدّث البوابة فورًا حتى لا يعيد التنقل
    // التالي سؤال الخادم ولا يُحجب المستخدم لحظيًا بعد نجاح التحقق.
    _phoneVerified = true;
  }

  Future<void> resendPhoneOtp(String localPhone) async {
    await _authService.resendPhoneOtp(localPhone);
  }

  Future<void> syncPhoneToProfile(String localPhone) async {
    await _authService.syncPhoneToProfile(localPhone);
  }

  /// الإيميل المرتبط برقم محلي، أو null إن لم يكن مرتبطًا بأي حساب. تُستخدم
  /// لفحص تفرّد الرقم قبل إرسال كود تغييره (تفادي إهدار رسالة SMS).
  Future<String?> emailForPhone(String localPhone) =>
      _authService.resolveEmail(localPhone);

  /// إيميل المستخدم الحالي — لتمييز رقمه الخاص عن رقم مملوك لحساب آخر في
  /// الفحص المسبق لتغيير الرقم. null خارج جلسة مصادَقة.
  String? get currentUserEmail => _authService.currentUser?.email;

  /// هل توجد جلسة مصادَقة محليًا؟ (قراءة متزامنة بلا شبكة.)
  bool get hasSession => _authService.currentUser != null;

  /// حالة توثيق الهاتف المعروفة حاليًا: null = غير معروفة، true = موثّق،
  /// false = غير موثّق.
  bool? get knownPhoneVerified => _phoneVerified;

  /// يضمن معرفة حالة توثيق هاتف المستخدم الحالي: يعيد المخزّن إن وُجد، وإلا
  /// يسأل الخادم عبر `get_my_phone_verified` مرة واحدة ويخزّن الناتج. عند فشل
  /// الشبكة يعيد `true` (fail-open) لأن البوابة الخادمية (RPC/RLS) هي الحارس
  /// الحقيقي، وفشل عابر لا يجوز أن يحجب مستخدمًا موثّقًا عن التطبيق. بلا جلسة
  /// يعيد true (لا شأن للبوابة بغير المسجّلين).
  Future<bool> ensurePhoneVerified() async {
    final cached = _phoneVerified;
    if (cached != null) return cached;
    if (!hasSession) return true;
    try {
      final verified = await _authService.getMyPhoneVerified();
      _phoneVerified = verified;
      return verified;
    } catch (_) {
      return true;
    }
  }

  /// يضبط حالة التوثيق المعروفة مباشرةً — يُستخدم بعد نجاح تحقق OTP من خارج
  /// هذا الـ cubit إن لزم، وأساسه ضبطها داخل [verifyPhoneOtp].
  void setPhoneVerified(bool value) {
    _phoneVerified = value;
  }
}