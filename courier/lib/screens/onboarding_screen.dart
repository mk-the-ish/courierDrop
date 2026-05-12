import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../controllers/onboarding_controller.dart';
import '../auth/auth_state.dart';
import '../api/api_client.dart';

class CourierOnboardingScreen extends StatefulWidget {
  final AuthState authState;

  const CourierOnboardingScreen({
    super.key,
    required this.authState,
  });

  @override
  State<CourierOnboardingScreen> createState() => _CourierOnboardingScreenState();
}

class _CourierOnboardingScreenState extends State<CourierOnboardingScreen> {
  late PageController _pageController;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(Function(String) callback) async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image != null) {
        callback(image.path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _uploadDocument(String filePath, String kind) async {
    final controller = context.read<CourierOnboardingController>();
    controller.setLoading(true);
    try {
      final url = await widget.authState.apiClient.uploadOnboardingDocument(
        filePath,
        kind: kind,
      );
      
      if (kind == 'id') {
        controller.setDocumentUrls(idUrl: url);
      } else if (kind == 'license') {
        controller.setDocumentUrls(licenseUrl: url);
      } else if (kind == 'vehicle') {
        controller.setVehicleDocumentUrl(url);
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document uploaded successfully')),
      );
    } catch (e) {
      controller.setError('Upload failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      controller.setLoading(false);
    }
  }

  Future<void> _submitOnboarding() async {
    final controller = context.read<CourierOnboardingController>();
    
    if (!controller.isStep3Valid) {
      controller.setError('Please complete all steps');
      return;
    }

    controller.setLoading(true);
    try {
      // Update profile
      await widget.authState.apiClient.patchOnboardingProfile(
        displayName: controller.displayName,
        phoneNumber: controller.phoneNumber,
      );

      controller.markSubmitted();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Onboarding submitted. Awaiting admin approval.')),
      );
      
      // Navigate back or to dashboard
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop();
      });
    } catch (e) {
      controller.setError('Submission failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      controller.setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CourierOnboardingController(),
      child: Consumer<CourierOnboardingController>(
        builder: (context, controller, _) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Courier Onboarding'),
              centerTitle: true,
            ),
            body: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                controller.goToStep(index);
              },
              children: [
                _buildStep1(context, controller),
                _buildStep2(context, controller),
                _buildStep3(context, controller),
              ],
            ),
            floatingActionButton: _buildFAB(context, controller),
            bottomNavigationBar: _buildBottomNav(context, controller),
          );
        },
      ),
    );
  }

  Widget _buildStep1(BuildContext context, CourierOnboardingController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Step 1: Bio Information',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
              hintText: 'Enter your full name',
            ),
            onChanged: (value) => controller.updateBio(name: value),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(),
              hintText: '+263 77 XXX XXXX',
            ),
            onChanged: (value) => controller.updateBio(phone: value),
          ),
          const SizedBox(height: 32),
          if (controller.error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                controller.error!,
                style: TextStyle(color: Colors.red.shade900),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep2(BuildContext context, CourierOnboardingController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Step 2: ID & License Documents',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text('ID Document', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (controller.idDocumentUrl != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('✓ ID Document uploaded', style: TextStyle(color: Colors.green)),
            )
          else
            ElevatedButton.icon(
              onPressed: () => _pickImage((path) {
                controller.updateDocuments(idPath: path);
                _uploadDocument(path, 'id');
              }),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture ID Photo'),
            ),
          const SizedBox(height: 24),
          const Text('License Document', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (controller.licenseDocumentUrl != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('✓ License uploaded', style: TextStyle(color: Colors.green)),
            )
          else
            ElevatedButton.icon(
              onPressed: () => _pickImage((path) {
                controller.updateDocuments(licensePath: path);
                _uploadDocument(path, 'license');
              }),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture License Photo'),
            ),
          const SizedBox(height: 32),
          if (controller.error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                controller.error!,
                style: TextStyle(color: Colors.red.shade900),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep3(BuildContext context, CourierOnboardingController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Step 3: Vehicle Details',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Vehicle Type',
              border: OutlineInputBorder(),
              hintText: 'e.g., Motorcycle, Car, Truck',
            ),
            onChanged: (value) => controller.updateVehicle(type: value),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Make',
                    border: OutlineInputBorder(),
                    hintText: 'Toyota',
                  ),
                  onChanged: (value) => controller.updateVehicle(make: value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    border: OutlineInputBorder(),
                    hintText: 'Corolla',
                  ),
                  onChanged: (value) => controller.updateVehicle(model: value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'License Plate',
              border: OutlineInputBorder(),
              hintText: 'ABC123',
            ),
            onChanged: (value) => controller.updateVehicle(plate: value),
          ),
          const SizedBox(height: 16),
          const Text('Vehicle Document', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (controller.vehicleDocumentUrl != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('✓ Vehicle document uploaded', style: TextStyle(color: Colors.green)),
            )
          else
            ElevatedButton.icon(
              onPressed: () => _pickImage((path) {
                controller.updateVehicle();
                _uploadDocument(path, 'vehicle');
              }),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture Vehicle Document'),
            ),
          const SizedBox(height: 32),
          if (controller.error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                controller.error!,
                style: TextStyle(color: Colors.red.shade900),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _buildFAB(BuildContext context, CourierOnboardingController controller) {
    if (controller.currentStep == 2) {
      return FloatingActionButton(
        onPressed: controller.isStep3Valid && !controller.isLoading
            ? _submitOnboarding
            : null,
        child: controller.isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check),
      );
    }
    return null;
  }

  Widget _buildBottomNav(BuildContext context, CourierOnboardingController controller) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (controller.currentStep > 0)
            OutlinedButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: const Text('Back'),
            )
          else
            const SizedBox(width: 100),
          Text(
            'Step ${controller.currentStep + 1}/3',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (controller.currentStep < 2)
            ElevatedButton(
              onPressed: controller.currentStep == 0
                  ? (controller.isStep1Valid ? () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } : null)
                  : (controller.isStep2Valid ? () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } : null),
              child: const Text('Next'),
            )
          else
            const SizedBox(width: 100),
        ],
      ),
    );
  }
}
