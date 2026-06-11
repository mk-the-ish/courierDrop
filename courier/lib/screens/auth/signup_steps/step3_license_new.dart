import "package:flutter/material.dart";
import "package:provider/provider.dart";
import 'dart:io';

import "../../../controllers/signup_controller.dart";
import "../../../theme.dart";
import "../../../widgets/dropcity_brand.dart";
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CourierSignupStep3License extends StatefulWidget {
  const CourierSignupStep3License({super.key});

  @override
  State<CourierSignupStep3License> createState() => _State();
}

class _State extends State<CourierSignupStep3License> {
  final licence = TextEditingController();
  DateTime? expiry;
  final ImagePicker _picker = ImagePicker();
  String? _frontPath;
  String? _backPath;

  @override
  void initState() {
    super.initState();
    _restoreSavedImages();
  }

  @override
  void dispose() {
    licence.dispose();
    super.dispose();
  }

  Future<void> _restoreSavedImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final f = prefs.getString('signup_step3_front');
      final b = prefs.getString('signup_step3_back');
      setState(
        () {
          _frontPath = (f != null && File(f).existsSync()) ? f : null;
          _backPath = (b != null && File(b).existsSync()) ? b : null;
        },
      );
    } catch (_) {
      // Ignore errors in restoration
    }
  }

  Future<void> _pickImageFor(String side, {bool fromGallery = false}) async {
    try {
      final src = fromGallery ? ImageSource.gallery : ImageSource.camera;
      final XFile? file = await _picker.pickImage(
        source: src,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) return;

      final p = file.path;
      final prefs = await SharedPreferences.getInstance();

      if (side == 'front') {
        setState(() => _frontPath = p);
        await prefs.setString('signup_step3_front', p);
      } else {
        setState(() => _backPath = p);
        await prefs.setString('signup_step3_back', p);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image pick failed: $e')),
        );
      }
    }
  }

  Future<void> _removeImage(String side) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (side == 'front') {
        await prefs.remove('signup_step3_front');
      } else {
        await prefs.remove('signup_step3_back');
      }
    } catch (_) {
      // Ignore errors
    }
    setState(() {
      side == 'front' ? _frontPath = null : _backPath = null;
    });
  }

  Future<void> _showOptionsFor(String side) async {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImageFor(side);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose From Gallery'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImageFor(side, fromGallery: true);
              },
            ),
            if ((side == 'front' && _frontPath != null) ||
                (side == 'back' && _backPath != null))
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Retake / Replace Photo'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImageFor(side);
                },
              ),
            if ((side == 'front' && _frontPath != null) ||
                (side == 'back' && _backPath != null))
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove Photo'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _removeImage(side);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> next() async {
    if (licence.text.trim().isEmpty || _frontPath == null || _backPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Licence number plus both photos are required."),
        ),
      );
      return;
    }

    try {
      final controller = context.read<CourierSignupController>();
      final success = await controller.submitStep3(
        licenseNumber: licence.text.trim(),
        licenseImageFrontPath: _frontPath!,
        licenseImageBackPath: _backPath!,
        expiryDate: expiry,
      );

      if (!success && mounted) {
        final errorMsg = controller.errorMessage ?? "Upload failed";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<CourierSignupController>().isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Driver's Licence",
          style: TextStyle(
            color: dropCitySafeSlate,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: licence,
          decoration: const InputDecoration(
            labelText: "Licence Number",
            prefixIcon: Icon(Icons.credit_card),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: DashedUploadBox(
                label: "Front of Licence",
                height: 112,
                hasImage: _frontPath != null,
                imagePath: _frontPath,
                onTap: () => _showOptionsFor('front'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DashedUploadBox(
                label: "Back of Licence",
                height: 112,
                hasImage: _backPath != null,
                imagePath: _backPath,
                onTap: () => _showOptionsFor('back'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_month, color: dropCityTransitTeal),
          title: Text(
            expiry == null
                ? "Expiry Date"
                : expiry!.toIso8601String().split("T").first,
          ),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              firstDate: DateTime.now(),
              lastDate: DateTime(2045),
              initialDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (d != null) setState(() => expiry = d);
          },
        ),
        const SizedBox(height: 22),
        CourierPrimaryButton(
          label: "Continue",
          loading: loading,
          onPressed: next,
        ),
      ],
    );
  }
}
