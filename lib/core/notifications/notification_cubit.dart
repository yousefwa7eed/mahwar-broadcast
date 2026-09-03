import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationsState extends Equatable {
  final List<NotificationModel> notifications;
  final bool isLoading;
  final String? error;

  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  NotificationsState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    String? error,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [notifications, isLoading, error];
}

/// إدارة إشعارات التطبيق بمصدر واحد (جدول notifications):
///  - يُملك الاشتراك الحي على مستوى الجلسة (لا يُغلق عند مغادرة الصفحات)
///    حتى يبقى الجرس محدّثاً أينما كان المستخدم.
///  - يتابع حالة المصادقة: يحمّل ويشترك عند الدخول، ويصفّر عند الخروج.
///  - يعالج الإدراج والتحديث (قراءة/غير مقروء من أي جهاز).
class NotificationCubit extends Cubit<NotificationsState> {
  final SupabaseClient _client = Supabase.instance.client;
  final List<StreamSubscription<AuthState>> _authSubscriptions = [];

  NotificationCubit() : super(const NotificationsState()) {
    _listenToAuth();
  }

  RealtimeChannel? _channel;

  String? get _userId => _client.auth.currentUser?.id;

  void _listenToAuth() {
    _authSubscriptions.add(
      _client.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        if ((data.event == AuthChangeEvent.signedIn ||
                data.event == AuthChangeEvent.initialSession) &&
            session != null) {
          loadNotifications();
          subscribeToNotifications();
        } else if (data.event == AuthChangeEvent.signedOut) {
          _channel?.unsubscribe();
          _channel = null;
          emit(const NotificationsState());
        }
      }),
    );
  }

  Future<void> loadNotifications() async {
    final userId = _userId;
    if (userId == null) return;

    emit(state.copyWith(isLoading: true));

    try {
      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final notifications =
          response.map((json) => NotificationModel.fromJson(json)).toList();

      emit(state.copyWith(
        notifications: notifications,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', userId);

      final updated = state.notifications.map((n) {
        if (n.id == notificationId) {
          return NotificationModel(
            id: n.id,
            userId: n.userId,
            orderId: n.orderId,
            type: n.type,
            metadata: n.metadata,
            isRead: true,
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList();

      emit(state.copyWith(notifications: updated));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> markAllAsRead() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      final updated = state.notifications.map((n) {
        return NotificationModel(
          id: n.id,
          userId: n.userId,
          orderId: n.orderId,
          type: n.type,
          metadata: n.metadata,
          isRead: true,
          createdAt: n.createdAt,
        );
      }).toList();

      emit(state.copyWith(notifications: updated));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// اشتراك حي (إدراج + تحديث) — idempotent ويُدار على مستوى الجلسة.
  void subscribeToNotifications() {
    final userId = _userId;
    if (userId == null) return;
    if (_channel != null) return;

    _channel = _client
        .channel('notifications-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _applyPostgresChange(payload),
        )
        .subscribe();
  }

  void _applyPostgresChange(PostgresChangePayload payload) {
    final record = Map<String, dynamic>.from(payload.newRecord as Map);
    final id = record['id'] as String;

    if (payload.eventType == PostgresChangeEvent.insert) {
      emit(state.copyWith(
        notifications: [NotificationModel.fromJson(record), ...state.notifications],
      ));
      return;
    }

    if (payload.eventType == PostgresChangeEvent.update) {
      final index = state.notifications.indexWhere((n) => n.id == id);
      if (index == -1) return;
      final updated = [...state.notifications];
      updated[index] = NotificationModel.fromJson(record);
      emit(state.copyWith(notifications: updated));
    }
  }

  void unsubscribeFromNotifications() {
    _channel?.unsubscribe();
    _channel = null;
  }

  @override
  Future<void> close() {
    for (final sub in _authSubscriptions) {
      sub.cancel();
    }
    unsubscribeFromNotifications();
    return super.close();
  }
}