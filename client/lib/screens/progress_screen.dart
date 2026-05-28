import "dart:async";
import "dart:convert";

import "package:flutter/material.dart";
import "package:geolocator/geolocator.dart";
import "dart:io";

import "package:image_picker/image_picker.dart";
import "package:latlong2/latlong.dart";
import "package:mobile_scanner/mobile_scanner.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../auth/auth_state.dart";
import "../widgets/location_preview_map.dart";

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

  static const String _prefParcelId = "progress_parcelId";
  static const String _prefPin = "progress_pin";
  static const String _prefLat = "progress_lat";
  static const String _prefLng = "progress_lng";
  static const String _prefPhotoPath = "progress_photoPath";
  static const String _prefPickupPin = "progress_pickupPin";
  static const String _prefDropoffPin = "progress_dropoffPin";

  @override
  void initState() {
    super.initState();
    _restoreFormState();
    _handleLostData();
  }

  Future<void> _handleLostData() async {
    final ImagePicker picker = ImagePicker();
    final LostDataResponse response = await picker.retrieveLostData();
    
    if (response.isEmpty) return;
    
    if (response.file != null) {
      setState(() {
        _photoPath = response.file!.path;
      });
      await _saveFormState();
    }
  }

  Future<void> _restoreFormState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      String? savedPhotoPath = prefs.getString(_prefPhotoPath);
      
      // Verify photo file actually exists
      if (savedPhotoPath != null && !File(savedPhotoPath).existsSync()) {
        savedPhotoPath = null;
        await prefs.remove(_prefPhotoPath);
      }
      
      setState(() {
        _parcelIdController.text = prefs.getString(_prefParcelId) ?? "";
        _pinController.text = prefs.getString(_prefPin) ?? "";
        _latController.text = prefs.getString(_prefLat) ?? "";
        _lngController.text = prefs.getString(_prefLng) ?? "";
        _photoPath = savedPhotoPath;
        _pickupPin = prefs.getString(_prefPickupPin);
        _dropoffPin = prefs.getString(_prefDropoffPin);
      });
    } catch (e) {
      // Ignore errors during restoration
    }
  }

  Future<void> _saveFormState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString(_prefParcelId, _parcelIdController.text),
        prefs.setString(_prefPin, _pinController.text),
        prefs.setString(_prefLat, _latController.text),
        prefs.setString(_prefLng, _lngController.text),
        if (_photoPath != null) prefs.setString(_prefPhotoPath, _photoPath!) else prefs.remove(_prefPhotoPath),
        if (_pickupPin != null) prefs.setString(_prefPickupPin, _pickupPin!) else prefs.remove(_prefPickupPin),
        if (_dropoffPin != null) prefs.setString(_prefDropoffPin, _dropoffPin!) else prefs.remove(_prefDropoffPin),
      ]);
    } catch (e) {
      // Ignore errors during save
    }
  }

  Future<void> _clearFormState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_prefParcelId),
        prefs.remove(_prefPin),
        prefs.remove(_prefLat),
        prefs.remove(_prefLng),
        prefs.remove(_prefPhotoPath),
        prefs.remove(_prefPickupPin),
        prefs.remove(_prefDropoffPin),
      ]);
    } catch (e) {
      // Ignore errors during clear
    }
  }

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
      await _saveFormState();
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
      await _clearFormState();
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
    await _saveFormState();
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (photo == null) {
      return;
    }
    if (!mounted) return;
    setState(() => _photoPath = photo.path);
    await _saveFormState();
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
                  onChanged: (_) => setState(() {}),
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
                  onChanged: (_) => setState(() {}),
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
          if (_latController.text.isNotEmpty &&
              _lngController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final lat = double.tryParse(_latController.text.trim());
                final lng = double.tryParse(_lngController.text.trim());
                final point = (lat != null && lng != null) ? LatLng(lat, lng) : null;
                return LocationPreviewMap(
                  point: point,
                  label: "Dropoff location preview",
                );
              },
            ),
          ],
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
