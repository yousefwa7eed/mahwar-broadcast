import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/order.dart';
import '../../l10n/app_localizations.dart';

/// هل تاريخ المعاملة (created_at) في نفس اليوم المختار للفلترة؟
bool orderMatchesDay(Order order, DateTime day) {
  final local = order.createdAt?.toLocal();
  if (local == null) return false;
  return local.year == day.year && local.month == day.month && local.day == day.day;
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

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  int _selectedTab = 0;

  /// فلترة حسب يوم المعاملة — null يعني كل الأيام.
  DateTime? _filterDate;

  List<Order> _orders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await _client
          .from('orders')
          .select()
          .eq(widget.forProvider ? 'provider_id' : 'car_owner_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final orders = response.map((json) => Order.fromJson(json)).toList();

      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'تعذّر تحميل السجل: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<Order> get _tabOrders {
    switch (_selectedTab) {
      case 1:
        return _orders
            .where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.priced)
            .toList();
      case 2:
        return _orders.where((o) => o.status == OrderStatus.completed).toList();
      case 3:
        return _orders
            .where((o) =>
                o.status == OrderStatus.cancelled ||
                o.status == OrderStatus.rejectedByProvider ||
                o.status == OrderStatus.rejectedByOwner)
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
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      helpText: 'اختر تاريخ المعاملة',
      cancelText: 'إلغاء',
      confirmText: 'تطبيق',
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
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n?.orderHistory ?? 'سجل الطلبات',
          style: TextStyle(
            fontFamily: 'Zain',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orangePrimary))
          : _error != null
          ? _buildError(context, isDark, l10n)
          : Column(
              children: [
                // Filter Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _pickFilterDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _filterDate != null
                              ? AppColors.orangePrimary.withValues(alpha: 0.6)
                              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
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
                                  ? 'فلترة بحث بالتاريخ: كل الأيام'
                                  : 'تاريخ المعاملة: ${_formatDay(context, _filterDate!)}',
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
                          onRefresh: _loadOrders,
                          color: AppColors.orangePrimary,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: _filteredOrders.length,
                            itemBuilder: (context, index) {
                              final order = _filteredOrders[index];
                              return _buildOrderCard(context, isDark, order, l10n);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildError(BuildContext context, bool isDark, AppLocalizations? l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadOrders,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orangePrimary),
            child: const Text(
              'إعادة المحاولة',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, bool isDark, AppLocalizations? l10n) {
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
            l10n?.noOrders ?? 'لا توجد طلبات',
            style: TextStyle(
              fontFamily: 'Zain',
              fontSize: 20,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
              color: isSelected ? AppColors.orangePrimary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(
      BuildContext context, bool isDark, Order order, AppLocalizations? l10n) {
    final statusColor = _statusColor(order.status);
    final statusLabel = order.statusLabel;

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
                    statusLabel,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const Spacer(),
                if (order.createdAt != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_rounded,
                        size: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(context, order.createdAt!),
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
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
              '${l10n?.serviceLabel ?? 'خدمة:'} ${order.serviceTypeId}',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            if (order.offeredPrice != null) ...[
              const SizedBox(height: 8),
              Text(
                '${order.offeredPrice!.toStringAsFixed(0)} ج.م',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.orangePrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(OrderStatus status) {
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

  String _formatDate(BuildContext context, DateTime date) {
    final local = date.toLocal();
    final material = MaterialLocalizations.of(context);
    final day = material.formatMediumDate(local);
    final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$day • $time';
  }

  /// عرض اليوم فقط (بدون وقت) لشريط فلترة التاريخ.
  String _formatDay(BuildContext context, DateTime date) {
    final local = date.toLocal();
    return MaterialLocalizations.of(context).formatMediumDate(local);
  }
}