import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../l10n/app_localizations.dart';

class LocationPickerWidget extends StatefulWidget {
  final LatLng? initialLocation;
  final ValueChanged<LatLng> onLocationChanged;
  final bool autoLocate;

  const LocationPickerWidget({
    super.key,
    this.initialLocation,
    required this.onLocationChanged,
    this.autoLocate = false,
  });

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  late final MapController _mapController;
  late LatLng _selectedLocation;
  bool _isLocating = false;
  double? _accuracyMeters;
  bool _isApproximate = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLocation = widget.initialLocation ?? const LatLng(30.0444, 31.2357);

    if (widget.autoLocate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _goToCurrentLocation();
      });
    }
  }

  /// يطلب صلاحية الموقع، ثم يستخدم التحديد الدقيق (refinePosition) الذي
  /// يعيد أول تحديد بدقة ≤ 50 م فوراً، وإلا أفضل تحديد خلال 30 ثانية.
  /// يعرض شارة الدقة وتحذيراً عند «الموقع تقريبي» مع زر «تحسين الدقة»
  /// الذي يعيد المحاولة فوراً. الاختيار اليدوي بالنقر على الخريطة يبقى
  /// متاحاً دائماً.
  Future<void> _goToCurrentLocation() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isLocating = true);

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage(l10n?.locationServiceDisabled ??
            'يرجى تفعيل خدمة الموقع (GPS) من إعدادات جهازك');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showMessage(l10n?.locationPermissionDenied ?? 'تم رفض إذن الوصول للموقع');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage(l10n?.locationPermissionPermanentlyDenied ??
            'إذن الموقع مرفوض بشكل دائم، يرجى تفعيله من إعدادات التطبيق');
        return;
      }

      // استهلاك التحديد المُسبَق إن وُجد، وإلا بدء تحديد جديد.
      var fix = await LocationService.instance.takePrewarmedRefinedPosition();
      fix ??= await LocationService.instance.refinePosition();

      if (fix == null) {
        _showMessageWithRetry(l10n?.locationTimeoutDelayed ??
            'تعذّر تحديد موقعك خلال 30 ثانية، تأكد من توافر GPS ثم أعد المحاولة');
        return;
      }

      // ignore: unnecessary_non_null_assertion
      final newLocation = LatLng(fix!.latitude, fix!.longitude);

      setState(() {
        // ignore: unnecessary_non_null_assertion
        _selectedLocation = newLocation;
        // ignore: unnecessary_non_null_assertion
        _accuracyMeters = fix!.accuracyMeters;
        // ignore: unnecessary_non_null_assertion
        _isApproximate = fix!.isApproximate;
      });
      _mapController.move(newLocation, 16);
      widget.onLocationChanged(newLocation);
    } catch (e) {
      _showMessage(l10n?.locationUnavailable ?? 'تعذّر تحديد الموقع الحالي');
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

  /// رسالة فشل تحديد الموقع مع زر «إعادة المحاولة» يعيد المحاولة فوراً،
  /// دون إجبار المستخدم على أي مسار آخر (يبقى قادراً على النقر على الخريطة).
  void _showMessageWithRetry(String message) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: l10n?.retry ?? 'إعادة المحاولة',
          onPressed: _goToCurrentLocation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 320,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedLocation,
                initialZoom: 15,
                onTap: (tapPosition, latLng) {
                  setState(() => _selectedLocation = latLng);
                  widget.onLocationChanged(latLng);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.mahwar.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: AppColors.orangePrimary,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // شارة "اضغط على الخريطة..."
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n?.tapMapToSetLocation ?? 'اضغط على الخريطة لتحديد الموقع',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // شارة دقة الموقع (عند توفرها)
            if (_accuracyMeters != null)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${l10n?.locationAccuracyLabel ?? 'دقة الموقع'} ≈ ${_accuracyMeters!.round()} ${l10n?.m ?? 'م'}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            // تحذير «الموقع تقريبي» مع زر «تحسين الدقة»
            if (_isApproximate)
              Positioned(
                bottom: 56,
                left: 12,
                right: 12,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.orangePrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.orangePrimary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.orangePrimary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n?.approximateLocationWarning ?? 'الموقع تقريبي، قد لا يكون دقيقاً',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: AppColors.orangePrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _isLocating ? null : _goToCurrentLocation,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.orangePrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            l10n?.refineLocation ?? 'تحسين الدقة',
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 12,
              right: 12,
              child: FloatingActionButton.small(
                heroTag: 'locate_me_btn',
                backgroundColor: AppColors.orangePrimary,
                onPressed: _isLocating ? null : _goToCurrentLocation,
                child: _isLocating
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.my_location_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}