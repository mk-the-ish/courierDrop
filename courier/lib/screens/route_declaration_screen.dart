import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:geolocator/geolocator.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:uuid/uuid.dart";

import "../auth/auth_state.dart";
import "../utils/offline_queue.dart";
import "pickup_mode_screen.dart";
import "assigned_parcels_screen.dart";

class RouteDeclarationScreen extends StatefulWidget {
  const RouteDeclarationScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  State<RouteDeclarationScreen> createState() => _RouteDeclarationScreenState();
}

class _RouteDeclarationScreenState extends State<RouteDeclarationScreen> {
  static const _cameraLatKey = "courier_camera_lat";
  static const _cameraLngKey = "courier_camera_lng";
  static const _cameraZoomKey = "courier_camera_zoom";

  final _formKey = GlobalKey<FormState>();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _windowStartController = TextEditingController();
  final _windowEndController = TextEditingController();
  final _notesController = TextEditingController();

  final List<LatLng> _polylinePoints = [];
  GoogleMapController? _mapController;
  CameraPosition _cameraPosition = const CameraPosition(
    target: LatLng(-17.9242, 31.1381),
    zoom: 15,
  );

  bool _allowMultipleParcels = true;
  bool _isSubmitting = false;
  bool _isLocating = false;
  bool _isLoadingCamera = true;

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission denied.")),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _polylinePoints.insert(
          0,
          LatLng(position.latitude, position.longitude),
        );
        _syncStartEndFromPolyline();
      });
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          14,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location error: $error")),
      );
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _startController.dispose();
    _endController.dispose();
    _windowStartController.dispose();
    _windowEndController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSavedCamera();
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

    if (mounted) {
      setState(() => _isLoadingCamera = false);
    }
  }

  Future<void> _saveCamera(CameraPosition position) async {
    _cameraPosition = position;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_cameraLatKey, position.target.latitude);
    await prefs.setDouble(_cameraLngKey, position.target.longitude);
    await prefs.setDouble(_cameraZoomKey, position.zoom);
  }

  void _syncStartEndFromPolyline() {
    if (_polylinePoints.isEmpty) {
      return;
    }
    final start = _polylinePoints.first;
    final end = _polylinePoints.length > 1 ? _polylinePoints.last : null;

    _startController.text =
        "${start.latitude.toStringAsFixed(6)}, ${start.longitude.toStringAsFixed(6)}";
    if (end != null) {
      _endController.text =
          "${end.latitude.toStringAsFixed(6)}, ${end.longitude.toStringAsFixed(6)}";
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    final corridorPayload = {
      "clientId": const Uuid().v4(),
      "startLocation": _startController.text.trim(),
      "endLocation": _endController.text.trim(),
      "windowStart": _windowStartController.text.trim(),
      "windowEnd": _windowEndController.text.trim(),
      "allowMultipleParcels": _allowMultipleParcels,
      "notes": _notesController.text.trim(),
    };
    try {
      final corridorId = await widget.authState.apiClient.postRouteDeclaration(
        clientId: corridorPayload["clientId"] as String,
        startLocation: corridorPayload["startLocation"] as String,
        endLocation: corridorPayload["endLocation"] as String,
        windowStart: corridorPayload["windowStart"] as String,
        windowEnd: corridorPayload["windowEnd"] as String,
        allowMultipleParcels:
            corridorPayload["allowMultipleParcels"] as bool? ?? true,
        notes: corridorPayload["notes"] as String?,
      );
      if (_polylinePoints.length >= 2) {
        await widget.authState.apiClient.postCorridorLine(
          corridorId: corridorId,
          polyline: _polylinePoints
              .map((point) => {"lat": point.latitude, "lng": point.longitude})
              .toList(),
        );
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Route declared.")),
      );
    } catch (_) {
      await OfflineQueue.instance(widget.authState.apiClient).enqueueRoute(
        corridorPayload: corridorPayload,
        polyline: _polylinePoints
            .map((point) => {"lat": point.latitude, "lng": point.longitude})
            .toList(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Queued offline. Will retry on reconnect.")),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = widget.authState.isBusy || _isSubmitting || _isLocating;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Route Declaration"),
        actions: [
          TextButton(
            onPressed: isBusy ? null : widget.authState.signOut,
            child: const Text(
              "Sign out",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isBusy ? null : _useCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                "Declare Today's Corridor",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text("Tap the map to add corridor points."),
              const SizedBox(height: 8),
              SizedBox(
                height: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _isLoadingCamera
                      ? const Center(child: CircularProgressIndicator())
                      : GoogleMap(
                          initialCameraPosition: _cameraPosition,
                          onMapCreated: (controller) =>
                              _mapController = controller,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: true,
                          onCameraMove: (position) =>
                              _cameraPosition = position,
                          onCameraIdle: () => _saveCamera(_cameraPosition),
                          onTap: (point) {
                            setState(() {
                              _polylinePoints.add(point);
                              _syncStartEndFromPolyline();
                            });
                          },
                          polylines: {
                            if (_polylinePoints.length >= 2)
                              Polyline(
                                polylineId: const PolylineId("corridor"),
                                points: _polylinePoints,
                                color: Colors.indigo,
                                width: 5,
                              ),
                          },
                          markers: {
                            if (_polylinePoints.isNotEmpty)
                              Marker(
                                markerId: const MarkerId("start"),
                                position: _polylinePoints.first,
                                infoWindow: const InfoWindow(title: "Start"),
                              ),
                            if (_polylinePoints.length >= 2)
                              Marker(
                                markerId: const MarkerId("end"),
                                position: _polylinePoints.last,
                                infoWindow: const InfoWindow(title: "End"),
                              ),
                          },
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _polylinePoints.isEmpty || isBusy
                          ? null
                          : () => setState(() {
                                _polylinePoints.removeLast();
                                if (_polylinePoints.isEmpty) {
                                  _startController.clear();
                                  _endController.clear();
                                } else {
                                  _syncStartEndFromPolyline();
                                }
                              }),
                      child: const Text("Undo last"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _polylinePoints.isEmpty || isBusy
                          ? null
                          : () => setState(() {
                                _polylinePoints.clear();
                                _startController.clear();
                                _endController.clear();
                              }),
                      child: const Text("Clear"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isBusy ? null : _useCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: Text(_isLocating ? "Locating..." : "Use current location"),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: isBusy
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PickupModeScreen(authState: widget.authState),
                          ),
                        );
                      },
                child: const Text("Pickup Mode"),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: isBusy
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AssignedParcelsScreen(
                                authState: widget.authState),
                          ),
                        );
                      },
                child: const Text("Assigned Parcels"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _startController,
                decoration: const InputDecoration(
                  labelText: "Start location",
                  hintText: "e.g., 12 Main Rd, District 8",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _endController,
                decoration: const InputDecoration(
                  labelText: "End location",
                  hintText: "e.g., Market Square",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _windowStartController,
                      decoration: const InputDecoration(
                        labelText: "Window start",
                        hintText: "07:00",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? "Required"
                              : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _windowEndController,
                      decoration: const InputDecoration(
                        labelText: "Window end",
                        hintText: "09:30",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? "Required"
                              : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text("Accept multiple parcels"),
                subtitle: const Text("Allow more than one parcel on this route"),
                value: _allowMultipleParcels,
                onChanged: isBusy
                    ? null
                    : (value) => setState(() => _allowMultipleParcels = value),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Notes for clients",
                  hintText: "e.g., Only small parcels, no liquids",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isBusy ? null : _submit,
                child: Text(isBusy ? "Submitting..." : "Declare route"),
              ),
              const SizedBox(height: 12),
              Text(
                "Points added: ${_polylinePoints.length}",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
