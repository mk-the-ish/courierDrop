import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:uuid/uuid.dart";

import "../auth/auth_state.dart";
import "../utils/offline_queue.dart";
import "map_route_declaration_screen.dart";

class RouteDeclarationScreen extends StatefulWidget {
  const RouteDeclarationScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  State<RouteDeclarationScreen> createState() => _RouteDeclarationScreenState();
}

class _RouteDeclarationScreenState extends State<RouteDeclarationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _windowStartController = TextEditingController();
  final _windowEndController = TextEditingController();
  final _notesController = TextEditingController();

  List<LatLng> _polylinePoints = [];
  bool _allowMultipleParcels = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _windowStartController.dispose();
    _windowEndController.dispose();
    _notesController.dispose();
    super.dispose();
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Route declared successfully.")),
      );
      // Clear form after success
      _startController.clear();
      _endController.clear();
      _windowStartController.clear();
      _windowEndController.clear();
      _notesController.clear();
      _polylinePoints = [];
      _allowMultipleParcels = true;
    } catch (_) {
      await OfflineQueue.instance(widget.authState.apiClient).enqueueRoute(
        corridorPayload: corridorPayload,
        polyline: _polylinePoints
            .map((point) => {"lat": point.latitude, "lng": point.longitude})
            .toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Queued offline. Will retry on reconnect.")),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = widget.authState.isBusy || _isSubmitting;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Declare Route"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _startController,
                decoration: const InputDecoration(
                  labelText: "Start location",
                  hintText: "e.g., 12 Main Rd, District 8",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
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
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          MapRouteDeclarationScreen(authState: widget.authState),
                    ),
                  );
                  if (result != null && result is List<LatLng>) {
                    setState(() => _polylinePoints = result);
                  }
                },
                icon: const Icon(Icons.map),
                label: Text(_polylinePoints.isEmpty
                    ? "Draw Route on Map"
                    : "Route: ${_polylinePoints.length} points"),
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
