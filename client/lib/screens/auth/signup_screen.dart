import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../auth/auth_state.dart";
import "../../controllers/signup_controller.dart";
import "../dashboard_screen.dart";
import "signup_step1_email.dart";
import "signup_step2_personal.dart";

class ClientSignupScreen extends StatelessWidget {
  const ClientSignupScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ClientSignupController>(
      create: (_) => ClientSignupController(
        authState: authState,
        apiClient: authState.apiClient,
      ),
      child: Consumer<ClientSignupController>(
        builder: (context, controller, _) {
          if (controller.step == 1) {
            return ClientSignupStep1Email(
              onBack: () => Navigator.of(context).pop(),
              onNext: (email, password) async {
                final ok = await controller.submitStep1(
                  email: email,
                  password: password,
                );
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(controller.error ?? "Failed to continue")),
                  );
                }
              },
            );
          }

          if (controller.step == 2) {
            return ClientSignupStep2Personal(
              onBack: controller.back,
              onComplete: (fullName, username, idNumber, idImagePath) async {
                final ok = await controller.submitStep2(
                  fullName: fullName,
                  username: username,
                  idNumber: idNumber,
                  idImagePath: idImagePath,
                );
                if (!context.mounted) return;
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(controller.error ?? "Signup failed")),
                  );
                  return;
                }
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => DashboardScreen(authState: authState),
                  ),
                  (_) => false,
                );
              },
            );
          }

          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 72),
                    const SizedBox(height: 12),
                    const Text("Account created successfully."),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => DashboardScreen(authState: authState),
                        ),
                        (_) => false,
                      ),
                      child: const Text("Continue"),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
