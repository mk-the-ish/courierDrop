import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../auth/auth_state.dart';
import '../controllers/location_tracking_controller.dart';
import '../utils/map_coordinates.dart';
import "../theme.dart";

/**
 * Pickup Screen
 * GPS gate verification with checkpoint validation
 * Shows: checkpoint radius, current location, distance to gate, manual PIN confirmation
 */

class PickupScreen extends StatefulWidget {
  final String parcelId;
  final double checkpointLat;
  final double checkpointLng;
  final double gateRadiusMeters;
  final AuthState authState;

  const PickupScreen({
    super.key,
    required this.parcelId,
    required this.checkpointLat,
    required this.checkpointLng,
    required this.gateRadiusMeters,
    required this.authState,
  });

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  bool _isVerifying = false;
  bool _gpsInRange = false;
  bool _pinConfirmed = false;
  String _manualPin = '';
  String? _verificationError;
  double? _distanceToGateMeters;

  final TextEditingController _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkCurrentLocation();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  /**
   * Check current location against checkpoint GPS gate
   */
  Future<void> _checkCurrentLocation() async {
    final locationController = context.read<LocationTrackingController>();
    
    try {
      final snapshot = await locationController.getCurrentLocationSnapshot();
      
      // Calculate distance from current location to checkpoint
      final distance = _calculateDistance(
        snapshot.lat,
        snapshot.lng,
        widget.checkpointLat,
        widget.checkpointLng,
      );

      setState(() {
        _distanceToGateMeters = distance;
        _gpsInRange = distance <= widget.gateRadiusMeters;
        _verificationError = null;
      });
    } catch (e) {
      setState(() {
        _verificationError = 'Failed to get location: $e';
        _gpsInRange = false;
      });
    }
  }

  /**
   * Verify PIN against server
   */
  Future<void> _verifyPin() async {
    if (_manualPin.isEmpty) {
      setState(() => _verificationError = 'Enter verification PIN');
      return;
    }

    if (!_gpsInRange) {
      setState(() => _verificationError = 'GPS verification failed. Not at pickup location.');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final response = await widget.authState.apiClient.post(
        '/parcels/${widget.parcelId}/checkpoints/verify',
        body: {
          'pin': _manualPin,
          'lat': (await context.read<LocationTrackingController>().getCurrentLocationSnapshot()).lat,
          'lng': (await context.read<LocationTrackingController>().getCurrentLocationSnapshot()).lng,
          'checkpoint_type': 'PICKUP',
        },
      );

      if (response['verified'] == true) {
        setState(() => _pinConfirmed = true);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pickup verified successfully!')),
        );

        // Navigate to next step or back
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop(true);
        });
      } else {
        setState(() => _verificationError = 'Verification failed: ${response['message']}');
      }
    } catch (e) {
      setState(() => _verificationError = 'Error: $e');
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  /**
   * Calculate distance between two points (Haversine formula)
   * Returns distance in meters
   */
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusM = 6371000.0;
    
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    
    final a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(_toRadians(lat1)) *
            Math.cos(_toRadians(lat2)) *
            Math.sin(dLng / 2) *
            Math.sin(dLng / 2);
    
    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    
    return earthRadiusM * c;
  }

  double _toRadians(double degrees) => degrees * (3.141592653589793 / 180.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pickup Verification'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map showing checkpoint
            Container(
              height: 250,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: normalizeLatLng(LatLng(widget.checkpointLat, widget.checkpointLng)),
                    initialZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      userAgentPackageName: "com.example.dropcity_courier",
                      tileProvider: NetworkTileProvider(
                        silenceExceptions: true,
                        cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
                          maxCacheSize: 250000000,
                          overrideFreshAge: const Duration(days: 7),
                        ),
                      ),
                    ),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: normalizeLatLng(LatLng(widget.checkpointLat, widget.checkpointLng)),
                          radius: widget.gateRadiusMeters,
                          useRadiusInMeter: true,
                          color: Colors.blue.withOpacity(0.2),
                          borderColor: Colors.blue,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: normalizeLatLng(LatLng(widget.checkpointLat, widget.checkpointLng)),
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, color: Colors.blue, size: 36),
                        ),
                      ],
                    ),
                  ],
                ),
            ),
            const SizedBox(height: 24),

            // GPS Status
            _buildStatusCard(
              title: 'GPS Verification',
              status: _gpsInRange ? 'In Range' : 'Out of Range',
              statusColor: _gpsInRange ? dropCityActiveMint : dropCityAlertAmber,
              details: [
                'Gate Radius: ${widget.gateRadiusMeters.toStringAsFixed(0)}m',
                if (_distanceToGateMeters != null)
                  'Distance: ${_distanceToGateMeters!.toStringAsFixed(1)}m',
              ],
            ),
            const SizedBox(height: 16),

            // Accuracy Status
            Consumer<LocationTrackingController>(
              builder: (context, locationController, _) {
                final accuracy = locationController.currentAccuracy;
                final isAccurate = (accuracy ?? 100) <= 30;

                return _buildStatusCard(
                  title: 'Location Accuracy',
                  status: isAccurate ? 'High' : 'Low',
                  statusColor: isAccurate ? dropCityActiveMint : dropCityAlertAmber,
                  details: [
                    if (accuracy != null) 'Accuracy: ±${accuracy.toStringAsFixed(1)}m',
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Manual PIN Verification
            const Text(
              'Verification PIN',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the PIN provided by the pickup point staff',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinController,
              obscureText: true,
              maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: '000000',
              ),
              onChanged: (value) => setState(() => _manualPin = value),
            ),
            const SizedBox(height: 24),

            // Error Display
            if (_verificationError != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dropCityErrorRed.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _verificationError!,
                  style: TextStyle(color: dropCityErrorRed, fontSize: 12),
                ),
              ),
            const SizedBox(height: 24),

            // Verification Status
            if (_pinConfirmed)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: dropCityActiveMint.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: dropCityActiveMint),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pickup verified! Proceeding to next step...',
                        style: TextStyle(color: dropCityActiveMint),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _pinConfirmed
          ? null
          : FloatingActionButton.extended(
              onPressed: _isVerifying || !_gpsInRange ? null : _verifyPin,
              label: _isVerifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify PIN'),
              icon: const Icon(Icons.check),
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _checkCurrentLocation,
          style: ElevatedButton.styleFrom(
            backgroundColor: dropCitySlateGrey.withOpacity(0.30),
          ),
          child: const Text(
            'Refresh Location',
            style: TextStyle(color: Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String status,
    required Color statusColor,
    required List<String> details,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: dropCitySlateGrey.withOpacity(0.30)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...details.map(
            (detail) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                detail,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Simple Math helper
class Math {
  static double sin(double x) {
    x = x % (2 * 3.141592653589793);
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  static double cos(double x) {
    x = x % (2 * 3.141592653589793);
    double result = 1;
    double term = 1;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  static double atan2(double y, double x) {
    if (x > 0) return (y / x).atan();
    if (x < 0 && y >= 0) return (y / x).atan() + 3.141592653589793;
    if (x < 0 && y < 0) return (y / x).atan() - 3.141592653589793;
    if (x == 0 && y > 0) return 3.141592653589793 / 2;
    if (x == 0 && y < 0) return -3.141592653589793 / 2;
    return 0;
  }

  static double sqrt(double x) {
    if (x < 0) return double.nan;
    if (x == 0) return 0;
    double guess = x;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}
