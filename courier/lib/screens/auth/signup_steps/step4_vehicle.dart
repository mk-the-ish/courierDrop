import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../controllers/signup_controller.dart';
import '../../../theme.dart';

class CourierSignupStep4Vehicle extends StatefulWidget {
  const CourierSignupStep4Vehicle({Key? key}) : super(key: key);

  @override
  State<CourierSignupStep4Vehicle> createState() =>
      _CourierSignupStep4VehicleState();
}

class _CourierSignupStep4VehicleState extends State<CourierSignupStep4Vehicle> {
  final _vehicleRegistrationController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _vehicleMakeController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _vehicleCapacityController = TextEditingController();
  final List<String> _vehicleImages = [];
  String? _vehicleTypeError;
  String? _registrationError;
  String? _capacityError;
  String? _imageError;
  final _imagePicker = ImagePicker();

  final vehicleTypes = ['Motorcycle', 'Scooter', 'Car', 'Van', 'Truck'];

  @override
  void dispose() {
    _vehicleRegistrationController.dispose();
    _vehicleTypeController.dispose();
    _vehicleMakeController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehicleColorController.dispose();
    _vehicleCapacityController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    setState(() {
      _vehicleTypeError = null;
      _registrationError = null;
      _capacityError = null;
      _imageError = null;
    });

    bool isValid = true;

    if (_vehicleTypeController.text.isEmpty) {
      setState(() => _vehicleTypeError = 'Please select vehicle type');
      isValid = false;
    }

    if (_vehicleRegistrationController.text.isEmpty) {
      setState(() => _registrationError = 'Registration number is required');
      isValid = false;
    }

    if (_vehicleCapacityController.text.isEmpty) {
      setState(() => _capacityError = 'Capacity is required');
      isValid = false;
    } else if (double.tryParse(_vehicleCapacityController.text) == null) {
      setState(() => _capacityError = 'Please enter a valid number');
      isValid = false;
    }

    if (_vehicleImages.isEmpty) {
      setState(
          () => _imageError = 'Please upload at least one vehicle image');
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
        if (_vehicleImages.length < 3) {
          setState(() {
            _vehicleImages.add(pickedFile.path);
            _imageError = null;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 3 images allowed'),
              backgroundColor: dropCityErrorRed,
            ),
          );
        }
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

  Future<void> _handleSubmit() async {
    if (!_validateInputs()) {
      return;
    }

    final vehicleData = {
      'vehicle_registration': _vehicleRegistrationController.text,
      'vehicle_type': _vehicleTypeController.text,
      'vehicle_make': _vehicleMakeController.text,
      'vehicle_model': _vehicleModelController.text,
      'vehicle_year': _vehicleYearController.text,
      'vehicle_color': _vehicleColorController.text,
      'vehicle_capacity_kg': _vehicleCapacityController.text,
    };

    final controller = context.read<CourierSignupController>();
    final success = await controller.submitStep4(
      vehicleData: vehicleData,
      vehicleImagePaths: _vehicleImages,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(controller.errorMessage ?? 'Failed to save vehicle info'),
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

          // Vehicle Type dropdown
          DropdownButtonFormField<String>(
            value: _vehicleTypeController.text.isEmpty
                ? null
                : _vehicleTypeController.text,
            items: vehicleTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _vehicleTypeController.text = value ?? '');
            },
            style: const TextStyle(color: dropCityTextLight),
            dropdownColor: dropCityDarkGradientEnd,
            decoration: InputDecoration(
              labelText: 'Vehicle Type',
              labelStyle: const TextStyle(color: dropCityTextGrey),
              errorText: _vehicleTypeError,
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
            ),
          ),
          const SizedBox(height: 16),

          // Vehicle Registration
          TextField(
            controller: _vehicleRegistrationController,
            style: const TextStyle(color: dropCityTextLight),
            decoration: InputDecoration(
              labelText: 'Registration Number',
              labelStyle: const TextStyle(color: dropCityTextGrey),
              errorText: _registrationError,
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
            ),
          ),
          const SizedBox(height: 16),

          // Vehicle Make and Model row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _vehicleMakeController,
                  style: const TextStyle(color: dropCityTextLight),
                  decoration: InputDecoration(
                    labelText: 'Make',
                    labelStyle: const TextStyle(color: dropCityTextGrey),
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
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _vehicleModelController,
                  style: const TextStyle(color: dropCityTextLight),
                  decoration: InputDecoration(
                    labelText: 'Model',
                    labelStyle: const TextStyle(color: dropCityTextGrey),
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
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Year and Color row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _vehicleYearController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: dropCityTextLight),
                  decoration: InputDecoration(
                    labelText: 'Year',
                    labelStyle: const TextStyle(color: dropCityTextGrey),
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
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _vehicleColorController,
                  style: const TextStyle(color: dropCityTextLight),
                  decoration: InputDecoration(
                    labelText: 'Color',
                    labelStyle: const TextStyle(color: dropCityTextGrey),
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
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Vehicle Capacity
          TextField(
            controller: _vehicleCapacityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: dropCityTextLight),
            decoration: InputDecoration(
              labelText: 'Capacity (kg)',
              labelStyle: const TextStyle(color: dropCityTextGrey),
              errorText: _capacityError,
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
            ),
          ),
          const SizedBox(height: 24),

          // Vehicle Images
          Text(
            'Vehicle Images (${_vehicleImages.length}/3)',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          if (_vehicleImages.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _vehicleImages.length,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(dropCityBorderRadius),
                    border: Border.all(
                      color: dropCityOrangeAccent,
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(_vehicleImages[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(
                              () => _vehicleImages.removeAt(index),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.7),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          if (_vehicleImages.length < 3) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 120,
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
                      Icons.add_a_photo_outlined,
                      size: 40,
                      color: dropCityOrangeAccent,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add Photo',
                      style: const TextStyle(
                        color: dropCityTextGrey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

          // Submit button
          Consumer<CourierSignupController>(
            builder: (context, controller, _) {
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: controller.isLoading ? null : _handleSubmit,
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
                          'Complete Profile',
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
