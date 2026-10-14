import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/logout_coordinator.dart';
import '../../core/auth/profile_cubit.dart';
import '../../core/constants/app_colors.dart';
import '../../core/errors/rpc_error_translator.dart';
import '../../core/models/order.dart';
import '../../core/notifications/notification_cubit.dart';
import '../../core/services/location_service.dart';
import '../../core/services/server_clock.dart';
import '../../core/settings/app_settings_cubit.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/profile_name_text.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/home_header.dart';
import 'widgets/sos_emergency_banner.dart';
import 'widgets/services_grid.dart';
import 'widgets/active_order_widget.dart';
import 'widgets/provider_rating_dialog.dart';
import '../notifications/notification_actions.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  int _currentIndex = 0;

  List<Order> _recentOrders = [];
  bool _isLoadingOrders = true;
  String _addressText = '';
  bool _isLocatingAddress = false;
  RealtimeChannel? _ordersChannel;

  /// الحالة الأخيرة التي رُأيت عليها كل طلب هذا الجلسة — تُستخدم لاكتشاف
  /// انتقال الطلب إلى «مكتمل» فقط عند حدوثه فعلياً (مع بدء أول تحميل
  /// كمرجع دون تنبيه). الطلبات المكتملة القديمة من جلسات سابقة لا تُنبّه.
  final Map<String, String> _seenOrderStatuses = {};

  /// طلبات معروضة عليها نافذة التقييم هذا الجلسة لمنع التكرار.
  final Set<String> _ratingPromptedOrders = {};

  @override
  void initState() {
    super.initState();
    _loadRecentOrders();
    _loadCurrentAddress();
    _subscribeToOrderChanges();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<NotificationCubit>();
      cubit.loadNotifications();
      cubit.subscribeToNotifications();
    });
  }

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    super.dispose();
  }

  /// يجيب العنوان الحالي الحقيقي للجهاز ويعرضه في أعلى الصفحة.
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

  Future<void> _loadRecentOrders() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoadingOrders = false);
      return;
    }

    try {
      final response = await _client
          .from('orders')
          .select()
          .eq('car_owner_id', userId)
          .order('created_at', ascending: false)
          .limit(20);

      final orders = response.map((json) => Order.fromJson(json)).toList();

      _processOrderStatusTransitions(orders);

      if (mounted) {
        setState(() {
          _recentOrders = orders;
          _isLoadingOrders = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingOrders = false);
      }
    }
  }

  /// يتبّع الحالة السابقة لكل طلب، وعند ملاحظة انتقال حي إلى «مكتمل»
  /// يعرض نافذة تقييم المزوّد (مرة واحدة لكل طلب في الجلسة). أول تحميل
  /// يُعتبر مرجعاً فقط — حتى لا تُنفَّذ النافذة لطلبات قديمة مكتملة.
  void _processOrderStatusTransitions(List<Order> orders) {
    for (final order in orders) {
      final previous = _seenOrderStatuses[order.id];
      _seenOrderStatuses[order.id] = order.status.name;

      if (order.status != OrderStatus.completed) continue;
      if (previous == null || previous == OrderStatus.completed.name) continue;
      if (_ratingPromptedOrders.contains(order.id)) continue;

      _ratingPromptedOrders.add(order.id);
      _maybePromptRating(order);
    }
  }

  /// يعرض نافذة التقييم بعد التأكد أن الطلب لم يُقيَّم بعد وأن المالك ما زال
  /// على شاشة البيت (إن كان على شاشة التتبع، فهي تعرض التقييم بنفسها).
  Future<void> _maybePromptRating(Order order) async {
    if (!mounted) return;

    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;

    try {
      final existing = await _client
          .from('ratings')
          .select('id')
          .eq('order_id', order.id)
          .maybeSingle();
      if (existing != null) return;
    } catch (_) {
      // القراءة فشلت — نعرض النافذة على أي حال؛ إرسال التقييم نفسه محمي
      // بعملية rate_provider التي ترفض التكرار.
    }

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => ProviderRatingDialog(
          orderId: order.id,
        ),
      );
    });
  }

  /// قبول عرض السعر مباشرة من البطاقة في البيت (RPC آمن يتحقق من هوية
  /// المالك). البطاقة تتحدّث حيوياً بعدها عبر Realtime إلى مرحلة التأكيد.
  Future<void> _acceptOffer(String orderId) async {
    final l10n = AppLocalizations.of(context);

    try {
      await _client.rpc('owner_accept_price', params: {
        'p_order_id': orderId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.orderConfirmed ?? 'تم تأكيد الطلب بنجاح!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(RpcErrorTranslator.translate(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// رفض عرض السعر مباشرة من البطاقة — الطلب ينتقل لـ rejected_by_owner
  /// وتختفي البطاقة (حالة نهائية) عبر التحديث الحي.
  Future<void> _rejectOffer(String orderId) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await showConfirmDialog(
      context,
      title: 'رفض عرض السعر؟',
      message: 'سيتم رفض عرض المزوّد وإنهاء هذا الطلب.',
      confirmLabel: 'نعم، رفض العرض',
      confirmColor: AppColors.error,
    );
    if (confirmed != true || !mounted) return;

    try {
      await _client.rpc('owner_reject_price', params: {
        'p_order_id': orderId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.priceRejected ?? 'تم رفض عرض السعر'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(RpcErrorTranslator.translate(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// اشتراك حي على طلبات هذا المالك حتى يتحدّث البيت فورياً عند أي تغيير
  /// في حالة الطلب (مثل تأكيد السعر، إلغاء، اكتمال) دون انتظار فتح الصفحة.
  void _subscribeToOrderChanges() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    _ordersChannel = _client
        .channel('owner-orders-$userId')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'orders',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'car_owner_id',
        value: userId,
      ),
      callback: (payload) => _loadRecentOrders(),
    )
        .subscribe();
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
            _buildHomeTab(context, isDark, l10n),
            _buildOrdersTab(context, isDark, l10n),
            _buildNotificationsTab(context, isDark, l10n),
            _buildProfileTab(context, isDark, l10n),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context, isDark),
    );
  }

  Widget _buildHomeTab(BuildContext context, bool isDark, AppLocalizations? l10n) {
    final activeOrder = _activeOrder;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeHeader(
            locationText: _addressText.isEmpty ? null : _addressText,
            isLocatingLocation: _isLocatingAddress,
            onLocationTap: _loadCurrentAddress,
            unreadNotifications: context.watch<NotificationCubit>().state.unreadCount,
            onNotificationTap: () => setState(() => _currentIndex = 2),
            role: 'car_owner',
          ),
          const SizedBox(height: 8),
          SosEmergencyBanner(
            onPressed: () {
              // S.O.S: يفتح طلب نجدة فورية (ونش S.O.S) مباشرة
              context.push('/request/create?serviceId=crane');
            },
          ),
          // بطاقة حالة الطلب النشط — تظهر تلقائياً ما دام هناك طلب غير
          // نهائي وتختفي عند الإتمام/الإلغاء. النقر يفتح شاشة التتبع.
          if (activeOrder != null) ...[
            const SizedBox(height: 16),
            ActiveOrderWidget(
              order: activeOrder,
              onTap: () => context.push('/request/track?orderId=${activeOrder.id}'),
              onAccept: () => _acceptOffer(activeOrder.id),
              onReject: () => _rejectOffer(activeOrder.id),
            ),
          ],
          const SizedBox(height: 16),
          ServicesGrid(
            onServiceTap: (service) {
              context.push('/request/create?serviceId=${service.id}');
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOrdersTab(BuildContext context, bool isDark, AppLocalizations? l10n) {
    if (_isLoadingOrders) {
      return const Center(child: CircularProgressIndicator(color: AppColors.orangePrimary));
    }

    if (_recentOrders.isEmpty) {
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
              l10n?.noOrdersCurrently ?? 'لا توجد طلبات حالياً',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Text(
                l10n?.orderHistory ?? 'سجل الطلبات',
                style: TextStyle(
                  fontFamily: 'Zain',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/orders/owner'),
                child: const Text(
                  'عرض الكل',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: AppColors.orangePrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadRecentOrders,
            color: AppColors.orangePrimary,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _recentOrders.length,
              itemBuilder: (context, index) {
                final order = _recentOrders[index];
                final statusColor = _orderStatusColor(order.status);
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/request/track?orderId=${order.id}'),
                  child: Container(
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
                            if (order.offeredPrice != null) ...[
                              const Spacer(),
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
                          '${l10n?.serviceLabel ?? 'خدمة:'} ${order.serviceTypeId}',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
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
      case OrderStatus.rejected:
      case OrderStatus.rejected:
      case OrderStatus.cancelled:
        return AppColors.error;
      case OrderStatus.completed:
        return AppColors.success;
    }
  }

  /// أحدث طلب نشط لهذا المالك — يُشتق من آخر قائمة محمّلة (مرتّبة تنازلياً
  /// بالإنشاء) دون استعلام إضافي. البطاقة تظهر فقط لطلب أُرسل فعلياً لمزوّد
  /// (provider_id مسجّل) ولم يصل بعد لحالة نهائية؛ الطلب المعلّق قبل اختيار
  /// المزوّد لا يظهر لأنه لم يُرسل بعد. تحديثها الحي يأتي من اشتراك Realtime
  /// الموجود في [_subscribeToOrderChanges].
  Order? get _activeOrder {
    for (final order in _recentOrders) {
      if (order.isActive) {
        return order;
      }
    }
    return null;
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
            // معالج موحّد مع صفحة الإشعارات: deep link خارجي / home /
            // طلب / إشعار عام (شاشة التفاصيل).
            onTap: () => openNotificationFromList(context, notification),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
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
                          notification.timeAgo(ServerClock.instance.now),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.orangePrimary.withValues(alpha: 0.15),
            child: const Icon(Icons.person_rounded, size: 50, color: AppColors.orangePrimary),
          ),
          const SizedBox(height: 16),
          // أثناء تحميل الملف الشخصي نعرض شيمر مكان الاسم مع إعادة محاولة
          // عند الخطأ — لا نص مؤقت من user_metadata.
          ProfileNameText(
            emptyFallback: l10n?.myAccount ?? 'حسابي',
            skeletonWidth: 180,
            skeletonHeight: 36,
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
            icon: Icons.person_outline_rounded,
            title: l10n?.profile ?? 'الملف الشخصي',
            isDark: isDark,
            onTap: () => context.push('/profile'),
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
          _buildProfileOption(
            context,
            icon: Icons.description_outlined,
            title: l10n?.termsOfUse ?? 'شروط الاستخدام',
            isDark: isDark,
            onTap: () => context.push('/terms'),
          ),
          _buildProfileOption(
            context,
            icon: Icons.privacy_tip_outlined,
            title: l10n?.privacyPolicy ?? 'سياسة الخصوصية',
            isDark: isDark,
            onTap: () => context.push('/privacy'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ListenableBuilder(
              listenable: LogoutCoordinator.isRunning,
              builder: (context, _) => OutlinedButton(
                onPressed: LogoutCoordinator.isRunning.value
                    ? null
                    : () => LogoutCoordinator().logout(
                          context: context,
                          resetProfile:
                              () => context.read<ProfileCubit>().reset(),
                        ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: LogoutCoordinator.isRunning.value
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : Text(
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

  Widget _buildBottomNav(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);
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
            _loadRecentOrders();
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
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home_rounded),
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
