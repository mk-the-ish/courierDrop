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