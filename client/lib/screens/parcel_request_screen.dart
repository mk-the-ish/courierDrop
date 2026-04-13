import "package:flutter/material.dart";
import "package:uuid/uuid.dart";

import "../auth/auth_state.dart";
import "../utils/offline_queue.dart";
import "map_selection_screen.dart";

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

  String _priority = "Standard";
  bool _fragile = false;
  bool _isSubmitting = false;
  String? _lastParcelId;

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
      // Clear form after successful submission
      _originController.clear();
      _destinationController.clear();
      _sizeController.clear();
      _notesController.clear();
      _priority = "Standard";
      _fragile = false;
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

  @override
  Widget build(BuildContext context) {
    final isBusy = widget.authState.isBusy || _isSubmitting;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Request Parcel"),
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
                "Create a Parcel Request",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (_lastParcelId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    "Last Parcel ID: $_lastParcelId",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _originController,
                decoration: const InputDecoration(
                  labelText: "Origin",
                  hintText: "Pickup address or landmark",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
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
                          MapSelectionScreen(authState: widget.authState),
                    ),
                  );
                  if (result != null) {
                    final origin = result['origin'];
                    final destination = result['destination'];
                    setState(() {
                      _originController.text =
                          "${origin.latitude.toStringAsFixed(4)}, ${origin.longitude.toStringAsFixed(4)}";
                      _destinationController.text =
                          "${destination.latitude.toStringAsFixed(4)}, ${destination.longitude.toStringAsFixed(4)}";
                    });
                  }
                },
                icon: const Icon(Icons.map),
                label: const Text("Select on Map"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sizeController,
                decoration: const InputDecoration(
                  labelText: "Parcel size",
                  hintText: "Small box, 2kg",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(
                  labelText: "Priority",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.priority_high),
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
                subtitle: const Text("Couriers will handle with care"),
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
