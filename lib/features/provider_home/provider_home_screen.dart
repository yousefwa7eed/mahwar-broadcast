import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/logout_coordinator.dart';
import '../../core/auth/profile_cubit.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/avatar_config.dart';
import '../../core/errors/rpc_error_translator.dart';
import '../../core/models/order.dart';
import '../../core/notifications/notification_cubit.dart';
import '../../core/services/location_service.dart';
import '../../core/services/server_clock.dart';
import '../../core/settings/app_settings_cubit.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/profile_name_text.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../l10n/app_localizations.dart';
import '../notifications/notification_actions.dart';
import 'widgets/active_order_card.dart';
import 'widgets/availability_toggle.dart';
import 'widgets/nearby_request_card.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen>
    with WidgetsBindingObserver {
  final SupabaseClient _client = Supabase.instance.client;
  int _currentIndex = 0;

  bool _isOnline = false;

  // هل أخفي المزوّد توفّره يدوياً في هذه الجلسة الحالية؟ إن كان كذلك فلا
  // نعيد تفعيله تلقائياً (احتراماً لقراره الصريح: إجازة قصيرة/عدم رغبة
  // بالتوافر اليوم رغم وجود جدول). لا يُشتق من قيمة is_online المحمّلة عند
  // فتح الشاشة — فافتتاح الحساب مخفياً قد يكون مجرد تأخر بداية الدوام ولا
  // ينبغي أن يحول دون توحيد الزر مع الجدول.
  bool _manuallyOffline = false;

  // هل فعّل المزوّد توافره يدوياً في هذه الجلسة؟ يُحترم قراره فلا نرجعه
  // إلى مخفي تلقائياً رغم خروجه عن الجدول (البقاء للعمل المتأخر أو خارج
  // الدوام). لا يُشتق من قيمة is_online المحمّلة عند الفتح — فالافتتاح على
  // OFF قد يكون لمجرد تآخر الجدول ولا ينبغي أن يمنع المراقب من تفعيله.
  bool _manuallyOnline = false;

  // مراقب الجدول: كل ثانيتين نتحقق من هل يستوجب الجدول تفعيلاً أم تخفياً،
  // ونوْحّد is_online معه — فدالة cron لا تلتقط سوى حدود مستقبلية، بينما
  // تغيير الجدول لبداية مضت (أو ليوم مغلق) يترك الحالة عالقة بدون هذا.
  Timer? _availabilityPoller;

  // هل مرّ التطبيق بدورة خلفية أثناء مراقبتنا؟ يُستخدم لجعل إعادة التفعيل
  // التلقائية متماثلة مع التخفي التلقائي: نعيد التفعيل فقط لمن خفّفناه نحن
  // في جلسة الاستخدام الحالية، لا لمن كان مخفياً قبل فتح التطبيق.
  bool _backgroundedWhileObserving = false;
  String _workshopName = '';
  double _providerLat = 0;
  double _providerLng = 0;

  // طلبات المزوّد النشطة (لوحة التحكم): إسناد أو عرض سعر أو تأكيد —
  // تبقى ظاهرة طوال دورة حياتها النشطة ولا تختفي إلّا عند الإتمام أو الإلغاء/الرفض.
  List<Order> _activeOrders = [];
  bool _isLoadingRequests = true;
  String _addressText = '';
  bool _isLocatingAddress = false;

  // أسماء العملاء والعناوين العربية للطلبات (يُحفظ مؤقتاً لتجنب إعادة الجلب)
  final Map<String, String> _ownerNames = {};
  final Map<String, String> _orderAddresses = {};
  final Map<String, String> _ownerAvatarIds = {};
  final Map<String, String> _ownerAvatarUrls = {};

  // سجل طلبات المزوّد (تبويب الطلبات)
  List<Order> _providerOrders = [];
  bool _isLoadingOrders = true;

  Map<String, String> _serviceNames = {};
  RealtimeChannel? _channel;

  // اشتراك Realtime على صف المزوّد نفسه: يبقى مفتاح التوفّر منسجماً مع
  // قاعدة البيانات عند تغيّر is_online من مصدر خارجي (وظيفة cron) بينما
  // الشاشة مفتوحة. RLS يسمح للمزوّد بقراءة صفّه، لذا لا يُحجب هنا.
  RealtimeChannel? _providerChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProviderData();
    _loadCurrentAddress();
    _loadServiceNames();
    _loadActiveOrders();
    _loadProviderOrders();
    _subscribeToOrderChanges();
    _subscribeToProviderChanges();
    _startAvailabilityPoller();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<NotificationCubit>();
      cubit.loadNotifications();
      cubit.subscribeToNotifications();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _availabilityPoller?.cancel();
    _channel?.unsubscribe();
    _providerChannel?.unsubscribe();
    super.dispose();
  }

  // تتبّع دورة حياة التطبيق: عند الخلفية نُخفيه عن قائمة المزوّدين القريبين،
  // وعند العودة للأمام نعيد تفعيله — إلا إذا كان قد أخفى نفسه يدوياً، أو كان
  // خارج ساعات دوامه المحددة (الجدول محترم: لا نُحيي حالة أطفأها cron عند
  // نهاية الدوام، فتستقر الحالة ولا ترجع للمزود من تلقاء نفسها).
  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _backgroundedWhileObserving = true;
        if (_isOnline) {
          _setProviderOnline(false);
        }
      case AppLifecycleState.resumed:
        if (_backgroundedWhileObserving) {
          _backgroundedWhileObserving = false;
          if (!_manuallyOffline && await _isWithinWorkingHours()) {
            _setProviderOnline(true);
          }
        }
        _refreshProviderLocation();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  // هل المزوّد حالياً داخل ساعات دوامه؟ نستدعي دالة جاهزة على السيرفر
  // (is_provider_available_now): تعيد true داخل الدوام أو إذا بلا جدول، و
  // false إذا خارج الدوام/اليوم مغلق. عند انقطاع الشبكة نعود true لنحافظ
  // على السلوك القديم (إعادة التفعيل) ولا نوقف عملاً قائماً.
  Future<bool> _isWithinWorkingHours() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return true;
    try {
      final result = await _client.rpc(
        'is_provider_available_now',
        params: {'p_provider_id': userId},
      );
      return result as bool? ?? true;
    } catch (_) {
      return true;
    }
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
        final online = provider?['is_online'] ?? false;
        setState(() {
          _workshopName = provider?['workshop_name'] ?? '';
          _providerLat = (provider?['latitude'] as num?)?.toDouble() ?? 0;
          _providerLng = (provider?['longitude'] as num?)?.toDouble() ?? 0;
          _isOnline = online == true;
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

  /// الطلبات النشطة لهذا المزوّد: بانتظار عرض سعر (pending)، أو عُرض السعر
  /// ولم يؤكّد العميل بعد (priced)، أو أُكّد وهو قيد التنفيذ (confirmed).
  /// تختفي البطاقة من القائمة فقط عند انتقال الطلب لحالة نهائية
  /// (completed / cancelled / rejected_by_provider / rejected_by_owner).
  Future<void> _loadActiveOrders() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoadingRequests = true);

    try {
      final response = await _client
          .from('orders')
          .select()
          .eq('provider_id', userId)
          .inFilter('status', ['pending', 'priced', 'confirmed'])
          .order('created_at', ascending: false)
          .limit(20);

      final orders = response.map((json) => Order.fromJson(json)).toList();

      if (mounted) {
        setState(() {
          _activeOrders = orders;
          _isLoadingRequests = false;
        });
      }
      _enrichActiveOrders(orders);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRequests = false);
      }
    }
  }

  /// يجلب بيانات إضافية لكل طلب نشط — اسم العميل (عبر RPC آمن
  /// لأن الـ RLS يخفي بقية المستخدمين) والعنوان العربي (reverse geocoding
  /// لأن address_text لا يُحفظ عند إنشاء الطلب). النتائج تُخزّن مؤقتاً.
  Future<void> _enrichActiveOrders(List<Order> orders) async {
    if (orders.isEmpty) return;

    final ownerIds = orders.map((o) => o.carOwnerId).toSet();
    for (final id in ownerIds) {
      if (_ownerNames.containsKey(id)) continue;
      try {
        final res = await _client.rpc('get_public_profile', params: {
          'p_user_id': id,
        });
        final rows = res as List;
        if (rows.isNotEmpty) {
          final row = rows.first as Map;
          final name = row['full_name'] as String?;
          _ownerNames[id] = (name == null || name.trim().isEmpty)
              ? 'العميل'
              : name.trim();
          final avatarId = row['avatar_id'] as String?;
          final avatarUrl = row['avatar_url'] as String?;
          if (avatarId != null && avatarId.isNotEmpty) {
            _ownerAvatarIds[id] = avatarId;
          }
          if (avatarUrl != null && avatarUrl.isNotEmpty) {
            _ownerAvatarUrls[id] = avatarUrl;
          }
        } else {
          _ownerNames[id] = 'العميل';
        }
      } catch (_) {
        _ownerNames[id] = 'العميل';
      }
    }

    for (final order in orders) {
      if (_orderAddresses.containsKey(order.id)) continue;
      final stored = order.addressText?.trim() ?? '';
      final isCoords = stored.isNotEmpty &&
          stored.contains(',') &&
          stored.split(',').every((p) => double.tryParse(p.trim()) != null);
      if (stored.isNotEmpty && !isCoords) {
        _orderAddresses[order.id] = stored;
      } else {
        _orderAddresses[order.id] = await LocationService.instance
            .getAddressForLocation(order.latitude, order.longitude);
      }
    }

    if (mounted) setState(() {});
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
        _loadActiveOrders();
        _loadProviderOrders();
      },
    )
        .subscribe();
  }

  // يبقي مفتاح التوفّر منسجماً مع is_online في قاعدة البيانات أثناء بقاء
  // الشاشة مفتوحة: عند تقليب cron الحالة عند حدود الجدول (أو أي كتابة
  // خارجية) تُطَبَّق القيمة هنا فوراً. صدى كتابة المزوّد نفسه بلا تأثير
  // (نفس القيمة => لا تغيير الظاهر)، وRLS يسمح للمزوّد بقراءة صفّه.
  void _subscribeToProviderChanges() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    _providerChannel = _client
        .channel('provider-self-$userId')
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'providers',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: userId,
      ),
      callback: (payload) {
        // نعتمد على is_online الحالي في السجل الجديد فقط (الحقيقة في قاعدة
        // البيانات)، ولا نقارنه بـ old_record — فالجدول كان replica identity
        // افتراضياً ولا يرسل عبره إلّا المفتاح، فكانت مقارنة true->false تفشل
        // ويبقى الزر مفتوحاً رغم إغلاق المزوّد على السيرفر.
        final online = (payload.newRecord['is_online'] ?? false) == true;
        if (!mounted || online == _isOnline) return;
        setState(() {
          _isOnline = online;
          _manuallyOffline = !online;
        });
      },
    )
        .subscribe();
  }

  Future<void> _toggleOnline(bool val) async {
    // قرار يدوي من المستخدم: نُسجّله حتى لا نتراجع عنه عند العودة للأمام
    // ولا يصحّحه مراقب الجدول.
    _manuallyOffline = !val;
    _manuallyOnline = val;
    await _setProviderOnline(val);
  }

  /// يكتب حالة التوفّر في قاعدة البيانات ويُبقي الواجهة متطابقة مع النتيجة؛
  /// أي فشل في الحفظ يُعيد الحالة السابقة بصمت (لكل من التبديل اليدوي
  /// وتغيّرات دورة الحياة).
  Future<void> _setProviderOnline(bool val) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isOnline = val);

    try {
      await _client
          .from('providers')
          .update({'is_online': val})
          .eq('id', userId);
    } catch (_) {
      if (mounted) {
        setState(() => _isOnline = !val);
      }
    }
  }

  // يبدأ مراقب الجدول: فحص أول فوري (بعد تحميل البيانات) ثم دورة كل 2 ثانية.
  // لا يتشغل إلا بوجود الجدول (المزوّد بلا جدول يبقى يدوياً مطلقاً)، ويصحّح
  // الحالة فقط حين تتعارض مع الجدول — دون التراجع عن قرار يدوي صريح
  // (إجازة قصيرة ⇒ _manuallyOffline، عمل متأخر ⇒ _manuallyOnline).
  void _startAvailabilityPoller() {
    _availabilityPoller?.cancel();
    _pollAvailability();
    _availabilityPoller = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollAvailability(),
    );
  }

  Future<void> _pollAvailability() async {
    if (!mounted) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final result = await _client.rpc(
        'provider_availability_snapshot',
        params: {'p_provider_id': userId},
      );
      final rows = result is List ? result : [result];
      if (rows.isEmpty || !mounted) return;
      final data = Map<String, dynamic>.from(rows.first as Map);
      final hasSchedule = data['has_schedule'] == true;
      final inHours = data['in_hours'] == true;

      // بلا جدول = تحكم يدوي كامل: لا نلمس الحالة إطلاقاً.
      if (!hasSchedule || inHours == _isOnline) return;

      if (inHours) {
        // الجدول يقتضي التفعيل: لا نتدخل إذا كان التخفي قراراً يدوياً.
        if (_manuallyOffline) return;
        _manuallyOnline = false;
        await _setProviderOnline(true);
      } else {
        // الجدول يقتضي التخفي: لا نتدخل إذا كان التفعيل يدوياً صريحاً.
        if (_manuallyOnline) return;
        _manuallyOffline = false;
        await _setProviderOnline(false);
      }
    } catch (_) {
      // مراقب ثانوي: قطع شبكة مؤقت لا يُزعج المستخدم.
    }
  }

  /// عند عودة التطبيق للأمام: تحدّث إحداثيات المزوّد من الموقع الفعلي
  /// للجهاز لتبقى القائمة القريبة دقيقة. إن فشل التحديد أو مُنعت الصلاحية
  /// نُبقي آخر إحداثيات معروفة بصمت دون إزعاج المستخدم.
  Future<void> _refreshProviderLocation() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final position = await LocationService.instance
          .getCurrentPosition(forceRefresh: true);
      if (position == null || !mounted) return;

      await _client.from('providers').update({
        'latitude': position.latitude,
        'longitude': position.longitude,
      }).eq('id', userId);

      if (mounted) {
        setState(() {
          _providerLat = position.latitude;
          _providerLng = position.longitude;
        });
      }
    } catch (_) {
      // صمت: نبقي آخر إحداثيات معروفة.
    }
  }

  /// قبول = فتح شاشة عرض السعر (انتقال الحالة بيتم جوه RPC provider_set_price)
  void _acceptOrder(String orderId) {
    context.push('/request/quote?orderId=$orderId');
  }

  Future<void> _rejectOrder(String orderId) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'رفض الطلب؟',
      message: 'سيتم إخطار العميل وإلغاء هذا الطلب.',
      confirmLabel: 'نعم، رفض الطلب',
      confirmColor: AppColors.error,
    );
    if (confirmed != true || !mounted) return;

    try {
      await _client.rpc('provider_reject_order', params: {
        'p_order_id': orderId,
      });

      if (mounted) {
        setState(() {
          _activeOrders.removeWhere((o) => o.id == orderId);
        });
      }
    } catch (e) {
      if (!mounted) return;
      // الطلب لم يعد في حالة "بانتظار عرض سعر" (انتهت مدته) → يُزال من اللوحة
      final msg = e.toString();
      if (msg.contains('ORDER_NOT_PENDING') || msg.contains('NOT_ASSIGNED')) {
        setState(() {
          _activeOrders.removeWhere((o) => o.id == orderId);
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
          content: Text(RpcErrorTranslator.translate(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _completeOrder(String orderId) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'إتمام الطلب؟',
      message: 'ستُعتبر الخدمة مكتملة وسيتمكّن العميل من تقييمك بعدها.',
      confirmLabel: 'إتمام الطلب',
      confirmColor: AppColors.success,
    );
    if (confirmed != true || !mounted) return;

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
        _loadActiveOrders();
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
    final profile = profileState is ProfileLoaded ? profileState.profile : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/profile/avatar?role=provider'),
                child: profile != null
                    ? AvatarWidget(
                        avatarId: profile.avatarId,
                        role: 'provider',
                        size: 44,
                        photoUrl: profile.avatarUrl,
                      )
                    : const ShimmerBox(
                        width: 44,
                        height: 44,
                        circle: true,
                      ),
              ),
              const SizedBox(width: 12),
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
                    // أثناء تحميل الملف الشخصي نعرض شيمر مكان الاسم، ولا
                    // نعرض نصاً مؤقتاً من user_metadata.
                    ProfileNameText(
                      prefix: l10n?.welcomeUser ?? 'مرحباً',
                      emptyFallback: l10n?.serviceProvider ?? 'مقدم الخدمة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      skeletonWidth: 110,
                      skeletonHeight: 21,
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
              if (_activeOrders.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.orangePrimary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_activeOrders.length}',
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
            onRefresh: _loadActiveOrders,
            color: AppColors.orangePrimary,
            child: _isLoadingRequests
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(color: AppColors.orangePrimary)),
                  )
                : _activeOrders.isEmpty
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
                    itemCount: _activeOrders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = _activeOrders[index];
                      final distance = order.latitude != 0 && _providerLat != 0
                          ? _calculateDistance(
                              _providerLat, _providerLng, order.latitude, order.longitude)
                          : 0.0;
                      return order.status == OrderStatus.pending
                          ? NearbyRequestCard(
                              customerName: _ownerNames[order.carOwnerId] ?? 'العميل',
                              carMake: order.carMake,
                              carModel: order.carModel,
                              carYear: order.carYear,
                              issueType: _serviceName(order.serviceTypeId),
                              distance: distance,
                              address: _orderAddresses[order.id] ?? '',
                              attachments: order.attachments ?? const [],
                              deadline: order.respondDeadline,
                              ownerPhone: order.ownerPhone,
                              sharePhone: order.sharePhone,
                              onAccept: () => _acceptOrder(order.id),
                              onReject: () => _rejectOrder(order.id),
                              onLocationTap: () =>
                                  context.push('/request/map?orderId=${order.id}'),
                              customerAvatarId: _ownerAvatarIds[order.carOwnerId],
                              customerAvatarUrl: _ownerAvatarUrls[order.carOwnerId],
                            )
                          : ActiveOrderCard(
                              customerName: _ownerNames[order.carOwnerId] ?? 'العميل',
                              carMake: order.carMake,
                              carModel: order.carModel,
                              carYear: order.carYear,
                              issueType: _serviceName(order.serviceTypeId),
                              address: _orderAddresses[order.id] ?? '',
                              attachments: order.attachments ?? const [],
                              ownerPhone: order.ownerPhone,
                              sharePhone: order.sharePhone,
                              status: order.status,
                              statusLabel: order.statusLabel,
                              offeredPrice: order.offeredPrice,
                              createdAt: order.createdAt,
                              onComplete: order.status == OrderStatus.confirmed
                                  ? () => _completeOrder(order.id)
                                  : null,
                              onLocationTap: () =>
                                  context.push('/request/map?orderId=${order.id}'),
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
              if (order.createdAt != null)
                Text(
                  _formatOrderDate(context, order.createdAt!),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              if (order.offeredPrice != null) ...[
                const SizedBox(width: 12),
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

  String _formatOrderDate(BuildContext context, DateTime date) {
    final local = date.toLocal();
    final material = MaterialLocalizations.of(context);
    final day = material.formatMediumDate(local);
    final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$day • $time';
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
            // معالج موحّد مع صفحة الإشعارات وتبويب العميل: deep link خارجي /
            // home / طلب / إشعار عام (شاشة التفاصيل).
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
            child: const Icon(Icons.business_rounded, size: 50, color: AppColors.orangePrimary),
          ),
          const SizedBox(height: 16),
          // اسم الورشة أولوية؛ وعند غيابه (أو أثناء تحميل الملف الشخصي)
          // يظهر شيمر مكان الاسم مع إعادة محاولة عند الخطأ.
          if (_workshopName.isNotEmpty)
            Text(
              _workshopName,
              style: TextStyle(
                fontFamily: 'Zain',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            )
          else
            ProfileNameText(
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
            icon: Icons.schedule_rounded,
            title: l10n?.workingHours ?? 'ساعات العمل',
            isDark: isDark,
            onTap: () => context.push('/provider/schedule'),
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
              onPressed: () => LogoutCoordinator().logout(
                context: context,
                resetProfile: () => context.read<ProfileCubit>().reset(),
              ),
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
                await SupabaseAuthService().deleteAccount();
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