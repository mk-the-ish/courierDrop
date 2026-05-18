import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/signup_controller.dart';
import './signup_steps/step1_email.dart';
import './signup_steps/step2_personal.dart';
import './signup_steps/step3_license.dart';
import './signup_steps/step4_vehicle.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1a1a2e),
              const Color(0xFF16213e),
            ],
          ),
        ),
        child: Consumer<CourierSignupController>(
          builder: (context, controller, _) {
            return Stack(
              children: [
                // Content based on step
                SingleChildScrollView(
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          // Progress indicator
                          _buildProgressIndicator(controller),
                          const SizedBox(height: 32),
                          // Step content
                          _buildStepContent(controller),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),

                // Back button in top-left
                if (controller.currentStep > 1)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 12,
                    left: 12,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        controller.goBack();
                      },
                    ),
                  ),

                // Close button (X) in top-right to close signup
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  right: 12,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(CourierSignupController controller) {
    const steps = 4;
    const stepNames = ['Email', 'Personal', 'License', 'Vehicle'];

    return Column(
      children: [
        // Step number and title
        Text(
          'Step ${controller.currentStep} of $steps',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[400],
              ),
        ),
        const SizedBox(height: 8),
        Text(
          stepNames[controller.currentStep - 1],
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 20),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: controller.currentStep / steps,
            minHeight: 8,
            backgroundColor: Colors.grey[700],
            valueColor: AlwaysStoppedAnimation<Color>(
              const Color(0xFFFF6B35),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent(CourierSignupController controller) {
    switch (controller.currentStep) {
      case 1:
        return const CourierSignupStep1Email();
      case 2:
        return const CourierSignupStep2Personal();
      case 3:
        return const CourierSignupStep3License();
      case 4:
        return const CourierSignupStep4Vehicle();
      case 5:
        return _buildCompletionScreen();
      default:
        return const SizedBox();
    }
  }

  Widget _buildCompletionScreen() {
    return Column(
      children: [
        const SizedBox(height: 60),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF4CAF50),
                const Color(0xFF66BB6A),
              ],
            ),
          ),
          child: const Icon(
            Icons.check,
            size: 60,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Welcome to DropCity!',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Your profile has been created successfully.\nYou\'re ready to start delivering!',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[400],
                height: 1.5,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 60),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed('/dashboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Go to Dashboard',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}
