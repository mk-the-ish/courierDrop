import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";

import "../services/map_service.dart";
import "../widgets/map_view.dart";
import "../utils/map_coordinates.dart";

class DeliveryPickerScreen extends StatefulWidget {
  const DeliveryPickerScreen({super.key});

  @override
  State<DeliveryPickerScreen> createState() => _DeliveryPickerScreenState();
}

class _DeliveryPickerScreenState extends State<DeliveryPickerScreen> {
  final MapService _mapService = MapService();
  final TextEditingController _searchController = TextEditingController();

  MapController? _controller;
  LatLng _center = const LatLng(-17.8252, 31.0335);

  LatLng? _pickup;
  LatLng? _dropoff;

  String? _pickupAddress;
  String? _dropoffAddress;
  String? _activeAddress;

  RouteInfo? _routeInfo;
  int _routeRequestId = 0;
  bool _selectingPickup = true;
  bool _isResolvingAddress = false;
  bool _isSearching = false;

  Timer? _cameraDebounce;
  Timer? _searchDebounce;

  List<PlaceSuggestion> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _resolveCenterAddress();
  }

  @override
  void dispose() {
    _cameraDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onCameraMove(LatLng position) {
    if (!isFiniteLatLng(position)) {
      return;
    }
    _center = position;
  }

  void _onCameraIdle() {
    _cameraDebounce?.cancel();
    _cameraDebounce = Timer(const Duration(milliseconds: 450), _resolveCenterAddress);
  }

  Future<void> _resolveCenterAddress() async {
    if (!mounted) {
      return;
    }

    if (!isFiniteLatLng(_center)) {
      return;
    }

    if (mounted) {
      setState(() {
        _isResolvingAddress = true;
      });
    }

    final address = await _mapService.reverseGeocode(_center);
    if (!mounted) {
      return;
    }

    setState(() {
      _activeAddress = address;
      if (_selectingPickup) {
        _pickup = _center;
        _pickupAddress = address;
      } else {
        _dropoff = _center;
        _dropoffAddress = address;
      }
      _isResolvingAddress = false;
    });

    if (_pickup != null && _dropoff != null) {
      await _updateRoute();
    }
  }

  Future<void> _updateRoute() async {
    final pickup = _pickup;
    final dropoff = _dropoff;
    if (pickup == null || dropoff == null) {
      return;
    }

    final requestId = ++_routeRequestId;
    final route = await _mapService.directions(origin: pickup, destination: dropoff);
    if (!mounted || requestId != _routeRequestId) {
      return;
    }

    if (route == null) {
      setState(() {
        _routeInfo = null;
      });
      return;
    }

    setState(() {
      _routeInfo = route;
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) {
        return;
      }

      if (mounted) {
        setState(() {
          _isSearching = true;
        });
      }

      final results = await _mapService.autocomplete(value);
      if (!mounted) {
        return;
      }

      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _onSuggestionSelected(PlaceSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    _searchController.text = suggestion.fullText;

    setState(() {
      _suggestions = const [];
    });

    final coordinates = await _mapService.getPlaceCoordinates(suggestion.placeId);
    if (coordinates == null || !isFiniteLatLng(coordinates) || _controller == null) {
      return;
    }

    _controller!.move(coordinates, 16);

    _center = coordinates;
    await _resolveCenterAddress();
  }

  void _nextStep() {
    if (_selectingPickup && _pickup != null) {
      if (mounted) {
        setState(() {
          _selectingPickup = false;
          _activeAddress = _dropoffAddress;
          _searchController.clear();
        });
      }
      return;
    }

    if (_dropoff != null) {
      _confirm();
    }
  }

  void _confirm() {
    final pickup = _pickup;
    final dropoff = _dropoff;
    if (pickup == null || dropoff == null) {
      return;
    }

    Navigator.of(context).pop({
      "pickup": pickup,
      "dropoff": dropoff,
      "pickupAddress": _pickupAddress,
      "dropoffAddress": _dropoffAddress,
      "distance": _routeInfo?.distanceText,
      "eta": _routeInfo?.durationText,
    });
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (_pickup != null) {
      markers.add(
        Marker(
          point: _pickup!,
          width: 40,
          height: 40,
          child: const Icon(Icons.place, color: Colors.green, size: 36),
        ),
      );
    }

    if (_dropoff != null) {
      markers.add(
        Marker(
          point: _dropoff!,
          width: 40,
          height: 40,
          child: const Icon(Icons.place, color: Colors.red, size: 36),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    final route = _routeInfo;
    if (route == null || route.polylinePoints.isEmpty) {
      return const {};
    }

    return {
      Polyline(
        points: route.polylinePoints,
        strokeWidth: 5,
        color: Colors.teal,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _selectingPickup ? _pickup != null : _dropoff != null;

    return Scaffold(
      body: Stack(
        children: [
          MapView(
            initialCenter: _center,
            onMapCreated: (controller) => _controller = controller,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Material(
                  elevation: 5,
                  borderRadius: BorderRadius.circular(10),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: _selectingPickup
                          ? "Search pickup location"
                          : "Search destination",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 260),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        return ListTile(
                          dense: true,
                          title: Text(suggestion.primaryText),
                          subtitle: Text(suggestion.secondaryText),
                          onTap: () => _onSuggestionSelected(suggestion),
                        );
                      },
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemCount: _suggestions.length,
                    ),
                  ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _BottomPanel(
              selectingPickup: _selectingPickup,
              pickup: _pickupAddress,
              dropoff: _dropoffAddress,
              previewAddress: _activeAddress,
              distance: _routeInfo?.distanceText,
              eta: _routeInfo?.durationText,
              isResolvingAddress: _isResolvingAddress,
              canContinue: canContinue,
              onNext: _nextStep,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.selectingPickup,
    required this.pickup,
    required this.dropoff,
    required this.previewAddress,
    required this.distance,
    required this.eta,
    required this.isResolvingAddress,
    required this.canContinue,
    required this.onNext,
  });

  final bool selectingPickup;
  final String? pickup;
  final String? dropoff;
  final String? previewAddress;
  final String? distance;
  final String? eta;
  final bool isResolvingAddress;
  final bool canContinue;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final title = selectingPickup ? "Step 1: Pick pickup" : "Step 2: Pick destination";
    final actionLabel = selectingPickup ? "Set Pickup" : "Confirm Delivery";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _LocationTile(label: "Pickup", value: pickup, color: Colors.green),
            const SizedBox(height: 6),
            _LocationTile(label: "Dropoff", value: dropoff, color: Colors.red),
            if (isResolvingAddress || (previewAddress != null && previewAddress!.isNotEmpty)) ...[
              const SizedBox(height: 10),
              Text(
                isResolvingAddress ? "Updating address..." : "Center pin: $previewAddress",
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            if (distance != null && distance!.isNotEmpty && eta != null && eta!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text("Step 3: Confirm ride/delivery - $distance, ETA $eta"),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canContinue ? onNext : null,
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.location_on, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "$label: ${value ?? "Not set yet"}",
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
