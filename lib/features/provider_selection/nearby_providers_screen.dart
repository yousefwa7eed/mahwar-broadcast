import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/provider_details.dart';
import '../../core/utils/distance_format.dart';
import '../../l10n/app_localizations.dart';

class NearbyProvidersScreen extends StatefulWidget {
  final String serviceId;
  final double lat;
  final double lng;

  const NearbyProvidersScreen({
    super.key,
    required this.serviceId,
    required this.lat,
    required this.lng,
  });

  @override
  State<NearbyProvidersScreen> createState() => _NearbyProvidersScreenState();
}

class _NearbyProvidersScreenState extends State<NearbyProvidersScreen> with WidgetsBindingObserver {
  static const Duration _refreshInterval = Duration(seconds: 5);

  final SupabaseClient _client = Supabase.instance.client;

  List<ProviderDetails> _providers = [];
  Map<String, String> _serviceNames = {};
  bool _isLoading = true;
  bool _isFetching = false;
  bool _backgrounded = false;
  String? _error;
  Timer? _timer;
  String _searchQuery = '';

  /// عدّاد فشل الاستطلاع المتتالي: بعد فشلين متتاليين نُظهر تلميحاً صغيراً
  /// غير حاجب مع زر إعادة المحاولة (لا نُقاطع المستخدم ولا نُغرق الشاشة).
  int _consecutiveFailures = 0;
  bool _showPollHint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadServiceNames();
    _loadProviders();
    _timer = Timer.periodic(_refreshInterval, (_) => _handlePoll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _backgrounded = true;
    } else if (state == AppLifecycleState.resumed) {
      final wasBackgrounded = _backgrounded;
      _backgrounded = false;
      if (wasBackgrounded && mounted) {
        _loadProviders(showLoading: false);
      }
    }
  }

  void _handlePoll() {
    if (!mounted || _backgrounded || _isFetching) return;
    _loadProviders(showLoading: false);
  }

  /// إعادة محاولة استطلاع واحدة عند ضغط المستخدم على تلميح الفشل.
  void _retryPoll() {
    _loadProviders(showLoading: false);
  }

  Future<void> _loadServiceNames() async {
    try {
      final response = await _client.from('service_types').select('id, name_ar');
      _serviceNames = {
        for (final row in response) row['id'] as String: row['name_ar'] as String? ?? row['id'] as String,
      };
    } catch (_) {}
  }

  Future<void> _loadProviders({bool showLoading = true}) async {
    if (_isFetching) return;
    _isFetching = true;

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final response = await _client.rpc(
        'get_nearest_providers',
        params: {
          'user_lat': widget.lat,
          'user_lng': widget.lng,
          'service_filter': widget.serviceId,
          'max_distance_meters': 50000,
        },
      );

      final providers = (response as List)
          .map((json) => ProviderDetails.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();

      _consecutiveFailures = 0;
      if (mounted) {
        setState(() {
          _providers = providers;
          _isLoading = false;
          _showPollHint = false;
        });
      }
    } catch (e) {
      _consecutiveFailures++;
      if (mounted && showLoading) {
        setState(() {
          _error = 'تعذّر تحميل المزودين: $e';
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          if (_consecutiveFailures >= 2) _showPollHint = true;
        });
      }
    } finally {
      _isFetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final filteredProviders = _providers.where((p) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final displayName = (p.workshopName.isNotEmpty ? p.workshopName : p.fullName).toLowerCase();
      final fullName = p.fullName.toLowerCase();
      return displayName.contains(query) || fullName.contains(query);
    }).toList();

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
          'اختر المزوّد',
          style: TextStyle(
            fontFamily: 'Zain',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n?.searchProviderHint ?? 'ابحث عن مزوّد بالاسم',
                hintStyle: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          if (_showPollHint && !_isLoading && _error == null)
            _buildPollHint(context, isDark),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.orangePrimary))
                : _error != null
                ? _buildError(context, isDark)
                : _providers.isEmpty
                ? _buildEmpty(context, isDark)
                : filteredProviders.isEmpty
                ? _buildNoMatch(context, isDark)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filteredProviders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildProviderCard(context, isDark, filteredProviders[index]),
                  ),
          ),
        ],
      ),
    );
  }

  /// تلميح صغير غير حاجب بعد فشل الاستطلاع مرتين متتاليتين — لا يغطّي القائمة
  /// ولا يمنع التفاعل، مع زر إعادة محاولة فوري.
  Widget _buildPollHint(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          const Icon(Icons.sync_problem_rounded, size: 16, color: AppColors.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l10n?.providerListUpdateFailed ?? 'تعذّر تحديث القائمة',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: _retryPoll,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.orangePrimary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l10n?.retry ?? 'إعادة المحاولة',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              onPressed: _loadProviders,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orangePrimary),
              child: const Text(
                'إعادة المحاولة',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_off_rounded, size: 64, color: AppColors.orangePrimary),
          const SizedBox(height: 16),
          Text(
            'لا يوجد مزودون متاحون قريباً',
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

  Widget _buildNoMatch(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 64, color: AppColors.orangePrimary),
          const SizedBox(height: 16),
          Text(
            l10n?.noProvidersMatch ?? 'لا يوجد مزوّدون مطابقون للبحث',
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

  Widget _buildProviderCard(BuildContext context, bool isDark, ProviderDetails p) {
    final l10n = AppLocalizations.of(context);

    final serviceLabels = p.services
        .map((s) => _serviceNames[s] ?? s)
        .toList();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(
        '/request/provider-details?providerId=${p.providerId}',
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.orangePrimary.withValues(alpha: 0.12),
              child: const Icon(Icons.business_rounded, color: AppColors.orangePrimary, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.workshopName.isNotEmpty ? p.workshopName : p.fullName,
                    style: TextStyle(
                      fontFamily: 'Zain',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.fullName,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  if (serviceLabels.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: serviceLabels
                          .map((s) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.orangePrimary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  s,
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    color: AppColors.orangePrimary,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        p.ratingLabel,
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
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.success),
                  const SizedBox(width: 2),
                  Text(
                    formatApproxDistance(
                      p.distanceMeters,
                      meterUnit: l10n?.m ?? 'م',
                      kmUnit: l10n?.km ?? 'كم',
                    ),
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}