import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../controllers/onboarding_controller.dart';
import '../auth/auth_state.dart';

class ClientOnboardingScreen extends StatefulWidget {
  final AuthState authState;

  const ClientOnboardingScreen({
    super.key,
    required this.authState,
  });

  @override
  State<ClientOnboardingScreen> createState() => _ClientOnboardingScreenState();
}

class _ClientOnboardingScreenState extends State<ClientOnboardingScreen> {
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

  Future<void> _uploadDocument(String filePath) async {
    final controller = context.read<ClientOnboardingController>();
    controller.setLoading(true);
    try {
      final url = await widget.authState.apiClient.uploadOnboardingDocument(
        filePath,
        kind: 'id',
      );
      controller.setIdDocumentUrl(url);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID document uploaded successfully')),
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
    final controller = context.read<ClientOnboardingController>();
    
    if (!controller.isStep2Valid) {
      controller.setError('Please complete all steps');
      return;
    }

    controller.setLoading(true);
    try {
      // Update profile
      await widget.authState.apiClient.patchOnboardingProfile(
        displayName: controller.displayName,
        phoneNumber: null,
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
      create: (_) => ClientOnboardingController(),
      child: Consumer<ClientOnboardingController>(
        builder: (context, controller, _) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Client Onboarding'),
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
              ],
            ),
            floatingActionButton: _buildFAB(context, controller),
            bottomNavigationBar: _buildBottomNav(context, controller),
          );
        },
      ),
    );
  }

  Widget _buildStep1(BuildContext context, ClientOnboardingController controller) {
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
              labelText: 'Username',
              border: OutlineInputBorder(),
              hintText: 'Choose a unique username',
            ),
            onChanged: (value) => controller.updateBio(usernameVal: value),
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

  Widget _buildStep2(BuildContext context, ClientOnboardingController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Step 2: ID Verification',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextField(
            decoration: const InputDecoration(
              labelText: 'ID Number',
              border: OutlineInputBorder(),
              hintText: 'e.g., National ID or Passport',
            ),
            onChanged: (value) => controller.updateId(number: value),
          ),
          const SizedBox(height: 24),
          const Text('ID Document Photo', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (controller.idDocumentUrl != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('✓ ID document uploaded', style: TextStyle(color: Colors.green)),
            )
          else
            ElevatedButton.icon(
              onPressed: () => _pickImage((path) {
                controller.updateId(docPath: path);
                _uploadDocument(path);
              }),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture ID Photo'),
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

  Widget? _buildFAB(BuildContext context, ClientOnboardingController controller) {
    if (controller.currentStep == 1) {
      return FloatingActionButton(
        onPressed: controller.isStep2Valid && !controller.isLoading
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

  Widget _buildBottomNav(BuildContext context, ClientOnboardingController controller) {
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
            'Step ${controller.currentStep + 1}/2',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (controller.currentStep < 1)
            ElevatedButton(
              onPressed: controller.isStep1Valid
                  ? () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  : null,
              child: const Text('Next'),
            )
          else
            const SizedBox(width: 100),
        ],
      ),
    );
  }
}
