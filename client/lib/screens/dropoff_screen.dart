import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../auth/auth_state.dart';
import '../controllers/location_tracking_controller.dart';
import '../utils/map_coordinates.dart';

/**
 * Dropoff Screen (Client/Recipient)
 * GPS gate verification for parcel delivery
 * Shows: virtual interchange location, GPS gate, OTP verification, condition photo
 */

class ClientDropoffScreen extends StatefulWidget {
  final String parcelId;
  final double dropoffLat;
  final double dropoffLng;
  final double gateRadiusMeters;
  final AuthState authState;

  const ClientDropoffScreen({
    super.key,
    required this.parcelId,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.gateRadiusMeters,
    required this.authState,
  });

  @override
  State<ClientDropoffScreen> createState() => _ClientDropoffScreenState();
}

class _ClientDropoffScreenState extends State<ClientDropoffScreen> {
  bool _isVerifying = false;
  bool _gpsInRange = false;
  bool _otpConfirmed = false;
  String _enteredOtp = '';
  String? _verificationError;
  double? _distanceToDropoffMeters;

  final TextEditingController _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkCurrentLocation();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  /**
   * Check current location against dropoff GPS gate
   */
  Future<void> _checkCurrentLocation() async {
    final locationController = context.read<LocationTrackingController>();
    
    try {
      final snapshot = await locationController.getCurrentLocationSnapshot();
      
      // Calculate distance from current location to dropoff point
      final distance = _calculateDistance(
        snapshot.lat,
        snapshot.lng,
        widget.dropoffLat,
        widget.dropoffLng,
      );

      if (mounted) {
        setState(() {
          _distanceToDropoffMeters = distance;
          _gpsInRange = distance <= widget.gateRadiusMeters;
          _verificationError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _verificationError = 'Failed to get location: $e';
          _gpsInRange = false;
        });
      }
    }
  }

  /**
   * Verify OTP from courier/delivery
   */
  Future<void> _verifyDropoffOtp() async {
    if (_enteredOtp.isEmpty) {
      if (mounted) {
        setState(() => _verificationError = 'Enter the OTP from your courier');
      }
      return;
    }

    if (!_gpsInRange) {
      if (mounted) {
        setState(() => _verificationError = 'Not at delivery location. GPS verification failed.');
      }
      return;
    }

    if (mounted) {
      setState(() => _isVerifying = true);
    }

    try {
      final response = await widget.authState.apiClient.post(
        '/handshake/complete-dropoff',
        body: {
          'parcelId': widget.parcelId,
          'otp': _enteredOtp,
          'lat': (await context.read<LocationTrackingController>().getCurrentLocationSnapshot()).lat,
          'lng': (await context.read<LocationTrackingController>().getCurrentLocationSnapshot()).lng,
          'accuracy': (await context.read<LocationTrackingController>().getCurrentLocationSnapshot()).accuracy,
          'photoUrl': 'pending', // Photo would be captured separately
        },
      );

      if (!mounted) return;

      if (response['status'] == 'ok') {
        setState(() => _otpConfirmed = true);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery verified successfully!')),
        );

        // Navigate to completion or dashboard
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop(true);
        });
      } else {
        if (mounted) {
          setState(() => _verificationError = 'Verification failed: ${response['message'] ?? 'Unknown error'}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _verificationError = 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
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
        title: const Text('Delivery Verification'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map showing dropoff location
            Container(
              height: 250,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: normalizeLatLng(LatLng(widget.dropoffLat, widget.dropoffLng)),
                  initialZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    userAgentPackageName: "com.example.dropcity_client",
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
                        point: normalizeLatLng(LatLng(widget.dropoffLat, widget.dropoffLng)),
                        radius: widget.gateRadiusMeters,
                        useRadiusInMeter: true,
                        color: Colors.purple.withOpacity(0.2),
                        borderColor: Colors.purple,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: normalizeLatLng(LatLng(widget.dropoffLat, widget.dropoffLng)),
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on, color: Colors.purple, size: 36),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Courier Location Status
            _buildStatusCard(
              title: 'Delivery Zone',
              status: _gpsInRange ? 'Courier At Location' : 'Waiting for Courier',
              statusColor: _gpsInRange ? Colors.green : Colors.orange,
              details: [
                'Safe Zone Radius: ${widget.gateRadiusMeters.toStringAsFixed(0)}m',
                if (_distanceToDropoffMeters != null)
                  'Distance: ${_distanceToDropoffMeters!.toStringAsFixed(1)}m',
              ],
            ),
            const SizedBox(height: 16),

            // Accuracy Status
            Consumer<LocationTrackingController>(
              builder: (context, locationController, _) {
                final accuracy = locationController.currentAccuracy;
                final isAccurate = (accuracy ?? 100) <= 30;

                return _buildStatusCard(
                  title: 'Your Location Accuracy',
                  status: isAccurate ? 'High Accuracy' : 'Low Accuracy',
                  statusColor: isAccurate ? Colors.green : Colors.orange,
                  details: [
                    if (accuracy != null) 'Accuracy: ±${accuracy.toStringAsFixed(1)}m',
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // OTP Verification
            const Text(
              'Delivery Verification Code',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the code your courier provided',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _otpController,
              obscureText: false,
              maxLength: 6,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 4),
              decoration: InputDecoration(
                labelText: 'OTP Code',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: '000000',
              ),
              onChanged: (value) => setState(() => _enteredOtp = value),
            ),
            const SizedBox(height: 24),

            // Error Display
            if (_verificationError != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _verificationError!,
                  style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                ),
              ),
            const SizedBox(height: 24),

            // Success State
            if (_otpConfirmed)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Delivery complete! Thank you for using DropCity.',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),

            // Instructions
            if (!_gpsInRange && !_otpConfirmed)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Waiting for courier...',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your courier is on the way. You will receive an SMS with the verification code when they arrive at your delivery zone.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _otpConfirmed
          ? null
          : FloatingActionButton.extended(
              onPressed: _isVerifying || !_gpsInRange ? null : _verifyDropoffOtp,
              label: _isVerifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm Delivery'),
              icon: const Icon(Icons.check),
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _checkCurrentLocation,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
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
        border: Border.all(color: Colors.grey.shade300),
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
