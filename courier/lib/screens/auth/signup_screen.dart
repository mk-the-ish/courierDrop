import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../controllers/signup_controller.dart";
import "../../theme.dart";
import "../../widgets/dropcity_brand.dart";
import "signup_steps/step1_email.dart";
import "signup_steps/step2_personal.dart";
import "signup_steps/step3_license.dart";
import "signup_steps/step4_vehicle.dart";

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CourierSignupController>(
      builder: (context, controller, _) {
        if (controller.currentStep == 5) return const _SignupCompleteScreen();
        return Scaffold(
          backgroundColor: dropCityCloudWhite,
          appBar: AppBar(
            leading: IconButton(
              onPressed: controller.currentStep > 1 ? controller.goBack : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
            ),
            title: const Text("Courier Signup"),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                CourierStepBar(step: controller.currentStep, total: 4),
                const SizedBox(height: 22),
                _stepContent(controller.currentStep),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _stepContent(int step) {
    switch (step) {
      case 1: return const CourierSignupStep1Email();
      case 2: return const CourierSignupStep2Personal();
      case 3: return const CourierSignupStep3License();
      case 4: return const CourierSignupStep4Vehicle();
      default: return const SizedBox.shrink();
    }
  }
}

class _SignupCompleteScreen extends StatelessWidget {
  const _SignupCompleteScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dropCityCloudWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(radius: 44, backgroundColor: dropCityActiveMint, child: Icon(Icons.check, color: Colors.white, size: 52)),
              const SizedBox(height: 24),
              const Text("Submitted for Approval", textAlign: TextAlign.center, style: TextStyle(color: dropCitySafeSlate, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              const Text("Your vehicle will be reviewed by DropCity admin before your first delivery.", textAlign: TextAlign.center, style: TextStyle(color: dropCitySlateGrey, height: 1.5)),
              const SizedBox(height: 30),
              CourierPrimaryButton(label: "Return to Home", onPressed: () => Navigator.of(context).pushReplacementNamed("/dashboard")),
            ],
          ),
        ),
      ),
    );
  }
}
