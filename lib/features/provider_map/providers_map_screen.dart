import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/provider_details.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/distance_format.dart';
import '../../l10n/app_localizations.dart';
import '../provider_selection/nearby_providers_params.dart';

/// خريطة المزوّدين حول العميل: صفحة استعراض مستقلة (ليست خريطة الطلب/الطوارئ)
/// تُظهر موقع المستخدم والورش المتاحة من حوله على خريطة واحدة.
///
/// البيانات من نفس RPC قائمة المزوّدين (`get_nearest_providers`) — بلا فلتر
/// خدمة وبحد مسافة [maxDistanceMeters] — فهو الوحيد الذي يُرجع إحداثيات
/// المزوّدين، ولا حاجة لأي تغيير في قاعدة البيانات.
class ProvidersMapScreen extends StatefulWidget {
  final double maxDistanceMeters;

  const ProvidersMapScreen({super.key, this.maxDistanceMeters = 25000});

  @override
  State<ProvidersMapScreen> createState() => _ProvidersMapScreenState();
}

class _ProvidersMapScreenState extends State<ProvidersMapScreen>
    with WidgetsBindingObserver {
  final SupabaseClient _client = Supabase.instance.client;
  final MapController _mapController = MapController();

  List<ProviderDetails> _providers = const [];
  Map<String, String> _serviceNames = {};
  LatLng? _myLocation;
  bool _isLoading = true;
  bool _fetching = false;
  bool _mapReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadServiceNames();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // موقع المزوّدين يتغيّر باستمرار — نعيد الجلب بهدوء عند العودة للتطبيق.
    if (state == AppLifecycleState.resumed && !_isLoading) {
      _load(silent: true);
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

  Future<void> _load({bool silent = false}) async {
    if (_fetching) return;
    _fetching = true;

    final l10n = AppLocalizations.of(context);
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final position = await LocationService.instance.getCurrentPosition();
      if (!mounted) return;
      if (position == null) {
        setState(() {
          _error =
              l10n?.providersMapLocationFailed ??
              'تعذّر تحديد موقعك. فعّل خدمة الموقع ثم أعد المحاولة.';
          _isLoading = false;
        });
        return;
      }

      final origin = LatLng(position.latitude, position.longitude);
      final response = await _client.rpc(
        'get_nearest_providers',
        params: buildNearestProvidersParams(
          userLat: origin.latitude,
          userLng: origin.longitude,
          serviceFilter: null,
          maxDistanceMeters: widget.maxDistanceMeters,
        ),
      );

      final providers = (response as List)
          .map(
            (json) =>
                ProviderDetails.fromJson(Map<String, dynamic>.from(json as Map)),
          )
          .where((p) => p.latitude != 0 || p.longitude != 0)
          .toList();

      if (!mounted) return;
      setState(() {
        _myLocation = origin;
        _providers = providers;
        _isLoading = false;
        _error = null;
      });
      _fitCamera();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            l10n?.providersMapLoadFailed ??
            'تعذّر تحميل المزوّدين على الخريطة.';
        _isLoading = false;
      });
    } finally {
      _fetching = false;
    }
  }

  /// يُلائم الكاميرا مع المستخدم وكل المزوّدين الظاهرين.
  void _fitCamera() {
    final origin = _myLocation;
    if (!_mapReady || origin == null) return;
    final points = [
      origin,
      ..._providers.map((p) => LatLng(p.latitude, p.longitude)),
    ];
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(56, 96, 56, 140),
        maxZoom: 16,
      ),
    );
  }

  void _recenter() {
    final origin = _myLocation;
    if (origin == null) return;
    _mapController.move(origin, 15);
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
          l10n?.providersMapTitle ?? 'المزوّدون حولك',
          style: TextStyle(
            fontFamily: 'Zain',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: l10n?.providersMapRefresh ?? 'تحديث',
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            onPressed: _isLoading ? null : () => _load(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.orangePrimary),
            )
          : _error != null
          ? _buildError(isDark)
          : _buildMap(isDark),
    );
  }

  Widget _buildError(bool isDark) {
    final l10n = AppLocalizations.of(context);
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                height: 1.6,
                color: secondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _load(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orangePrimary,
              ),
              child: Text(
                l10n?.retry ?? 'إعادة المحاولة',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(bool isDark) {
    final l10n = AppLocalizations.of(context);
    final origin = _myLocation!;
    final points = [
      origin,
      ..._providers.map((p) => LatLng(p.latitude, p.longitude)),
    ];

    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: origin,
              initialZoom: 14,
              minZoom: 4,
              maxZoom: 18,
              initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(points),
                padding: const EdgeInsets.fromLTRB(56, 96, 56, 140),
                maxZoom: 16,
              ),
              onMapReady: () => _mapReady = true,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mahwar.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: origin,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.orangePrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  ..._providers.map(
                    (p) => Marker(
                      point: LatLng(p.latitude, p.longitude),
                      width: 46,
                      height: 46,
                      child: GestureDetector(
                        onTap: () => _showProviderSheet(p),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.orangePrimary,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: AppColors.orangePrimary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // عدّاد المزوّدين المتاحين
        Positioned(
          top: 8,
          left: 16,
          right: 16,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.storefront_rounded,
                    size: 16,
                    color: AppColors.orangePrimary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _providers.isEmpty
                          ? (l10n?.noNearbyProviders ?? 'لا يوجد مزودون متاحون قريباً')
                          : (l10n?.providersMapCount(_providers.length) ??
                                'متاح الآن: ${_providers.length} مزوّد'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_providers.isEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 84,
            child: _buildEmptyCard(isDark),
          ),

        // العودة لموقع المستخدم
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.small(
            heroTag: 'providers-map-recenter',
            tooltip: l10n?.providersMapRecenter ?? 'العودة لموقعي',
            backgroundColor: isDark ? AppColors.darkCard : Colors.white,
            foregroundColor: AppColors.orangePrimary,
            onPressed: _myLocation == null ? null : _recenter,
            child: const Icon(Icons.my_location_rounded),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(bool isDark) {
    final l10n = AppLocalizations.of(context);
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_rounded, color: AppColors.orangePrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n?.providersMapEmpty ??
                  'لا يوجد مزوّدون متاحون حاليًا — جرّب تحديث الخريطة بعد قليل',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                height: 1.5,
                color: secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProviderSheet(ProviderDetails p) async {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final serviceLabels = p.services
        .map((s) => _serviceNames[s] ?? s)
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: secondary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.orangePrimary.withValues(alpha: 0.12),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.orangePrimary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.workshopName.isNotEmpty ? p.workshopName : p.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Zain',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: secondary,
                          ),
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
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.success,
                        ),
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
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      p.ratingLabel(l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        color: secondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (serviceLabels.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: serviceLabels
                      .map(
                        (s) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
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
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    context.push(
                      '/request/provider-details?providerId=${p.providerId}',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orangePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    l10n?.providersMapViewProfile ?? 'عرض الملف',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
