import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";

class MapView extends StatelessWidget {
  const MapView({
    super.key,
    required this.initialCenter,
    required this.onMapCreated,
    required this.onCameraMove,
    required this.onCameraIdle,
    required this.markers,
    required this.polylines,
    this.myLocationEnabled = true,
  });

  final LatLng initialCenter;
  final ValueChanged<GoogleMapController> onMapCreated;
  final ValueChanged<CameraPosition> onCameraMove;
  final VoidCallback onCameraIdle;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final bool myLocationEnabled;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: initialCenter, zoom: 14),
          onMapCreated: onMapCreated,
          onCameraMove: onCameraMove,
          onCameraIdle: onCameraIdle,
          markers: markers,
          polylines: polylines,
          myLocationEnabled: myLocationEnabled,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: true,
          mapToolbarEnabled: false,
        ),
        const IgnorePointer(
          child: Center(
            child: Icon(Icons.location_pin, size: 42, color: Colors.red),
          ),
        ),
      ],
    );
  }
}
