import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import '../services/server_clock.dart';

class NotificationsState extends Equatable {
  final List<NotificationModel> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  const NotificationsState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  NotificationsState copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [notifications, unreadCount, isLoading, error];
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

    // TEMP DIAGNOSTIC (notifications load latency investigation) — حذف بعد التشخيص
    final diagStart = DateTime.now();
    debugPrint('[notif-diag] load START');

    emit(state.copyWith(isLoading: true));

    // حدّث مرجع "الآن" من ساعة الخادم قبل الرسم — حتى تُحسب "منذ ..."
    // ضد زمن الخادم لا ساعة الجهاز غير المزامنة.
    final clockRefresh = ServerClock.instance.refresh();

    try {
      final diagQueryStart = DateTime.now();
      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      debugPrint(
          '[notif-diag] list query done  +${DateTime.now().difference(diagStart).inMilliseconds}ms (query=${DateTime.now().difference(diagQueryStart).inMilliseconds}ms, rows=${response.length})');

      final notifications =
          response.map((json) => NotificationModel.fromJson(json)).toList();

      final diagCountStart = DateTime.now();
      final unreadCount = await _loadUnreadTotal(userId);
      debugPrint(
          '[notif-diag] unread count done  +${DateTime.now().difference(diagStart).inMilliseconds}ms (query=${DateTime.now().difference(diagCountStart).inMilliseconds}ms, unread=$unreadCount)');

      unawaited(clockRefresh);
      emit(state.copyWith(
        notifications: notifications,
        unreadCount: unreadCount,
        isLoading: false,
      ));
      debugPrint(
          '[notif-diag] load END  +${DateTime.now().difference(diagStart).inMilliseconds}ms total');
    } catch (e) {
      debugPrint(
          '[notif-diag] load FAILED after ${DateTime.now().difference(diagStart).inMilliseconds}ms: $e');
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  /// العدد الإجمالي للإشعارات غير المقروءة (من الخادم، لا من آخر 50 محمَّلة)
  /// حتى تبقى الشارة صحيحة مهما كثرت الإشعارات.
  Future<int> _loadUnreadTotal(String userId) async {
    final res = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false)
        .count(CountOption.exact);
    return res.count;
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

      final wasUnread = state.notifications
          .any((n) => n.id == notificationId && !n.isRead);

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

      emit(state.copyWith(
        notifications: updated,
        unreadCount: wasUnread && state.unreadCount > 0
            ? state.unreadCount - 1
            : state.unreadCount,
      ));
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

      emit(state.copyWith(notifications: updated, unreadCount: 0));
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
    final record = Map<String, dynamic>.from(payload.newRecord);

    // الإشعار وصل حالاً — ثبّت مرجع "الآن" على ساعة الخادم إن مرّت عليه مدته
    // حتى يبقى "منذ ..." للإشعار الجديد دقيقاً حتى لو كانت ساعة الجهاز خاطئة.
    ServerClock.instance.refresh();

    if (payload.eventType == PostgresChangeEvent.insert) {
      final isRead = (record['is_read'] as bool?) ?? false;
      emit(state.copyWith(
        notifications: [NotificationModel.fromJson(record), ...state.notifications],
        unreadCount: isRead ? state.unreadCount : state.unreadCount + 1,
      ));
      return;
    }

    if (payload.eventType == PostgresChangeEvent.update) {
      final id = record['id'] as String?;
      if (id == null) return;
      final index = state.notifications.indexWhere((n) => n.id == id);
      if (index == -1) return;
      final wasUnread = !state.notifications[index].isRead;
      final nowUnread = (record['is_read'] as bool?) ?? false;
      var unreadCount = state.unreadCount;
      if (wasUnread && !nowUnread && unreadCount > 0) unreadCount--;
      if (!wasUnread && nowUnread) unreadCount++;
      final updated = [...state.notifications];
      updated[index] = _mergeRecord(record, state.notifications[index]);
      emit(state.copyWith(notifications: updated, unreadCount: unreadCount));
    }
  }

  /// يبني إشعارًا من سجل realtime قد يكون جزئيًا، مُبقِيًا على القيم الحالية
  /// (مثل [createdAt]) لأي عمود غير مذكور في السجل الوارد.
  NotificationModel _mergeRecord(Map<String, dynamic> record, NotificationModel current) {
    final map = <String, dynamic>{
      'id': current.id,
      'user_id': current.userId,
      'order_id': current.orderId,
      'type': current.type,
      'metadata': current.metadata,
      'created_at': current.createdAt?.toIso8601String(),
      'is_read': current.isRead,
      ...record,
    };
    return NotificationModel.fromJson(map);
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