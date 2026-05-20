import "dart:io";

import "package:flutter/material.dart";
import "package:geolocator/geolocator.dart";
import "package:image_picker/image_picker.dart";

import "../auth/auth_state.dart";

class RecipientHandoffScreen extends StatefulWidget {
  const RecipientHandoffScreen({
    super.key,
    required this.authState,
    required this.parcelId,
  });

  final AuthState authState;
  final String parcelId;

  @override
  State<RecipientHandoffScreen> createState() => _RecipientHandoffScreenState();
}

class _RecipientHandoffScreenState extends State<RecipientHandoffScreen> {
  final _picker = ImagePicker();
  String? _photoPath;
  bool _submitting = false;
  String? _otp;
  String? _expiresAt;
  double? _lat;
  double? _lng;

  Future<void> _capturePhoto() async {
    final image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (image == null) return;
    setState(() => _photoPath = image.path);
  }

  Future<void> _issueOtp() async {
    if (_photoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Capture a recipient confirmation photo first.")),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception("Location permission denied");
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _lat = pos.latitude;
      _lng = pos.longitude;

      // Upload recipient confirmation photo for traceability.
      await widget.authState.apiClient.uploadHandshakePhoto(
        _photoPath!,
        parcelId: widget.parcelId,
      );

      final resp = await widget.authState.apiClient.recipientIssueDropoffOtp(
        parcelId: widget.parcelId,
        lat: _lat!,
        lng: _lng!,
      );
      setState(() {
        _otp = resp["dropoffOtp"]?.toString();
        _expiresAt = resp["expiresAt"]?.toString();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not generate PIN: $e")),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recipient Handoff")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Confirm receipt and generate handoff PIN",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Take a quick confirmation photo, then generate a PIN for the courier.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _capturePhoto,
            icon: const Icon(Icons.camera_alt),
            label: Text(_photoPath == null ? "Capture confirmation photo" : "Retake photo"),
          ),
          if (_photoPath != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(_photoPath!),
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submitting ? null : _issueOtp,
            child: Text(_submitting ? "Generating..." : "Generate PIN"),
          ),
          if (_otp != null) ...[
            const SizedBox(height: 20),
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "PIN generated",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _otp!,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text("Expires: ${_expiresAt ?? "-"}"),
                    if (_lat != null && _lng != null)
                      Text("Location: ${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}"),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
