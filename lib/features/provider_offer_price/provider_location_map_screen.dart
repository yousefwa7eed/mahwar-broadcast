import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/order.dart';

/// شاشة الخريطة الكاملة التي يفتحها المزوّد من صفحة تقديم عرض السعر.
/// تُظهر موقع العميل وموقع المزوّد (الورشة أو الموقع الحالي عبر GPS) معاً،
/// مع الخط المستقيم بينهما والمسافة التقريبية، وزر لفتح مسار في تطبيق الخرائط
/// حتى يستطيع المزوّد تحديد الوقت المتوقع للوصول إلى العميل.
class ProviderLocationMapScreen extends StatefulWidget {
  final String orderId;

  const ProviderLocationMapScreen({super.key, required this.orderId});

  @override
  State<ProviderLocationMapScreen> createState() =>
      _ProviderLocationMapScreenState();
}

class _ProviderLocationMapScreenState extends State<ProviderLocationMapScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  Order? _order;
  LatLng? _workshopLocation;
  LatLng? _gpsLocation;
  bool _isLoading = true;
  bool _isLocating = false;
  String? _error;

  LatLng? get _providerPosition => _gpsLocation ?? _workshopLocation;

  LatLng? get _customerLocation {
    final o = _order;
    if (o == null) return null;
    return LatLng(o.latitude, o.longitude);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final orderRes = await _client
          .from('orders')
          .select()
          .eq('id', widget.orderId)
          .single();
      final order = Order.fromJson(orderRes);

      LatLng? workshop;
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        try {
          final provider = await _client
              .from('providers')
              .select('latitude, longitude')
              .eq('id', userId)
              .maybeSingle();
          if (provider != null) {
            workshop = LatLng(
              (provider['latitude'] as num).toDouble(),
              (provider['longitude'] as num).toDouble(),
            );
          }
        } catch (_) {
          // الموقع الحالي للورشة غير متاح — لا يمنع عرض خريطة العميل
        }
      }

      if (mounted) {
        setState(() {
          _order = order;
          _workshopLocation = workshop;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'تعذّر تحميل بيانات الخريطة: $e';
          _isLoading = false;
        });
      }
    }
  }

  double? _distanceMeters() {
    final customer = _customerLocation;
    final provider = _providerPosition;
    if (customer == null || provider == null) return null;
    return const Distance()(customer, provider);
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} كم';
    }
    return '${meters.toStringAsFixed(0)} متر';
  }

  Future<void> _openInMaps() async {
    final provider = _providerPosition;
    final customer = _customerLocation;
    if (provider == null || customer == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${provider.latitude},${provider.longitude}'
      '&destination=${customer.latitude},${customer.longitude}'
      '&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showMessage('لا توجد تطبيقات خرائط متاحة على جهازك');
    }
  }

  Future<void> _locateCurrentPosition() async {
    setState(() => _isLocating = true);

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('يرجى تفعيل خدمة الموقع (GPS) من إعدادات جهازك');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showMessage('تم رفض إذن الوصول للموقع');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          'إذن الموقع مرفوض بشكل دائم، يرجى تفعيله من إعدادات التطبيق',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (mounted) {
        setState(() {
          _gpsLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (_) {
      _showMessage('تعذّر تحديد الموقع الحالي');
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'خريطة الوصول',
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
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.orangePrimary),
            )
          : _error != null
              ? _buildError(isDark)
              : _buildMap(isDark),
    );
  }

  Widget _buildError(bool isDark) {
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
          ],
        ),
      ),
    );
  }

  Widget _buildMap(bool isDark) {
    final customer = _customerLocation;
    if (customer == null) {
      return _buildError(isDark);
    }

    final provider = _providerPosition;
    final points = [customer, ?provider];
    final hasProvider = provider != null;
    final distance = _distanceMeters();

    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: customer,
              initialZoom: 14,
              initialCameraFit: hasProvider
                  ? CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(points),
                      padding: const EdgeInsets.all(48),
                      maxZoom: 16,
                    )
                  : null,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mahwar.app',
              ),
              if (hasProvider)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [provider, customer],
                      strokeWidth: 3,
                      color: AppColors.orangePrimary,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: customer,
                    width: 150,
                    height: 64,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMarkerLabel('موقع العميل', AppColors.error, isDark),
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.error,
                          size: 34,
                        ),
                      ],
                    ),
                  ),
                  if (hasProvider)
                    Marker(
                      point: provider,
                      width: 150,
                      height: 64,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMarkerLabel('موقعك', AppColors.success, isDark),
                          const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.success,
                            size: 34,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.straighten_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    distance != null
                        ? 'المسافة التقريبية عن العميل: ${_formatDistance(distance)}'
                        : 'موقع العميل',
                    overflow: TextOverflow.ellipsis,
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
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 16,
          child: _buildBottomPanel(isDark, hasProvider),
        ),
      ],
    );
  }

  Widget _buildMarkerLabel(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildBottomPanel(bool isDark, bool hasProvider) {
    final distance = _distanceMeters();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem(AppColors.error, 'موقع العميل'),
              if (hasProvider) _buildLegendItem(AppColors.success, 'موقعك'),
            ],
          ),
          if (distance != null && hasProvider) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.straighten_rounded, size: 16, color: AppColors.orangePrimary),
                const SizedBox(width: 6),
                Text(
                  'المسافة التقريبية: ${_formatDistance(distance)}',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: hasProvider ? _openInMaps : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orangePrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.navigation_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'فتح مسار في الخرائط',
                      style: TextStyle(
                        fontFamily: 'Zain',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.orangePrimary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _isLocating ? null : _locateCurrentPosition,
                  tooltip: 'تحديد موقعي الحالي',
                  icon: _isLocating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.my_location_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}