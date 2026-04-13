import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:geolocator/geolocator.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../auth/auth_state.dart";

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
  static const _cameraLatKey = "courier_map_camera_lat";
  static const _cameraLngKey = "courier_map_camera_lng";
  static const _cameraZoomKey = "courier_map_camera_zoom";

  final List<LatLng> _polylinePoints = [];
  GoogleMapController? _mapController;
  bool _isLocating = false;

  CameraPosition _cameraPosition = const CameraPosition(
    target: LatLng(-17.8252, 31.0335), // Harare Coordinates
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    _loadSavedCamera();
  }

  void _onMapCreated(GoogleMapController controller) {
    // Use setState to ensure the UI knows the controller is ready
    setState(() {
      _mapController = controller;
    });
  }

  Future<void> _loadSavedCamera() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_cameraLatKey);
    final lng = prefs.getDouble(_cameraLngKey);
    final zoom = prefs.getDouble(_cameraZoomKey);
    if (lat != null && lng != null && zoom != null) {
      setState(() {
        _cameraPosition = CameraPosition(
          target: LatLng(lat, lng),
          zoom: zoom,
        );
      });
    }
  }

  Future<void> _saveCamera(CameraPosition position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_cameraLatKey, position.target.latitude);
    await prefs.setDouble(_cameraLngKey, position.target.longitude);
    await prefs.setDouble(_cameraZoomKey, position.zoom);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission denied.")),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;

      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location error: $error")),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _confirmSelection() {
    if (_polylinePoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one route point.")),
      );
      return;
    }

    if (widget.onPolylineSelected != null) {
      widget.onPolylineSelected!(_polylinePoints);
    }
    Navigator.of(context).pop(_polylinePoints);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Draw Route"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: _cameraPosition,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              // Aggressive memory optimizations
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              onMapCreated: _onMapCreated,
              onCameraMove: (position) {
                _cameraPosition = position;
                _saveCamera(position);
              },
              onTap: (point) {
                setState(() {
                  _polylinePoints.add(point);
                });
              },
              markers: {
                for (int i = 0; i < _polylinePoints.length; i++)
                  Marker(
                    markerId: MarkerId("point_$i"),
                    position: _polylinePoints[i],
                    infoWindow: InfoWindow(title: "Point ${i + 1}"),
                    icon: i == 0
                        ? BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen,
                          )
                        : i == _polylinePoints.length - 1
                            ? BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueRed,
                              )
                            : BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueBlue,
                              ),
                  ),
              },
              polylines: {
                if (_polylinePoints.length > 1)
                  Polyline(
                    polylineId: const PolylineId("route"),
                    points: _polylinePoints,
                    color: Colors.blue,
                    width: 4,
                  ),
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Points added: ${_polylinePoints.length}",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (_polylinePoints.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _polylinePoints.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final point = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text(
                                "P${idx + 1}: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}",
                                style: const TextStyle(fontSize: 11),
                              ),
                              onDeleted: () {
                                setState(() {
                                  _polylinePoints.removeAt(idx);
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLocating ? null : _useCurrentLocation,
                        icon: const Icon(Icons.my_location),
                        label: Text(
                          _isLocating ? "Locating..." : "Add Current",
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _polylinePoints.isEmpty
                            ? null
                            : () {
                                setState(() {
                                  _polylinePoints.removeLast();
                                });
                              },
                        child: const Text("Undo"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _polylinePoints.isEmpty
                            ? null
                            : () {
                                setState(() {
                                  _polylinePoints.clear();
                                });
                              },
                        child: const Text("Clear"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _polylinePoints.isEmpty ? null : _confirmSelection,
                  child: const SizedBox(
                    width: double.infinity,
                    child: Center(
                      child: Text("Use This Route"),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
