import "package:flutter/material.dart";
import "package:geolocator/geolocator.dart";
import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math" as math;

import "package:image_picker/image_picker.dart";
import "package:mobile_scanner/mobile_scanner.dart";
import "package:firebase_messaging/firebase_messaging.dart";

import "../auth/auth_state.dart";

class PickupModeScreen extends StatefulWidget {
  const PickupModeScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  State<PickupModeScreen> createState() => _PickupModeScreenState();
}

class _PickupModeScreenState extends State<PickupModeScreen> {
  final _parcelIdController = TextEditingController();
  final _pinController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  String? _photoPath;
  String? _pickupPointHint;

  bool _isSubmitting = false;
  bool _isLocating = false;
  bool _isLoading = false;
  StreamSubscription<Position>? _positionSub;
  double? _distanceToGate;
  Timer? _lockoutTimer;
  int? _lockoutSeconds;
  String? _currentTopic;

  @override
  void dispose() {
    _positionSub?.cancel();
    _lockoutTimer?.cancel();
    _unsubscribeTopic();
    _parcelIdController.dispose();
    _pinController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission denied.")),
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _latController.text = position.latitude.toStringAsFixed(6);
      _lngController.text = position.longitude.toStringAsFixed(6);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location error: $error")),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _submit() async {
    final parcelId = _parcelIdController.text.trim();
    final pin = _pinController.text.trim();
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    if (parcelId.isEmpty || pin.isEmpty || _photoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Parcel ID, PIN, and photo required.")),
      );
      return;
    }
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Valid lat/lng required.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final photoUrl = await widget.authState.apiClient.uploadHandshakePhoto(
        _photoPath!,
        parcelId: parcelId,
      );
      await widget.authState.apiClient.pickupHandshake(
        parcelId: parcelId,
        pin: pin,
        lat: lat,
        lng: lng,
        accuracy: await _getAccuracy(),
        photoUrl: photoUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pickup verified.")),
      );
    } catch (error) {
      _handleLockout(error.toString());
      final message = _friendlyPickupError(error.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<double?> _getAccuracy() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return position.accuracy;
    } catch (_) {
      return null;
    }
  }

  String _friendlyPickupError(String raw) {
    try {
      final start = raw.indexOf("{");
      if (start != -1) {
        final jsonText = raw.substring(start);
        final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
        if (decoded["code"] == "HANDSHAKE_PIN_LOCKED") {
          return "PIN locked. Try again soon.";
        }
        if (decoded["code"] == "HANDSHAKE_GPS_FAIL") {
          final meters = decoded["distanceMeters"];
          if (meters != null) {
            return "Outside GPS gate. You're about ${meters}m away.";
          }
          return "Outside GPS gate.";
        }
        if (decoded["error"] != null) {
          return decoded["error"].toString();
        }
      }
    } catch (_) {
      // ignore
    }
    return "Pickup error: $raw";
  }

  void _handleLockout(String raw) {
    try {
      final start = raw.indexOf("{");
      if (start != -1) {
        final jsonText = raw.substring(start);
        final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
        if (decoded["code"] == "HANDSHAKE_PIN_LOCKED" &&
            decoded["retryAfterSeconds"] != null) {
          final seconds = (decoded["retryAfterSeconds"] as num).toInt();
          _startLockout(seconds);
        }
      }
    } catch (_) {
      // ignore
    }
  }

  void _startLockout(int seconds) {
    _lockoutTimer?.cancel();
    setState(() => _lockoutSeconds = seconds);
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_lockoutSeconds == null || _lockoutSeconds! <= 1) {
        timer.cancel();
        setState(() => _lockoutSeconds = null);
      } else {
        setState(() => _lockoutSeconds = _lockoutSeconds! - 1);
      }
    });
  }

  Future<void> _loadParcel() async {
    final parcelId = _parcelIdController.text.trim();
    if (parcelId.isEmpty) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _subscribeToTopic(parcelId);
      final parcel = await widget.authState.apiClient.getParcel(parcelId);
      final pickupPoint = parcel["pickup_point"]?.toString();
      if (pickupPoint != null) {
        final match = RegExp(r"POINT\(([-\d\.]+) ([-\d\.]+)\)")
            .firstMatch(pickupPoint);
        if (match != null) {
          final lng = match.group(1);
          final lat = match.group(2);
          if (lat != null && lng != null) {
            _latController.text = double.parse(lat).toStringAsFixed(6);
            _lngController.text = double.parse(lng).toStringAsFixed(6);
            _pickupPointHint = "Pickup gate loaded";
            _startDistanceTracking();
          }
        }
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Load error: $error")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startDistanceTracking() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      final gateLat = double.tryParse(_latController.text.trim());
      final gateLng = double.tryParse(_lngController.text.trim());
      if (gateLat == null || gateLng == null) {
        return;
      }
      final meters = _distanceMeters(
        position.latitude,
        position.longitude,
        gateLat,
        gateLng,
      );
      if (mounted) {
        setState(() => _distanceToGate = meters);
      }
    });
  }

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * (math.pi / 180);
    final dLng = (lng2 - lng1) * (math.pi / 180);
    final rLat1 = lat1 * (math.pi / 180);
    final rLat2 = lat2 * (math.pi / 180);
    final sinDLat = math.sin(dLat / 2);
    final sinDLng = math.sin(dLng / 2);
    final h = sinDLat * sinDLat +
        math.cos(rLat1) * math.cos(rLat2) * sinDLng * sinDLng;
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthRadius * c;
  }

  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrScanScreen()),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _parcelIdController.text = result);
      await _subscribeToTopic(result);
      _loadParcel();
    }
  }

  Future<void> _subscribeToTopic(String parcelId) async {
    final topic = "parcel_$parcelId";
    if (_currentTopic == topic) {
      return;
    }
    await _unsubscribeTopic();
    await FirebaseMessaging.instance.subscribeToTopic(topic);
    _currentTopic = topic;
  }

  Future<void> _unsubscribeTopic() async {
    final topic = _currentTopic;
    if (topic == null) {
      return;
    }
    await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    _currentTopic = null;
  }

  Future<void> _capturePhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (photo == null) {
      return;
    }
    setState(() => _photoPath = photo.path);
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = widget.authState.isBusy || _isSubmitting || _isLocating || _isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text("Pickup Mode")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _parcelIdController,
            decoration: const InputDecoration(
              labelText: "Parcel ID",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy ? null : _scanQr,
                  child: const Text("Scan QR"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy ? null : _loadParcel,
                  child: const Text("Load Parcel"),
                ),
              ),
            ],
          ),
          if (_pickupPointHint != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _pickupPointHint!,
                style: const TextStyle(color: Colors.green),
              ),
            ),
          if (_distanceToGate != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "Distance to gate: ${_distanceToGate!.toStringAsFixed(0)} m",
                style: const TextStyle(color: Colors.blueGrey),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _pinController,
            decoration: const InputDecoration(
              labelText: "Pickup PIN",
              border: OutlineInputBorder(),
            ),
          ),
          if (_lockoutSeconds != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "PIN locked. Try again in $_lockoutSeconds s.",
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isBusy ? null : _capturePhoto,
            icon: const Icon(Icons.camera_alt),
            label: Text(_photoPath == null ? "Capture photo" : "Retake photo"),
          ),
          if (_photoPath != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(_photoPath!),
                height: 140,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latController,
                  decoration: const InputDecoration(
                    labelText: "Lat (gate)",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lngController,
                  decoration: const InputDecoration(
                    labelText: "Lng (gate)",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isBusy ? null : _useCurrentLocation,
            icon: const Icon(Icons.my_location),
            label: Text(_isLocating ? "Locating..." : "Use current location"),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: isBusy ? null : _submit,
            child: Text(isBusy ? "Submitting..." : "Verify pickup"),
          ),
        ],
      ),
    );
  }
}

class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  late MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Parcel QR")),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final code = barcodes.first.rawValue;
            if (code != null && code.isNotEmpty) {
              _controller.stop();
              Navigator.of(context).pop(code);
            }
          }
        },
      ),
    );
  }
}
