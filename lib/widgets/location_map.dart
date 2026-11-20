import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../models/site.dart';
import 'app_button.dart';

/// Maps come from OpenStreetMap, which needs no account or key. Its terms
/// ask apps to name themselves and show the attribution.
const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _appPackage = 'com.example.real_estate';
const _india = LatLng(20.5937, 78.9629);

LatLng _toLatLng(MapPoint point) => LatLng(point.latitude, point.longitude);

TileLayer _tiles() => TileLayer(urlTemplate: _tileUrl, userAgentPackageName: _appPackage);

Widget _attribution() => const SimpleAttributionWidget(source: Text('OpenStreetMap contributors'));

Marker _pin(LatLng point) => Marker(
      point: point,
      width: 44,
      height: 44,
      alignment: Alignment.topCenter,
      child: Icon(Icons.location_on_rounded, size: 44, color: AppColors.primary),
    );

/// A place chosen on the map, with the city it is in if one was
/// found for it.
class PickedPlace {
  final MapPoint point;
  final String? placeName;

  const PickedPlace(this.point, this.placeName);
}

/// Opens the map to choose a spot. With no [initial] spot it captures the
/// device's current position straight away; tapping the map moves the pin.
Future<PickedPlace?> pickMapPoint(BuildContext context, {MapPoint? initial, String? title}) {
  return showDialog<PickedPlace>(
    context: context,
    builder: (_) => Theme(
      data: AppTheme.lightTheme,
      child: _MapPickerDialog(initial: initial, title: title ?? 'Choose on map'),
    ),
  );
}

/// Shows [point] on a full map that can be moved and zoomed.
Future<void> showLocationOnMap(BuildContext context, {required String name, required MapPoint point}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Theme(
      data: AppTheme.lightTheme,
      child: _MapFrame(
        title: name,
        subtitle: point.label,
        map: FlutterMap(
          options: MapOptions(initialCenter: _toLatLng(point), initialZoom: 14),
          children: [
            _tiles(),
            MarkerLayer(markers: [_pin(_toLatLng(point))]),
            _attribution(),
          ],
        ),
        footer: Align(
          alignment: Alignment.centerRight,
          child: AppButton.outline(text: 'Close', onPressed: () => Navigator.of(context).pop()),
        ),
      ),
    ),
  );
}

/// A small map that cannot be moved, showing [point]. Tapping it calls
/// [onTap], usually to open [showLocationOnMap].
class LocationMapPreview extends StatelessWidget {
  final MapPoint point;
  final double height;
  final VoidCallback? onTap;

  const LocationMapPreview({super.key, required this.point, this.height = 120, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              key: ValueKey(point),
              options: MapOptions(
                initialCenter: _toLatLng(point),
                initialZoom: 12,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                _tiles(),
                MarkerLayer(markers: [_pin(_toLatLng(point))]),
              ],
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '© OpenStreetMap',
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight, fontSize: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog layout shared by the picker and the viewer: title, map, footer.
class _MapFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget map;
  final Widget footer;

  const _MapFrame({required this.title, this.subtitle, required this.map, required this.footer});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: AppColors.pureWhite,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 760,
        height: size.height * 0.85,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.map_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleLarge.copyWith(
                            color: AppColors.textPrimaryLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ClipRRect(borderRadius: BorderRadius.circular(14), child: map),
              ),
              const SizedBox(height: 12),
              footer,
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPickerDialog extends StatefulWidget {
  final MapPoint? initial;
  final String title;

  const _MapPickerDialog({required this.initial, required this.title});

  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  final _map = MapController();
  LatLng? _picked;
  String? _placeName;
  String? _problem;
  bool _locating = false;
  bool _mapReady = false;
  int _lookup = 0; // Only the newest place-name lookup may answer.

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) {
      // Capture where the user is now, so they only adjust the pin.
      _locateMe();
    } else {
      _picked = _toLatLng(initial);
      _findPlaceName(_picked!);
    }
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  Future<void> _locateMe() async {
    setState(() {
      _locating = true;
      _problem = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Location is turned off on this device. Turn it on, or tap the map.';
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw 'Location permission was not given. Allow it in settings, or tap the map.';
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      _choose(LatLng(position.latitude, position.longitude), zoom: 15);
    } on TimeoutException {
      _showProblem('Could not find your position in time. Try again, or tap the map.');
    } catch (error) {
      _showProblem(error is String ? error : 'Could not find your position. Tap the map instead.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showProblem(String message) {
    if (mounted) setState(() => _problem = message);
  }

  void _choose(LatLng point, {double? zoom}) {
    setState(() {
      _picked = point;
      _placeName = null;
      _problem = null;
    });
    if (_mapReady) _map.move(point, zoom ?? _map.camera.zoom);
    _findPlaceName(point);
  }

  /// Looks up the city at [point], to suggest it as the location name.
  /// Optional: if it fails, the user simply types the name.
  Future<void> _findPlaceName(LatLng point) async {
    final lookup = ++_lookup;
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '${point.latitude}',
        'lon': '${point.longitude}',
        'zoom': '10', // City level, not street or neighbourhood.
        'accept-language': 'en',
      });
      // Browsers set their own User-Agent; apps must name themselves.
      final response = await http
          .get(uri, headers: kIsWeb ? null : {'User-Agent': '$_appPackage (Kaira Properties)'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 || lookup != _lookup || !mounted) return;
      final address = (jsonDecode(response.body) as Map<String, dynamic>)['address'] as Map<String, dynamic>?;
      if (address == null) return;
      for (final key in ['city', 'town', 'state_district', 'municipality', 'village']) {
        final name = address[key];
        if (name is String && name.trim().isNotEmpty) {
          setState(() => _placeName = name.trim());
          return;
        }
      }
    } catch (_) {
      // No name suggestion; the point itself is still chosen.
    }
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    final status = _problem ??
        (_locating
            ? 'Finding your current position…'
            : picked == null
                ? 'Tap the map to drop the pin.'
                : [if (_placeName != null) 'City: $_placeName', MapPoint(picked.latitude, picked.longitude).label]
                    .join(' · '));

    return _MapFrame(
      title: widget.title,
      subtitle: 'Your position is captured automatically. Tap the map to move the pin.',
      map: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: picked ?? _india,
              initialZoom: picked == null ? 4.5 : 15,
              onMapReady: () => _mapReady = true,
              onTap: (_, point) => _choose(point),
            ),
            children: [
              _tiles(),
              if (picked != null) MarkerLayer(markers: [_pin(picked)]),
              _attribution(),
            ],
          ),
          Positioned(
            right: 12,
            top: 12,
            child: FloatingActionButton.small(
              heroTag: null,
              tooltip: 'Use my current position',
              backgroundColor: AppColors.pureWhite,
              foregroundColor: AppColors.primary,
              onPressed: _locating ? null : _locateMe,
              child: _locating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
        ],
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _problem != null ? Icons.info_outline_rounded : Icons.place_outlined,
                size: 18,
                color: _problem != null ? AppColors.warning : AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  status,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryLight),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppButton.outline(text: 'Cancel', onPressed: () => Navigator.of(context).pop()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.primary(
                  text: 'Use this spot',
                  gradient: AppColors.brandGradient,
                  onPressed: picked == null
                      ? null
                      : () => Navigator.of(context).pop(
                            PickedPlace(MapPoint(picked.latitude, picked.longitude), _placeName),
                          ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
