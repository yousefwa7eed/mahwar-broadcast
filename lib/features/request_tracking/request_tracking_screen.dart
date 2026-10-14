import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/rpc_error_translator.dart';
import '../../../core/models/order.dart';
import '../../../core/models/provider_details.dart';
import '../../../core/services/server_clock.dart';
import '../../../l10n/app_localizations.dart';
import 'widgets/order_status_indicator.dart';
import 'widgets/provider_offer_card.dart';
import 'widgets/transaction_summary_card.dart';

class RequestTrackingScreen extends StatefulWidget {
  final String orderId;

  const RequestTrackingScreen({super.key, required this.orderId});

  @override
  State<RequestTrackingScreen> createState() => _RequestTrackingScreenState();
}

class _RequestTrackingScreenState extends State<RequestTrackingScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  Order? _order;
  bool _isLoading = true;
  String? _error;

  String? _providerName;
  String? _workshopName;
  String? _providerPhone;
  String? _providerAvatarId;
  String? _providerAvatarUrl;

  // حالة التقييم لما الطلب يخلص
  int _rating = 0;
  final _ratingCommentController = TextEditingController();
  bool _isRated = false;
  bool _isSubmittingRating = false;
  bool _isLoadingRating = false;
  bool _isActing = false;

  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _subscribeToOrderChanges();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _ratingCommentController.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'تعذّر تحميل بيانات الطلب';
          _isLoading = false;
        });
      }
    }
  }

  /// يجيب بيانات المزوّد المرتبط بالطلب عبر RPC آمن (profiles مخفي بالـ RLS)
  bool _isOwner(Order order) => _client.auth.currentUser?.id == order.carOwnerId;

  Future<void> _loadProviderInfo(String providerId) async {
    try {
      final response = await _client.rpc('get_provider_details', params: {
        'p_provider_id': providerId,
      });

      final rows = response as List;
      if (rows.isNotEmpty) {
        final p = ProviderDetails.fromJson(Map<String, dynamic>.from(rows.first as Map));
        _providerName = p.fullName.isEmpty ? p.workshopName : p.fullName;
        _workshopName = p.workshopName;
        _providerPhone = p.phoneNumber;
        _providerAvatarId = p.avatarId;
        _providerAvatarUrl = p.avatarUrl;
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
        }
      },
    )
        .subscribe();
  }

  Future<void> _acceptPrice() async {
    final l10n = AppLocalizations.of(context);

    setState(() => _isActing = true);

    try {
      await _client.rpc('owner_accept_price', params: {
        'p_order_id': widget.orderId,
      });

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
            content: Text(RpcErrorTranslator.translate(e)),
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
      await _client.rpc('owner_reject_price', params: {
        'p_order_id': widget.orderId,
      });

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
            content: Text(RpcErrorTranslator.translate(e)),
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
        title: const Text('إلغاء الطلب؟'),
        content: const Text('سيتم إلغاء الطلب الحالي وإخطار المزوّد (إن تم إسناده).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('تراجع'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('إلغاء الطلب'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isActing = true);
    try {
      await _client.rpc('owner_cancel_order', params: {
        'p_order_id': widget.orderId,
      });
      if (mounted) {
        setState(() => _isActing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء الطلب'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(RpcErrorTranslator.translate(e)),
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
        const SnackBar(
          content: Text('رقم المزوّد غير متاح'),
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
        const SnackBar(
          content: Text('يرجى اختيار تقييم من 1 إلى 5'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmittingRating = true);

    try {
      await _client.rpc('rate_provider', params: {
        'p_order_id': widget.orderId,
        'p_rating': _rating,
        'p_comment': _ratingCommentController.text.trim().isEmpty
            ? null
            : _ratingCommentController.text.trim(),
      });

      if (mounted) {
        setState(() {
          _isSubmittingRating = false;
          _isRated = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('شكراً لك! تم إرسال تقييمك'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingRating = false);
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
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              // رجوع للرئيسية الصحيحة حسب دور المشاهد (وليست دائماً /home/owner).
              final order = _order;
              final userId = _client.auth.currentUser?.id;
              final isOwner = order == null || order.carOwnerId == userId;
              context.go(isOwner ? '/home/owner' : '/home/provider');
            }
          },
        ),
        title: Text(
          AppLocalizations.of(context)?.trackOrder ?? 'تتبع الطلب',
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
          ? _buildError(context, isDark)
          : _buildContent(context, isDark),
    );
  }

  Widget _buildError(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    final order = _order!;
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 24),

          // Provider Offer Card (تظهر لما يكون فيه سعر معروض)
          if (order.status == OrderStatus.priced && order.offeredPrice != null)
            ProviderOfferCard(
              providerName: _providerName ?? '',
              workshopName: _workshopName ?? '',
              distance: 0,
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
          if (order.status == OrderStatus.confirmed && order.offeredPrice != null)
            ProviderOfferCard(
              providerName: _providerName ?? '',
              workshopName: _workshopName ?? '',
              distance: 0,
              price: order.offeredPrice!,
              currency: order.currency,
              estimatedMinutes: order.etaMinutes ?? 0,
              providerNotes: order.providerNotes,
              attachments: order.providerAttachments ?? const [],
              onCall: _callProvider,
              avatarId: _providerAvatarId,
              avatarUrl: _providerAvatarUrl,
            ),

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

          // Completed - التقييم
          if (order.status == OrderStatus.completed) ...[
            const SizedBox(height: 24),
            _isLoadingRating
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: AppColors.orangePrimary),
                    ),
                  )
                : _isRated
                ? _buildRatedCard(context, isDark)
                : _buildRatingForm(context, isDark),
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
              l10n?.searchingProvider ?? 'جاري إرسال الطلب إلى المزوّد المختار...',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
                      : const Text(
                          'إلغاء الطلب',
                          style: TextStyle(
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
    );
  }

  Widget _buildRatedCard(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.feedback_rounded, size: 40, color: AppColors.success),
          const SizedBox(height: 8),
          Text(
            'تم تقييم المزوّد',
            style: TextStyle(
              fontFamily: 'Zain',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
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
              'كيف كانت تجربتك مع المزوّد؟',
              style: TextStyle(
                fontFamily: 'Zain',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
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
                    i < _rating ? Icons.star_rounded : Icons.star_border_rounded,
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
              hintText: 'أضف تعليقاً (اختياري)...',
              hintStyle: TextStyle(
                fontFamily: 'Cairo',
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
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
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
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
                  : const Text(
                      'إرسال التقييم',
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
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
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
