import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapSelectionScreen extends StatefulWidget {
  const MapSelectionScreen({super.key, this.onPointsSelected});

  final Function(LatLng origin, LatLng destination)? onPointsSelected;

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  GoogleMapController? _controller;

  LatLng? _origin;
  LatLng? _destination;
  bool _selectingOrigin = true;

  final CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(-17.8252, 31.0335),
    zoom: 12,
  );

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller; // ❌ do NOT dispose here
  }

  void _onTap(LatLng point) {
    setState(() {
      if (_selectingOrigin) {
        _origin = point;
      } else {
        _destination = point;
      }
      _selectingOrigin = !_selectingOrigin;
    });
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (_origin != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: _origin!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }

    if (_destination != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destination!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolyline() {
    if (_origin == null || _destination == null) return {};

    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [_origin!, _destination!],
        width: 4,
        color: Colors.teal,
      ),
    };
  }

  void _confirm() {
    if (_origin != null && _destination != null) {
      widget.onPointsSelected?.call(_origin!, _destination!);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    // Only dispose once here
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Points")),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: _initialPosition,
              onMapCreated: _onMapCreated,
              onTap: _onTap,

              // Performance tweaks
              liteModeEnabled: false, // set true if targeting low-end Android
              myLocationEnabled: false,
              zoomControlsEnabled: false,

              markers: _buildMarkers(),
              polylines: _buildPolyline(),
            ),
          ),

          _BottomPanel(
            origin: _origin,
            destination: _destination,
            selectingOrigin: _selectingOrigin,
            onClear: () {
              setState(() {
                _origin = null;
                _destination = null;
                _selectingOrigin = true;
              });
            },
            onConfirm: _confirm,
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.origin,
    required this.destination,
    required this.selectingOrigin,
    required this.onClear,
    required this.onConfirm,
  });

  final LatLng? origin;
  final LatLng? destination;
  final bool selectingOrigin;
  final VoidCallback onClear;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            selectingOrigin ? 'Tap map to select ORIGIN' : 'Tap map to select DESTINATION',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (origin != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Origin: ${origin!.latitude.toStringAsFixed(4)}, ${origin!.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          if (destination != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Destination: ${destination!.latitude.toStringAsFixed(4)}, ${destination!.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onClear,
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: origin != null && destination != null ? onConfirm : null,
                  child: const Text('Confirm'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}