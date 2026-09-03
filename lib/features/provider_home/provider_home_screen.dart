import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/profile_cubit.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/order.dart';
import '../../core/notifications/notification_cubit.dart';
import '../../core/services/location_service.dart';
import '../../core/settings/app_settings_cubit.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/availability_toggle.dart';
import 'widgets/nearby_request_card.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  int _currentIndex = 0;

  bool _isOnline = true;
  String _workshopName = '';
  double _providerLat = 0;
  double _providerLng = 0;

  // طلبات معيّنة لهذا المزوّد بانتظار عرض سعر (لوحة التحكم)
  List<Order> _assignedPending = [];
  bool _isLoadingRequests = true;
  String _addressText = '';
  bool _isLocatingAddress = false;

  // سجل طلبات المزوّد (تبويب الطلبات)
  List<Order> _providerOrders = [];
  bool _isLoadingOrders = true;

  Map<String, String> _serviceNames = {};
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadProviderData();
    _loadCurrentAddress();
    _loadServiceNames();
    _loadAssignedOrders();
    _loadProviderOrders();
    _subscribeToOrderChanges();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<NotificationCubit>();
      cubit.loadNotifications();
      cubit.subscribeToNotifications();
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadProviderData() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final provider = await _client
          .from('providers')
          .select('workshop_name, latitude, longitude, is_online')
          .eq('id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _workshopName = provider?['workshop_name'] ?? '';
          _providerLat = (provider?['latitude'] as num?)?.toDouble() ?? 0;
          _providerLng = (provider?['longitude'] as num?)?.toDouble() ?? 0;
          _isOnline = provider?['is_online'] ?? true;
        });
      }
    } catch (e) {
      // silent
    }
  }

  /// يجيب العنوان الحالي الحقيقي للجهاز ويعرضه في أعلى لوحة التحكم.
  Future<void> _loadCurrentAddress() async {
    if (_isLocatingAddress) return;

    setState(() {
      _isLocatingAddress = true;
      _addressText = '';
    });

    final address = await LocationService.instance.getCurrentAddress(forceRefresh: true);

    if (mounted) {
      setState(() {
        _addressText = address ?? '';
        _isLocatingAddress = false;
      });
    }
  }

  Future<void> _loadServiceNames() async {
    try {
      final response = await _client.from('service_types').select('id, name_ar');
      _serviceNames = {
        for (final row in response)
          row['id'] as String: row['name_ar'] as String? ?? row['id'] as String,
      };
    } catch (_) {}
  }

  String _serviceName(String id) => _serviceNames[id] ?? id;

  /// الطلبات المعيّنة لهذا المزوّد بانتظار عرض سعر (بتظهر في لوحة التحكم)
  Future<void> _loadAssignedOrders() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoadingRequests = true);

    try {
      final response = await _client
          .from('orders')
          .select()
          .eq('provider_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(20);

      final orders = response.map((json) => Order.fromJson(json)).toList();

      if (mounted) {
        setState(() {
          _assignedPending = orders;
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRequests = false);
      }
    }
  }

  /// سجل كل طلبات المزوّد (تبويب الطلبات)
  Future<void> _loadProviderOrders() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoadingOrders = true);

    try {
      final response = await _client
          .from('orders')
          .select()
          .eq('provider_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final orders = response.map((json) => Order.fromJson(json)).toList();

      if (mounted) {
        setState(() {
          _providerOrders = orders;
          _isLoadingOrders = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingOrders = false);
      }
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * pi / 180;

  void _subscribeToOrderChanges() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    _channel = _client
        .channel('provider-orders-$userId')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'orders',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'provider_id',
        value: userId,
      ),
      callback: (payload) {
        _loadAssignedOrders();
        _loadProviderOrders();
      },
    )
        .subscribe();
  }

  Future<void> _toggleOnline(bool val) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isOnline = val);

    try {
      await _client
          .from('providers')
          .update({'is_online': val})
          .eq('id', userId);
    } catch (e) {
      if (mounted) {
        setState(() => _isOnline = !val);
      }
    }
  }

  /// قبول = فتح شاشة عرض السعر (انتقال الحالة بيتم جوه RPC provider_set_price)
  void _acceptOrder(String orderId) {
    context.push('/request/quote?orderId=$orderId');
  }

  Future<void> _rejectOrder(String orderId) async {
    try {
      await _client.rpc('provider_reject_order', params: {
        'p_order_id': orderId,
      });

      if (mounted) {
        setState(() {
          _assignedPending.removeWhere((o) => o.id == orderId);
        });
      }
    } catch (e) {
      if (!mounted) return;
      // الطلب لم يعد في حالة "بانتظار عرض سعر" (انتهت مدته) → يُزال من اللوحة
      final msg = e.toString();
      if (msg.contains('ORDER_NOT_PENDING') || msg.contains('NOT_ASSIGNED')) {
        setState(() {
          _assignedPending.removeWhere((o) => o.id == orderId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('هذا الطلب لم يعد متاحاً (ربما انتهت مدته)'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء رفض الطلب: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _completeOrder(String orderId) async {
    try {
      await _client.rpc('provider_complete_order', params: {
        'p_order_id': orderId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إتمام الطلب بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadProviderOrders();
        _loadAssignedOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildDashboardTab(context, isDark, l10n),
            _buildOrdersTab(context, isDark, l10n),
            _buildNotificationsTab(context, isDark, l10n),
            _buildProfileTab(context, isDark, l10n),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context, isDark, l10n),
    );
  }

  Widget _buildDashboardTab(BuildContext context, bool isDark, AppLocalizations? l10n) {
    final profileState = context.watch<ProfileCubit>().state;
    final userName = profileState is ProfileLoaded ? profileState.profile.fullName : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.home ?? 'لوحة التحكم',
                      style: TextStyle(
                        fontFamily: 'Zain',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      '${l10n?.welcomeUser ?? 'مرحباً،'} ${userName.isNotEmpty ? userName : (l10n?.serviceProvider ?? 'مقدم الخدمة')}',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    if (_addressText.isNotEmpty || _isLocatingAddress) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _loadCurrentAddress,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: AppColors.orangePrimary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _isLocatingAddress
                                    ? 'جاري تحديد الموقع...'
                                    : _addressText,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _currentIndex = 2),
                icon: Icon(
                  Icons.notifications_outlined,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          AvailabilityToggle(
            isOnline: _isOnline,
            onToggle: _toggleOnline,
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Text(
                'طلباتك الحالية',
                style: TextStyle(
                  fontFamily: 'Zain',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(width: 8),
              if (_assignedPending.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.orangePrimary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_assignedPending.length}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          RefreshIndicator(
            onRefresh: _loadAssignedOrders,
            color: AppColors.orangePrimary,
            child: _isLoadingRequests
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(color: AppColors.orangePrimary)),
                  )
                : _assignedPending.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n?.noNearbyRequests ?? 'لا توجد طلبات معيّنة لك حالياً',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _assignedPending.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = _assignedPending[index];
                      final distance = order.latitude != 0 && _providerLat != 0
                          ? _calculateDistance(
                              _providerLat, _providerLng, order.latitude, order.longitude)
                          : 0.0;
                      return NearbyRequestCard(
                        carMake: order.carMake,
                        carModel: order.carModel,
                        carYear: order.carYear,
                        issueType: _serviceName(order.serviceTypeId),
                        distance: distance,
                        address: order.addressText ?? '',
                        attachments: order.attachments ?? const [],
                        deadline: order.respondDeadline,
                        onAccept: () => _acceptOrder(order.id),
                        onReject: () => _rejectOrder(order.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTab(BuildContext context, bool isDark, AppLocalizations? l10n) {
    if (_isLoadingOrders) {
      return const Center(child: CircularProgressIndicator(color: AppColors.orangePrimary));
    }

    if (_providerOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 64,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.noOrders ?? 'لا توجد طلبات حالياً',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProviderOrders,
      color: AppColors.orangePrimary,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _providerOrders.length,
        itemBuilder: (context, index) => _buildProviderOrderCard(
            context, isDark, _providerOrders[index]),
      ),
    );
  }

  Widget _buildProviderOrderCard(BuildContext context, bool isDark, Order order) {
    final statusColor = _orderStatusColor(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.statusLabel,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              const Spacer(),
              if (order.offeredPrice != null)
                Text(
                  '${order.offeredPrice!.toStringAsFixed(0)} ج.م',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.orangePrimary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            order.carDisplayName,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _serviceName(order.serviceTypeId),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (order.status == OrderStatus.pending)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptOrder(order.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orangePrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'تقديم عرض سعر',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectOrder(order.id),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'رفض',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else if (order.status == OrderStatus.confirmed)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _completeOrder(order.id),
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text(
                      'إتمام الطلب',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _orderStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.priced:
        return AppColors.orangePrimary;
      case OrderStatus.confirmed:
        return AppColors.success;
      case OrderStatus.rejectedByProvider:
      case OrderStatus.rejectedByOwner:
      case OrderStatus.cancelled:
        return AppColors.error;
      case OrderStatus.completed:
        return AppColors.success;
    }
  }

  Widget _buildNotificationsTab(BuildContext context, bool isDark, AppLocalizations? l10n) {
    final state = context.watch<NotificationCubit>().state;

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.orangePrimary));
    }

    if (state.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.noNewNotifications ?? 'لا توجد إشعارات جديدة',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<NotificationCubit>().loadNotifications(),
      color: AppColors.orangePrimary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (state.unreadCount > 0)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () => context.read<NotificationCubit>().markAllAsRead(),
                icon: const Icon(Icons.mark_email_read_outlined, size: 20),
                label: Text(
                  l10n?.markAllRead ?? 'تعيين الكل كمقروء',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.orangePrimary,
                ),
              ),
            ),
          ...List.generate(state.notifications.length, (index) {
            final notification = state.notifications[index];
          return GestureDetector(
            onTap: () {
              if (!notification.isRead) {
                context.read<NotificationCubit>().markAsRead(notification.id);
              }
              if (notification.orderId != null) {
                context.push('/request/track?orderId=${notification.orderId}');
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: notification.isRead
                      ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                      : notification.color.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: notification.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(notification.icon, color: notification.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            fontFamily: 'Zain',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        if (notification.body.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            notification.body,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          notification.timeAgo(),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: notification.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
        ],
      ),
    );
  }

  Widget _buildProfileTab(BuildContext context, bool isDark, AppLocalizations? l10n) {
    final settingsCubit = context.watch<AppSettingsCubit>();
    final isArabic = settingsCubit.state.locale.languageCode == 'ar';
    final profileState = context.watch<ProfileCubit>().state;
    final userName = profileState is ProfileLoaded ? profileState.profile.fullName : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.orangePrimary.withValues(alpha: 0.15),
            child: const Icon(Icons.business_rounded, size: 50, color: AppColors.orangePrimary),
          ),
          const SizedBox(height: 16),
          Text(
            _workshopName.isNotEmpty ? _workshopName : userName,
            style: TextStyle(
              fontFamily: 'Zain',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 32),
          _buildProfileOption(
            context,
            icon: Icons.business_outlined,
            title: l10n?.workshopInfo ?? 'بيانات الورشة',
            isDark: isDark,
            onTap: () async {
              await context.push('/provider/workshop');
              _loadProviderData();
            },
          ),
          _buildProfileOption(
            context,
            icon: Icons.build_outlined,
            title: l10n?.mySpecializations ?? 'تخصصاتي',
            isDark: isDark,
            onTap: () => context.push('/provider/specialties'),
          ),
          _buildProfileOption(
            context,
            icon: Icons.language_rounded,
            title: '${l10n?.languageLabel ?? 'اللغة'}: ${l10n?.currentLanguage ?? (isArabic ? 'العربية' : 'English')}',
            isDark: isDark,
            onTap: () => settingsCubit.toggleLocale(),
          ),
          _buildProfileOption(
            context,
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            title: isArabic ? (l10n?.lightMode ?? 'الوضع الفاتح') : (l10n?.darkMode ?? 'الوضع الداكن'),
            isDark: isDark,
            onTap: () => settingsCubit.toggleTheme(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () async {
                await AuthService().signOut();
                if (context.mounted) context.go('/select-user-type');
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                l10n?.logout ?? 'تسجيل الخروج',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _showDeleteAccountDialog(context, l10n),
            child: Text(
              l10n?.deleteAccount ?? 'حذف الحساب',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.orangePrimary),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        onTap: onTap,
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AppLocalizations? l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n?.deleteAccount ?? 'حذف الحساب',
          style: TextStyle(
            fontFamily: 'Zain',
            fontSize: 20,
            color: AppColors.error,
          ),
        ),
        content: Text(
          l10n?.deleteAccountConfirm ?? 'هل أنت متأكد من حذف حسابك نهائياً؟ لن تتمكن من استعادته.',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n?.cancel ?? 'إلغاء',
              style: const TextStyle(fontFamily: 'Cairo', color: AppColors.lightTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await AuthService().deleteAccount();
                if (context.mounted) context.go('/select-user-type');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('حدث خطأ: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'حذف',
              style: TextStyle(fontFamily: 'Cairo', color: AppColors.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, bool isDark, AppLocalizations? l10n) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) {
            _loadProviderOrders();
          }
          if (index == 2) {
            context.read<NotificationCubit>().loadNotifications();
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.orangePrimary,
        unselectedItemColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        selectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_outlined),
            activeIcon: const Icon(Icons.dashboard_rounded),
            label: l10n?.home ?? 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt_long_outlined),
            activeIcon: const Icon(Icons.receipt_long_rounded),
            label: l10n?.orders ?? 'الطلبات',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.notifications_outlined),
            activeIcon: const Icon(Icons.notifications_rounded),
            label: l10n?.notifications ?? 'الإشعارات',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline_rounded),
            activeIcon: const Icon(Icons.person_rounded),
            label: l10n?.myAccount ?? 'حسابي',
          ),
        ],
      ),
    );
  }
}