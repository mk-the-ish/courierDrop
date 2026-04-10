import "dart:math" as math;

import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:uuid/uuid.dart";

import "../auth/auth_state.dart";
import "../utils/offline_queue.dart";
import "progress_screen.dart";
import "parcel_status_screen.dart";

class ParcelRequestScreen extends StatefulWidget {
  const ParcelRequestScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  State<ParcelRequestScreen> createState() => _ParcelRequestScreenState();
}

class _ParcelRequestScreenState extends State<ParcelRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _sizeController = TextEditingController();
  final _notesController = TextEditingController();
  LatLng? _originPoint;
  LatLng? _destinationPoint;
  bool _selectingOrigin = true;

  String _priority = "Standard";
  bool _fragile = false;
  bool _isSubmitting = false;
  bool _isMatching = false;
  List<Map<String, dynamic>> _matches = [];
  List<LatLng> _pickupMarkers = [];
  List<LatLng> _dropoffMarkers = [];
  String? _lastParcelId;

  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = (b.latitude - a.latitude) * (3.141592653589793 / 180);
    final dLng = (b.longitude - a.longitude) * (3.141592653589793 / 180);
    final lat1 = a.latitude * (3.141592653589793 / 180);
    final lat2 = b.latitude * (3.141592653589793 / 180);
    final sinDLat = math.sin(dLat / 2);
    final sinDLng = math.sin(dLng / 2);
    final h = sinDLat * sinDLat +
        math.cos(lat1) * math.cos(lat2) * sinDLng * sinDLng;
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthRadius * c;
  }

  String _estimatedPickupDistance() {
    if (_originPoint == null || _matches.isEmpty) {
      return "-";
    }
    final pickup = _matches.first["pickup_point"] as Map<String, dynamic>?;
    if (pickup == null ||
        pickup["lat"] == null ||
        pickup["lng"] == null) {
      return "-";
    }
    final pickupPoint = LatLng(
      (pickup["lat"] as num).toDouble(),
      (pickup["lng"] as num).toDouble(),
    );
    final meters = _distanceMeters(_originPoint!, pickupPoint);
    if (meters >= 1000) {
      return "${(meters / 1000).toStringAsFixed(2)} km";
    }
    return "${meters.toStringAsFixed(0)} m";
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _sizeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    final payload = {
      "clientId": const Uuid().v4(),
      "origin": _originController.text.trim(),
      "destination": _destinationController.text.trim(),
      "size": _sizeController.text.trim(),
      "priority": _priority,
      "fragile": _fragile,
      "notes": _notesController.text.trim(),
    };
    try {
      final parcelId = await widget.authState.apiClient.postParcelRequest(
        clientId: payload["clientId"] as String,
        origin: payload["origin"] as String,
        destination: payload["destination"] as String,
        size: payload["size"] as String?,
        priority: payload["priority"] as String,
        fragile: payload["fragile"] as bool? ?? false,
        notes: payload["notes"] as String?,
      );
      if (!mounted) {
        return;
      }
      setState(() => _lastParcelId = parcelId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Parcel request submitted.")),
      );
    } catch (_) {
      await OfflineQueue.instance(widget.authState.apiClient)
          .enqueueParcel(payload);
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

  Future<void> _findMatches() async {
    if (_originPoint == null || _destinationPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select origin and destination on the map.")),
      );
      return;
    }

    setState(() => _isMatching = true);
    try {
      final matches = await widget.authState.apiClient.matchCorridors(
        originLat: _originPoint!.latitude,
        originLng: _originPoint!.longitude,
        destinationLat: _destinationPoint!.latitude,
        destinationLng: _destinationPoint!.longitude,
      );
      if (!mounted) {
        return;
      }
      final pickups = <LatLng>[];
      final dropoffs = <LatLng>[];
      matches.sort((a, b) {
        final aVal = (a["pickup_fraction"] as num?)?.toDouble() ?? 0;
        final bVal = (b["pickup_fraction"] as num?)?.toDouble() ?? 0;
        return aVal.compareTo(bVal);
      });
      for (final match in matches) {
        final pickup = match["pickup_point"] as Map<String, dynamic>?;
        final dropoff = match["dropoff_point"] as Map<String, dynamic>?;
        if (pickup != null &&
            pickup["lat"] != null &&
            pickup["lng"] != null) {
          pickups.add(
            LatLng(
              (pickup["lat"] as num).toDouble(),
              (pickup["lng"] as num).toDouble(),
            ),
          );
        }
        if (dropoff != null &&
            dropoff["lat"] != null &&
            dropoff["lng"] != null) {
          dropoffs.add(
            LatLng(
              (dropoff["lat"] as num).toDouble(),
              (dropoff["lng"] as num).toDouble(),
            ),
          );
        }
      }
      setState(() {
        _matches = matches;
        _pickupMarkers = pickups;
        _dropoffMarkers = dropoffs;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Match error: $error")),
      );
    } finally {
      if (mounted) {
        setState(() => _isMatching = false);
      }
    }
  }

  Future<void> _requestCourier(String corridorId) async {
    if (_lastParcelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Submit a parcel request first.")),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final corridorIds = _matches
          .map((m) => m["corridor_id"]?.toString())
          .where((id) => id != null && id != "-")
          .cast<String>()
          .toList();
      await widget.authState.apiClient.requestCourier(
        parcelId: _lastParcelId!,
        corridorId: corridorId,
        corridorIds: corridorIds,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Courier requested.")),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Request error: $error")),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = widget.authState.isBusy || _isSubmitting || _isMatching;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Request Parcel"),
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
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_matches.isNotEmpty)
                Card(
                  color: Colors.teal.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.local_shipping, color: Colors.teal),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Available couriers: ${_matches.length}\n"
                            "Best pickup fraction: ${((_matches.first["pickup_fraction"] as num?) ?? 0).toStringAsFixed(3)}\n"
                            "Estimated pickup distance: ${_estimatedPickupDistance()}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_matches.isNotEmpty) const SizedBox(height: 8),
              OutlinedButton(
                onPressed: isBusy
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ProgressScreen(authState: widget.authState),
                          ),
                        );
                      },
                child: const Text("Parcel Progress / Dropoff"),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: isBusy
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ParcelStatusScreen(authState: widget.authState),
                          ),
                        );
                      },
                child: const Text("Parcel Status"),
              ),
              if (_matches.isNotEmpty) const SizedBox(height: 12),
              const Text(
                "Create a Parcel Request",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (_lastParcelId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    "Parcel ID: $_lastParcelId",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _originController,
                decoration: const InputDecoration(
                  labelText: "Origin",
                  hintText: "Pickup address or landmark",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _destinationController,
                decoration: const InputDecoration(
                  labelText: "Destination",
                  hintText: "Dropoff address or landmark",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sizeController,
                decoration: const InputDecoration(
                  labelText: "Parcel size",
                  hintText: "Small box, 2kg",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(
                  labelText: "Priority",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: "Standard", child: Text("Standard")),
                  DropdownMenuItem(value: "Express", child: Text("Express")),
                  DropdownMenuItem(value: "Same-day", child: Text("Same-day")),
                ],
                onChanged: isBusy ? null : (value) => setState(() => _priority = value!),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text("Fragile item"),
                subtitle: const Text("Couriers will be alerted to handle with care"),
                value: _fragile,
                onChanged: isBusy ? null : (value) => setState(() => _fragile = value),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Notes",
                  hintText: "Any special handling instructions",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isBusy ? null : _submit,
                child: Text(isBusy ? "Submitting..." : "Submit request"),
              ),
              const SizedBox(height: 12),
              const Text(
                "Courier matching results will appear here in the next milestone.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                "Find Available Couriers",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text("Tap the map to select origin and destination."),
              const SizedBox(height: 8),
              SizedBox(
                height: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(-26.2041, 28.0473),
                      zoom: 12,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                    onTap: (point) {
                      setState(() {
                        if (_selectingOrigin || _originPoint == null) {
                          _originPoint = point;
                          _selectingOrigin = false;
                        } else {
                          _destinationPoint = point;
                          _selectingOrigin = true;
                        }
                      });
                    },
                    markers: {
                      if (_originPoint != null)
                        Marker(
                          markerId: const MarkerId("origin"),
                          position: _originPoint!,
                          infoWindow: const InfoWindow(title: "Origin"),
                        ),
                      if (_destinationPoint != null)
                        Marker(
                          markerId: const MarkerId("destination"),
                          position: _destinationPoint!,
                          infoWindow: const InfoWindow(title: "Destination"),
                        ),
                      for (int i = 0; i < _pickupMarkers.length; i++)
                        Marker(
                          markerId: MarkerId("pickup_$i"),
                          position: _pickupMarkers[i],
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen,
                          ),
                          infoWindow: const InfoWindow(title: "Pickup"),
                        ),
                      for (int i = 0; i < _dropoffMarkers.length; i++)
                        Marker(
                          markerId: MarkerId("dropoff_$i"),
                          position: _dropoffMarkers[i],
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueRed,
                          ),
                          infoWindow: const InfoWindow(title: "Dropoff"),
                        ),
                    },
                    polylines: {
                      if (_originPoint != null && _destinationPoint != null)
                        Polyline(
                          polylineId: const PolylineId("route"),
                          points: [_originPoint!, _destinationPoint!],
                          color: Colors.teal,
                          width: 4,
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
                      onPressed: isBusy
                          ? null
                          : () => setState(() {
                                _originPoint = null;
                                _selectingOrigin = true;
                              }),
                      child: const Text("Clear origin"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isBusy
                          ? null
                          : () => setState(() {
                                _destinationPoint = null;
                                _selectingOrigin = false;
                              }),
                      child: const Text("Clear destination"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: isBusy ? null : _findMatches,
                child: Text(_isMatching ? "Finding..." : "Find couriers"),
              ),
              const SizedBox(height: 12),
              if (_matches.isEmpty)
                const Text(
                  "No matches yet.",
                  textAlign: TextAlign.center,
                ),
              if (_matches.isNotEmpty)
                ..._matches.map((match) {
                  final corridorId = match["corridor_id"]?.toString() ?? "-";
                  final pickupFraction =
                      match["pickup_fraction"]?.toString() ?? "-";
                  final dropoffFraction =
                      match["dropoff_fraction"]?.toString() ?? "-";
                  return Card(
                    child: ListTile(
                      title: Text("Corridor $corridorId"),
                      subtitle: Text(
                        "Pickup: $pickupFraction | Dropoff: $dropoffFraction",
                      ),
                      trailing: TextButton(
                        onPressed: isBusy || corridorId == "-"
                            ? null
                            : () => _requestCourier(corridorId),
                        child: const Text("Request"),
                      ),
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
