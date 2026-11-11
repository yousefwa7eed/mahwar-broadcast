import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'last_account_store.dart';
import 'phone_utils.dart';

class ProfileData extends Equatable {
  final String fullName;
  final String? phoneNumber;
  final String? email;
  final String? nationalId;
  final String? role;
  final String? avatarId;
  final String? avatarUrl;

  const ProfileData({
    this.fullName = '',
    this.phoneNumber,
    this.email,
    this.nationalId,
    this.role,
    this.avatarId,
    this.avatarUrl,
  });

  const ProfileData.empty() : this();

  ProfileData copyWith({
    String? fullName,
    String? phoneNumber,
    String? email,
    String? nationalId,
    String? role,
    String? avatarId,
    String? avatarUrl,
  }) {
    return ProfileData(
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      nationalId: nationalId ?? this.nationalId,
      role: role ?? this.role,
      avatarId: avatarId ?? this.avatarId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  List<Object?> get props => [fullName, phoneNumber, email, nationalId, role, avatarId, avatarUrl];
}

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();
  @override
  List<Object?> get props => [];
}

class ProfileLoadRequested extends ProfileEvent {
  const ProfileLoadRequested();
}

class ProfileUpdated extends ProfileEvent {
  final ProfileData profile;
  const ProfileUpdated(this.profile);
  @override
  List<Object?> get props => [profile];
}

class ProfileReset extends ProfileEvent {
  const ProfileReset();
}

abstract class ProfileState extends Equatable {
  const ProfileState();
  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  final ProfileData profile;
  const ProfileLoaded(this.profile);
  @override
  List<Object?> get props => [profile];
}

class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);
  @override
  List<Object?> get props => [message];
}

class ProfileCubit extends Cubit<ProfileState> {
  final SupabaseClient _client = Supabase.instance.client;

  /// اشتراك مستمع `onAuthStateChange`. يُخزَّن ليُلغى في [close] — بدون ذلك
  /// يبقى المستمع حيًّا بعد إغلاق الـ cubit (تسريب/أحداث مكررة).
  StreamSubscription<AuthState>? _authSub;

  ProfileCubit() : super(const ProfileInitial()) {
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSub = _client.auth.onAuthStateChange.listen((authState) {
      final event = authState.event;
      if (event == AuthChangeEvent.signedIn) {
        loadProfile();
      } else if (event == AuthChangeEvent.signedOut) {
        emit(const ProfileInitial());
      }
    });
  }

  /// يلغي الاشتراك في تدفق المصادقة قبل إغلاق الـ cubit.
  @override
  Future<void> close() async {
    await _authSub?.cancel();
    _authSub = null;
    return super.close();
  }

  Future<void> loadProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      emit(const ProfileInitial());
      return;
    }

    try {
      final response = await _client
          .from('profiles')
          .select('full_name, phone_number, email, national_id, role, avatar_id, avatar_url')
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 12));

      if (response == null) {
        emit(const ProfileLoaded(ProfileData()));
        return;
      }

      final profile = ProfileData(
        fullName: response['full_name'] ?? '',
        phoneNumber: response['phone_number'],
        email: response['email'],
        nationalId: response['national_id'],
        role: response['role'],
        avatarId: response['avatar_id'],
        avatarUrl: response['avatar_url'],
      );
      emit(ProfileLoaded(profile));
      unawaited(_rememberLastAccount(profile));
    } on TimeoutException {
      // مهلة أمان: لا نبقى على شاشة هيكل شيمر بلا نهاية — نتحول لخطأ
      // يُعرض مع زر إعادة المحاولة.
      emit(const ProfileError('profile_load_timeout'));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> refreshProfile() async {
    await loadProfile();
  }

  /// يحفظ اسم/رقم/دور الحساب محليًا لتلميح «العودة إلى حسابك» بعد إعادة
  /// التثبيت. الدور يُقبل فقط إن كان معروفًا، والرقم يُؤخذ من `profiles` ثم من
  /// جلسة GoTrue — ولا يُكتب شيء إن غاب أحدهما.
  Future<void> _rememberLastAccount(ProfileData profile) async {
    final role = profile.role;
    if (role == null) return;
    if (role != 'car_owner' && role != 'provider') return;
    final name = profile.fullName.trim();
    if (name.isEmpty) return;
    final rawPhone = profile.phoneNumber ?? _client.auth.currentUser?.phone;
    if (rawPhone == null || rawPhone.isEmpty) return;
    final phone = PhoneUtils.normalize(rawPhone);
    if (!PhoneUtils.isValidEgyptianMobile(phone)) return;
    await LastAccountStore().write(
      LastAccount(name: name, phone: phone, role: role),
    );
  }

  void updateProfile(ProfileData profile) {
    emit(ProfileLoaded(profile));
  }

  /// يعيد الحالة إلى الابتدائية — يُستدعى عند تسجيل الخروج حتى لا تبقى
  /// بيانات آخر مستخدم معروضة محليًا عند خروج أو دخول مستخدم آخر.
  void reset() => emit(const ProfileInitial());
}
