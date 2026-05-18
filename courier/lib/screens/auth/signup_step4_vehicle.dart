import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CourierSignupStep4Vehicle extends StatefulWidget {
  final Function(Map<String, dynamic> vehicleData, List<String> vehicleImagePaths)
      onComplete;
  final VoidCallback onBack;

  const CourierSignupStep4Vehicle({
    super.key,
    required this.onComplete,
    required this.onBack,
  });

  @override
  State<CourierSignupStep4Vehicle> createState() =>
      _CourierSignupStep4VehicleState();
}

class _CourierSignupStep4VehicleState extends State<CourierSignupStep4Vehicle> {
  final _formKey = GlobalKey<FormState>();
  final _registrationController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _capacityController = TextEditingController(text: '50');

  String? _selectedVehicleType;
  List<File> _vehicleImages = [];
  bool _isLoading = false;

  final ImagePicker _imagePicker = ImagePicker();
  
  final List<String> _vehicleTypes = ['Motorcycle', 'Car', 'Van', 'Truck'];

  @override
  void dispose() {
    _registrationController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      if (_vehicleImages.length < 3) {
        setState(() => _vehicleImages.add(File(pickedFile.path)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 3 images allowed')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() => _vehicleImages.removeAt(index));
  }

  void _handleComplete() {
    if (_formKey.currentState!.validate() &&
        _selectedVehicleType != null &&
        _vehicleImages.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final vehicleData = {
          'vehicle_type': _selectedVehicleType,
          'vehicle_registration': _registrationController.text.trim(),
          'vehicle_make': _makeController.text.trim(),
          'vehicle_model': _modelController.text.trim(),
          'vehicle_year': int.tryParse(_yearController.text),
          'vehicle_color': _colorController.text.trim(),
          'vehicle_capacity_kg': double.tryParse(_capacityController.text) ?? 50,
        };

        final imagePaths = _vehicleImages.map((f) => f.path).toList();
        widget.onComplete(vehicleData, imagePaths);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    } else if (_vehicleImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture vehicle photos')),
      );
    } else if (_selectedVehicleType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select vehicle type')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F3A7D)),
          onPressed: widget.onBack,
        ),
        title: const Text(
          'Vehicle Details',
          style: TextStyle(color: Color(0xFF0F3A7D), fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress indicator
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0D7A7A),
                    ),
                    child: const Center(
                      child: Text(
                        '4',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: 1.0,
                      minHeight: 4,
                      backgroundColor: Colors.grey[300],
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Color(0xFF0D7A7A)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Title
              const Text(
                'Vehicle Information',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F3A7D),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Step 4 of 4 - Final Step',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Vehicle type dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedVehicleType,
                      decoration: InputDecoration(
                        labelText: 'Vehicle Type',
                        prefixIcon: const Icon(Icons.directions_car_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: _vehicleTypes.map((type) {
                        return DropdownMenuItem(
                          value: type.toLowerCase(),
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedVehicleType = value);
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a vehicle type';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Registration number
                    TextFormField(
                      controller: _registrationController,
                      decoration: InputDecoration(
                        hintText: 'ABC-1234',
                        labelText: 'Vehicle Registration',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Registration number is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Make
                    TextFormField(
                      controller: _makeController,
                      decoration: InputDecoration(
                        hintText: 'Toyota',
                        labelText: 'Make',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Vehicle make is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Model
                    TextFormField(
                      controller: _modelController,
                      decoration: InputDecoration(
                        hintText: 'Corolla',
                        labelText: 'Model',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Vehicle model is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Year
                    TextFormField(
                      controller: _yearController,
                      decoration: InputDecoration(
                        hintText: '2023',
                        labelText: 'Year',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Year is required';
                        }
                        final year = int.tryParse(value!);
                        if (year == null || year < 1990 || year > DateTime.now().year + 1) {
                          return 'Enter a valid year';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Color
                    TextFormField(
                      controller: _colorController,
                      decoration: InputDecoration(
                        hintText: 'Blue',
                        labelText: 'Color',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Vehicle color is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Capacity
                    TextFormField(
                      controller: _capacityController,
                      decoration: InputDecoration(
                        hintText: '50',
                        labelText: 'Capacity (kg)',
                        prefixIcon: const Icon(Icons.scale_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Capacity is required';
                        }
                        if (double.tryParse(value!) == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Vehicle photos section
              Text(
                'Vehicle Photos (up to 3)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              // Photo grid
              if (_vehicleImages.isEmpty)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[50],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to add photos',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _vehicleImages.length + (_vehicleImages.length < 3 ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _vehicleImages.length) {
                          return GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[50],
                              ),
                              child: Icon(
                                Icons.add,
                                color: Colors.grey[400],
                              ),
                            ),
                          );
                        }
                        return Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(_vehicleImages[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 32),
              // Complete button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_isLoading || _vehicleImages.isEmpty)
                      ? null
                      : _handleComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D7A7A),
                    disabledBackgroundColor: Colors.grey[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Complete Signup',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
