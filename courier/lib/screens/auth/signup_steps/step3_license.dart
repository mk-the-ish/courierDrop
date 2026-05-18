import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../controllers/signup_controller.dart';

class CourierSignupStep3License extends StatefulWidget {
  const CourierSignupStep3License({Key? key}) : super(key: key);

  @override
  State<CourierSignupStep3License> createState() =>
      _CourierSignupStep3LicenseState();
}

class _CourierSignupStep3LicenseState extends State<CourierSignupStep3License> {
  final _licenseNumberController = TextEditingController();
  String? _selectedLicenseImage;
  String? _licenseNumberError;
  String? _imageError;
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _licenseNumberController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    setState(() {
      _licenseNumberError = null;
      _imageError = null;
    });

    bool isValid = true;

    if (_licenseNumberController.text.isEmpty) {
      setState(() => _licenseNumberError = 'License number is required');
      isValid = false;
    }

    if (_selectedLicenseImage == null) {
      setState(() => _imageError = 'Please upload your license image');
      isValid = false;
    }

    return isValid;
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedLicenseImage = pickedFile.path;
          _imageError = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleNext() async {
    if (!_validateInputs()) {
      return;
    }

    final controller = context.read<CourierSignupController>();
    final success = await controller.submitStep3(
      licenseNumber: _licenseNumberController.text,
      licenseImagePath: _selectedLicenseImage!,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              controller.errorMessage ?? 'Failed to upload license'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),

          // License Number field
          TextField(
            controller: _licenseNumberController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Driving License Number',
              labelStyle: TextStyle(color: Colors.grey[400]),
              errorText: _licenseNumberError,
              errorStyle: const TextStyle(color: Color(0xFFEF5350)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFFF6B35),
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              prefixIcon: const Icon(
                Icons.card_travel_outlined,
                color: Color(0xFFFF6B35),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // License Image upload section
          Text(
            'Upload License Image',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          if (_selectedLicenseImage != null)
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF6B35), width: 2),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(_selectedLicenseImage!),
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.7),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() => _selectedLicenseImage = null);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey[700]!,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  color: Colors.grey[900]?.withOpacity(0.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      size: 48,
                      color: Color(0xFFFF6B35),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tap to take a photo',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Upload front or back of license',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_imageError != null) ...[
            const SizedBox(height: 8),
            Text(
              _imageError!,
              style: const TextStyle(
                color: Color(0xFFEF5350),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 32),

          // Next button
          Consumer<CourierSignupController>(
            builder: (context, controller, _) {
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: controller.isLoading ? null : _handleNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    disabledBackgroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: controller.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Next',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                  ),
              );
            },
          ),
        ],
      ),
    );
  }
}
