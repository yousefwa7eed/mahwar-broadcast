import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/auth/auth_cubit.dart';
import '../../../core/auth/home_route.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/rpc_error_translator.dart';
import '../../../core/models/order.dart';
import '../../../core/models/provider_details.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/server_clock.dart';
import '../../../core/services/sound_effects_service.dart';
import '../../../core/utils/distance.dart';
import '../../../core/widgets/navigate_to_customer_card.dart';
import '../../../core/widgets/offline_view.dart';
import '../../../l10n/app_localizations.dart';
import 'provider_alert_prompt_store.dart';
import 'provider_alert_service.dart';
import 'provider_alert_status.dart';
import 'widgets/order_status_indicator.dart';
import 'widgets/provider_offer_card.dart';
import 'widgets/provider_offline_alert_card.dart';
import 'widgets/transaction_summary_card.dart';

class RequestTrackingScreen extends StatefulWidget {
  final String orderId;

  const RequestTrackingScreen({super.key, required this.orderId});

  @override
  State<RequestTrackingScreen> createState() => _RequestTrackingScreenState();
}

class _RequestTrackingScreenState extends State<RequestTrackingScreen>
    with WidgetsBindingObserver {
  final SupabaseClient _client = Supabase.instance.client;

  Order? _order;
  bool _isLoading = true;
  String? _error;

  /// سبب فشل التحميل الأول (أوفلاين/خطأ) — يحدد نوع رسالة الخطأ.
  LoadFailure? _failure;

  String? _providerName;
  String? _workshopName;
  String? _providerPhone;
  String? _providerAvatarId;
  String? _providerAvatarUrl;
  double? _providerLat;
  double? _providerLng;

  // حالة التقييم لما الطلب يخلص
  int _rating = 0;
  final _ratingCommentController = TextEditingController();
  bool _isRated = false;
  bool _isSubmittingRating = false;
  bool _isLoadingRating = false;
  bool _isActing = false;

  RealtimeChannel? _channel;

  /// اقتراح تنبيه المزوّد الغائب: يُفحص مرة واحدة بعد 30 ثانية من إنشاء
  /// الطلب (قرار المنتج)، ويُعرض مرة واحدة لكل طلب على هذا الجهاز.
  Timer? _alertPromptTimer;
  bool _alertTimerArmed = false;
  ProviderAlertStatus? _alertStatus;
  bool _alertSending = false;
  bool _alertSent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadOrder();
    _subscribeToOrderChanges();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel?.unsubscribe();
    _alertPromptTimer?.cancel();
    _ratingCommentController.dispose();
    super.dispose();
  }

  /// العودة من الخلفية: Realtime **لا يعيد بثّ** الأحداث التي فاتت أثناء
  /// تعليق النظام أو انقطاع الشبكة، فتبقى الشاشة على حالة قديمة (رفض/قبول/
  /// إلغاء وقع والتطبيق مغلق). المرجع هو الخادم: نعيد الجلب ونعيد الاشتراك
  /// الحي، وأي انتقال فائت يُكتشف هنا فيُحدّث الشاشة ويُشغّل مؤثره.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    _channel?.unsubscribe();
    _channel = null;
    _subscribeToOrderChanges();
    _refreshFromServer();
  }

  /// إعادة الجلب من الخادم (سحب التحديث أو العودة من الخلفية).
  Future<void> _refreshFromServer() async {
    await _loadOrder();
  }

  Future<void> _loadOrder() async {
    // إعادة المحاولة من شاشة الخطأ: نعود لحالة التحميل بدل إبقاء الرسالة.
    if (_order == null && !_isLoading && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
        _failure = null;
      });
    }
    final previousStatus = _order?.status;
    try {
      final response = await _client
          .from('orders')
          .select()
          .eq('id', widget.orderId)
          .single();

      final order = Order.fromJson(response);

      if (order.providerId != null) {
        await _loadProviderInfo(order.providerId!);
      }
      if (order.status == OrderStatus.completed) {
        await _loadRatingState();
      }

      if (mounted) {
        setState(() {
          _order = order;
          _isLoading = false;
          _error = null;
          _failure = null;
        });
      }

      // انتقال فاته Realtime → يُصوَّت عند اكتشافه من الخادم. أول تحميل
      // (previousStatus == null) مرجع بلا صوت، والخدمة تمنع التكرار إن كان
      // الحدث نفسه وصل حيّاً قبل لحظات.
      if (previousStatus != null && previousStatus != order.status) {
        unawaited(
          SoundEffectsService.instance.playOrderStatus(order.id, order.status),
        );
      }

      _maybeArmAlertPrompt();
    } catch (_) {
      final failure = await classifyLoadFailure();
      if (mounted) {
        setState(() {
          // فشل تحديث لا يمحو طلباً معروضاً: نُبقي آخر حالة نعرفها بدل شاشة
          // خطأ فارغة — المستخدم يفضّل بيانات متأخرة على لا شيء.
          if (_order == null) {
            _error =
                AppLocalizations.of(context)?.orderLoadFailed ??
                'تعذّر تحميل بيانات الطلب';
            _failure = failure;
          }
          _isLoading = false;
        });
      }
    }
  }

  /// يجيب بيانات المزوّد المرتبط بالطلب عبر RPC آمن (profiles مخفي بالـ RLS)
  bool _isOwner(Order order) =>
      _client.auth.currentUser?.id == order.carOwnerId;

  /// رجوع آمن: دور الخادم أولًا (لا افتراض مالك عند غياب الطلب — كان هذا
  /// يفتح رئيسية المالك داخل حساب المزوّد)، ثم عضوية الطلب كاحتياط.
  Future<void> _handleBack() async {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final cubit = context.read<AuthCubit>();
    var role = cubit.cachedRole;
    if (role == null) {
      try {
        role = await cubit.resolveCurrentRole();
      } catch (_) {
        role = null;
      }
    }
    final order = _order;
    final route = trackingBackRouteFor(
      serverRole: role,
      userId: _client.auth.currentUser?.id,
      ownerId: order?.carOwnerId,
      providerId: order?.providerId,
    );
    if (!mounted || route == null) return;
    context.go(route);
  }

  Future<void> _loadProviderInfo(String providerId) async {
    try {
      final response = await _client.rpc(
        'get_provider_details',
        params: {'p_provider_id': providerId},
      );

      final rows = response as List;
      if (rows.isNotEmpty) {
        final p = ProviderDetails.fromJson(
          Map<String, dynamic>.from(rows.first as Map),
        );
        _providerName = p.fullName.isEmpty ? p.workshopName : p.fullName;
        _workshopName = p.workshopName;
        _providerPhone = p.phoneNumber;
        _providerAvatarId = p.avatarId;
        _providerAvatarUrl = p.avatarUrl;
        _providerLat = p.latitude;
        _providerLng = p.longitude;
      }
    } catch (e) {
      // لو فشل جلب بيانات المزوّد، الشاشة تكمل عادي بدون توقف
    }
  }

  Future<void> _loadRatingState() async {
    setState(() => _isLoadingRating = true);

    try {
      final response = await _client
          .from('ratings')
          .select('rating, comment')
          .eq('order_id', widget.orderId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (response != null) {
            _isRated = true;
            _rating = (response['rating'] as num?)?.toInt() ?? 0;
          }
          _isLoadingRating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRating = false);
      }
    }
  }

  /// يسمع لأي تغيير يحصل على نفس الطلب ويحدّث الشاشة تلقائيًا
  void _subscribeToOrderChanges() {
    _channel = _client
        .channel('order-${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.orderId,
          ),
          callback: (payload) async {
            final updatedOrder = Order.fromJson(payload.newRecord);

            // انتقال حقيقي في قاعدة البيانات → صوت الحالة. قد تكون شاشة بيت
            // المالك مفتوحة تحت هذه الشاشة وتستقبل نفس الحدث، والخدمة تمنع
            // تشغيل المؤثر مرتين لنفس (الطلب، الحالة).
            if (_order != null && _order!.status != updatedOrder.status) {
              unawaited(
                SoundEffectsService.instance.playOrderStatus(
                  widget.orderId,
                  updatedOrder.status,
                ),
              );
            }

            if (updatedOrder.providerId != null &&
                updatedOrder.providerId != _order?.providerId) {
              await _loadProviderInfo(updatedOrder.providerId!);
            }
            if (updatedOrder.status == OrderStatus.completed &&
                _order?.status != OrderStatus.completed) {
              await _loadRatingState();
            }

            if (mounted) {
              setState(() => _order = updatedOrder);
              _maybeArmAlertPrompt();
            }
          },
        )
        .subscribe();
  }

  /// يُجهّز فحص اقتراح التنبيه بعد 30 ثانية من إنشاء الطلب. لا يُسلّح إلا
  /// لطلب المالك المسند لمزوّد وما زال pending، ومرة واحدة لكل جلسة شاشة —
  /// فحص الخادم نفسه هو من يقرر الظهور (نافذة الساعتين + الحصص).
  void _maybeArmAlertPrompt() {
    if (_alertTimerArmed || !mounted) return;
    final order = _order;
    if (order == null || !_isOwner(order)) return;
    if (order.status != OrderStatus.pending) return;
    if ((order.providerId ?? '').isEmpty) return;

    _alertTimerArmed = true;
    final createdAt = order.createdAt;
    final elapsed = createdAt == null
        ? Duration.zero
        : ServerClock.instance.now.difference(createdAt);
    final wait = const Duration(seconds: 30) - elapsed;
    _alertPromptTimer = Timer(
      wait.isNegative ? Duration.zero : wait,
      () => unawaited(_checkProviderAlert()),
    );
  }

  /// الفحص الفعلي بعد الـ30 ثانية: هل المزوّد مسجّل خروج داخل نافذة الساعتين
  /// وهل ما زالت له حصة؟ العرض مرة واحدة لكل طلب (محليًا)، والتحقق النهائي
  /// عند الإرسال داخل Edge Function.
  Future<void> _checkProviderAlert() async {
    final order = _order;
    if (!mounted || order == null) return;
    if (!_isOwner(order) || order.status != OrderStatus.pending) return;

    if (await ProviderAlertPromptStore.instance.wasShown(order.id)) return;

    ProviderAlertStatus status;
    try {
      status = await ProviderAlertService().status(order.id);
    } catch (_) {
      return;
    }
    if (!mounted || !status.showCard) return;

    await ProviderAlertPromptStore.instance.markShown(order.id);
    if (!mounted) return;
    setState(() => _alertStatus = status);
  }

  Future<void> _sendProviderAlert() async {
    if (_alertSending || _alertSent) return;
    setState(() => _alertSending = true);

    try {
      await ProviderAlertService().send(widget.orderId);
      if (!mounted) return;
      setState(() {
        _alertSending = false;
        _alertSent = true;
      });
    } on ProviderAlertSmsException catch (e) {
      if (!mounted) return;
      setState(() {
        _alertSending = false;
        switch (e.error) {
          case ProviderAlertSendError.alreadySent:
            _alertSent = true;
          case ProviderAlertSendError.monthlyQuotaUsed:
            _alertStatus = const ProviderAlertStatus(
              isLoggedOut: true,
              canAlert: false,
              reason: ProviderAlertReason.monthlyQuotaUsed,
            );
          case ProviderAlertSendError.dailyCapReached:
            _alertStatus = const ProviderAlertStatus(
              isLoggedOut: true,
              canAlert: false,
              reason: ProviderAlertReason.dailyCapReached,
            );
          case ProviderAlertSendError.providerActive:
          case ProviderAlertSendError.orderNotPending:
            // الحالة تغيّرت على الخادم: لا معنى للاقتراح بعد الآن.
            _alertStatus = null;
          case ProviderAlertSendError.notOwner:
          case ProviderAlertSendError.unauthenticated:
          case ProviderAlertSendError.failed:
            break;
        }
      });
      if (!mounted) return;
      final message = switch (e.error) {
        ProviderAlertSendError.monthlyQuotaUsed =>
          AppLocalizations.of(context)?.providerOfflineAlertMonthlyUsed ??
              'تم استخدام رسالة التنبيه الشهرية لهذا المزوّد.',
        ProviderAlertSendError.dailyCapReached =>
          AppLocalizations.of(context)?.providerOfflineAlertDailyCap ??
              'تعذّر إرسال تنبيه إضافي الآن، حاول لاحقًا.',
        ProviderAlertSendError.alreadySent =>
          AppLocalizations.of(context)?.providerAlertSmsAlreadySent ??
              'سبق إرسال تنبيه لهذا الطلب.',
        ProviderAlertSendError.providerActive ||
        ProviderAlertSendError.orderNotPending ||
        ProviderAlertSendError.notOwner =>
          null,
        ProviderAlertSendError.unauthenticated ||
        ProviderAlertSendError.failed =>
          AppLocalizations.of(context)?.providerAlertSmsFailed ??
              'تعذّر إرسال التنبيه، حاول مرة أخرى.',
      };
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _alertSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.providerAlertSmsFailed ??
                'تعذّر إرسال التنبيه، حاول مرة أخرى.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _acceptPrice() async {
    final l10n = AppLocalizations.of(context);

    setState(() => _isActing = true);

    try {
      await _client.rpc(
        'owner_accept_price',
        params: {'p_order_id': widget.orderId},
      );

      unawaited(
        SoundEffectsService.instance.playOrderStatus(
          widget.orderId,
          OrderStatus.confirmed,
        ),
      );

      if (mounted) {
        setState(() => _isActing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.orderConfirmed ?? 'تم تأكيد الطلب بنجاح!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              RpcErrorTranslator.translate(e, AppLocalizations.of(context)),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectPrice() async {
    final l10n = AppLocalizations.of(context);

    setState(() => _isActing = true);

    try {
      await _client.rpc(
        'owner_reject_price',
        params: {'p_order_id': widget.orderId},
      );

      unawaited(
        SoundEffectsService.instance.playOrderStatus(
          widget.orderId,
          OrderStatus.rejectedByOwner,
        ),
      );

      if (mounted) {
        setState(() => _isActing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.priceRejected ?? 'تم رفض عرض السعر'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              RpcErrorTranslator.translate(e, AppLocalizations.of(context)),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// إلغاء الطلب من طرف المالك (RPC آمن يتحقق من هوية المالك ويفرض حالة pending).
  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)?.cancelOrderConfirmTitle ??
              'إلغاء الطلب؟',
        ),
        content: Text(
          AppLocalizations.of(context)?.cancelOrderConfirmBody ??
              'سيتم إلغاء الطلب الحالي وإخطار المزوّد (إن تم إسناده).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(context)?.goBack ?? 'تراجع'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              AppLocalizations.of(context)?.cancelOrder ?? 'إلغاء الطلب',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isActing = true);
    try {
      await _client.rpc(
        'owner_cancel_order',
        params: {'p_order_id': widget.orderId},
      );
      unawaited(
        SoundEffectsService.instance.playOrderStatus(
          widget.orderId,
          OrderStatus.cancelled,
        ),
      );
      if (mounted) {
        setState(() => _isActing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.orderCancelled ?? 'تم إلغاء الطلب',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              RpcErrorTranslator.translate(e, AppLocalizations.of(context)),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _callProvider() async {
    final phone = _providerPhone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.providerPhoneUnavailable ??
                'رقم المزوّد غير متاح',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.selectRatingPrompt ??
                'يرجى اختيار تقييم من 1 إلى 5',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmittingRating = true);

    try {
      await _client.rpc(
        'rate_provider',
        params: {
          'p_order_id': widget.orderId,
          'p_rating': _rating,
          'p_comment': _ratingCommentController.text.trim().isEmpty
              ? null
              : _ratingCommentController.text.trim(),
        },
      );

      unawaited(SoundEffectsService.instance.play(SoundEffect.ratingSubmitted));

      if (mounted) {
        setState(() {
          _isSubmittingRating = false;
          _isRated = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.ratingSubmittedThanks ??
                  'شكراً لك! تم إرسال تقييمك',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingRating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              RpcErrorTranslator.translate(e, AppLocalizations.of(context)),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          onPressed: _handleBack,
        ),
        title: Text(
          AppLocalizations.of(context)?.trackOrder ?? 'تتبع الطلب',
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.orangePrimary),
            )
          : _error != null
          ? _failure == LoadFailure.offline
                ? OfflineView(onRetry: _refreshFromServer)
                : LoadFailedView(
                    message: _error!,
                    onRetry: _refreshFromServer,
                  )
          : _buildContent(context, isDark),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    final order = _order!;
    final l10n = AppLocalizations.of(context);
    final offerDistanceMeters = optionalDistanceMeters(
      order.latitude,
      order.longitude,
      _providerLat,
      _providerLng,
    );

    return RefreshIndicator(
      onRefresh: _refreshFromServer,
      color: AppColors.orangePrimary,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Status Indicator - حالة حقيقية من قاعدة البيانات
            OrderStatusIndicator(status: order.status),
            // عدّاد الإلغاء التلقائي (قرار العميل: 5 دقائق)
            if (order.status == OrderStatus.pending &&
                order.autoCancel &&
                order.respondDeadline != null) ...[
              const SizedBox(height: 12),
              _AutoCancelCountdown(deadline: order.respondDeadline!),
            ],
            // اقتراح تنبيه المزوّد الغائب — للمالك فقط، وبعد فحص الحالة على
            // الخادم (مزوّد مسجّل خروج داخل نافذة الساعتين + الحصة).
            if (_isOwner(order) &&
                order.status == OrderStatus.pending &&
                _alertStatus != null) ...[
              const SizedBox(height: 12),
              ProviderOfflineAlertCard(
                reason: _alertStatus!.reason,
                canSend: _alertStatus!.canAlert,
                isSending: _alertSending,
                sent: _alertSent,
                onSend: _alertSending ? null : _sendProviderAlert,
                onDismiss: () => setState(() => _alertStatus = null),
              ),
            ],
            const SizedBox(height: 24),

            // Provider Offer Card (تظهر لما يكون فيه سعر معروض)
            if (order.status == OrderStatus.priced &&
                order.offeredPrice != null)
              ProviderOfferCard(
                providerName: _providerName ?? '',
                workshopName: _workshopName ?? '',
                distanceMeters: offerDistanceMeters,
                price: order.offeredPrice!,
                currency: order.currency,
                estimatedMinutes: order.etaMinutes ?? 0,
                providerNotes: order.providerNotes,
                attachments: order.providerAttachments ?? const [],
                // أزرار القبول/الرفض للمالك فقط — المزوّد المشاهد لا يملك الحالة.
                onAccept: _isOwner(order) && !_isActing ? _acceptPrice : null,
                onReject: _isOwner(order) && !_isActing ? _rejectPrice : null,
                avatarId: _providerAvatarId,
                avatarUrl: _providerAvatarUrl,
              ),

            // Confirmed - Show contact options
            if (order.status == OrderStatus.confirmed &&
                order.offeredPrice != null)
              ProviderOfferCard(
                providerName: _providerName ?? '',
                workshopName: _workshopName ?? '',
                distanceMeters: offerDistanceMeters,
                price: order.offeredPrice!,
                currency: order.currency,
                estimatedMinutes: order.etaMinutes ?? 0,
                providerNotes: order.providerNotes,
                attachments: order.providerAttachments ?? const [],
                onCall: _callProvider,
                avatarId: _providerAvatarId,
                avatarUrl: _providerAvatarUrl,
              ),

            // المزوّد وحده يحتاج التحرّك نحو العميل بعد تأكيد السعر — نقترح
            // عليه فتح الاتجاهات مباشرة بدل البحث عن العنوان يدويًا.
            if (order.status == OrderStatus.confirmed && !_isOwner(order)) ...[
              const SizedBox(height: 12),
              NavigateToCustomerCard(
                latitude: order.latitude,
                longitude: order.longitude,
              ),
            ],

            // ملخّص المعاملة للطلبات المنتهية: تاريخ المعاملة، اسم المزوّد،
            // مسار الأحداث (اكتمال أو فشل مع توضيح الجهة الرافضة).
            if (order.isFinalized) ...[
              const SizedBox(height: 24),
              TransactionSummaryCard(
                order: order,
                providerName: _providerName ?? '',
                workshopName: _workshopName ?? '',
                avatarId: _providerAvatarId,
                avatarUrl: _providerAvatarUrl,
              ),
            ],

            // Completed - التقييم للمالك فقط. المزوّد يرى تقييم العميل في
            // شاشة تفاصيل الطلب الخاصة به، ولا تُعرض له واجهة تقييم بصياغة
            // موجّهة للمالك («كيف كانت تجربتك مع المزوّد؟»).
            if (order.status == OrderStatus.completed) ...[
              if (_isOwner(order)) ...[
                const SizedBox(height: 24),
                _isLoadingRating
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            color: AppColors.orangePrimary,
                          ),
                        ),
                      )
                    : _isRated
                    ? _buildRatedCard(context, isDark)
                    : _buildRatingForm(context, isDark),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.go(
                    _isOwner(order) ? '/home/owner' : '/home/provider',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orangePrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    l10n?.backToHome ?? 'العودة للرئيسية',
                    style: TextStyle(
                      fontFamily: 'Zain',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],

            if (order.status == OrderStatus.pending) ...[
              const SizedBox(height: 40),
              Text(
                l10n?.searchingProvider ??
                    'جاري إرسال الطلب إلى المزوّد المختار...',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              if (_client.auth.currentUser?.id == order.carOwnerId) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isActing ? null : _cancelOrder,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isActing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.error,
                            ),
                          )
                        : Text(
                            l10n?.cancelOrder ?? 'إلغاء الطلب',
                            style: const TextStyle(
                              fontFamily: 'Zain',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ],

            if (order.status == OrderStatus.rejectedByOwner ||
                order.status == OrderStatus.rejectedByProvider ||
                order.status == OrderStatus.cancelled) ...[
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.go(
                    _isOwner(order) ? '/home/owner' : '/home/provider',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orangePrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    l10n?.backToHome ?? 'العودة للرئيسية',
                    style: TextStyle(
                      fontFamily: 'Zain',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRatedCard(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.feedback_rounded,
            size: 40,
            color: AppColors.success,
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.providerRated ?? 'تم تقييم المزوّد',
            style: TextStyle(
              fontFamily: 'Zain',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => Icon(
                i < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                color: Colors.amber,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingForm(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.orangePrimary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              l10n?.ratingExperiencePrompt ?? 'كيف كانت تجربتك مع المزوّد؟',
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    i < _rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ratingCommentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  l10n?.addCommentOptionalHint ?? 'أضف تعليقاً (اختياري)...',
              hintStyle: TextStyle(
                fontFamily: 'Cairo',
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              filled: true,
              fillColor: isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            style: TextStyle(
              fontFamily: 'Cairo',
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmittingRating ? null : _submitRating,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orangePrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSubmittingRating
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      l10n?.submitRating ?? 'إرسال التقييم',
                      style: const TextStyle(
                        fontFamily: 'Zain',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// عدّاد الإلغاء التلقائي الظاهر للعميل أثناء انتظار طلبه (pending).
/// يذكّر العميل بأن طلبه سيُلغى تلقائياً عند انتهاء المهلة التي اختارها،
/// وعند الوصول للصفر يختفي العدّاد (لا تبقى رسالة ثابتة) والدولة الفعلية
/// تتحدث من الخادم عبر Realtime.
class _AutoCancelCountdown extends StatefulWidget {
  final DateTime deadline;

  const _AutoCancelCountdown({required this.deadline});

  @override
  State<_AutoCancelCountdown> createState() => _AutoCancelCountdownState();
}

class _AutoCancelCountdownState extends State<_AutoCancelCountdown> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    // ثبّت "الآن" على ساعة الخادم ثم احسب المتبقي — لا على ساعة الجهاز.
    _remaining = _computeRemaining();
    if (_remaining.inSeconds > 0) {
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _updateRemaining(),
      );
    }
    ServerClock.instance.refresh().then((_) {
      if (mounted) _updateRemaining();
    });
  }

  Duration _computeRemaining() {
    final next = widget.deadline.difference(ServerClock.instance.now);
    return next.inSeconds <= 0 ? Duration.zero : next;
  }

  void _updateRemaining() {
    final next = _computeRemaining();
    if (next.inSeconds <= 0) {
      _timer?.cancel();
    }
    if (mounted) setState(() => _remaining = next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (d.inHours > 0) {
      return '${d.inHours}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final expired = _remaining.inSeconds <= 0;
    if (expired) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n?.autoCancelCountdown(_fmt(_remaining)) ??
                  'سيُلغى الطلب تلقائياً خلال 5 دقائق — متبقي ${_fmt(_remaining)}',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
