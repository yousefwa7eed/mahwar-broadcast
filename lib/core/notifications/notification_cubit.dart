import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import '../services/connectivity_service.dart';
import '../services/server_clock.dart';

class NotificationsState extends Equatable {
  final List<NotificationModel> notifications;
  final int unreadCount;

  /// تحميل أول بلا بيانات معروضة (تُعرض مكانه سكيليتون).
  final bool isLoading;

  /// تحديث خلفي والقائمة المعروفة معروضة (لا تُخفى الواجهة).
  final bool isRefreshing;

  /// رمز خطأ مختصر (`offline` / `failed`) — لا يُعرض نص الخادم مباشرة.
  final String? errorCode;

  /// هل جُلبت القائمة مرة واحدة على الأقل لهذه الجلسة؟
  final bool hasLoaded;

  /// وقت آخر جلب ناجح — يمنع إعادة الجلب عند كل فتح للشاشة.
  final DateTime? lastLoadedAt;

  const NotificationsState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.isRefreshing = false,
    this.errorCode,
    this.hasLoaded = false,
    this.lastLoadedAt,
  });

  NotificationsState copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
    bool? isLoading,
    bool? isRefreshing,
    String? errorCode,
    bool? hasLoaded,
    DateTime? lastLoadedAt,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorCode: errorCode,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      lastLoadedAt: lastLoadedAt ?? this.lastLoadedAt,
    );
  }

  @override
  List<Object?> get props => [
    notifications,
    unreadCount,
    isLoading,
    isRefreshing,
    errorCode,
    hasLoaded,
    lastLoadedAt,
  ];
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

  static const String errorOffline = 'offline';
  static const String errorFailed = 'failed';

  /// أقل مدة قبل إعادة الجلب عند إعادة فتح الشاشة — القائمة تبقى معروضة
  /// والتحديث الحيّ (Realtime) يغطي الجديد، فلا داعي لجلب كامل كل فتح.
  static const Duration refreshTtl = Duration(seconds: 30);

  bool _isFetching = false;

  /// هل يلزم الجلب؟ (force = سحب للتحديث أو إعادة محاولة صريحة)
  @visibleForTesting
  static bool shouldFetch({
    required bool force,
    required bool hasLoaded,
    required DateTime? lastLoadedAt,
    required DateTime now,
    Duration ttl = refreshTtl,
  }) {
    if (force) return true;
    if (!hasLoaded || lastLoadedAt == null) return true;
    return now.difference(lastLoadedAt) >= ttl;
  }

  Future<void> loadNotifications({bool force = false}) async {
    final userId = _userId;
    if (userId == null) return;
    if (_isFetching) return;
    if (!shouldFetch(
      force: force,
      hasLoaded: state.hasLoaded,
      lastLoadedAt: state.lastLoadedAt,
      now: DateTime.now(),
    )) {
      return;
    }

    _isFetching = true;
    emit(
      state.copyWith(
        // السكيليتون للتحميل الأول فقط؛ القائمة المعروضة (ولو فارغة بعد
        // تحميل ناجح) تُحدَّث في الخلفية دون وميض.
        isLoading: !state.hasLoaded,
        isRefreshing: state.hasLoaded,
        errorCode: null,
      ),
    );

    // حدّث مرجع "الآن" من ساعة الخادم قبل الرسم — حتى تُحسب "منذ ..."
    // ضد زمن الخادم لا ساعة الجهاز غير المزامنة.
    final clockRefresh = ServerClock.instance.refresh();

    try {
      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final notifications =
          response.map((json) => NotificationModel.fromJson(json)).toList();

      final unreadCount = await _loadUnreadTotal(userId);

      unawaited(clockRefresh);
      emit(
        state.copyWith(
          notifications: notifications,
          unreadCount: unreadCount,
          isLoading: false,
          isRefreshing: false,
          hasLoaded: true,
          lastLoadedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      // نميّز انقطاع الشبكة عن فشل الخادم: رسالة «لا يوجد اتصال» أدق
      // للمستخدم من «تعذّر التحميل» العامة.
      final online = await ConnectivityService.instance.isOnline();
      emit(
        state.copyWith(
          isLoading: false,
          isRefreshing: false,
          errorCode: online ? errorFailed : errorOffline,
        ),
      );
    } finally {
      _isFetching = false;
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
    } catch (_) {
      emit(state.copyWith(errorCode: errorFailed));
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
    } catch (_) {
      emit(state.copyWith(errorCode: errorFailed));
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