import "package:flutter/material.dart";
import "package:provider/provider.dart";
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import "../../../controllers/signup_controller.dart";
import "../../../theme.dart";
import "../../../widgets/dropcity_brand.dart";
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CourierSignupStep2Personal extends StatefulWidget {
    const CourierSignupStep2Personal({super.key});
    @override
    State<CourierSignupStep2Personal> createState() => _State();
}

class _State extends State<CourierSignupStep2Personal> {
    final name = TextEditingController(), phone = TextEditingController(), id = TextEditingController();
    bool uploaded = false;
    String? _idImagePath;
    final ImagePicker _picker = ImagePicker();

    @override
    void initState() {
        super.initState();
        _restoreSavedImage();
    }

    @override
    void dispose() {
        name.dispose();
        phone.dispose();
        id.dispose();
        super.dispose();
    }

    Future<void> _restoreSavedImage() async {
        try {
            final prefs = await SharedPreferences.getInstance();
            final p = prefs.getString('signup_step2_idImage');
            if (p != null && File(p).existsSync()) {
                setState(() {
                    _idImagePath = p;
                    uploaded = true;
                });
            }
        } catch (_) {}
    }

    Future<void> _pickIdImage() async {
        try {
            final XFile? file = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 85);
            if (file == null) return;
            
            // Copy temp file to persistent app storage
            final appDir = await getApplicationDocumentsDirectory();
            final fileName = 'id_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final persistentPath = p.join(appDir.path, fileName);
            await File(file.path).copy(persistentPath);
            
            setState(() {
                _idImagePath = persistentPath;
                uploaded = true;
            });
            try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('signup_step2_idImage', persistentPath);
            } catch (_) {}
        } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to capture image: $e')));
        }
    }

    Future<void> _pickFromGallery() async {
        try {
            final XFile? file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
            if (file == null) return;
            
            // Copy temp file to persistent app storage
            final appDir = await getApplicationDocumentsDirectory();
            final fileName = 'id_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final persistentPath = p.join(appDir.path, fileName);
            await File(file.path).copy(persistentPath);
            
            setState(() {
                _idImagePath = persistentPath;
                uploaded = true;
            });
            try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('signup_step2_idImage', persistentPath);
            } catch (_) {}
        } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
        }
    }

    Future<void> _removeSavedImage() async {
        try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('signup_step2_idImage');
        } catch (_) {}
        setState(() {
            _idImagePath = null;
            uploaded = false;
        });
    }

    Future<void> _showImageOptions() async {
        showModalBottomSheet<void>(
            context: context,
            builder: (ctx) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                    ListTile(
                        leading: const Icon(Icons.camera_alt),
                        title: const Text('Take Photo'),
                        onTap: () {
                            Navigator.of(ctx).pop();
                            _pickIdImage();
                        },
                    ),
                    ListTile(
                        leading: const Icon(Icons.photo_library),
                        title: const Text('Choose From Gallery'),
                        onTap: () {
                            Navigator.of(ctx).pop();
                            _pickFromGallery();
                        },
                    ),
                    if (uploaded)
                        ListTile(
                            leading: const Icon(Icons.refresh),
                            title: const Text('Retake / Replace Photo'),
                            onTap: () {
                                Navigator.of(ctx).pop();
                                _pickIdImage();
                            },
                        ),
                    if (uploaded)
                        ListTile(
                            leading: const Icon(Icons.delete_outline),
                            title: const Text('Remove Photo'),
                            onTap: () {
                                Navigator.of(ctx).pop();
                                _removeSavedImage();
                            },
                        ),
                    ListTile(
                        leading: const Icon(Icons.close),
                        title: const Text('Cancel'),
                        onTap: () => Navigator.of(ctx).pop(),
                    ),
                ]),
            ),
        );
    }

    Future<void> next() async {
        if (name.text.trim().isEmpty || id.text.trim().isEmpty || !uploaded) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Complete personal details and ID upload.")));
            return;
        }
        await context.read<CourierSignupController>().submitStep2(fullName: name.text.trim(), idNumber: id.text.trim(), idImagePath: _idImagePath ?? "");
    }

    @override
    Widget build(BuildContext context) {
        final loading = context.watch<CourierSignupController>().isLoading;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Personal Details", style: TextStyle(color: dropCitySafeSlate, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text("Your ID is used for identity verification only.", style: TextStyle(color: dropCitySlateGrey, fontSize: 11)),
            const SizedBox(height: 18),
            TextField(controller: name, decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 14),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number", hintText: "+263 7X XXX XXXX", prefixIcon: Icon(Icons.phone_outlined))),
            const SizedBox(height: 14),
            TextField(controller: id, decoration: const InputDecoration(labelText: "National ID Number", prefixIcon: Icon(Icons.badge_outlined))),
            const SizedBox(height: 18),
            DashedUploadBox(label: "Upload National ID Photo", height: 138, hasImage: uploaded, onTap: () => _pickIdImage()),
            const SizedBox(height: 10),
            if (_idImagePath != null)
                Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                    child: SizedBox(height: 120, child: Image.file(File(_idImagePath!), fit: BoxFit.contain)),
                ),
            const SizedBox(height: 12),
            CourierPrimaryButton(label: "Continue", loading: loading, onPressed: next),
        ]);
    }
}
