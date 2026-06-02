import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:geolocator/geolocator.dart";
import "package:http/http.dart" as http;
import "package:http/retry.dart";
import "package:latlong2/latlong.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../auth/auth_state.dart";
import "../utils/map_coordinates.dart";

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

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    required this.fullText,
    required this.coordinates,
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;
  final String fullText;
  final LatLng coordinates;
}

class OSMMapService {
  OSMMapService._(this._client);

  factory OSMMapService.create({http.Client? client}) {
    return OSMMapService._(
      RetryClient(
        client ?? http.Client(),
        retries: 3,
        when: _shouldRetryResponse,
        whenError: _shouldRetryError,
        delay: _retryDelay,
      ),
    );
  }

  final http.Client _client;

  static bool _shouldRetryResponse(http.BaseResponse response) {
    return response.statusCode == 429 || response.statusCode >= 500;
  }

  static bool _shouldRetryError(Object error, StackTrace stackTrace) {
    return error is SocketException || error is TimeoutException;
  }

  static Duration _retryDelay(int retryCount) {
    return Duration(milliseconds: 400 * (1 << retryCount));
  }

  Future<List<PlaceSuggestion>> autocomplete(String query) async {
    if (query.trim().length < 2) return const [];
    final uri = Uri.parse("https://nominatim.openstreetmap.org/search").replace(
      queryParameters: {
        "q": query.trim(),
        "format": "jsonv2",
        "addressdetails": "1",
        "limit": "8",
        "countrycodes": "zw",
      },
    );
    final response = await _client
        .get(
          uri,
          headers: {"User-Agent": "DropCity/1.0"},
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return const [];

    final body = jsonDecode(response.body) as List<dynamic>;
    return body.map((item) {
      final row = item as Map<String, dynamic>;
      final lat = double.tryParse(row["lat"]?.toString() ?? "");
      final lon = double.tryParse(row["lon"]?.toString() ?? "");
      if (lat == null || lon == null) {
        return null;
      }
      final display = row["display_name"]?.toString() ?? "";
      final parts = display.split(",");
      final primary = parts.isNotEmpty ? parts.first.trim() : display;
      final secondary = parts.length > 1 ? parts.sublist(1).join(",").trim() : "";
      return PlaceSuggestion(
        placeId: "$lat,$lon",
        primaryText: primary,
        secondaryText: secondary,
        fullText: display,
        coordinates: LatLng(lat, lon),
      );
    }).whereType<PlaceSuggestion>().toList();
  }

  Future<LatLng?> getPlaceCoordinates(String placeId) async {
    final parts = placeId.split(",");
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0]);
    final lon = double.tryParse(parts[1]);
    if (lat == null || lon == null) return null;
    return LatLng(lat, lon);
  }

  Future<String> reverseGeocode(LatLng coordinates) async {
    final fallback =
        "${coordinates.latitude.toStringAsFixed(5)}, ${coordinates.longitude.toStringAsFixed(5)}";
    final uri = Uri.parse("https://nominatim.openstreetmap.org/reverse").replace(
      queryParameters: {
        "lat": coordinates.latitude.toString(),
        "lon": coordinates.longitude.toString(),
        "format": "jsonv2",
      },
    );
    final response = await _client
        .get(
          uri,
          headers: {"User-Agent": "DropCity/1.0"},
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return fallback;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body["display_name"]?.toString() ?? fallback;
  }

  Future<RouteInfo?> route({
    required List<LatLng> points,
  }) async {
    if (points.length < 2) return null;
    final coordinates = points
        .map((point) => "${point.longitude},${point.latitude}")
        .join(";");
    final uri = Uri.parse(
      "https://router.project-osrm.org/route/v1/driving/"
      "$coordinates"
      "?overview=full&geometries=polyline&alternatives=false&steps=false&continue_straight=true",
    );
    final response = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body["code"]?.toString() != "Ok") return null;
    final routes = body["routes"] as List<dynamic>? ?? const [];
    if (routes.isEmpty) return null;

    final route = routes.first as Map<String, dynamic>;
    return RouteInfo(
      points: _decodePolyline(route["geometry"]?.toString() ?? ""),
      distance: "${(((route["distance"] as num?)?.toDouble() ?? 0) / 1000).toStringAsFixed(1)} km",
      duration: "${(((route["duration"] as num?)?.toDouble() ?? 0) / 60).ceil()} min",
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
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

      poly.add(LatLng(lat / 1e5, lng / 1e5));
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
  final OSMMapService _mapService = OSMMapService.create();
  final MapController _mapController = MapController();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  final List<LatLng> _points = [];
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  RouteInfo? _routeInfo;
  bool _isLoadingRoute = false;
  bool _isLocating = false;
  bool _searchingForStart = true;
  bool _isSearchingPlaces = false;
  bool _isMapReady = false;
  String? _activeAddress;
  String? _startAddress;
  String? _endAddress;

  LatLng _center = const LatLng(-17.8252, 31.0335);
  List<PlaceSuggestion> _suggestions = const [];

  Timer? _searchDebounce;
  Timer? _cameraDebounce;
  int _routeRequestId = 0;
  int? _insertAfterIndex;

  @override
  void initState() {
    super.initState();
    _loadCamera();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _cameraDebounce?.cancel();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _loadCamera() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble("courier_map_camera_lat");
    final lng = prefs.getDouble("courier_map_camera_lng");
    if (!mounted || lat == null || lng == null) return;
    final saved = LatLng(lat, lng);
    if (!isFiniteLatLng(saved)) return;
    setState(() => _center = saved);
    if (_isMapReady) {
      _mapController.move(saved, 14);
    }
  }

  Future<void> _saveCamera() async {
    if (!isFiniteLatLng(_center)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble("courier_map_camera_lat", _center.latitude);
    await prefs.setDouble("courier_map_camera_lng", _center.longitude);
  }

  void _rebuildMarkers() {
    _markers.clear();
    for (var i = 0; i < _points.length; i++) {
      final index = i;
      final isStart = i == 0;
      final isEnd = i == _points.length - 1;
      final color = isStart
          ? Colors.green
          : isEnd
              ? Colors.red
              : Colors.orange;
      _markers.add(
        Marker(
          point: _points[index],
          width: 46,
          height: 46,
          child: GestureDetector(
            onTap: () {
              if (index < 0 || index >= _points.length) return;
              _points.removeAt(index);
              _normalizeInsertAfterIndex();
              _rebuildMarkers();
              setState(() {});
              _scheduleRouteUpdate();
            },
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 4,
                    offset: Offset(0, 2),
                    color: Color(0x22000000),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  "${i + 1}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  void _normalizeInsertAfterIndex() {
    if (_points.isEmpty) {
      _insertAfterIndex = null;
      return;
    }
    if (_insertAfterIndex == null) return;
    if (_insertAfterIndex! >= _points.length) {
      _insertAfterIndex = _points.length - 1;
    }
    if (_insertAfterIndex! < 0) {
      _insertAfterIndex = null;
    }
  }

  void _setInsertAfterIndex(int? index) {
    if (index == null) {
      setState(() => _insertAfterIndex = null);
      return;
    }
    if (index < 0 || index >= _points.length) return;
    setState(() => _insertAfterIndex = index);
  }

  void _addPoint(LatLng point) {
    if (!isFiniteLatLng(point)) {
      return;
    }
    if (_points.length >= 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Max points reached")),
      );
      return;
    }
    final insertAfter = _insertAfterIndex;
    final int insertIndex = insertAfter == null
        ? _points.length
        : (insertAfter + 1).clamp(0, _points.length).toInt();
    _points.insert(insertIndex, point);
    _insertAfterIndex = insertIndex;
    _rebuildMarkers();
    _scheduleRouteUpdate();
    setState(() {});
  }

  void _scheduleRouteUpdate() {
    _cameraDebounce?.cancel();
    _cameraDebounce = Timer(const Duration(milliseconds: 350), _updateRoute);
  }

  Future<void> _updateRoute() async {
    if (_points.length < 2) return;
    final requestId = ++_routeRequestId;
    if (mounted) {
      setState(() => _isLoadingRoute = true);
    }
    try {
      final result = await _mapService.route(
        points: List<LatLng>.from(_points),
      );
      if (!mounted || requestId != _routeRequestId) return;
      if (result == null || result.points.isEmpty) {
        setState(() {
          _routeInfo = null;
          _polylines.clear();
        });
        return;
      }
      setState(() {
        _routeInfo = result;
        _polylines
          ..clear()
          ..add(
            Polyline(
              points: result.points,
              strokeWidth: 6,
              borderStrokeWidth: 2,
              borderColor: Colors.white,
              color: Colors.teal,
            ),
          );
      });
      _fitRoute(result.points);
    } catch (e) {
      debugPrint("Route error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingRoute = false);
      }
    }
  }

  void _fitRoute(List<LatLng> points) {
    if (points.isEmpty || !_isMapReady) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  void _onCameraChanged(LatLng center) {
    if (!isFiniteLatLng(center)) return;
    _center = center;
    _cameraDebounce?.cancel();
    _cameraDebounce = Timer(const Duration(milliseconds: 450), _saveCamera);
  }

  void _onSearchChanged(String value, {required bool forStart}) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      if (value.trim().length < 2) {
        setState(() => _suggestions = const []);
        return;
      }
      setState(() => _isSearchingPlaces = true);
      try {
        final list = await _mapService.autocomplete(value);
        if (!mounted) return;
        setState(() {
          _suggestions = list;
          _searchingForStart = forStart;
        });
      } finally {
        if (mounted) {
          setState(() => _isSearchingPlaces = false);
        }
      }
    });
  }

  Future<void> _pickSuggestion(PlaceSuggestion suggestion) async {
    final coordinates = suggestion.coordinates ?? await _mapService.getPlaceCoordinates(suggestion.placeId);
    if (!mounted || coordinates == null) return;
    if (!isFiniteLatLng(coordinates)) return;
    _mapController.move(coordinates, 16);
    setState(() {
      _center = coordinates;
      _suggestions = const [];
      _activeAddress = suggestion.fullText;
      if (_searchingForStart) {
        _startController.text = suggestion.fullText;
        _startAddress = suggestion.fullText;
      } else {
        _endController.text = suggestion.fullText;
        _endAddress = suggestion.fullText;
      }
      if (_points.isEmpty) {
        _points.add(coordinates);
      } else if (_searchingForStart) {
        _points[0] = coordinates;
      } else if (_points.length == 1) {
        _points.add(coordinates);
      } else {
        _points[_points.length - 1] = coordinates;
      }
      _normalizeInsertAfterIndex();
      _rebuildMarkers();
    });
    _scheduleRouteUpdate();
    final address = await _mapService.reverseGeocode(coordinates);
    if (!mounted) return;
    setState(() {
      _activeAddress = address;
      if (_searchingForStart) {
        _startAddress = address;
      } else {
        _endAddress = address;
      }
    });
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
        throw Exception("Location permission denied");
      }
      final position = await Geolocator.getCurrentPosition();
      final current = LatLng(position.latitude, position.longitude);
      if (!isFiniteLatLng(current)) return;
      _mapController.move(current, 16);
      _addPoint(current);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _undo() {
    if (_points.isEmpty) return;
    _points.removeLast();
    _normalizeInsertAfterIndex();
    _rebuildMarkers();
    _polylines.clear();
    setState(() {});
    _scheduleRouteUpdate();
  }

  void _clear() {
    _points.clear();
    _markers.clear();
    _polylines.clear();
    _routeInfo = null;
    _insertAfterIndex = null;
    _startController.clear();
    _endController.clear();
    _startAddress = null;
    _endAddress = null;
    setState(() {});
  }

  void _confirm() {
    if (_points.length < 2) return;
    widget.onPolylineSelected?.call(_points);
    Navigator.pop(context, {
      "startPoint": _points.first,
      "endPoint": _points.last,
      "polyline": _points,
    });
  }

  @override
  Widget build(BuildContext context) {
    final insertLabel = _insertAfterIndex == null
        ? "Appending new points at the end"
        : "Next waypoint inserts after stop ${_insertAfterIndex! + 1}";
    return Scaffold(
      appBar: AppBar(
        title: const Text("Draw Route"),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: normalizeLatLng(_center),
              initialZoom: 15,
              onPositionChanged: (position, hasGesture) {
                final center = position.center;
                if (center != null && isFiniteLatLng(center)) {
                  _onCameraChanged(center);
                }
              },
              onMapReady: () {
                _isMapReady = true;
                if (isFiniteLatLng(_center)) {
                  _mapController.move(_center, 14);
                }
              },
              onLongPress: (_, point) => _addPoint(point),
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.example.dropcity_courier",
                tileProvider: NetworkTileProvider(
                  silenceExceptions: true,
                  cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
                    maxCacheSize: 250000000,
                    overrideFreshAge: const Duration(days: 7),
                  ),
                ),
              ),
              PolylineLayer(polylines: _polylines.toList()),
              MarkerLayer(markers: _markers.toList()),
              const Align(
                child: IgnorePointer(
                  child: Icon(Icons.location_pin, size: 42, color: Colors.red),
                ),
              ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 170,
            child: Card(
              color: Colors.black87,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _points.length < 2
                      ? "Choose an insertion slot, then long press the map to add the first corridor points"
                      : "Choose a stop to insert after, then long press the map to add a waypoint between stops",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _startController,
                      onChanged: (value) => _onSearchChanged(value, forStart: true),
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: "Start location",
                        prefixIcon: Icon(Icons.trip_origin),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _endController,
                      onChanged: (value) => _onSearchChanged(value, forStart: false),
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: "End location",
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        insertLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.blueGrey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text("Append end"),
                              selected: _insertAfterIndex == null,
                              onSelected: (_) => _setInsertAfterIndex(null),
                            ),
                            const SizedBox(width: 8),
                            for (var i = 0; i < _points.length; i++) ...[
                              ChoiceChip(
                                label: Text("After ${i + 1}"),
                                selected: _insertAfterIndex == i,
                                onSelected: (_) => _setInsertAfterIndex(i),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (_isSearchingPlaces)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(),
                      ),
                    if (_suggestions.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final item = _suggestions[index];
                            return ListTile(
                              dense: true,
                              title: Text(item.primaryText),
                              subtitle: Text(item.secondaryText),
                              onTap: () => _pickSuggestion(item),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
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
    super.key,
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
  const _Info({required this.icon, required this.text, super.key});

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
