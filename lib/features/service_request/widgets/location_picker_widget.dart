import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
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

  /// يطلب صلاحية الموقع من نظام التشغيل، ويجيب الموقع الحالي الحقيقي للجهاز،
  /// وينقل الخريطة والعلامة (marker) إليه مباشرة.
  Future<void> _goToCurrentLocation() async {
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
        _showMessage('إذن الموقع مرفوض بشكل دائم، يرجى تفعيله من إعدادات التطبيق');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final newLocation = LatLng(position.latitude, position.longitude);

      setState(() => _selectedLocation = newLocation);
      _mapController.move(newLocation, 16);
      widget.onLocationChanged(newLocation);
    } catch (e) {
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
                  AppLocalizations.of(context)?.tapMapToSetLocation ?? 'اضغط على الخريطة لتحديد الموقع',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: Colors.white,
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