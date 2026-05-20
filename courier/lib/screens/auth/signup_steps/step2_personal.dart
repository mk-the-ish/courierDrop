import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../controllers/signup_controller.dart';
import '../../../theme.dart';

class CourierSignupStep2Personal extends StatefulWidget {
  const CourierSignupStep2Personal({Key? key}) : super(key: key);

  @override
  State<CourierSignupStep2Personal> createState() =>
      _CourierSignupStep2PersonalState();
}

class _CourierSignupStep2PersonalState
    extends State<CourierSignupStep2Personal> {
  final _fullNameController = TextEditingController();
  final _idNumberController = TextEditingController();
  String? _selectedIdImage;
  String? _nameError;
  String? _idError;
  String? _imageError;
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _fullNameController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    setState(() {
      _nameError = null;
      _idError = null;
      _imageError = null;
    });

    bool isValid = true;

    if (_fullNameController.text.isEmpty) {
      setState(() => _nameError = 'Full name is required');
      isValid = false;
    } else if (_fullNameController.text.length < 3) {
      setState(() => _nameError = 'Name must be at least 3 characters');
      isValid = false;
    }

    if (_idNumberController.text.isEmpty) {
      setState(() => _idError = 'ID number is required');
      isValid = false;
    }

    if (_selectedIdImage == null) {
      setState(() => _imageError = 'Please upload your ID image');
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
          _selectedIdImage = pickedFile.path;
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
    final success = await controller.submitStep2(
      fullName: _fullNameController.text,
      idNumber: _idNumberController.text,
      idImagePath: _selectedIdImage!,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(controller.errorMessage ?? 'Failed to upload ID'),
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

          // Full Name field
          TextField(
            controller: _fullNameController,
            style: const TextStyle(color: dropCityTextLight),
            decoration: InputDecoration(
              labelText: 'Full Name',
              labelStyle: const TextStyle(color: dropCityTextGrey),
              errorText: _nameError,
              errorStyle: const TextStyle(color: dropCityErrorRed),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(dropCityBorderRadius),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(dropCityBorderRadius),
                borderSide: const BorderSide(
                  color: dropCityOrangeAccent,
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(dropCityBorderRadius),
                borderSide: const BorderSide(color: dropCityInputBorder),
              ),
              prefixIcon: const Icon(
                Icons.person_outline,
                color: dropCityOrangeAccent,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ID Number field
          TextField(
            controller: _idNumberController,
            keyboardType: TextInputType.text,
            style: const TextStyle(color: dropCityTextLight),
            decoration: InputDecoration(
              labelText: 'National ID Number',
              labelStyle: const TextStyle(color: dropCityTextGrey),
              errorText: _idError,
              errorStyle: const TextStyle(color: dropCityErrorRed),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(dropCityBorderRadius),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(dropCityBorderRadius),
                borderSide: const BorderSide(
                  color: dropCityOrangeAccent,
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(dropCityBorderRadius),
                borderSide: const BorderSide(color: dropCityInputBorder),
              ),
              prefixIcon: const Icon(
                Icons.badge_outlined,
                color: dropCityOrangeAccent,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ID Image upload section
          Text(
            'Upload ID Image',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          if (_selectedIdImage != null)
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(dropCityBorderRadius),
                border: Border.all(color: dropCityOrangeAccent, width: 2),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(_selectedIdImage!),
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
                          setState(() => _selectedIdImage = null);
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
                  borderRadius: BorderRadius.circular(dropCityBorderRadius),
                  border: Border.all(
                    color: dropCityInputBorder,
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
                      color: dropCityOrangeAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tap to take a photo',
                      style: const TextStyle(
                        color: dropCityTextGrey,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Use clear, well-lit photo',
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
                    backgroundColor: dropCityOrangeAccent,
                    disabledBackgroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(dropCityBorderRadius),
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
