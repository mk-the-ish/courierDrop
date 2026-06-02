import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../auth/auth_state.dart";
import "../../controllers/signup_controller.dart";
import "../../theme.dart";
import "../../widgets/dropcity_brand.dart";
import "../dashboard_screen.dart";
import "courier_app_redirect_screen.dart";
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
          if (controller.step == -1) {
            return CourierAppRedirectScreen(onBack: controller.back);
          }

          if (controller.step == 0) {
            return _SignupChoiceScreen(
              onBack: () => Navigator.of(context).pop(),
              onClient: controller.chooseClientAccount,
              onCourier: controller.chooseCourierAccount,
            );
          }

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
                    const Icon(Icons.check_circle, color: dropCityActiveMint, size: 72),
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

class _SignupChoiceScreen extends StatefulWidget {
  const _SignupChoiceScreen({
    required this.onBack,
    required this.onClient,
    required this.onCourier,
  });

  final VoidCallback onBack;
  final VoidCallback onClient;
  final VoidCallback onCourier;

  @override
  State<_SignupChoiceScreen> createState() => _SignupChoiceScreenState();
}

class _SignupChoiceScreenState extends State<_SignupChoiceScreen> {
  String? _choice;

  @override
  Widget build(BuildContext context) {
    final canContinue = _choice != null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text("Create Account"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StepDots(activeIndex: 0, count: 3),
              const SizedBox(height: 32),
              const Text(
                "Choose how to join",
                style: TextStyle(
                  color: dropCitySafeSlate,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              _ChoiceCard(
                selected: _choice == "client",
                icon: Icons.inventory_2_outlined,
                title: "I want to send parcels",
                subtitle: "Create a client account",
                onTap: () => setState(() => _choice = "client"),
              ),
              const SizedBox(height: 12),
              _ChoiceCard(
                selected: _choice == "courier",
                icon: Icons.directions_car_filled_outlined,
                title: "I carry parcels on my route",
                subtitle: "Use the courier app — more steps required",
                onTap: () => setState(() => _choice = "courier"),
              ),
              const Spacer(),
              DropCityPrimaryButton(
                label: "Continue",
                onPressed: !canContinue
                    ? null
                    : () {
                        if (_choice == "client") {
                          widget.onClient();
                        } else {
                          widget.onCourier();
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? dropCityTransitTeal : dropCitySlateGrey.withOpacity(0.25),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: dropCitySafeSlate.withOpacity(0.06),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: dropCityTransitTeal.withOpacity(0.10),
              foregroundColor: dropCityTransitTeal,
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: dropCitySafeSlate,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: dropCitySlateGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: dropCitySlateGrey),
          ],
        ),
      ),
    );
  }
}
