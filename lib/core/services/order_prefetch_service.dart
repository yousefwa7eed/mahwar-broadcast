import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order.dart';

/// جلب مسبق لطلبات الجلسة عند دخول التطبيق، وذاكرة قصيرة تعرض آخر قائمة
/// معروفة فورًا عند فتح تبويب/شاشة الطلبات قبل أن يصل الرد الجديد.
///
/// الذاكرة مقيّدة بمعرّف المستخدم الذي جُلبت له: أي قراءة بمعرّف جلسة آخر
/// تعيد null، فلا يمكن أن تظهر طلبات حساب سابق في حساب جديد على نفس الجهاز.
class OrderPrefetchService {
  OrderPrefetchService._();

  static final OrderPrefetchService instance = OrderPrefetchService._();

  /// بعد هذه المدة تُعتبر الذاكرة قديمة (تُعرض لكن تُحدَّث من الخادم).
  static const Duration cacheTtl = Duration(seconds: 60);

  static const int prefetchLimit = 20;

  SupabaseClient get _client => Supabase.instance.client;

  String? _ownerUserId;
  List<Order>? _ownerOrders;
  DateTime? _ownerFetchedAt;

  String? _providerUserId;
  List<Order>? _providerOrders;
  DateTime? _providerFetchedAt;

  StreamSubscription<AuthState>? _authSubscription;

  /// يبدأ مراقبة الخروج لتفريغ الذاكرة. يُستدعى مرة واحدة من main.
  void start() {
    _authSubscription ??= _client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) clear();
    });
  }

  /// جلب صامت لطلبات [role] في الخلفية — أي فشل يُتجاهل ويُترك للشاشة.
  Future<void> prefetch(String? role) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      if (role == 'car_owner') {
        final rows = await _client
            .from('orders')
            .select()
            .eq('car_owner_id', userId)
            .order('created_at', ascending: false)
            .limit(prefetchLimit);
        setOwnerOrders(userId, _parse(rows));
      } else if (role == 'provider') {
        final rows = await _client
            .from('orders')
            .select()
            .eq('provider_id', userId)
            .order('created_at', ascending: false)
            .limit(prefetchLimit);
        setProviderOrders(userId, _parse(rows));
      }
    } catch (_) {
      // أوفلاين أو خطأ عابر — الشاشات تجلب بنفسها وتعرض الحالة المناسبة.
    }
  }

  List<Order>? ownerOrdersFor(String? userId) =>
      _matches(_ownerUserId, userId) ? _ownerOrders : null;

  List<Order>? providerOrdersFor(String? userId) =>
      _matches(_providerUserId, userId) ? _providerOrders : null;

  void setOwnerOrders(String userId, List<Order> orders) {
    _ownerUserId = userId;
    _ownerOrders = orders;
    _ownerFetchedAt = DateTime.now();
  }

  void setProviderOrders(String userId, List<Order> orders) {
    _providerUserId = userId;
    _providerOrders = orders;
    _providerFetchedAt = DateTime.now();
  }

  /// هل ما زالت القائمة المخزَّنة حديثة بما يكفي دون إعادة جلب؟
  bool ownerCacheIsFresh({DateTime? now}) =>
      _ownerOrders != null && _isFresh(_ownerFetchedAt, now: now);

  bool providerCacheIsFresh({DateTime? now}) =>
      _providerOrders != null && _isFresh(_providerFetchedAt, now: now);

  @visibleForTesting
  bool isFreshWithin(DateTime? fetchedAt, {DateTime? now}) =>
      _isFresh(fetchedAt, now: now);

  bool _isFresh(DateTime? fetchedAt, {DateTime? now}) {
    if (fetchedAt == null) return false;
    return (now ?? DateTime.now()).difference(fetchedAt) < cacheTtl;
  }

  bool _matches(String? cachedUserId, String? currentUserId) =>
      cachedUserId != null &&
      currentUserId != null &&
      cachedUserId == currentUserId;

  void clear() {
    _ownerUserId = null;
    _ownerOrders = null;
    _ownerFetchedAt = null;
    _providerUserId = null;
    _providerOrders = null;
    _providerFetchedAt = null;
  }

  @visibleForTesting
  void stopForTesting() {
    _authSubscription?.cancel();
    _authSubscription = null;
    clear();
  }

  List<Order> _parse(List<Map<String, dynamic>> rows) =>
      rows.map(Order.fromJson).toList(growable: false);
}
