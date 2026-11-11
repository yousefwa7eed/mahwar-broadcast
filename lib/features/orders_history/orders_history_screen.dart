import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/order.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/order_prefetch_service.dart';
import '../../core/widgets/offline_view.dart';
import '../../core/widgets/order_history_card.dart';
import '../../core/widgets/skeletons.dart';
import '../../l10n/app_localizations.dart';

/// هل تاريخ المعاملة (created_at) في نفس اليوم المختار للفلترة؟
bool orderMatchesDay(Order order, DateTime day) {
  final local = order.createdAt?.toLocal();
  if (local == null) return false;
  return local.year == day.year &&
      local.month == day.month &&
      local.day == day.day;
}

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key, this.forProvider = false});

  /// عرض سجل طلبات المزوّد (فلترة على provider_id) بدل سجل العميل
  /// (فلترة على car_owner_id) — مع بقاء الشكل والتبويبات وفلترة التاريخ
  /// نفسها، لأن بطاقة الطلب (الحالة/التاريخ/السيارة/الخدمة/السعر) صالحة
  /// للطرفين. النقر على أي طلب يفتح شاشة التتبع (وفيها «ملخّص المعاملة»).
  final bool forProvider;

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen>
    with SkeletonGate<OrdersHistoryScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  int _selectedTab = 0;

  /// فلترة حسب يوم المعاملة — null يعني كل الأيام.
  DateTime? _filterDate;

  List<Order> _orders = [];

  /// هل اكتمل تحميل ناجح (أو وُجدت لقطة جلب مسبق)؟ يمنع مسح رسالة الفشل
  /// عند تحديث سجل فارغ معروض.
  bool _ordersLoaded = false;

  /// سبب فشل آخر تحميل — null بعد أي نجاح؛ لا يُعرض نص استثناء خام.
  LoadFailure? _failure;

  @override
  void initState() {
    super.initState();
    // لقطة الجلب المسبق: تُعرض فورًا ثم يُحدَّث السجل من الخادم في الخلفية.
    final prefetch = OrderPrefetchService.instance;
    final userId = _client.auth.currentUser?.id;
    final cached = widget.forProvider
        ? prefetch.providerOrdersFor(userId)
        : prefetch.ownerOrdersFor(userId);
    if (cached != null) {
      _orders = cached;
      _ordersLoaded = true;
    }
    unawaited(runWithSkeleton(_loadOrders));
  }

  Future<void> _loadOrders() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    if (!_ordersLoaded && mounted) {
      setState(() => _failure = null);
    }

    try {
      final response = await _client
          .from('orders')
          .select()
          .eq(widget.forProvider ? 'provider_id' : 'car_owner_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final orders = response.map((json) => Order.fromJson(json)).toList();
      final prefetch = OrderPrefetchService.instance;
      if (widget.forProvider) {
        prefetch.setProviderOrders(userId, orders);
      } else {
        prefetch.setOwnerOrders(userId, orders);
      }

      if (mounted) {
        setState(() {
          _orders = orders;
          _ordersLoaded = true;
          _failure = null;
        });
      }
    } catch (_) {
      final failure = await classifyLoadFailure();
      if (mounted) {
        setState(() {
          // سجل قديم معروض أفضل من شاشة خطأ — يبقى ويُحدَّث في المحاولة التالية.
          if (_orders.isEmpty) _failure = failure;
        });
      }
    }
  }

  List<Order> get _tabOrders {
    switch (_selectedTab) {
      case 1:
        return _orders
            .where(
              (o) =>
                  o.status == OrderStatus.pending ||
                  o.status == OrderStatus.priced,
            )
            .toList();
      case 2:
        return _orders.where((o) => o.status == OrderStatus.completed).toList();
      case 3:
        return _orders
            .where(
              (o) =>
                  o.status == OrderStatus.cancelled ||
                  o.status == OrderStatus.rejectedByProvider ||
                  o.status == OrderStatus.rejectedByOwner,
            )
            .toList();
      default:
        return _orders;
    }
  }

  List<Order> get _filteredOrders {
    final byTab = _tabOrders;
    if (_filterDate == null) return byTab;
    return byTab.where((o) => orderMatchesDay(o, _filterDate!)).toList();
  }

  Future<void> _pickFilterDate() async {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      helpText: l10n?.selectTransactionDate ?? 'اختر تاريخ المعاملة',
      cancelText: l10n?.cancel ?? 'إلغاء',
      confirmText: l10n?.apply ?? 'تطبيق',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.orangePrimary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _filterDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n?.orderHistory ?? 'سجل الطلبات',
          style: TextStyle(
            fontFamily: 'Zain',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: skeletonVisible
          ? const OrdersHistorySkeleton()
          : _orders.isEmpty && _failure != null
          ? _failure == LoadFailure.offline
                ? OfflineView(onRetry: _loadOrders)
                : LoadFailedView(
                    message: l10n?.ordersLoadFailed ?? 'تعذّر تحميل الطلبات',
                    onRetry: _loadOrders,
                  )
          : Column(
              children: [
                // Filter Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _buildTab(l10n?.allTab ?? 'الكل', 0, isDark),
                      const SizedBox(width: 8),
                      _buildTab(l10n?.activeTab ?? 'النشطة', 1, isDark),
                      const SizedBox(width: 8),
                      _buildTab(l10n?.completedTab ?? 'المكتملة', 2, isDark),
                      const SizedBox(width: 8),
                      _buildTab(l10n?.cancelledTab ?? 'الملغاة', 3, isDark),
                    ],
                  ),
                ),

                // فلترة بحث بالتاريخ (تاريخ المعاملة)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _pickFilterDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkCard
                            : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _filterDate != null
                              ? AppColors.orangePrimary.withValues(alpha: 0.6)
                              : (isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            size: 18,
                            color: AppColors.orangePrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _filterDate == null
                                  ? (l10n?.filterByDateAllDays ??
                                        'فلترة بحث بالتاريخ: كل الأيام')
                                  : '${l10n?.transactionDateLabel ?? 'تاريخ المعاملة'}: ${_formatDay(context, _filterDate!)}',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _filterDate != null
                                    ? AppColors.orangePrimary
                                    : (isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary),
                              ),
                            ),
                          ),
                          if (_filterDate != null)
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => setState(() => _filterDate = null),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Orders List
                Expanded(
                  child: _filteredOrders.isEmpty
                      ? _buildEmpty(context, isDark, l10n)
                      : RefreshIndicator(
                          onRefresh: () => runWithSkeleton(_loadOrders),
                          color: AppColors.orangePrimary,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            itemCount: _filteredOrders.length,
                            itemBuilder: (context, index) {
                              final order = _filteredOrders[index];
                              return OrderHistoryCard(
                                order: order,
                                onTap: () => context.push(
                                  widget.forProvider
                                      ? '/orders/provider/detail?orderId=${order.id}'
                                      : '/request/track?orderId=${order.id}',
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmpty(
    BuildContext context,
    bool isDark,
    AppLocalizations? l10n,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 64,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            l10n?.noOrders ?? 'لا توجد طلبات',
            style: TextStyle(
              fontFamily: 'Zain',
              fontSize: 20,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, bool isDark) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.orangePrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.orangePrimary
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary),
            ),
          ),
        ),
      ),
    );
  }

  /// عرض اليوم فقط (بدون وقت) لشريط فلترة التاريخ.
  String _formatDay(BuildContext context, DateTime date) {
    final local = date.toLocal();
    return MaterialLocalizations.of(context).formatMediumDate(local);
  }
}
