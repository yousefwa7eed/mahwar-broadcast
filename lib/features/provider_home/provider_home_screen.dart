import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/logout_coordinator.dart';
import '../../core/auth/profile_cubit.dart';
import '../../core/auth/provider_logout_dialog.dart';
import '../../core/auth/provider_logout_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/avatar_config.dart';
import '../../core/errors/rpc_error_translator.dart';
import '../../core/models/order.dart';
import '../../core/notifications/notification_cubit.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/order_prefetch_service.dart';
import '../../core/services/server_clock.dart';
import '../../core/services/sound_effects_service.dart';
import '../../core/settings/app_settings_cubit.dart';
import '../../core/utils/distance.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/delete_account_dialog.dart';
import '../../core/widgets/offline_view.dart';
import '../../core/widgets/order_meta_row.dart';
import '../../core/widgets/profile_name_text.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../core/widgets/skeletons.dart';
import '../../core/widgets/support_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../notifications/notification_actions.dart';
import 'availability_resolution.dart';
import 'owner_profiles_resolution.dart';
import 'provider_heartbeat.dart';
import 'provider_heartbeat_params.dart';
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

  // القرار اليدوي للمزوّد مخزّن في قاعدة البيانات (providers.availability_override):
  // 'auto' = الجدول يحكم، 'on' = مفعّل يدوياً، 'off' = مخفي يدوياً. الـ cron
  // يعيدها 'auto' عند حدود الجدول، فيستعيد الجدول السيطرة عند أقرب معاد متغيّر.
  String _availabilityOverride = 'auto';

  // مراقب الجدول: كل ثانيتين نتحقق هل يستوجب الجدول تفعيلاً أم تخفياً ونوحّد
  // is_online معه، لكن فقط عندما يكون القرار 'auto' (لا نجامل قراراً يدوياً).
  Timer? _availabilityPoller;

  // نبضة موقع المزوّد: المسار الوحيد لكتابة الموقع الحيّ. تُرسل فوراً عند
  // فتح الشاشة/التفعيل/العودة للمقدمة ثم كل 60 ثانية، أثناء التوفّر وفي
  // المقدمة فقط. لا نكتب إحداثيات المزوّد مباشرة بعد الآن.
  late final ProviderHeartbeat _heartbeat;

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

  /// آخر حالة شُغّل لها صوت لكل طلب — يمنع تكرار الصوت عند تحديثات متتالية
  /// لا تغيّر الحالة.
  final Map<String, String> _lastSoundStatus = {};

  // سجل طلبات المزوّد (تبويب الطلبات)
  List<Order> _providerOrders = [];
  bool _isLoadingOrders = true;

  /// هل اكتمل تحميل ناجح (أو وُجدت لقطة جلب مسبق)؟ يمنع وميض السكيليتون
  /// عند تحديث قائمة فارغة معروضة.
  bool _ordersLoaded = false;

  /// سبب فشل آخر تحميل لسجل الطلبات — null بعد أي نجاح.
  LoadFailure? _ordersFailure;

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
    _heartbeat = ProviderHeartbeat(sendBeat: _sendHeartbeat);
    // لقطة الجلب المسبق عند دخول التطبيق: تُعرض فورًا بدل شاشة تحميل،
    // ثم يصل التحديث من الخادم في الخلفية دون إخفاء القائمة.
    final cached = OrderPrefetchService.instance.providerOrdersFor(
      _client.auth.currentUser?.id,
    );
    if (cached != null) {
      _providerOrders = cached;
      _isLoadingOrders = false;
      _ordersLoaded = true;
    }
    _loadProviderData();
    _markProviderActive();
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
    _heartbeat.dispose();
    _channel?.unsubscribe();
    _providerChannel?.unsubscribe();
    super.dispose();
  }

  // دورة حياة التطبيق: لا تؤثّر على التوفّر إطلاقاً — لا إخفاء عند الخلفية
  // ولا إرجاع عند العودة. التوفّر يحكمه القرار اليدوي المخزّن + الجدول فقط.
  // نبضة الموقع وحدها تتبع دورة الحياة: تتوقّف في الخلفية وتُستأنف بنبضة
  // فورية عند العودة للمقدمة (فلا نستهلك GPS بلا داعٍ في الخلفية).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _heartbeat.setForeground(true);
        if (!mounted) return;
        // Realtime لا يعيد بثّ ما فاته أثناء التعليق، لذا نعيد الاشتراك
        // والجلب عند العودة حتى لا تبقى الشاشة على حالة طلب قديمة.
        _channel?.unsubscribe();
        _channel = null;
        _providerChannel?.unsubscribe();
        _providerChannel = null;
        _subscribeToOrderChanges();
        _subscribeToProviderChanges();
        _loadProviderData();
        _markProviderActive();
        _loadActiveOrders();
        _loadProviderOrders();
        final cubit = context.read<NotificationCubit>();
        cubit.loadNotifications();
        cubit.subscribeToNotifications();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _heartbeat.setForeground(false);
    }
  }

  Future<void> _loadProviderData() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final provider = await _client
          .from('providers')
          .select(
            'workshop_name, latitude, longitude, is_online, availability_override',
          )
          .eq('id', userId)
          .maybeSingle();

      if (mounted) {
        final online = provider?['is_online'] == true;
        setState(() {
          _workshopName = provider?['workshop_name'] ?? '';
          _providerLat = (provider?['latitude'] as num?)?.toDouble() ?? 0;
          _providerLng = (provider?['longitude'] as num?)?.toDouble() ?? 0;
          _isOnline = online;
          _availabilityOverride =
              provider?['availability_override'] as String? ?? 'auto';
        });
        // يُزامن جدولة النبضة مع حالة التوفّر الفعلية: إن كان متاحاً نُرسل
        // نبضة فورية عند الفتح، وإن كان غير متاح لا نُرسل شيئاً.
        _heartbeat.setOnline(online);
      }
    } catch (e) {
      // silent
    }
  }

  /// يلغي وقت الخروج المسجّل عند عودة المزوّد للنشاط. مستقل عن نبضة الموقع
  /// (التي تتوقف لو رُفض إذن GPS) وعن is_online (قرار يدوي/جدول).
  Future<void> _markProviderActive() async {
    try {
      await ProviderLogoutService().markActive();
    } catch (_) {
      // أفضل جهد: فشل الشبكة لا يعطّل الواجهة.
    }
  }

  /// يجيب العنوان الحالي الحقيقي للجهاز ويعرضه في أعلى لوحة التحكم.
  Future<void> _loadCurrentAddress() async {
    if (_isLocatingAddress) return;

    setState(() {
      _isLocatingAddress = true;
      _addressText = '';
    });

    final address = await LocationService.instance.getCurrentAddress(
      forceRefresh: true,
    );

    if (mounted) {
      setState(() {
        _addressText = address ?? '';
        _isLocatingAddress = false;
      });
    }
  }

  Future<void> _loadServiceNames() async {
    try {
      final response = await _client
          .from('service_types')
          .select('id, name_ar');
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

  /// يجلب بيانات إضافية لكل طلب نشط — أسماء العملاء عبر RPC دُفعي واحد
  /// آمن (الـ RLS يخفي بقية المستخدمين، والفحص الدُفعي يستبدل N رحلات
  /// متسلسلة برحلة واحدة) والعنوان العربي (reverse geocoding لأن
  /// address_text لا يُحفظ عند إنشاء الطلب، بدفعات متوازية محدودة).
  /// النتائج تُخزّن مؤقتاً؛ والرقم غير المرئي خادميًا يسقط للبديل الافتراضي
  /// كما في الفحص الفردي السابق (fail-closed بلا كشف وجود).
  Future<void> _enrichActiveOrders(List<Order> orders) async {
    if (orders.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final fallbackName = l10n?.notificationCustomerFallback ?? 'العميل';

    final pendingOwnerIds = orders
        .map((o) => o.carOwnerId)
        .where((id) => !_ownerNames.containsKey(id))
        .toSet();
    if (pendingOwnerIds.isNotEmpty) {
      try {
        final res = await _client.rpc(
          'get_public_profiles',
          params: buildGetPublicProfilesParams(
            userIds: pendingOwnerIds.toList(),
          ),
        );
        final resolved = resolveOwnerProfiles(
          rows: res as List<Object?>,
          requestedIds: pendingOwnerIds,
          fallbackName: fallbackName,
        );
        _ownerNames.addAll(resolved.names);
        _ownerAvatarIds.addAll(resolved.avatarIds);
        _ownerAvatarUrls.addAll(resolved.avatarUrls);
      } catch (_) {
        for (final id in pendingOwnerIds) {
          _ownerNames[id] = fallbackName;
        }
      }
    }

    final toGeocode = <Order>[];
    for (final order in orders) {
      if (_orderAddresses.containsKey(order.id)) continue;
      final stored = order.addressText?.trim() ?? '';
      final isCoords =
          stored.isNotEmpty &&
          stored.contains(',') &&
          stored.split(',').every((p) => double.tryParse(p.trim()) != null);
      if (stored.isNotEmpty && !isCoords) {
        _orderAddresses[order.id] = stored;
      } else {
        toGeocode.add(order);
      }
    }
    await mapBounded<Order, void>(toGeocode, 4, (order) async {
      _orderAddresses[order.id] = await LocationService.instance
          .getAddressForLocation(order.latitude, order.longitude);
    });

    if (mounted) setState(() {});
  }

  /// سجل كل طلبات المزوّد (تبويب الطلبات)
  Future<void> _loadProviderOrders() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    // سكيليتون فقط في التحميل الأول — لا نغطّي قائمة معروضة (ولو فارغة).
    if (!_ordersLoaded && mounted) {
      setState(() {
        _isLoadingOrders = true;
        _ordersFailure = null;
      });
    }

    try {
      final response = await _client
          .from('orders')
          .select()
          .eq('provider_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final orders = response.map((json) => Order.fromJson(json)).toList();
      OrderPrefetchService.instance.setProviderOrders(userId, orders);

      if (mounted) {
        setState(() {
          _providerOrders = orders;
          _isLoadingOrders = false;
          _ordersLoaded = true;
          _ordersFailure = null;
        });
      }
    } catch (_) {
      final failure = await classifyLoadFailure();
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
          // قائمة قديمة معروضة أهم من رسالة خطأ: نُبقيها ونكتفي بالجلب
          // التالي (سحب للتحديث / عودة المقدمة).
          if (_providerOrders.isEmpty) _ordersFailure = failure;
        });
      }
    }
  }

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
            _playOrderEventSound(payload);
            _loadActiveOrders();
            _loadProviderOrders();
          },
        )
        .subscribe();
  }

  /// صوت فوري لأحداث الطلب القادمة عبر Realtime: طلب جديد، أو انتقال حالة
  /// قرّره الطرف الآخر (قبول/رفض/إلغاء). أفعال المزوّد نفسه تُصوَّت محلياً بعد
  /// نجاح الـ RPC، ومنع التكرار في الخدمة يوحّد المصدرين.
  void _playOrderEventSound(PostgresChangePayload payload) {
    final record = payload.newRecord;
    final id = record['id'] as String?;
    final statusName = record['status'] as String?;
    final status = statusName == null ? null : Order.tryParseStatus(statusName);
    if (id == null || status == null) return;

    if (payload.eventType == PostgresChangeEvent.insert) {
      _lastSoundStatus[id] = status.name;
      unawaited(
        SoundEffectsService.instance.playOrderStatus(
          id,
          status,
          forProvider: true,
        ),
      );
      return;
    }

    if (_lastSoundStatus[id] == status.name) return;
    _lastSoundStatus[id] = status.name;
    unawaited(
      SoundEffectsService.instance.playOrderStatus(
        id,
        status,
        forProvider: true,
      ),
    );
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
            // نعتمد على is_online وavailability_override من السجل الجديد (الحقيقة
            // في قاعدة البيانات). أي تقليب خارجي — cron عند حدود الجدول، أو تغيير
            // من جهاز/جلسة أخرى — ينعكس هنا فوراً.
            final online = (payload.newRecord['is_online'] ?? false) == true;
            final override =
                payload.newRecord['availability_override'] as String? ?? 'auto';
            if (!mounted ||
                (online == _isOnline && override == _availabilityOverride)) {
              return;
            }
            setState(() {
              _isOnline = online;
              _availabilityOverride = override;
            });
            // تقليب خارجي للتوفّر => نواكب جدولة النبضة (بدء/إيقاف) فوراً.
            _heartbeat.setOnline(online);
          },
        )
        .subscribe();
  }

  Future<void> _toggleOnline(bool val) async {
    // قرار يدوي صريح من المستخدم: نُخزّنه على الصف (on/off) حتى يُحترم رغم
    // الخروج من الشاشة أو إعادة التشغيل، ولا يصحّحه مراقب الجدول حتى تعيده
    // الـ cron إلى 'auto' عند أقرب حدّ للجدول.
    await _setAvailability(val, override: val ? 'on' : 'off');
  }

  /// يكتب حالة التوفّر في قاعدة البيانات ويُبقي الواجهة متطابقة مع النتيجة؛
  /// أي فشل في الحفظ يُعيد الحالة السابقة بصمت.
  ///
  /// [override] غير فارغ عند القرار اليدوي فقط؛ عند التصحيح التلقائي وفق
  /// الجدول نتركه null فلا نلمس availability_override (تبقى 'auto').
  Future<void> _setAvailability(bool val, {String? override}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final prevOnline = _isOnline;
    final prevOverride = _availabilityOverride;
    setState(() {
      _isOnline = val;
      if (override != null) _availabilityOverride = override;
    });

    try {
      await _client
          .from('providers')
          .update({'is_online': val, 'availability_override': ?override})
          .eq('id', userId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isOnline = prevOnline;
          _availabilityOverride = prevOverride;
        });
      }
    } finally {
      // بعد استقرار الحالة (نجاح أو تراجع): نُزامن جدولة النبضة مع is_online.
      _heartbeat.setOnline(_isOnline);
    }
  }

  // يبدأ مراقب الجدول: فحص أول فوري (بعد تحميل البيانات) ثم دورة كل 2 ثانية.
  // يعتمد على availability_override الراجع من السيرفر: حين يكون 'auto' يوحّد
  // is_online مع الجدول، وحين يكون قراراً يدوياً ('on'/'off') لا يتدخّل.
  // بلا جدول = تحكّم يدوي كامل.
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
      final override = data['availability_override'] as String? ?? 'auto';

      // نُزامن القرار اليدوي من السيرفر (قد يكون cron أعاده إلى 'auto').
      if (mounted && override != _availabilityOverride) {
        setState(() => _availabilityOverride = override);
      }

      final action = resolveAvailability(
        hasSchedule: hasSchedule,
        inHours: inHours,
        availabilityOverride: override,
        isOnline: _isOnline,
      );
      switch (action) {
        case AvailabilityAction.goOnline:
          await _setAvailability(true);
        case AvailabilityAction.goOffline:
          await _setAvailability(false);
        case AvailabilityAction.none:
          break;
      }
    } catch (_) {
      // مراقب ثانوي: قطع شبكة مؤقت لا يُزعج المستخدم.
    }
  }

  /// نبضة واحدة: نجيب أحدث موقع من [LocationService] (منطق آخر موقع معروف/
  /// تحديد مباشر نفسه، بلا أي مكدّس موقع جديد) ونرسله عبر RPC
  /// `provider_heartbeat`. الخادم يقرّر هل يستحق التحديد تحريك الإحداثيات
  /// (دقة ≤ 200م) ويختم وقت الحداثة دائماً. لا نرسل أي مُعرّف مزوّد — الهوية
  /// تُستخرج من التوثيق في الخادم. فشل الشبكة/الصلاحية صامت تماماً.
  Future<void> _sendHeartbeat() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      final position = await LocationService.instance.getCurrentPosition(
        forceRefresh: true,
      );
      if (position == null) return;

      await _client.rpc(
        'provider_heartbeat',
        params: buildProviderHeartbeatParams(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        ),
      );
    } catch (_) {
      // صمت تام: لا نُسقِط الواجهة ولا نُسجّل أي إحداثيات (رسالة عامة debug فقط).
      assert(() {
        debugPrint('provider_heartbeat: skipped (network/permission)');
        return true;
      }());
    }
  }

  /// قبول = فتح شاشة عرض السعر (انتقال الحالة بيتم جوه RPC provider_set_price)
  void _acceptOrder(String orderId) {
    context.push('/request/quote?orderId=$orderId');
  }

  Future<void> _rejectOrder(String orderId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n?.providerRejectOrderConfirmTitle ?? 'رفض الطلب؟',
      message:
          l10n?.providerRejectOrderConfirmBody ??
          'سيتم إخطار العميل وإلغاء هذا الطلب.',
      confirmLabel: l10n?.providerRejectOrderConfirmLabel ?? 'نعم، رفض الطلب',
      confirmColor: AppColors.error,
    );
    if (confirmed != true || !mounted) return;

    try {
      await _client.rpc(
        'provider_reject_order',
        params: {'p_order_id': orderId},
      );

      unawaited(
        SoundEffectsService.instance.playOrderStatus(
          orderId,
          OrderStatus.rejectedByProvider,
          forProvider: true,
        ),
      );

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
            content: Text(
              l10n?.providerOrderNoLongerAvailable ??
                  'هذا الطلب لم يعد متاحاً (ربما انتهت مدته)',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(RpcErrorTranslator.translate(e, l10n)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _completeOrder(String orderId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n?.completeOrderTitle ?? 'إتمام الطلب؟',
      message:
          l10n?.completeOrderConfirmBody ??
          'ستُعتبر الخدمة مكتملة وسيتمكّن العميل من تقييمك بعدها.',
      confirmLabel: l10n?.completeOrder ?? 'إتمام الطلب',
      confirmColor: AppColors.success,
    );
    if (confirmed != true || !mounted) return;

    try {
      await _client.rpc(
        'provider_complete_order',
        params: {'p_order_id': orderId},
      );

      unawaited(
        SoundEffectsService.instance.playOrderStatus(
          orderId,
          OrderStatus.completed,
          forProvider: true,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.orderCompletedToast ?? 'تم إتمام الطلب بنجاح'),
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
            content: Text(RpcErrorTranslator.translate(e, l10n)),
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
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
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

  Widget _buildDashboardTab(
    BuildContext context,
    bool isDark,
    AppLocalizations? l10n,
  ) {
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
                    : const ShimmerBox(width: 44, height: 44, circle: true),
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
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
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
                                    ? (l10n?.locatingLocation ??
                                          'جاري تحديد الموقع...')
                                    : _addressText,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
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
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          AvailabilityToggle(isOnline: _isOnline, onToggle: _toggleOnline),
          const SizedBox(height: 24),

          Row(
            children: [
              Text(
                l10n?.currentOrdersTitle ?? 'طلباتك الحالية',
                style: TextStyle(
                  fontFamily: 'Zain',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(width: 8),
              if (_activeOrders.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.orangePrimary,
                      ),
                    ),
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
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n?.noNearbyRequests ??
                              'لا توجد طلبات معيّنة لك حالياً',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
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
                      final distanceMeters = optionalDistanceMeters(
                        _providerLat,
                        _providerLng,
                        order.latitude,
                        order.longitude,
                      );
                      return order.status == OrderStatus.pending
                          ? NearbyRequestCard(
                              customerName:
                                  _ownerNames[order.carOwnerId] ??
                                  (l10n?.notificationCustomerFallback ??
                                      'العميل'),
                              carMake: order.carMake,
                              carModel: order.carModel,
                              carYear: order.carYear,
                              brandId: order.carBrandId,
                              carTrim: order.carTrim,
                              carColor: order.carColor,
                              carPlate: order.carPlate,
                              issueType: _serviceName(order.serviceTypeId),
                              distanceMeters: distanceMeters,
                              address: _orderAddresses[order.id] ?? '',
                              attachments: order.attachments ?? const [],
                              deadline: order.respondDeadline,
                              onAccept: () => _acceptOrder(order.id),
                              onReject: () => _rejectOrder(order.id),
                              onLocationTap: () => context.push(
                                '/request/map?orderId=${order.id}',
                              ),
                              customerAvatarId:
                                  _ownerAvatarIds[order.carOwnerId],
                              customerAvatarUrl:
                                  _ownerAvatarUrls[order.carOwnerId],
                            )
                          : ActiveOrderCard(
                              customerName:
                                  _ownerNames[order.carOwnerId] ??
                                  (l10n?.notificationCustomerFallback ??
                                      'العميل'),
                              carMake: order.carMake,
                              carModel: order.carModel,
                              carYear: order.carYear,
                              brandId: order.carBrandId,
                              carTrim: order.carTrim,
                              carColor: order.carColor,
                              carPlate: order.carPlate,
                              issueType: _serviceName(order.serviceTypeId),
                              address: _orderAddresses[order.id] ?? '',
                              attachments: order.attachments ?? const [],
                              orderId: order.id,
                              status: order.status,
                              statusLabel: order.statusLabel(l10n),
                              offeredPrice: order.offeredPrice,
                              createdAt: order.createdAt,
                              onComplete: order.status == OrderStatus.confirmed
                                  ? () => _completeOrder(order.id)
                                  : null,
                              onLocationTap: () => context.push(
                                '/request/map?orderId=${order.id}',
                              ),
                            );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTab(
    BuildContext context,
    bool isDark,
    AppLocalizations? l10n,
  ) {
    if (_isLoadingOrders && !_ordersLoaded) {
      return const OrderListSkeleton();
    }

    if (_providerOrders.isEmpty && _ordersFailure != null) {
      return _ordersFailure == LoadFailure.offline
          ? OfflineView(onRetry: _loadProviderOrders)
          : LoadFailedView(
              message: l10n?.ordersLoadFailed ?? 'تعذّر تحميل الطلبات',
              onRetry: _loadProviderOrders,
            );
    }

    if (_providerOrders.isEmpty) {
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
              l10n?.noOrders ?? 'لا توجد طلبات حالياً',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
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
        itemCount: _providerOrders.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n?.orders ?? 'الطلبات',
                      style: TextStyle(
                        fontFamily: 'Zain',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/orders/provider'),
                    child: Text(
                      l10n?.viewAll ?? 'عرض الكل',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.orangePrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return _buildProviderOrderCard(
            context,
            isDark,
            _providerOrders[index - 1],
          );
        },
      ),
    );
  }

  Widget _buildProviderOrderCard(
    BuildContext context,
    bool isDark,
    Order order,
  ) {
    final l10n = AppLocalizations.of(context);
    final statusColor = _orderStatusColor(order.status);

    return GestureDetector(
      onTap: () => context.push('/orders/provider/detail?orderId=${order.id}'),
      child: _buildProviderOrderCardBody(
        context,
        isDark,
        order,
        l10n,
        statusColor,
      ),
    );
  }

  Widget _buildProviderOrderCardBody(
    BuildContext context,
    bool isDark,
    Order order,
    AppLocalizations? l10n,
    Color statusColor,
  ) {
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
          OrderMetaRow(
            badge: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                order.statusLabel(l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (order.createdAt != null)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _formatOrderDate(context, order.createdAt!),
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ),
                if (order.offeredPrice != null) ...[
                  const SizedBox(width: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${order.offeredPrice!.toStringAsFixed(0)} ${l10n?.egp ?? 'ج.م'}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.orangePrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            order.carDisplayName,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _serviceName(order.serviceTypeId),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
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
                    child: Text(
                      l10n?.providePriceOffer ?? 'تقديم عرض سعر',
                      style: const TextStyle(
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
                    child: Text(
                      l10n?.reject ?? 'رفض',
                      style: const TextStyle(
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
                    label: Text(
                      l10n?.completeOrder ?? 'إتمام الطلب',
                      style: const TextStyle(
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

  Widget _buildNotificationsTab(
    BuildContext context,
    bool isDark,
    AppLocalizations? l10n,
  ) {
    final state = context.watch<NotificationCubit>().state;
    final cubit = context.read<NotificationCubit>();

    if (state.notifications.isEmpty && state.isLoading) {
      return const NotificationListSkeleton();
    }

    if (state.notifications.isEmpty && state.errorCode != null) {
      return state.errorCode == NotificationCubit.errorOffline
          ? OfflineView(onRetry: () => cubit.loadNotifications(force: true))
          : LoadFailedView(
              message: l10n?.notificationsLoadFailed ?? 'تعذّر تحميل الإشعارات',
              onRetry: () => cubit.loadNotifications(force: true),
            );
    }

    if (state.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.noNewNotifications ?? 'لا توجد إشعارات جديدة',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => cubit.loadNotifications(force: true),
      color: AppColors.orangePrimary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (state.unreadCount > 0)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () =>
                    context.read<NotificationCubit>().markAllAsRead(),
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
            final title = notification.localizedTitle(l10n);
            final body = notification.localizedBody(l10n);
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
                        ? (isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder)
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
                      child: Icon(
                        notification.icon,
                        color: notification.color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Zain',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          if (body.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              body,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            notification.timeAgo(
                              ServerClock.instance.now,
                              l10n,
                            ),
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
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

  Widget _buildProfileTab(
    BuildContext context,
    bool isDark,
    AppLocalizations? l10n,
  ) {
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
            child: const Icon(
              Icons.business_rounded,
              size: 50,
              color: AppColors.orangePrimary,
            ),
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
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
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
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          const SizedBox(height: 32),
          _buildProfileCardGroup(
            isDark: isDark,
            children: [
              _buildProfileOptionItem(
                context,
                icon: Icons.business_outlined,
                title: l10n?.workshopInfo ?? 'بيانات الورشة',
                isDark: isDark,
                onTap: () async {
                  await context.push('/provider/workshop');
                  _loadProviderData();
                },
              ),
              _buildProfileOptionItem(
                context,
                icon: Icons.build_outlined,
                title: l10n?.mySpecializations ?? 'تخصصاتي',
                isDark: isDark,
                onTap: () => context.push('/provider/specialties'),
              ),
              _buildProfileOptionItem(
                context,
                icon: Icons.schedule_rounded,
                title: l10n?.workingHours ?? 'ساعات العمل',
                isDark: isDark,
                onTap: () => context.push('/provider/schedule'),
              ),
              _buildProfileOptionItem(
                context,
                icon: Icons.badge_outlined,
                title: l10n?.providerPublicProfileMenu ?? 'ملفي العام',
                isDark: isDark,
                onTap: () {
                  final providerId = _client.auth.currentUser?.id;
                  if (providerId == null) return;
                  context.push('/provider/profile?providerId=$providerId');
                },
              ),
              _buildProfileOptionItem(
                context,
                icon: Icons.qr_code_2_rounded,
                title: l10n?.providerQrTitle ?? 'رمز QR الخاص بي',
                isDark: isDark,
                onTap: () {
                  final providerId = _client.auth.currentUser?.id;
                  if (providerId == null) return;
                  context.push('/provider/qr?providerId=$providerId');
                },
              ),
              _buildProfileOptionItem(
                context,
                icon: Icons.lock_outline_rounded,
                title: l10n?.changePassword ?? 'تغيير كلمة المرور',
                isDark: isDark,
                onTap: () => context.push('/profile/change-password'),
              ),
              _buildProfileOptionItem(
                context,
                icon: Icons.language_rounded,
                title:
                    '${l10n?.languageLabel ?? 'اللغة'}: ${l10n?.currentLanguage ?? (isArabic ? 'العربية' : 'English')}',
                isDark: isDark,
                onTap: () => settingsCubit.toggleLocale(),
              ),
              _buildProfileOptionItem(
                context,
                icon: isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                title: isArabic
                    ? (l10n?.lightMode ?? 'الوضع الفاتح')
                    : (l10n?.darkMode ?? 'الوضع الداكن'),
                isDark: isDark,
                onTap: () => settingsCubit.toggleTheme(),
              ),
              _buildProfileOptionItem(
                context,
                icon: Icons.headset_mic_outlined,
                title: isArabic
                    ? 'الدعم والشكاوى والاقتراحات'
                    : 'Support & Complaints',
                isDark: isDark,
                onTap: () => showSupportDialog(context),
              ),
            ],
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
                    : () async {
                        // آخر جلسة؟ تحذير ساعتين قبل الخروج (لا يوقف أجهزة أخرى).
                        final proceed =
                            await confirmProviderLastSessionLogout(context);
                        if (!proceed || !context.mounted) return;
                        LogoutCoordinator().logout(
                          context: context,
                          resetProfile: () =>
                              context.read<ProfileCubit>().reset(),
                        );
                      },
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
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _showDeleteAccountDialog(context),
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

  Widget _buildProfileCardGroup({
    required bool isDark,
    required List<Widget> children,
  }) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 56,
                endIndent: 16,
                color: borderColor,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileOptionItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.orangePrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.orangePrimary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
      ),
      onTap: onTap,
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final deleted = await showDeleteAccountDialog(
      context,
      authService: SupabaseAuthService(),
    );
    if (deleted == true && context.mounted) {
      context.go('/select-user-type');
    }
  }

  Widget _buildBottomNav(
    BuildContext context,
    bool isDark,
    AppLocalizations? l10n,
  ) {
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
        unselectedItemColor: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
        ),
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
