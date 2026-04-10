import "dart:async";
import "dart:convert";

import "package:flutter/material.dart";
import "package:geolocator/geolocator.dart";
import "dart:io";

import "package:image_picker/image_picker.dart";
import "package:mobile_scanner/mobile_scanner.dart";

import "../auth/auth_state.dart";

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _parcelIdController = TextEditingController();
  final _pinController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  String? _photoPath;

  bool _isSubmitting = false;
  bool _isLocating = false;
  String? _pickupPin;
  String? _dropoffPin;
  bool _pickupUsed = false;
  bool _dropoffUsed = false;
  Timer? _lockoutTimer;
  int? _lockoutSeconds;

  @override
  void dispose() {
    _lockoutTimer?.cancel();
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

  Future<void> _initHandshake() async {
    final parcelId = _parcelIdController.text.trim();
    if (parcelId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Parcel ID required.")),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final response =
          await widget.authState.apiClient.initHandshake(parcelId);
      if (!mounted) return;
      setState(() {
        _pickupPin = response["pickupPin"]?.toString();
        _dropoffPin = response["dropoffPin"]?.toString();
        _pickupUsed = false;
        _dropoffUsed = false;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Init error: $error")),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _dropoff() async {
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
      await widget.authState.apiClient.dropoffHandshake(
        parcelId: parcelId,
        pin: pin,
        lat: lat,
        lng: lng,
        accuracy: await _getAccuracy(),
        photoUrl: photoUrl,
      );
      if (!mounted) return;
      setState(() {
        _pickupPin = null;
        _pickupUsed = true;
        _dropoffPin = null;
        _dropoffUsed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Dropoff verified.")),
      );
    } catch (error) {
      _handleLockout(error.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Dropoff error: $error")),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _capturePhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (photo == null) {
      return;
    }
    setState(() => _photoPath = photo.path);
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

  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrScanScreen()),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _parcelIdController.text = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = widget.authState.isBusy || _isSubmitting || _isLocating;
    return Scaffold(
      appBar: AppBar(title: const Text("Progress / Dropoff")),
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
          OutlinedButton(
            onPressed: isBusy ? null : _scanQr,
            child: const Text("Scan Parcel QR"),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy ? null : _initHandshake,
                  child: const Text("Generate PINs"),
                ),
              ),
            ],
          ),
          if (_pickupPin != null || _dropoffPin != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "Pickup PIN: ${_pickupUsed ? "***" : (_pickupPin ?? "-")} | "
                "Dropoff PIN: ${_dropoffUsed ? "***" : (_dropoffPin ?? "-")}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 20),
          TextField(
            controller: _pinController,
            decoration: const InputDecoration(
              labelText: "Dropoff PIN",
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
                    labelText: "Lat",
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
                    labelText: "Lng",
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
            onPressed: isBusy ? null : _dropoff,
            child: Text(isBusy ? "Submitting..." : "Verify dropoff"),
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
