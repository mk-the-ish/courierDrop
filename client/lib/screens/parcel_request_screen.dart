import "dart:async";
import "dart:convert";

import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:uuid/uuid.dart";
import "package:permission_handler/permission_handler.dart";

import "../auth/auth_state.dart";
import "../utils/offline_queue.dart";
import "map_selection_screen.dart";

class _PlaceSuggestion {
  const _PlaceSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  final String displayName;
  final double latitude;
  final double longitude;

  String get coordString =>
      "${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}";
}

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
  bool _isSearchingOrigin = false;
  bool _isSearchingDestination = false;
  Timer? _originDebounce;
  Timer? _destinationDebounce;
  List<_PlaceSuggestion> _originSuggestions = [];
  List<_PlaceSuggestion> _destinationSuggestions = [];
  _PlaceSuggestion? _selectedOrigin;
  _PlaceSuggestion? _selectedDestination;

  @override
  void dispose() {
    _originDebounce?.cancel();
    _destinationDebounce?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    _sizeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<List<_PlaceSuggestion>> _fetchSuggestions(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) {
      return [];
    }
    final uri = Uri.https(
      "nominatim.openstreetmap.org",
      "/search",
      {
        "q": trimmed,
        "format": "jsonv2",
        "addressdetails": "1",
        "limit": "5",
      },
    );
    final response = await http.get(
      uri,
      headers: const {"User-Agent": "dropcity-client"},
    );
    if (response.statusCode != 200) {
      return [];
    }
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.map((item) {
      final map = item as Map<String, dynamic>;
      return _PlaceSuggestion(
        displayName: map["display_name"]?.toString() ?? "Unknown location",
        latitude: double.tryParse(map["lat"]?.toString() ?? "") ?? 0,
        longitude: double.tryParse(map["lon"]?.toString() ?? "") ?? 0,
      );
    }).where((suggestion) => suggestion.latitude != 0 || suggestion.longitude != 0).toList();
  }

  void _onOriginChanged(String value) {
    if (_selectedOrigin != null && value.trim() != _selectedOrigin!.displayName) {
      _selectedOrigin = null;
    }
    _originDebounce?.cancel();
    _originDebounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isSearchingOrigin = true);
      final results = await _fetchSuggestions(value);
      if (!mounted) {
        return;
      }
      setState(() {
        _originSuggestions = results;
        _isSearchingOrigin = false;
      });
    });
  }

  Future<void> _pickPointsFromMap() async {
    // Before navigating to MapSelectionScreen
    if (await Permission.location.request().isGranted) {
      // Navigate to map
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => MapSelectionScreen(authState: widget.authState),
        ),
      );
      if (!mounted || result == null) {
        return;
      }
      final origin = result["origin"];
      final destination = result["destination"];
      if (origin is! LatLng || destination is! LatLng) {
        return;
      }

      final originSuggestion = _PlaceSuggestion(
        displayName: "Map pin (${origin.latitude.toStringAsFixed(4)}, ${origin.longitude.toStringAsFixed(4)})",
        latitude: origin.latitude,
        longitude: origin.longitude,
      );
      final destinationSuggestion = _PlaceSuggestion(
        displayName: "Map pin (${destination.latitude.toStringAsFixed(4)}, ${destination.longitude.toStringAsFixed(4)})",
        latitude: destination.latitude,
        longitude: destination.longitude,
      );

      setState(() {
        _selectedOrigin = originSuggestion;
        _selectedDestination = destinationSuggestion;
        _originController.text = originSuggestion.displayName;
        _destinationController.text = destinationSuggestion.displayName;
        _originSuggestions = [];
        _destinationSuggestions = [];
      });
    }
  }

  void _onDestinationChanged(String value) {
    if (_selectedDestination != null &&
        value.trim() != _selectedDestination!.displayName) {
      _selectedDestination = null;
    }
    _destinationDebounce?.cancel();
    _destinationDebounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isSearchingDestination = true);
      final results = await _fetchSuggestions(value);
      if (!mounted) {
        return;
      }
      setState(() {
        _destinationSuggestions = results;
        _isSearchingDestination = false;
      });
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    final originValue = _selectedOrigin?.coordString ??
        _originController.text.trim();
    final destinationValue = _selectedDestination?.coordString ??
        _destinationController.text.trim();
    final payload = {
      "clientId": const Uuid().v4(),
      "origin": originValue,
      "destination": destinationValue,
      "size": _sizeController.text.trim(),
      "priority": _priority,
      "fragile": _fragile,
      "notes": _notesController.text.trim(),
    };
    try {
      final parcelId = await widget.authState.apiClient.postParcelRequest(
        clientId: payload["clientId"] as String,
        origin: originValue,
        destination: destinationValue,
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
      _selectedOrigin = null;
      _selectedDestination = null;
      _originSuggestions = [];
      _destinationSuggestions = [];
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
              OutlinedButton.icon(
                onPressed: isBusy ? null : _pickPointsFromMap,
                icon: const Icon(Icons.map),
                label: const Text("Pick Origin & Destination On Map"),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _originController,
                decoration: const InputDecoration(
                  labelText: "Origin",
                  hintText: "Pickup address or landmark",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                onChanged: _onOriginChanged,
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? "Required"
                        : _selectedOrigin == null
                            ? "Select a suggested location or use map picker"
                            : null,
              ),
              if (_isSearchingOrigin)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (_originSuggestions.isNotEmpty)
                _SuggestionList(
                  suggestions: _originSuggestions,
                  onSelected: (suggestion) {
                    setState(() {
                      _originController.text = suggestion.displayName;
                      _selectedOrigin = suggestion;
                      _originSuggestions = [];
                    });
                  },
                ),
              if (_selectedOrigin != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    "Using coordinates: ${_selectedOrigin!.coordString}",
                    style: const TextStyle(fontSize: 12, color: Colors.teal),
                  ),
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
                onChanged: _onDestinationChanged,
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? "Required"
                        : _selectedDestination == null
                            ? "Select a suggested location or use map picker"
                            : null,
              ),
              if (_isSearchingDestination)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (_destinationSuggestions.isNotEmpty)
                _SuggestionList(
                  suggestions: _destinationSuggestions,
                  onSelected: (suggestion) {
                    setState(() {
                      _destinationController.text = suggestion.displayName;
                      _selectedDestination = suggestion;
                      _destinationSuggestions = [];
                    });
                  },
                ),
              if (_selectedDestination != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    "Using coordinates: ${_selectedDestination!.coordString}",
                    style: const TextStyle(fontSize: 12, color: Colors.teal),
                  ),
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

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({
    required this.suggestions,
    required this.onSelected,
  });

  final List<_PlaceSuggestion> suggestions;
  final ValueChanged<_PlaceSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 6),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return ListTile(
            dense: true,
            title: Text(suggestion.displayName),
            subtitle: Text(suggestion.coordString),
            onTap: () => onSelected(suggestion),
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: suggestions.length,
      ),
    );
  }
}
