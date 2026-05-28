import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";

import "../utils/map_coordinates.dart";

class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.initialCenter,
    required this.onMapCreated,
    required this.onCameraMove,
    required this.onCameraIdle,
    required this.markers,
    required this.polylines,
    this.myLocationEnabled = true,
  });

  final LatLng initialCenter;
  final ValueChanged<MapController> onMapCreated;
  final ValueChanged<LatLng> onCameraMove;
  final VoidCallback onCameraIdle;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final bool myLocationEnabled;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MapController _mapController = MapController();
  Timer? _idleTimer;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: normalizeLatLng(widget.initialCenter),
        initialZoom: 14,
        onMapReady: () {
          if (!mounted) return;
          _isMapReady = true;
          widget.onMapCreated(_mapController);
        },
        onPositionChanged: (position, hasGesture) {
          if (!_isMapReady) return;
          final center = position.center;
          if (center != null && isFiniteLatLng(center)) {
            widget.onCameraMove(center);
          }
          _idleTimer?.cancel();
          _idleTimer = Timer(const Duration(milliseconds: 350), widget.onCameraIdle);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          userAgentPackageName: "com.example.dropcity_client",
          tileProvider: NetworkTileProvider(
            silenceExceptions: true,
            cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
              maxCacheSize: 250000000,
              overrideFreshAge: const Duration(days: 7),
            ),
          ),
        ),
        PolylineLayer(polylines: widget.polylines.toList()),
        MarkerLayer(markers: widget.markers.toList()),
        const Align(
          child: IgnorePointer(
            child: Icon(Icons.location_pin, size: 42, color: Colors.red),
          ),
        ),
      ],
    );
  }
}
