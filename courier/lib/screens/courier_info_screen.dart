import "package:flutter/material.dart";

import "../auth/auth_state.dart";

class CourierInfoScreen extends StatefulWidget {
  const CourierInfoScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  State<CourierInfoScreen> createState() => _CourierInfoScreenState();
}

class _CourierInfoScreenState extends State<CourierInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleTypeController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _licensePlateController = TextEditingController();
  final _maxCapacityController = TextEditingController();

  bool _isSubmitting = false;
  String? _selectedVehicleType;

  @override
  void dispose() {
    _vehicleTypeController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _licensePlateController.dispose();
    _maxCapacityController.dispose();
    super.dispose();
  }

  Future<void> _submitVehicleInfo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final year = int.tryParse(_yearController.text.trim());
      final maxCapacity = int.tryParse(_maxCapacityController.text.trim());

      if (year == null || maxCapacity == null) {
        throw Exception("Year and capacity must be valid numbers");
      }

      await widget.authState.apiClient.submitVehicleInfo(
        vehicleType: _selectedVehicleType!,
        make: _makeController.text.trim(),
        model: _modelController.text.trim(),
        year: year,
        color: _colorController.text.trim(),
        licensePlate: _licensePlateController.text.trim(),
        maxCapacityKg: maxCapacity,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Vehicle information saved!")),
      );

      // Navigate to dashboard and replace the entire HomeScreen stack
      if (mounted) {
        Navigator.of(context).pushReplacementNamed("/");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Complete Your Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Vehicle Information",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Tell us about your delivery vehicle so we can match parcels appropriately.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedVehicleType,
                decoration: const InputDecoration(
                  labelText: "Vehicle Type",
                  hintText: "Select vehicle type",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.directions_car),
                ),
                items: const [
                  DropdownMenuItem(value: "motorcycle", child: Text("Motorcycle")),
                  DropdownMenuItem(value: "bicycle", child: Text("Bicycle")),
                  DropdownMenuItem(value: "scooter", child: Text("Scooter")),
                  DropdownMenuItem(value: "car", child: Text("Car")),
                  DropdownMenuItem(value: "van", child: Text("Van")),
                  DropdownMenuItem(value: "truck", child: Text("Truck")),
                ],
                onChanged: (value) => setState(() => _selectedVehicleType = value),
                validator: (value) => value == null ? "Please select a vehicle type" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _makeController,
                decoration: const InputDecoration(
                  labelText: "Make/Brand",
                  hintText: "e.g., Honda, Toyota, Ford",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? "Please enter vehicle make" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: "Model",
                  hintText: "e.g., CR-V, Corolla, Transit",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? "Please enter vehicle model" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Year",
                  hintText: "e.g., 2022",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.date_range),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Please enter vehicle year";
                  final year = int.tryParse(value);
                  if (year == null || year < 1900 || year > 2100) {
                    return "Please enter a valid year";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _colorController,
                decoration: const InputDecoration(
                  labelText: "Color",
                  hintText: "e.g., White, Black, Blue",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.palette),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _licensePlateController,
                decoration: const InputDecoration(
                  labelText: "License Plate",
                  hintText: "e.g., ABC 123",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? "Please enter license plate"
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxCapacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Max Capacity (kg)",
                  hintText: "e.g., 50",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.scale),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter maximum capacity";
                  }
                  final capacity = int.tryParse(value);
                  if (capacity == null || capacity <= 0) {
                    return "Please enter a valid capacity";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitVehicleInfo,
                  child: Text(
                    _isSubmitting ? "Saving..." : "Continue to Dashboard",
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pushReplacementNamed("/"),
                  child: const Text("Skip for now"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
