import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
  final AuthService _authService = AuthService();

  AuthCubit() : super(const AuthInitial()) {
    _init();
  }

  void _init() {
    // Check current auth state
    final user = _authService.currentUser;
    if (user != null) {
      emit(AuthAuthenticated(user));
    } else {
      emit(const AuthUnauthenticated());
    }

    // Listen to auth state changes
    _authService.authStateChanges.listen((authState) {
      final event = authState.event;
      final session = authState.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        emit(AuthAuthenticated(session.user));
        _saveFcmToken(session.user.id);
        _subscribeToRoleTopic(session.user);
      } else if (event == AuthChangeEvent.signedOut) {
        emit(const AuthUnauthenticated());
      }
    });
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

      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);
    } catch (e) {
      // تجاهل الخطأ هنا عمدًا - فشل حفظ التوكن مش المفروض يمنع تسجيل الدخول
    }
  }

  /// يشترك الجهاز في FCM Topic المناسب حسب دور المستخدم (car_owner / provider)
  /// عشان نقدر نبعت إشعارات جماعية لكل فئة من غير ما نجمع كل الـ tokens يدويًا.
  /// بيحاول ياخد الـ role الأول من user_metadata (المتاح فورًا من غير استدعاء إضافي)،
  /// ولو مش موجود، بيرجع يسأل جدول profiles كخطة بديلة.
  Future<void> _subscribeToRoleTopic(User user) async {
    try {
      String? role = user.userMetadata?['role'] as String?;

      role ??= await _fetchRoleFromProfile(user.id);

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

  Future<String?> _fetchRoleFromProfile(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      return response?['role'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// يحدّد الدور الحقيقي للمستخدم المسجّل (المصدر الأول: profiles جدول،
  /// والبديل: user_metadata من توكن الجلسة). يُستخدم لتوجيه الشاشة الرئيسية
  /// بعد الدخول بدلاً من الثقة في معرّف الدور الوارد من رابط الصفحة،
  /// مما يمنع توجيه مالك/مزوّد لشاشة الرئيسية الخاطئة.
  Future<String> resolveCurrentRole() async {
    final user = _authService.currentUser;
    if (user == null) return 'car_owner';

    final fromProfile = await _fetchRoleFromProfile(user.id);
    if (fromProfile != null) return fromProfile;

    return user.userMetadata?['role'] as String? ?? 'car_owner';
  }

  /// يحدّد هل identifier ده إيميل أو رقم هاتف، ويرجع الإيميل الحقيقي الصالح
  /// للاستخدام في signInWithPassword في الحالتين:
  /// - لو فيه علامة @، بنعتبره إيميل (مقصوص الأطراف ومنزوع الحروف الكبيرة).
  /// - لو مش فيه، بنعتبره رقم هاتف ونوحّد صيغته (بنزيل المسافات والشرطات
  ///   وبنحوّل +20/0020 إلى 0) وبندوّر على الإيميل المرتبط بيه فعليًا.
  Future<String?> _resolveEmail(String identifier) async {
    final value = identifier.trim();
    if (value.isEmpty) return null;

    if (value.contains('@')) {
      return value.toLowerCase();
    }

    final sanitized = PhoneUtils.normalize(value);

    try {
      final response = await Supabase.instance.client.rpc(
        'get_email_by_phone',
        params: {'p_phone': sanitized},
      );
      final email = response as String?;
      if (email == null || email.isEmpty) return null;
      return email;
    } catch (e) {
      // Don't swallow real backend/network errors behind a generic
      // "no account" message. Re-throw so signIn can surface what failed.
      rethrow;
    }
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
      emit(AuthError('حدث خطأ غير متوقع: ${e.toString()}'));
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
          emit(const AuthError('لا يوجد حساب مرتبط بهذا الرقم أو البريد الإلكتروني'));
          return;
        }
        email = resolved;
      } on AuthException catch (e) {
        emit(AuthError(e.message));
        return;
      } on Exception {
        emit(const AuthError('لا يوجد اتصال بالإنترنت، تحقق من اتصالك وحاول مجددًا'));
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
      emit(AuthError('حدث خطأ غير متوقع: ${e.toString()}'));
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError('حدث خطأ أثناء تسجيل الخروج'));
    }
  }
}