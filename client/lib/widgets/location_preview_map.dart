import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../utils/map_coordinates.dart';

class LocationPreviewMap extends StatelessWidget {
  const LocationPreviewMap({
    super.key,
    required this.point,
    this.height = 180,
    this.label = 'Location preview',
  });

  final LatLng? point;
  final double height;
  final String label;

  @override
  Widget build(BuildContext context) {
    final center = normalizeLatLng(point);
    final markerPoint = isFiniteLatLng(point) ? point : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: height,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 16,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.dropcity_client',
                  tileProvider: NetworkTileProvider(
                    silenceExceptions: true,
                    cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
                      maxCacheSize: 250000000,
                      overrideFreshAge: const Duration(days: 7),
                    ),
                  ),
                ),
                if (markerPoint != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: markerPoint,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
