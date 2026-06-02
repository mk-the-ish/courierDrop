import "package:flutter/material.dart";

import "../theme.dart";
import "../widgets/dropcity_brand.dart";

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onSignupPressed,
    required this.onLoginPressed,
    required this.appType,
  });

  final VoidCallback onSignupPressed;
  final VoidCallback onLoginPressed;
  final String appType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dropCityCloudWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const DropCityLogoMark(size: 132),
              const SizedBox(height: 36),
              const Text(
                "Send Anything, Anywhere in Harare",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dropCitySafeSlate,
                  fontSize: 22,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Powered by commuters already going your way.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dropCitySlateGrey,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const Spacer(flex: 3),
              DropCityPrimaryButton(
                label: "Get Started",
                onPressed: onSignupPressed,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onLoginPressed,
                child: const Text("I already have an account"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
