import "dart:async";
import "dart:convert";

import "package:flutter/material.dart";
import "package:geolocator/geolocator.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";

import "../auth/auth_state.dart";

/// API key is injected at build time:
/// flutter run --dart-define=MAPS_API_KEY=your_key_here
const String googleApiKey = String.fromEnvironment("MAPS_API_KEY");

class RouteInfo {
  RouteInfo({
    required this.points,
    required this.distance,
    required this.duration,
  });

  final List<LatLng> points;
  final String distance;
  final String duration;
}

class DirectionsService {
  static Future<RouteInfo> getRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    if (googleApiKey.isEmpty) {
      throw Exception("Missing MAPS_API_KEY");
    }

    final url =
        "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=${origin.latitude},${origin.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&mode=driving"
        "&departure_time=now"
        "&key=$googleApiKey";

    final res = await http.get(Uri.parse(url));

    if (res.statusCode != 200) {
      throw Exception("Directions API failed");
    }

    final data = json.decode(res.body) as Map<String, dynamic>;

    if ((data["routes"] as List<dynamic>? ?? const []).isEmpty) {
      throw Exception("No route found");
    }

    final route = (data["routes"] as List<dynamic>).first as Map<String, dynamic>;
    final leg = (route["legs"] as List<dynamic>).first as Map<String, dynamic>;

    return RouteInfo(
      points: _decodePolyline(
        ((route["overview_polyline"] as Map<String, dynamic>)["points"] ?? "")
            .toString(),
      ),
      distance: ((leg["distance"] as Map<String, dynamic>)["text"] ?? "").toString(),
      duration: (((leg["duration_in_traffic"] ?? leg["duration"]) as Map<String, dynamic>)["text"] ?? "")
          .toString(),
    );
  }

  static List<LatLng> _decodePolyline(String encoded) {
    final poly = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return poly;
  }
}

class MapRouteDeclarationScreen extends StatefulWidget {
  const MapRouteDeclarationScreen({
    super.key,
    required this.authState,
    this.onPolylineSelected,
  });

  final AuthState authState;
  final Function(List<LatLng> polyline)? onPolylineSelected;

  @override
  State<MapRouteDeclarationScreen> createState() =>
      _MapRouteDeclarationScreenState();
}

class _MapRouteDeclarationScreenState extends State<MapRouteDeclarationScreen> {
  GoogleMapController? _controller;

  final List<LatLng> _points = [];
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  RouteInfo? _routeInfo;

  bool _isLoadingRoute = false;
  bool _isLocating = false;

  CameraPosition _camera = const CameraPosition(
    target: LatLng(-17.8252, 31.0335),
    zoom: 15,
  );

  Timer? _cameraDebounce;
  Timer? _routeDebounce;

  static const int _maxPoints = 50;
  static const String _latKey = "courier_map_camera_lat";
  static const String _lngKey = "courier_map_camera_lng";
  static const String _zoomKey = "courier_map_camera_zoom";

  @override
  void initState() {
    super.initState();
    _loadCamera();
  }

  void _onMapCreated(GoogleMapController c) {
    _controller = c;
  }

  void _onCameraMove(CameraPosition pos) {
    _camera = pos;

    _cameraDebounce?.cancel();
    _cameraDebounce = Timer(const Duration(milliseconds: 500), () {
      _saveCamera(pos);
    });
  }

  Future<void> _loadCamera() async {
    final prefs = await SharedPreferences.getInstance();

    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    final zoom = prefs.getDouble(_zoomKey);

    if (lat != null && lng != null && zoom != null && mounted) {
      setState(() {
        _camera = CameraPosition(
          target: LatLng(lat, lng),
          zoom: zoom,
        );
      });
    }
  }

  Future<void> _saveCamera(CameraPosition pos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_latKey, pos.target.latitude);
    await prefs.setDouble(_lngKey, pos.target.longitude);
    await prefs.setDouble(_zoomKey, pos.zoom);
  }

  void _addPoint(LatLng point) {
    if (_points.length >= _maxPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Max points reached")),
      );
      return;
    }

    _points.add(point);

    _markers.add(
      Marker(
        markerId: MarkerId("p${_points.length}"),
        position: point,
      ),
    );

    _scheduleRouteUpdate();

    setState(() {});
  }

  void _scheduleRouteUpdate() {
    _routeDebounce?.cancel();
    _routeDebounce = Timer(const Duration(milliseconds: 400), _updateRoute);
  }

  Future<void> _updateRoute() async {
    if (_points.length < 2) {
      return;
    }

    setState(() => _isLoadingRoute = true);

    try {
      final result = await DirectionsService.getRoute(
        _points.first,
        _points.last,
      );

      _polylines
        ..clear()
        ..add(
          Polyline(
            polylineId: const PolylineId("route"),
            points: result.points,
            width: 5,
            color: Colors.teal,
          ),
        );

      _routeInfo = result;
    } catch (e) {
      debugPrint("Route error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingRoute = false);
      }
    }
  }

  Future<void> _addCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition();

      final latLng = LatLng(pos.latitude, pos.longitude);

      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 16),
      );

      _addPoint(latLng);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location failed")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _undo() {
    if (_points.isEmpty) {
      return;
    }

    _points.removeLast();
    _markers.removeWhere((m) => m.markerId.value == "p${_points.length + 1}");

    _polylines.clear();
    _routeInfo = null;

    _scheduleRouteUpdate();

    setState(() {});
  }

  void _clear() {
    _points.clear();
    _markers.clear();
    _polylines.clear();
    _routeInfo = null;
    setState(() {});
  }

  void _confirm() {
    if (_points.length < 2) {
      return;
    }

    widget.onPolylineSelected?.call(_points);
    Navigator.pop(context, _points);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _cameraDebounce?.cancel();
    _routeDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Draw Route")),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _camera,
            onMapCreated: _onMapCreated,
            onCameraMove: _onCameraMove,
            onTap: _addPoint,
            markers: _markers,
            polylines: _polylines,
            zoomControlsEnabled: false,
            tiltGesturesEnabled: false,
            rotateGesturesEnabled: false,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _Controls(
              count: _points.length,
              isLocating: _isLocating,
              isLoadingRoute: _isLoadingRoute,
              routeInfo: _routeInfo,
              onAddCurrent: _addCurrentLocation,
              onUndo: _undo,
              onClear: _clear,
              onConfirm: _confirm,
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.count,
    required this.isLocating,
    required this.isLoadingRoute,
    required this.routeInfo,
    required this.onAddCurrent,
    required this.onUndo,
    required this.onClear,
    required this.onConfirm,
  });

  final int count;
  final bool isLocating;
  final bool isLoadingRoute;
  final RouteInfo? routeInfo;

  final VoidCallback onAddCurrent;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoadingRoute) const LinearProgressIndicator(),
            if (routeInfo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Info(icon: Icons.route, text: routeInfo!.distance),
                    _Info(icon: Icons.access_time, text: routeInfo!.duration),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLocating ? null : onAddCurrent,
                    icon: const Icon(Icons.my_location),
                    label: Text(isLocating ? "Locating..." : "Add Current"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: count > 0 ? onUndo : null,
                    child: const Text("Undo"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: count > 0 ? onClear : null,
                    child: const Text("Clear"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: count >= 2 ? onConfirm : null,
                    child: const Text("Confirm Route"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.teal),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
