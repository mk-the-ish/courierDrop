import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "../auth/auth_state.dart";

class MapSelectionScreen extends StatefulWidget {
  const MapSelectionScreen({
    super.key,
    required this.authState,
    this.onPointsSelected,
  });

  final AuthState authState;
  final Function(LatLng origin, LatLng destination)? onPointsSelected;

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  final GlobalKey _mapKey = GlobalKey();
  LatLng? _originPoint;
  LatLng? _destinationPoint;
  bool _selectingOrigin = true;
  GoogleMapController? _mapController;

  @override
  void dispose() {
    // Simply dispose the active controller
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    // Dispose any previous instance before replacing the controller.
    _mapController?.dispose();
    _mapController = controller;
  }

  void _confirmSelection() {
    if (_originPoint == null || _destinationPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select both origin and destination."),
        ),
      );
      return;
    }

    if (widget.onPointsSelected != null) {
      widget.onPointsSelected!(_originPoint!, _destinationPoint!);
    }
    Navigator.of(context).pop({
      'origin': _originPoint,
      'destination': _destinationPoint,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Delivery Points"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              key: _mapKey,
              initialCameraPosition: const CameraPosition(
                target: LatLng(-17.8252, 31.0335), // Harare Coordinates
                zoom: 12,
              ),
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              // Aggressive memory optimizations
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              onMapCreated: _onMapCreated,
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
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                  ),
                if (_destinationPoint != null)
                  Marker(
                    markerId: const MarkerId("destination"),
                    position: _destinationPoint!,
                    infoWindow: const InfoWindow(title: "Destination"),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
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
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectingOrigin ? "Tap on map to select Origin" : "Tap on map to select Destination",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (_originPoint != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, color: Colors.green, size: 12),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Origin: ${_originPoint!.latitude.toStringAsFixed(4)}, ${_originPoint!.longitude.toStringAsFixed(4)}",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () =>
                              setState(() => _originPoint = null),
                          constraints: const BoxConstraints(
                            minWidth: 30,
                            minHeight: 30,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                if (_destinationPoint != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, color: Colors.red, size: 12),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Destination: ${_destinationPoint!.latitude.toStringAsFixed(4)}, ${_destinationPoint!.longitude.toStringAsFixed(4)}",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () =>
                              setState(() => _destinationPoint = null),
                          constraints: const BoxConstraints(
                            minWidth: 30,
                            minHeight: 30,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _originPoint = null;
                            _destinationPoint = null;
                            _selectingOrigin = true;
                          });
                        },
                        child: const Text("Clear"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _originPoint != null && _destinationPoint != null
                            ? _confirmSelection
                            : null,
                        child: const Text("Confirm"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
