import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/auth_state.dart';
import '../controllers/location_tracking_controller.dart';
import '../utils/map_coordinates.dart';
import "../theme.dart";

/**
 * Courier Dropoff Screen
 * Delivery completion with GPS gate, OTP generation, and condition photo
 * Shows: delivery location, GPS accuracy, OTP generation UI, photo capture
 */

class CourierDropoffScreen extends StatefulWidget {
  final String parcelId;
  final String recipientId;
  final double dropoffLat;
  final double dropoffLng;
  final double gateRadiusMeters;
  final AuthState authState;

  const CourierDropoffScreen({
    super.key,
    required this.parcelId,
    required this.recipientId,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.gateRadiusMeters,
    required this.authState,
  });

  @override
  State<CourierDropoffScreen> createState() => _CourierDropoffScreenState();
}

class _CourierDropoffScreenState extends State<CourierDropoffScreen> {
  bool _isAtLocation = false;
  bool _otpGenerated = false;
  String? _generatedOtp;
  String? _photoUrl;
  bool _isUploading = false;
  bool _isCompleting = false;
  String? _verificationError;
  double? _distanceToDropoffMeters;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _checkCurrentLocation();
  }

  /**
   * Check if courier is within GPS gate
   */
  Future<void> _checkCurrentLocation() async {
    final locationController = context.read<LocationTrackingController>();
    
    try {
      final snapshot = await locationController.getCurrentLocationSnapshot();
      
      final distance = _calculateDistance(
        snapshot.lat,
        snapshot.lng,
        widget.dropoffLat,
        widget.dropoffLng,
      );

      setState(() {
        _distanceToDropoffMeters = distance;
        _isAtLocation = distance <= widget.gateRadiusMeters;
        _verificationError = null;
      });
    } catch (e) {
      setState(() {
        _verificationError = 'Failed to get location: $e';
        _isAtLocation = false;
      });
    }
  }

  /**
   * Generate OTP for recipient
   */
  Future<void> _generateOtp() async {
    if (!_isAtLocation) {
      setState(() => _verificationError = 'You must be at the delivery location');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final response = await widget.authState.apiClient.post(
        '/handshake/courier/request-manual-dropoff-otp',
        body: {
          'parcelId': widget.parcelId,
          'phoneE164': '+1234567890', // Would be fetched from backend
        },
      );

      setState(() {
        _generatedOtp = response['otp'];
        _otpGenerated = true;
        _verificationError = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP generated and sent to recipient')),
      );
    } catch (e) {
      setState(() => _verificationError = 'Failed to generate OTP: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  /**
   * Capture condition photo of parcel
   */
  Future<void> _captureConditionPhoto() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() => _isUploading = true);

        try {
          final url = await widget.authState.apiClient.uploadOnboardingDocument(
            image.path,
            kind: 'delivery_photo',
          );

          setState(() {
            _photoUrl = url;
            _isUploading = false;
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo uploaded successfully')),
          );
        } catch (e) {
          setState(() {
            _verificationError = 'Photo upload failed: $e';
            _isUploading = false;
          });
        }
      }
    } catch (e) {
      setState(() => _verificationError = 'Failed to capture photo: $e');
    }
  }

  /**
   * Complete delivery with OTP and photo
   */
  Future<void> _completeDelivery() async {
    if (!_isAtLocation) {
      setState(() => _verificationError = 'Not at delivery location');
      return;
    }

    if (!_otpGenerated || _generatedOtp == null) {
      setState(() => _verificationError = 'Generate OTP first');
      return;
    }

    if (_photoUrl == null) {
      setState(() => _verificationError = 'Capture delivery photo first');
      return;
    }

    setState(() => _isCompleting = true);

    try {
      final locationSnapshot = await context
          .read<LocationTrackingController>()
          .getCurrentLocationSnapshot();

      final response = await widget.authState.apiClient.post(
        '/handshake/courier/complete-dropoff',
        body: {
          'parcelId': widget.parcelId,
          'otp': _generatedOtp,
          'photoUrl': _photoUrl,
          'lat': locationSnapshot.lat,
          'lng': locationSnapshot.lng,
          'accuracy': locationSnapshot.accuracy,
        },
      );

      if (response['status'] == 'ok') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery completed successfully!')),
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop(true);
        });
      } else {
        setState(() => _verificationError = 'Completion failed: ${response['message']}');
      }
    } catch (e) {
      setState(() => _verificationError = 'Error: $e');
    } finally {
      setState(() => _isCompleting = false);
    }
  }

  /**
   * Calculate distance using Haversine formula
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
        title: const Text('Complete Delivery'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map
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
                        point: normalizeLatLng(LatLng(widget.dropoffLat, widget.dropoffLng)),
                        radius: widget.gateRadiusMeters,
                        useRadiusInMeter: true,
                        color: dropCityActiveMint.withOpacity(0.2),
                        borderColor: dropCityActiveMint,
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
                        child: const Icon(Icons.location_on, color: dropCityActiveMint, size: 36),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Location Status
            _buildStatusCard(
              title: 'Delivery Location',
              status: _isAtLocation ? 'At Location' : 'Approaching',
              statusColor: _isAtLocation ? dropCityActiveMint : dropCityAlertAmber,
              details: [
                'Safe Zone: ${widget.gateRadiusMeters.toStringAsFixed(0)}m radius',
                if (_distanceToDropoffMeters != null)
                  'Distance: ${_distanceToDropoffMeters!.toStringAsFixed(1)}m',
              ],
            ),
            const SizedBox(height: 16),

            // Accuracy
            Consumer<LocationTrackingController>(
              builder: (context, locationController, _) {
                final accuracy = locationController.currentAccuracy;
                return _buildStatusCard(
                  title: 'GPS Accuracy',
                  status: (accuracy ?? 100) <= 30 ? 'High' : 'Low',
                  statusColor: (accuracy ?? 100) <= 30 ? dropCityActiveMint : dropCityAlertAmber,
                  details: [
                    if (accuracy != null) 'Accuracy: ±${accuracy.toStringAsFixed(1)}m',
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Step 1: Generate OTP
            _buildStepCard(
              step: 1,
              title: 'Generate Verification Code',
              completed: _otpGenerated,
              child: Column(
                children: [
                  if (!_otpGenerated)
                    ElevatedButton.icon(
                      onPressed: _isAtLocation && !_isUploading ? _generateOtp : null,
                      icon: const Icon(Icons.vpn_key),
                      label: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Generate OTP'),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: dropCityActiveMint.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Text('Code sent to recipient:', style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 8),
                          Text(
                            _generatedOtp ?? '000000',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Step 2: Capture Photo
            _buildStepCard(
              step: 2,
              title: 'Parcel Condition Photo',
              completed: _photoUrl != null,
              child: Column(
                children: [
                  if (_photoUrl == null)
                    ElevatedButton.icon(
                      onPressed: !_isUploading ? _captureConditionPhoto : null,
                      icon: const Icon(Icons.camera_alt),
                      label: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Capture Photo'),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: dropCityActiveMint.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('✓ Photo uploaded', style: TextStyle(color: dropCityActiveMint)),
                    ),
                ],
              ),
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
          ],
        ),
      ),
      floatingActionButton: (_otpGenerated && _photoUrl != null && !_isCompleting)
          ? FloatingActionButton.extended(
              onPressed: _isAtLocation ? _completeDelivery : null,
              label: const Text('Complete Delivery'),
              icon: const Icon(Icons.check),
            )
          : null,
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
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...details.map((d) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(d, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          )),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required int step,
    required String title,
    required bool completed,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: completed ? dropCityActiveMint : dropCitySlateGrey.withOpacity(0.30)),
        borderRadius: BorderRadius.circular(12),
        color: completed ? dropCityActiveMint.withOpacity(0.08) : Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: completed ? dropCityActiveMint : Colors.grey,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    completed ? '✓' : '$step',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: completed ? 18 : 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          child,
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
